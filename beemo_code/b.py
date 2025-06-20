import os
import sys
import json
import time
import queue
import threading
import requests
import logging
import pyaudio
import vosk
import io
import google.generativeai as genai
import google.api_core.exceptions
import firebase_admin
from firebase_admin import credentials, firestore, db
from pydub import AudioSegment
from pydub.utils import make_chunks
from datetime import datetime
from typing import Dict, List, Optional, Tuple, Any
import subprocess
from enum import Enum
from gtts import gTTS
import tempfile
import RPi.GPIO as GPIO  # Add this import


FIREBASE_DATABASE_URL = "https://beemo-ccbba-default-rtdb.firebaseio.com/"
FIREBASE_WEB_API_KEY = "AIzaSyBD4jhnPrF2UMiPe1TpJJY7jQpNeGlLVxM"
FIREBASE_EMAIL = "bemmobmo@gmail.com"
FIREBASE_PASSWORD = "12345678aA"
GOOGLE_APP_CREDS = "./firebase_credentials.json"
GEMINI_API_KEY = "AIzaSyDsabVogXmS1cBIRe7S-ulgZpBcpjQ0PtU"
ELEVENLABS_API_KEY = "sk_6889f1937d882ed764e499c7a1a763b9f6fd4525e878b968"



try:
    from utils.location_service import LocationService
    from utils.weather_service import WeatherService
    from utils.news_service import NewsService
    from utils.joke_service import JokeService
    SERVICES_AVAILABLE = True
except ImportError as e:
    print(f"⚠️ Utility services not found: {e}. Creating dummy services.")
    SERVICES_AVAILABLE = False

    # Define dummy classes if imports fail
    class LocationService:
        def get_location(self): return "Location service not available"
    class WeatherService:
        def get_weather(self, *args, **kwargs): return "Weather service not available"
    class NewsService:
        def get_news(self, *args, **kwargs): return "News service not available"
    class JokeService:
        def get_joke(self): return "Joke service not available"



try:
    from emotions import BeemoEmotionDisplay
    EMOTIONS_AVAILABLE = True
except ImportError as e:
    print(f"⚠️ Emotions module not found: {e}. BEEMO will run without emotions.")
    EMOTIONS_AVAILABLE = False
    BeemoEmotionDisplay = None

# --- Constants ---

VOSK_MODEL_PATH_DEFAULT = "/home/pi/beemo/robot/vosk-model-small-en-us-0.15/vosk-model-small-en-us-0.15"

class VoiceDetectionManager:
    """Handles voice detection using Vosk model and microphone input.
    Listens for commands directly without a wake word.
    """

    def __init__(self, model_path: str = VOSK_MODEL_PATH_DEFAULT):
        self.logger = logging.getLogger(__name__)
        self.model_path = model_path
        self.model = None
        self.recognizer = None
        self.microphone = None
        self.audio_queue = queue.Queue()
        self.is_listening = False # Tracks if the audio stream and callback are active

        # Audio settings
        self.CHUNK = 4096
        self.FORMAT = pyaudio.paInt16
        self.CHANNELS = 1
        self.RATE = 16000

        self._initialize_vosk()
        self._initialize_audio_system() # Renamed for clarity

        self.stream = None # Reference to the PyAudio stream
        self._audio_thread = None # Reference to the audio callback thread

    def _initialize_vosk(self):
        """Initialize Vosk speech recognition model"""
        try:
            if not os.path.exists(self.model_path):
                self.logger.error(f"Vosk model not found at: {self.model_path}")
                raise FileNotFoundError(f"Vosk model not found at: {self.model_path}")

            self.model = vosk.Model(self.model_path)
            # Recognizer is created per command or listening session to allow reset
            self.logger.info("Vosk model loaded successfully. Recognizer will be created as needed.")

        except Exception as e:
            self.logger.error(f"Failed to initialize Vosk model: {e}")
            raise

    def _initialize_audio_system(self):
        """Initialize PyAudio for microphone input"""
        try:
            self.microphone = pyaudio.PyAudio()
            # Test microphone access briefly
            test_stream = self.microphone.open(
                format=self.FORMAT,
                channels=self.CHANNELS,
                rate=self.RATE,
                input=True,
                frames_per_buffer=self.CHUNK
            )
            test_stream.stop_stream()
            test_stream.close()
            self.logger.info("Audio system initialized successfully")

        except Exception as e:
            self.logger.error(f"Failed to initialize audio system: {e}")
            # Allow graceful failure if no mic, main app can switch to text mode
            self.microphone = None
            raise # Re-raise to be caught by AI constructor

    def _get_recognizer(self) -> vosk.KaldiRecognizer:
        """Creates or resets a Vosk recognizer instance."""
        recognizer = vosk.KaldiRecognizer(self.model, self.RATE)
        recognizer.SetWords(True) # Enable word timestamps if needed
        recognizer.SetPartialWords(True) # Enable partial results
        return recognizer

    def _audio_callback(self):
        """Audio callback function to capture microphone input and put it in a queue."""
        if not self.stream:
            self.logger.error("Audio stream not available for callback.")
            return

        self.logger.debug("Audio callback thread started.")
        while self.is_listening:
            try:
                data = self.stream.read(self.CHUNK, exception_on_overflow=False)
                self.audio_queue.put(data)
            except IOError as e:
                if e.errno == pyaudio.paInputOverflowed: # type: ignore
                    self.logger.warning("Input overflowed. Skipping frame.")
                    continue
                self.logger.error(f"Audio callback IO error: {e}")
                break # Exit thread on other IO errors
            except Exception as e:
                self.logger.error(f"Audio callback error: {e}")
                break
        self.logger.debug("Audio callback thread finished.")

    def start_listening(self) -> bool:
        """Starts the microphone stream and the audio processing callback.
        This keeps the audio_queue populated.
        """
        if self.is_listening:
            self.logger.info("Already listening.")
            return True

        if not self.microphone:
            self.logger.error("PyAudio not initialized. Cannot start listening.")
            return False
        if not self.model:
            self.logger.error("Vosk model not loaded. Cannot start listening.")
            return False

        try:
            self.stream = self.microphone.open(
                format=self.FORMAT,
                channels=self.CHANNELS,
                rate=self.RATE,
                input=True,
                frames_per_buffer=self.CHUNK
            )
            self.stream.start_stream()
            self.is_listening = True

            self._audio_thread = threading.Thread(target=self._audio_callback)
            self._audio_thread.daemon = True
            self._audio_thread.start()

            self.logger.info("Voice detection started (audio capture running).")
            return True

        except Exception as e:
            self.logger.error(f"Failed to start voice detection: {e}")
            if self.stream:
                self.stream.stop_stream()
                self.stream.close()
                self.stream = None
            self.is_listening = False
            return False

    def stop_listening(self):
        """Stops the microphone stream and audio processing callback."""
        if not self.is_listening:
            self.logger.info("Not currently listening.")
            return

        self.is_listening = False # Signal callback thread to stop

        if self._audio_thread and self._audio_thread.is_alive():
            self.logger.debug("Waiting for audio thread to join...")
            self._audio_thread.join(timeout=1.0) # Wait for thread to finish
            if self._audio_thread.is_alive():
                self.logger.warning("Audio thread did not join in time.")
        self._audio_thread = None

        if self.stream:
            try:
                if self.stream.is_active():
                    self.stream.stop_stream()
                self.stream.close()
            except Exception as e:
                self.logger.error(f"Error closing audio stream: {e}")
            self.stream = None

        # Clear the queue
        while not self.audio_queue.empty():
            try:
                self.audio_queue.get_nowait()
            except queue.Empty:
                break

        self.logger.info("Voice detection stopped (audio capture ended).")

    def listen_for_command(self, timeout: int = 10) -> Optional[str]:
        """
        Listens for a single spoken command.
        Reads from the audio_queue populated by _audio_callback.
        Returns the transcribed text or None if no command is detected within timeout.
        """
        if not self.is_listening or not self.stream or not self.stream.is_active():
            self.logger.warning("Audio stream not active. Cannot listen for command.")
            # Try to restart it if it was stopped abruptly
            if not self.is_listening:
                 if not self.start_listening():
                    return None
            elif not self.stream or not self.stream.is_active():
                self.logger.warning("Stream inactive, attempting to restart listening process.")
                self.stop_listening() # Clean up first
                if not self.start_listening():
                    return None


        local_recognizer = self._get_recognizer() # Fresh recognizer for each command
        self.logger.info(f"Listening for command (timeout: {timeout}s)...")

        start_time = time.time()
        command_parts = []
        last_speech_time = start_time
        silence_threshold = 2.0 # seconds of silence to consider command ended

        try:
            while time.time() - start_time < timeout:
                if not self.is_listening: # Check if stop_listening was called externally
                    self.logger.info("Listening interrupted externally.")
                    break
                try:
                    data = self.audio_queue.get(timeout=0.1) # Wait briefly for audio data
                except queue.Empty:
                    # No audio data, check for silence timeout if speech had started
                    if command_parts and (time.time() - last_speech_time > silence_threshold):
                        self.logger.info("Silence detected after speech, finalizing command.")
                        break
                    continue # Continue waiting for audio or main timeout

                if local_recognizer.AcceptWaveform(data):
                    result = json.loads(local_recognizer.Result())
                    text = result.get('text', '').strip()
                    if text:
                        self.logger.debug(f"Recognized segment: {text}")
                        command_parts.append(text)
                        last_speech_time = time.time() # Reset silence timer on new speech
                else:
                    partial_result = json.loads(local_recognizer.PartialResult())
                    partial_text = partial_result.get('partial', '').strip()
                    if partial_text:
                        # self.logger.debug(f"Partial: {partial_text}") # Can be noisy
                        last_speech_time = time.time() # Reset silence timer on partial speech

                # If we have started capturing command parts, and then silence occurs
                if command_parts and (time.time() - last_speech_time > silence_threshold):
                    self.logger.info("Extended silence after speech, finalizing command.")
                    break

            # Process any final piece of audio
            final_result_text = json.loads(local_recognizer.FinalResult()).get('text', '').strip()
            if final_result_text:
                command_parts.append(final_result_text)

        except Exception as e:
            self.logger.error(f"Error listening for command: {e}", exc_info=True)
            return None
        finally:
            # local_recognizer is local, no cleanup needed beyond this scope
            pass

        command = ' '.join(command_parts).strip().lower()

        if command:
            self.logger.info(f"Command recognized: {command}")
            return command
        else:
            self.logger.info("No command recognized within timeout or just silence.")
            return None

    def cleanup(self):
        """Clean up resources"""
        self.stop_listening() # Ensures stream and thread are stopped
        if self.microphone:
            self.microphone.terminate()
            self.microphone = None
        self.logger.info("VoiceDetectionManager resources cleaned up.")

class DeviceManager:
    """Enhanced device manager with better error handling and caching"""

    def __init__(self, user_id: str, firestore_db_client, firebase_db_client):
        self.user_id = user_id
        self.firestore_db = firestore_db_client        # For device metadata
        self.firebase_db = firebase_db_client          # For real-time device states
        self.locations_cache = {}
        self.device_mapping_cache = {}
        self.current_location_id = None
        self.last_sync = None
        self.logger = logging.getLogger(__name__)
        self._sync_lock = threading.Lock()

    def sync_devices(self) -> bool:
        """Thread-safe device synchronization"""
        with self._sync_lock: # Ensure only one sync operation at a time
            return self._sync_devices_internal()

    def _sync_devices_internal(self) -> bool:
        """Internal sync method with improved error handling"""
        if not self.user_id:
            self.logger.warning("⚠️ User ID not set. Cannot sync devices.")
            return False
        if not self.firestore_db:
            self.logger.warning("⚠️ Firestore client not available. Cannot sync devices.")
            return False
        if not self.firebase_db: # Check for firebase_admin.db
            self.logger.warning("⚠️ Firebase RealtimeDB client not available. Cannot sync devices.")
            return False

        try:
            # Path to device states in Firebase Realtime Database
            states_ref = self.firebase_db.reference(f'device_states/{self.user_id}')
            device_states = states_ref.get() # Fetch data

            if device_states:
                new_locations_cache = {}
                new_device_mapping_cache = {}
                self.logger.info("Syncing devices...")

                for location_id, devices_in_loc in device_states.items():
                    location_name = self._get_location_name_from_firestore(location_id)
                    current_location_entry = {
                        'name': location_name,
                        'devices': {}
                    }
                    self.logger.info(f"  Location: {location_name} (ID: {location_id})")

                    if isinstance(devices_in_loc, dict):
                        for device_id, state in devices_in_loc.items():
                            if isinstance(state, dict): # Ensure state is a dictionary
                                device_type = self._determine_device_type(state, device_id) # Pass ID for context
                                device_name_fs = self._get_device_name_from_firestore(device_id)

                                current_location_entry['devices'][device_id] = {
                                    'type': device_type,
                                    'name': device_name_fs,
                                    'state': state # Store the full state
                                }
                                self.logger.info(f"    Device: {device_name_fs} (ID: {device_id}, Type: {device_type})")

                                if device_type not in new_device_mapping_cache:
                                    new_device_mapping_cache[device_type] = []
                                new_device_mapping_cache[device_type].append(
                                    {'id': device_id, 'location_id': location_id, 'name': device_name_fs}
                                )
                    new_locations_cache[location_id] = current_location_entry


                # Atomically update caches
                self.locations_cache = new_locations_cache
                self.device_mapping_cache = new_device_mapping_cache

                if not self.current_location_id and self.locations_cache:
                    # Set a default current location if none is set and locations exist
                    self.current_location_id = next(iter(self.locations_cache))
                    self.logger.info(f"Default current location set to: {self.locations_cache[self.current_location_id]['name']}")

                self.last_sync = datetime.now()
                self.logger.info("Device sync complete.")
                return True
            else:
                self.logger.info(f"No device states found for user {self.user_id} to sync.")
                self.locations_cache = {} # Clear cache if no devices found
                self.device_mapping_cache = {}
                return False # Indicate no devices were synced

        except firebase_admin.db.ApiCallError as e: # More specific exception for DB calls
            self.logger.error(f"❌ Firebase API error during device sync: {e}", exc_info=True)
        except Exception as e:
            self.logger.error(f"❌ Unexpected error syncing devices: {e}", exc_info=True)
        return False

    def get_device_summary(self, include_offline: bool = False) -> List[Dict]:
        """Get comprehensive device summary with auto-sync if cache is stale."""
        if not self.last_sync or (datetime.now() - self.last_sync).seconds > 300: # Sync if older than 5 mins
            self.logger.info("Device cache stale or not initialized, performing sync.")
            self.sync_devices()

        summary = []
        if not self.locations_cache:
            self.logger.info("No locations in cache to summarize.")
            return summary

        for location_id, location_data in self.locations_cache.items():
            devices_summary_list = []
            for device_id, device_data in location_data['devices'].items():
                state = device_data.get('state', {})
                # Check for device connectivity/status if available in state
                if not include_offline and state.get('online') is False: # Example: if 'online' trait exists
                    continue # Skip offline devices if not requested

                status_parts = []
                if 'on' in state: # Common trait for switches, lights
                     status_parts.append('ON' if state['on'] else 'OFF')
                elif 'isOn' in state: # Alternative naming
                     status_parts.append('ON' if state['isOn'] else 'OFF')


                if 'brightness' in state:
                    status_parts.append(f"{state['brightness']}% bright")

                # Thermostat specific states
                if device_data['type'] == 'thermostat':
                    if 'thermostatTemperatureSetpoint' in state:
                        status_parts.append(f"target {state['thermostatTemperatureSetpoint']}°C")
                    if 'thermostatTemperatureAmbient' in state:
                        status_parts.append(f"ambient {state['thermostatTemperatureAmbient']}°C")
                    if 'thermostatMode' in state:
                        status_parts.append(f"mode {state['thermostatMode']}")
                elif 'targetTemperature' in state: # Generic temperature
                    status_parts.append(f"target {state['targetTemperature']}°C")
                elif 'temperature' in state: # Generic current temperature
                    status_parts.append(f"{state['temperature']}°C")


                devices_summary_list.append({
                    'id': device_id,
                    'name': device_data['name'],
                    'type': device_data['type'],
                    'status': ', '.join(status_parts) if status_parts else "Status unknown"
                })

            if devices_summary_list: # Only add location if it has (online) devices
                summary.append({
                    'location': location_data['name'],
                    'devices': devices_summary_list
                })
        return summary

    def find_devices_by_name(self, target_name_part: str) -> List[Dict]:
        """Find multiple devices matching name pattern, case-insensitive."""
        if not self.last_sync: # Ensure devices are loaded if accessed directly
            self.sync_devices()

        target_lower = target_name_part.lower()
        matching_devices = []

        if not self.locations_cache:
            return []

        for location_id, loc_data in self.locations_cache.items():
            for dev_id, dev_data in loc_data['devices'].items():
                if target_lower in dev_data['name'].lower():
                    matching_devices.append({
                        'id': dev_id,
                        'location_id': location_id, # Keep track of location_id
                        'name': dev_data['name'],
                        'type': dev_data['type'],
                        'state': dev_data.get('state', {}) # Include state for decision making
                    })
        return matching_devices

    def find_device_by_name(self, target_name_part: str) -> Optional[Dict]:
        """Find single device by name (returns the first match)."""
        devices = self.find_devices_by_name(target_name_part)
        return devices[0] if devices else None

    def _get_location_name_from_firestore(self, location_id: str) -> str:
        """Get friendly location name from Firestore."""
        try:
            # Path to user's places in Firestore
            doc_ref = self.firestore_db.collection('users').document(self.user_id).collection('places').document(location_id)
            doc = doc_ref.get()
            if doc.exists:
                return doc.to_dict().get('name', location_id) # Default to ID if name not present
        except Exception as e:
            self.logger.error(f"Error fetching location name for {location_id} from Firestore: {e}")
        return location_id.replace("_", " ").title() # Fallback formatting

    def _get_device_name_from_firestore(self, device_id: str) -> str:
        """Get friendly device name from Firestore (global device collection)."""
        try:
            doc_ref_general = self.firestore_db.collection('devices').document(device_id)
            doc_general = doc_ref_general.get()
            if doc_general.exists:
                return doc_general.to_dict().get('name', device_id)
        except Exception as e:
            self.logger.error(f"Error fetching device name for {device_id} from Firestore: {e}")
        return device_id.replace("_", " ").title() # Fallback formatting

    def _determine_device_type(self, state: Dict, device_id_for_debug: str = "") -> str:
        """
        Enhanced device type detection based on state keys (traits).
        This often aligns with how smart home platforms define devices (e.g., Google Home traits).
        """
        if not isinstance(state, dict):
            self.logger.warning(f"Device state for {device_id_for_debug} is not a dict: {state}")
            return 'unknown'

        state_keys = set(state.keys())

        # Order can matter: more specific types first
        if 'thermostatTemperatureSetpoint' in state_keys or 'thermostatMode' in state_keys:
            return 'thermostat'
        if 'action.devices.traits.Rotation' in state_keys or 'rotationDegrees' in state_keys : # Example for Blinds/Covers
             return 'blinds'
        if 'isLocked' in state_keys or 'lockState' in state_keys: # More general lock trait
            return 'lock' # Changed from 'door' for clarity
        if 'brightness' in state_keys or 'color' in state_keys or ('on' in state_keys and 'spectrumRgb' in state_keys):
            return 'light' # Common light traits
        if 'action.devices.traits.OnOff' in state_keys or 'on' in state_keys: # General On/Off trait
             # Could be a switch, plug, or a simple on/off light.
             # Further refinement might be needed based on other traits or device metadata.
            return 'switch'
        if 'volume' in state_keys or 'currentInput' in state_keys and 'action.devices.traits.MediaState' in state_keys:
            return 'speaker_or_tv' # Needs more context sometimes
        if 'channel' in state_keys : # Older TV style
            return 'tv'

        # Fallback for computer detection (less reliable, relies on naming)
        name_lower = str(state.get('name', '')).lower() # 'name' might not be in RTDB state directly
        # Instead, one might fetch from Firestore if type determination is critical and not in state
        if 'computer' in name_lower or 'pc' in name_lower:
            # Check if device_name_fs (from Firestore) was passed or can be fetched here
            # For now, this relies on state having a 'name' field, which is not standard.
            # Better: rely on specific traits for computers if they exist.
            if 'powerState' in state_keys: # A hypothetical trait for computers
                return 'computer'

        self.logger.debug(f"Could not determine specific type for device {device_id_for_debug} with keys {state_keys}, defaulting to 'unknown'.")
        return 'unknown'


class BeemoMode(Enum):
    ASSISTANT = "assistant"
    PLATFORM = "platform"

class EnhancedSmartHomeAI:
    """Enhanced smart home AI with direct voice commands and improved functionality"""

    def __init__(self):
        self.logger = self._setup_logging()

        # Initialize emotion display first (before other components)
        try:
            if EMOTIONS_AVAILABLE:
                self.emotion_display = BeemoEmotionDisplay()
                self.emotion_display.trigger_emotion('startup')
                self.logger.info("Beemo Emotion Display initialized successfully")
            else:
                self.emotion_display = None
                self.logger.warning("Running without emotion display")
        except Exception as e:
            self.logger.error(f"Failed to initialize Beemo Emotion Display: {e}")
            self.emotion_display = None

        # Initialize utility services with error handling
        try:
            self.location_service = LocationService()
            self.weather_service = WeatherService()
            self.news_service = NewsService()
            self.joke_service = JokeService()
            if SERVICES_AVAILABLE:
                self.logger.info("Utility services initialized successfully")
            else:
                self.logger.warning("Using dummy utility services - some features may be limited")
        except Exception as e:
            self.logger.error(f"Error initializing utility services: {e}")
            # Create dummy instances if initialization fails
            self.location_service = LocationService()
            self.weather_service = WeatherService()
            self.news_service = NewsService()
            self.joke_service = JokeService()

        # Gemini API Configuration
        self.gemini_api_key = GEMINI_API_KEY
        genai.configure(api_key=self.gemini_api_key)
        self.model = genai.GenerativeModel('gemini-1.5-flash-latest')
        self.logger.info("Gemini API configured successfully")

        # ElevenLabs Configuration
        self.elevenlabs_api_key = ELEVENLABS_API_KEY
        self.elevenlabs_voice_id = "ThT5KcBeYPX3keUQqHPh"  # Default female voice
        self.elevenlabs_api_url = "https://api.elevenlabs.io/v1/text-to-speech"
        self.elevenlabs_headers = {
            "Accept": "audio/mpeg",
            "Content-Type": "application/json",
            "xi-api-key": ELEVENLABS_API_KEY
        }

        # Firebase Configuration - Using static values
        self.firebase_web_api_key = FIREBASE_WEB_API_KEY
        self.firebase_email = FIREBASE_EMAIL
        self.firebase_password = FIREBASE_PASSWORD
        self.firebase_db_url = FIREBASE_DATABASE_URL
        self.firebase_project_id = 'beemo-ccbba'  # Extracted from database URL
        self.google_app_creds = GOOGLE_APP_CREDS

        # Initialize components
        self.voice_manager = None
        self.user_id = None
        self.firebase_app_admin = None
        self.pyrebase_auth = None
        self.firestore_db_client = None
        self.firebase_rtdb_client = None
        self.device_manager = None
        self.conversation_history = []

        self.voice_mode_enabled = True # Flag to control if voice mode attempts initialization
        self.running = True

        # Initialize additional services
        self.weather_service = WeatherService()
        self.news_service = NewsService()
        self.location_service = LocationService()
        self.joke_service = JokeService()

        # Initialize Beemo Emotion Display
        try:
            self.emotion_display = BeemoEmotionDisplay() if BeemoEmotionDisplay else None
            if self.emotion_display:
                # Start sensor monitoring for physical interactions
                self.emotion_display.start_sensor_monitoring()
                self.logger.info("Beemo Emotion Display initialized successfully")
            else:
                self.logger.warning("Beemo Emotion Display not available - running without emotions")
        except Exception as e:
            self.logger.error(f"Failed to initialize Beemo Emotion Display: {e}")
            self.emotion_display = None

        self.current_mode = BeemoMode.ASSISTANT
        self.platform_commands = {
            "switch": self._switch_mode,
            "status": self._platform_status,
            "help": self._platform_help,
            "reboot": self._platform_reboot,
            "shutdown": self._platform_shutdown
        }

        self.tts_lock = threading.Lock()  # Add a lock to synchronize TTS and command input

        self._initialize_system()

    def _setup_logging(self) -> logging.Logger:
        """Setup enhanced logging configuration"""
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(name)s - %(levelname)s - %(module)s.%(funcName)s:%(lineno)d - %(message)s',
            handlers=[
                logging.FileHandler('smart_home_ai.log', mode='w'),
                logging.StreamHandler(sys.stdout)
            ]
        )
        return logging.getLogger(__name__)

    def _initialize_system(self):
        """Initialize all system components sequentially."""
        self.logger.info("System initialization started.")

        if not self._initialize_firebase_and_auth():
            self.logger.error("Critical: Firebase initialization or authentication failed. Cannot proceed.")
            self.speak_or_print("Error: Could not connect to Firebase services or authenticate. Please check configuration and network.")
            self.user_id = None
            return

        if self.voice_mode_enabled:
            try:
                self.voice_manager = VoiceDetectionManager()
                self.logger.info("VoiceDetectionManager initialized.")
            except Exception as e:
                self.logger.warning(f"VoiceDetectionManager failed to initialize: {e}. Voice input will be disabled.", exc_info=True)
                self.speak_or_print("Warning: Voice input could not be set up. Falling back to text mode if possible.")
                self.voice_manager = None
        else:
            self.logger.info("Voice mode is disabled by configuration.")
            self.voice_manager = None

        if self.user_id and self.firestore_db_client and self.firebase_rtdb_client:
            self.device_manager = DeviceManager(
                self.user_id,
                self.firestore_db_client,
                self.firebase_rtdb_client
            )
            if self.device_manager.sync_devices():
                self.logger.info("DeviceManager initialized and initial sync successful.")
            else:
                self.logger.warning("DeviceManager initialized, but initial sync failed or found no devices.")
            self._setup_system_prompt()
        else:
            self.logger.error("Cannot initialize DeviceManager: Missing user_id or DB clients.")
            self.speak_or_print("Error: Could not set up device management.")

        self.logger.info("System initialization complete.")

        # Save Beemo status to Firestore at startup
        try:
            self._save_beemo_status_to_firestore(online=True)
            self._setup_status_listener()
        except Exception as e:
            self.logger.error(f"Failed to save Beemo status to Firestore or set up listener: {e}")

    def _initialize_firebase_and_auth(self) -> bool:
        """Initialize Firebase Admin SDK and Pyrebase for authentication."""
        try:
            if not firebase_admin._apps:
                if not os.path.exists(self.google_app_creds):
                    self.logger.error(f"Firebase admin credentials file not found: {self.google_app_creds}")
                    return False

                cred = credentials.Certificate(self.google_app_creds)
                self.firebase_app_admin = firebase_admin.initialize_app(cred, {
                    'databaseURL': FIREBASE_DATABASE_URL
                })
                self.logger.info("Firebase Admin SDK initialized.")
            else:
                self.firebase_app_admin = firebase_admin.get_app()
                self.logger.info("Using existing Firebase Admin SDK app.")

            self.firestore_db_client = firestore.client(app=self.firebase_app_admin)
            self.firebase_rtdb_client = db

            # Create collections for tracking
            self.commands_collection = self.firestore_db_client.collection('command_history')
            self.emotion_states_collection = self.firestore_db_client.collection('emotion_states')
            self.logger.info("Firestore collections initialized.")

            firebase_config_pyrebase = self._build_firebase_config_for_pyrebase()
            if not firebase_config_pyrebase:
                self.logger.error("Failed to build Pyrebase config.")
                return False

            import pyrebase
            pyrebase_app = pyrebase.initialize_app(firebase_config_pyrebase)
            self.pyrebase_auth = pyrebase_app.auth()
            self.logger.info("Pyrebase initialized for authentication.")

            if not FIREBASE_EMAIL or not FIREBASE_PASSWORD:
                self.logger.error("Firebase email or password not set in environment variables.")
                return False

            user_creds = self.pyrebase_auth.sign_in_with_email_and_password(
                FIREBASE_EMAIL, FIREBASE_PASSWORD
            )
            self.user_id = user_creds['localId']
            self.logger.info(f"User authenticated successfully via Pyrebase. User ID: {self.user_id}")
            return True

        except Exception as e:
            self.logger.error(f"Firebase initialization or authentication failed: {e}", exc_info=True)
            return False

    def _build_firebase_config_for_pyrebase(self) -> Optional[Dict]:
        """Builds Firebase configuration for Pyrebase client."""
        try:
            project_id = self.firebase_project_id
            if not project_id:
                self.logger.warning("FIREBASE_PROJECT_ID not set in .env. Attempting to derive from DB URL.")
                if self.firebase_db_url and 'https://' in self.firebase_db_url:
                    domain_part = self.firebase_db_url.split('/')[2]
                    project_id_candidate = domain_part.split('.')[0]
                    if project_id_candidate.endswith('-default-rtdb'):
                        project_id = project_id_candidate.replace('-default-rtdb', '')
                    else:
                        project_id = project_id_candidate
                    self.logger.info(f"Derived project ID: {project_id}")
                else:
                    self.logger.error("Cannot derive Firebase project ID: DB URL is invalid or missing.")
                    return None

            if not project_id:
                self.logger.error("Firebase project ID could not be determined.")
                return None

            auth_domain = f"{project_id}.firebaseapp.com"
            storage_bucket = f"{project_id}.appspot.com"

            config = {
                "apiKey": self.firebase_web_api_key,
                "authDomain": auth_domain,
                "databaseURL": self.firebase_db_url,
                "projectId": project_id,
                "storageBucket": storage_bucket,
            }

            if not all([config["apiKey"], config["authDomain"], config["databaseURL"], config["projectId"]]):
                self.logger.error(f"Incomplete Firebase config for Pyrebase: One or more critical fields missing. Config: {config}")
                return None

            self.logger.debug(f"Pyrebase config built: {config}")
            return config

        except Exception as e:
            self.logger.error(f"Failed to build Firebase config for Pyrebase: {e}", exc_info=True)
            return None

    def _setup_system_prompt(self):
        """Setup enhanced system prompt with better context awareness."""
        current_time_str = datetime.now().strftime('%I:%M %p on %A, %B %d, %Y')

        location_name = "your current home"
        if self.device_manager and self.device_manager.current_location_id and \
           self.device_manager.locations_cache.get(self.device_manager.current_location_id):
            location_name = self.device_manager.locations_cache[self.device_manager.current_location_id]['name']

        system_content = f"""You are Beemo, a friendly and intelligent smart home assistant. You can control devices and have natural conversations.

Current Context:

Time: {current_time_str}

Location: {location_name}

Your Capabilities:

Control smart home devices using natural language

Get weather information for any city or current location

Fetch latest news (general or by category)

Tell jokes

Determine current location

Answer questions and engage in conversation

Remember context from earlier in the conversation

When handling weather requests:

For specific cities: SERVICE_REQUEST: {{"service": "weather", "params": {{"city": "city_name"}}}}

For current location: SERVICE_REQUEST: {{"service": "weather", "params": {{"location": "current"}}}}

Special Instructions:

When you detect a device control intent, include a JSON block in your response like this:
DEVICE_CONTROL: {{"device": "device_name", "action": "turn_on/turn_off/set", "value": "optional_value"}}

When you detect a request for weather, news, jokes, or location, include a SERVICE_REQUEST block:
SERVICE_REQUEST: {{"service": "weather/news/joke/location", "params": {{"city": "city_name"}} }}

Maintain conversation context and remember recent device states.

Be natural and friendly in your responses, while being efficient with device control. Your primary response to the user should NOT contain the DEVICE_CONTROL block, that's for programmatic use.
"""
        if self.device_manager:
            device_summary_for_prompt = []
            raw_summary = self.device_manager.get_device_summary(include_offline=True)
            if raw_summary:
                for loc in raw_summary:
                    loc_devices_parts = []
                    for dev in loc['devices']:
                        loc_devices_parts.append(f"{dev['name']} (type: {dev['type']}, ID: {dev['id']})")
                    device_summary_for_prompt.append(f"In {loc['location']}: {'; '.join(loc_devices_parts)}")

                devices_context = "\nAvailable Devices Overview:\n" + "\n".join(device_summary_for_prompt)
                max_device_context_len = 2000
                if len(devices_context) > max_device_context_len:
                    devices_context = devices_context[:max_device_context_len] + "\n... (device list truncated)"
                system_content += devices_context
            else:
                system_content += "\nNo smart home devices are currently synced or available."
        else:
            system_content += "\nDevice manager not available. Cannot list devices."


        self.conversation_history = [{"role": "system", "content": system_content}]
        self.logger.info("System prompt configured for LLM.")
        self.logger.debug(f"System prompt content:\n{system_content[:500]}...")


    def call_openrouter(self, messages: List[Dict]) -> str:
        """Call the Gemini API for LLM completion (backward-compatible)."""
        if not self.gemini_api_key or not self.model:
            self.logger.error("Gemini API key not set or model not initialized.")
            return "I'm sorry, I can't process requests right now (AI service not configured)."

        system_instruction_text = None
        conversation_messages = messages

        # Extract the system prompt, if it exists.
        if messages and messages[0]["role"] == "system":
            system_instruction_text = messages[0]["content"]
            conversation_messages = messages[1:]

        # Build the Gemini-formatted conversation list.
        gemini_contents = []
        is_first_user_message = True

        for msg in conversation_messages:
            role = "model" if msg["role"] == "assistant" else "user"
            content = msg["content"]

            # Instead of a special parameter, prepend system instructions to the first user message.
            if role == "user" and is_first_user_message and system_instruction_text:
                content = f"{system_instruction_text}\n\n---\n\nUser Question: {content}"
                is_first_user_message = False  # Ensure it only happens once

            gemini_contents.append({"role": role, "parts": [{"text": content}]})

        if not gemini_contents:
            self.logger.error("No user content found to send to Gemini.")
            return "I'm sorry, I could not determine your query."

        try:
            # The gemini_contents list now has the system prompt baked into the first user turn.
            # Call generate_content WITHOUT the system_instruction parameter.
            response = self.model.generate_content(gemini_contents)
            return response.text

        except google.api_core.exceptions.NotFound as e:
            self.logger.error(f"Gemini API request failed (NotFound): {e}", exc_info=True)
            configured_model_name_str = self.model.model_name if self.model else "None"
            try:
                self.logger.info("Attempting to list available Gemini models for diagnosis...")
                available_models_for_gen_content = [m.name for m in genai.list_models() if 'generateContent' in m.supported_generation_methods]
                self.logger.info(f"Configured model: {configured_model_name_str}")
                self.logger.info(f"Available models: {available_models_for_gen_content}")
                if configured_model_name_str not in available_models_for_gen_content:
                    self.logger.warning("The configured model was not found in the available list.")
            except Exception as list_models_exception:
                self.logger.error(f"Failed to list available models: {list_models_exception}")
            return f"I'm sorry, the AI model ('{configured_model_name_str}') could not be found or is not supported. Please check logs."
        except Exception as e:
            self.logger.error(f"Gemini API request failed: {e}", exc_info=True)
            return f"I'm sorry, there was an error communicating with the AI service ({type(e).__name__}). Check library compatibility."


    def _switch_mode(self, args=None):
        """Switch between assistant and platform modes"""
        if self.current_mode == BeemoMode.ASSISTANT:
            self.current_mode = BeemoMode.PLATFORM
            print(">> MODE: PLATFORM (command center)")
            if self.emotion_display:
                self.emotion_display.display_animation('excited', loop=1)
            return "Switched to platform mode. Type 'help' for commands."
        else:
            self.current_mode = BeemoMode.ASSISTANT
            print(">> MODE: BEEMO (assistant)")
            if self.emotion_display:
                self.emotion_display.display_animation('happy', loop=1)
            return "Switched to assistant mode."

    def _platform_status(self, args=None):
        """Display system status"""
        status = {
            "mode": self.current_mode.value,
            "voice_enabled": bool(self.voice_manager and self.voice_manager.is_listening),
            "display_enabled": bool(self.emotion_display and self.emotion_display.display_initialized),
            "servo_enabled": bool(self.emotion_display and self.emotion_display.servo_controller.servo_enabled),
            "firebase_connected": bool(self.user_id and self.firebase_rtdb_client),
            "devices_synced": bool(self.device_manager and self.device_manager.last_sync)
        }
        return json.dumps(status, indent=2)

    def _platform_help(self, args=None):
        """Display available platform commands"""
        commands = {
            "switch": "Switch between assistant and platform modes",
            "status": "Display system status",
            "help": "Show this help message",
            "reboot": "Reboot the system",
            "shutdown": "Shutdown the system"
        }
        return json.dumps(commands, indent=2)

    def _platform_reboot(self, args=None):
        """Reboot the system"""
        self.speak_or_print("Rebooting system...")
        if self.emotion_display:
            self.emotion_display.display_animation('dizzy', loop=1)
        self.shutdown()
        os.execv(sys.executable, ['python'] + sys.argv)
        return "Rebooting..."

    def _platform_shutdown(self, args=None):
        """Shutdown the system"""
        self.speak_or_print("Shutting down...")
        if self.emotion_display:
            self.emotion_display.display_animation('sleep', loop=1)
        self.running = False
        return "Shutting down..."

    def process_platform_command(self, command_str):
        """Process commands in platform mode"""
        parts = command_str.lower().strip().split()
        if not parts:
            return "No command provided. Type 'help' for available commands."

        command = parts[0]
        args = parts[1:] if len(parts) > 1 else None

        response = None
        if command in self.platform_commands:
            try:
                response = self.platform_commands[command](args)
            except Exception as e:
                self.logger.error(f"Error executing platform command: {e}")
                response = f"Error: {str(e)}"
        else:
            response = f"Unknown command: {command}. Type 'help' for available commands."

        # Save platform response to Firestore under this user
        try:
            if self.firestore_db_client and self.user_id:
                platform_collection = self.firestore_db_client.collection('platforme')
                doc_ref = platform_collection.document()
                doc_ref.set({
                    'user_id': self.user_id,
                    'command': command_str,
                    'response': response,
                    'timestamp': firestore.SERVER_TIMESTAMP
                })
                self.logger.info("Platform response saved to Firestore.")
        except Exception as e:
            self.logger.error(f"Failed to save platform response to Firestore: {e}")

        return response

    def process_command(self, user_input: str):
        """Process user input using LLM, handle device control, and respond."""
        if not user_input or not user_input.strip():
            self.logger.info("Empty command received.")
            return

        # Save command to Firestore with timestamp
        command_doc = {
            'user_id': self.user_id,
            'command': user_input,
            'timestamp': firestore.SERVER_TIMESTAMP,
            'device_states': {},  # Will be updated if device control happens
            'emotion_displayed': None  # Will be updated after emotion processing
        }
        command_ref = self.commands_collection.document()
        
        # Show listening emotion when processing command
        if self.emotion_display:
            self.emotion_display.trigger_emotion('command', user_input)

        # Check if it's a platform-related command
        platform_keywords = ["platform", "command center", "command"]
        if any(keyword in user_input.lower() for keyword in platform_keywords):
            try:
                # Call agent.py with platform command
                result = subprocess.run(
                    ["python", "/home/pi/beemo/robot/agent.py", "platform", user_input],
                    capture_output=True,
                    text=True,
                    check=True
                )
                try:
                    response_data = json.loads(result.stdout)
                    if "error" in response_data:
                        self.speak_or_print(f"Platform error: {response_data['error']}")
                    else:
                        self.speak_or_print(f"Platform response: {response_data.get('response', 'No response')}")
                except json.JSONDecodeError:
                    self.speak_or_print("Received invalid response from platform")
                return
            except subprocess.CalledProcessError as e:
                self.logger.error(f"Error calling platform command: {e}")
                self.speak_or_print("Sorry, there was an error processing your platform command.")
                return

        # Continue with normal command processing
        self.logger.info(f"User command: {user_input}")
        self.conversation_history.append({"role": "user", "content": user_input})

        current_conversation = [self.conversation_history[0]] + self.conversation_history[-12:]

        ai_response_raw = self.call_openrouter(current_conversation)
        self.logger.info(f"LLM Raw Response: {ai_response_raw}")

        human_readable_response = ai_response_raw

        if "DEVICE_CONTROL:" in ai_response_raw:
            try:
                control_part = ai_response_raw.split("DEVICE_CONTROL:")[1].strip()
                json_start_index = control_part.find('{')
                json_end_index = control_part.rfind('}')

                if json_start_index != -1 and json_end_index != -1 and json_start_index < json_end_index:
                    json_str = control_part[json_start_index : json_end_index+1]
                    self.logger.debug(f"Extracted JSON for device control: {json_str}")
                    control_data_list = json.loads(json_str)
                    human_readable_response = ai_response_raw.split("DEVICE_CONTROL:")[0].strip()

                    if not isinstance(control_data_list, list):
                        control_data_list = [control_data_list]

                    control_feedback_parts = []
                    for control_data in control_data_list:
                        if isinstance(control_data, dict):
                            device_name_or_id = control_data.get('device', '')
                            action = control_data.get('action', '')
                            value = control_data.get('value', None)

                            if device_name_or_id and action:
                                success, msg = self._execute_device_command(device_name_or_id, action, value)
                                control_feedback_parts.append(msg)
                            else:
                                control_feedback_parts.append(f"Skipped invalid control command: {control_data}")
                        else:
                             control_feedback_parts.append(f"Skipped non-dict control entry: {control_data}")

                    feedback_summary = ". ".join(control_feedback_parts)
                    if not human_readable_response:
                        human_readable_response = feedback_summary if feedback_summary else "Okay, I've processed that."
                    else:
                         human_readable_response += f" ({feedback_summary})"
                else:
                    self.logger.warning("DEVICE_CONTROL found, but JSON block is malformed or missing.")
                    if "DEVICE_CONTROL:" in human_readable_response:
                         human_readable_response = human_readable_response.split("DEVICE_CONTROL:")[0].strip()

            except json.JSONDecodeError as e:
                self.logger.error(f"Error parsing JSON from LLM for device control: {e}. Raw part: '{control_part}'")
                human_readable_response = ai_response_raw.split("DEVICE_CONTROL:")[0].strip()
                human_readable_response += " (I tried to control a device but had trouble understanding the details.)"
            except Exception as e:
                self.logger.error(f"Error processing device control instructions: {e}", exc_info=True)
                human_readable_response += " (An error occurred while trying to control a device.)"

        if "SERVICE_REQUEST:" in ai_response_raw:
            try:
                service_part = ai_response_raw.split("SERVICE_REQUEST:")[1].strip()
                json_start = service_part.find('{')
                json_end = service_part.rfind('}')
                if json_start != -1 and json_end != -1:
                    service_data = json.loads(service_part[json_start:json_end+1])
                    service_type = service_data.get('service')
                    params = service_data.get('params', {})

                    service_response = None
                    if service_type == 'weather':
                        if 'city' in params:
                            service_response = self.weather_service.get_weather(city=params['city'])
                        elif 'location' in user_input.lower():
                            # If user asks for "my location" or "current location"
                            try:
                                location = self.location_service.get_location()
                                if location and isinstance(location, dict):
                                    service_response = self.weather_service.get_weather(
                                        lat=location.get('latitude'),
                                        lon=location.get('longitude')
                                    )
                                else:
                                    service_response = self.weather_service.get_weather(city="London")  # Default fallback
                            except Exception as e:
                                self.logger.error(f"Error getting location for weather: {e}")
                                service_response = "I couldn't determine your location. Please specify a city name."
                    elif service_type == 'news':
                        service_response = self.news_service.get_news(
                            country=params.get('country', 'us'),
                            category=params.get('category'),
                            max_articles=params.get('max_articles', 5)
                        )
                    elif service_type == 'joke':
                        service_response = self.joke_service.get_joke()
                    elif service_type == 'location':
                        service_response = self.location_service.get_location()

                    if service_response:
                        human_readable_response = service_response
                        # Update conversation history with the actual response
                        self.conversation_history[-1]["content"] = human_readable_response

            except json.JSONDecodeError as e:
                self.logger.error(f"Error parsing service request JSON: {e}")
                human_readable_response = "I had trouble understanding the service request format."
            except Exception as e:
                self.logger.error(f"Error processing service request: {e}")
                human_readable_response = f"Sorry, I had trouble with that request: {str(e)}"

        # Show appropriate emotion based on response type
        if self.emotion_display:
            emotion_type = 'neutral'  # default emotion

            if "sorry" in human_readable_response.lower() or "error" in human_readable_response.lower():
                emotion_type = 'error'
            elif any(word in human_readable_response.lower() for word in ['success', 'done', 'turned on', 'turned off']):
                emotion_type = 'success'
            elif "weather" in human_readable_response.lower():
                emotion_type = 'weather'
            elif "joke" in human_readable_response.lower():
                emotion_type = 'joke'

            # Use the new trigger_emotion method
            self.emotion_display.trigger_emotion(emotion_type)

        # Update command document with AI response
        command_doc.update({
            'ai_response': human_readable_response,
            'emotion_displayed': self.emotion_display.current_emotion if self.emotion_display else None
        })
        command_ref.set(command_doc)

        self.speak_or_print(human_readable_response)
        self.conversation_history.append({"role": "assistant", "content": human_readable_response})

        if len(self.conversation_history) > 13:
            self.conversation_history = [self.conversation_history[0]] + self.conversation_history[-12:]

    def _execute_device_command(self, device_name_or_id: str, action: str, value: Any) -> Tuple[bool, str]:
        """Executes a command on a device."""
        if not self.device_manager:
            return False, "Device manager not available."

        target_device = None
        all_devices = [] # Build a flat list of all devices for easier ID lookup
        for loc_id, loc_data in self.device_manager.locations_cache.items():
            for dev_id, dev_data in loc_data['devices'].items():
                all_devices.append({'id': dev_id, 'location_id': loc_id, **dev_data}) # Add location_id here

        for dev in all_devices:
            if dev['id'] == device_name_or_id:
                target_device = dev
                break

        if not target_device:
            matching_devices = self.device_manager.find_devices_by_name(device_name_or_id)
            if not matching_devices:
                return False, f"Device '{device_name_or_id}' not found."
            if len(matching_devices) > 1:
                target_device = matching_devices[0]
                self.logger.warning(f"Multiple devices match '{device_name_or_id}', using first match: {target_device['name']}")
            else:
                target_device = matching_devices[0]

        device_id = target_device['id']
        # Ensure location_id is present in target_device (it should be from find_devices_by_name or all_devices list)
        location_id = target_device.get('location_id')
        if not location_id:
             self.logger.error(f"Could not determine location_id for device {device_id}. Aborting command.")
             return False, f"Internal error: Missing location for device {target_device['name']}."
        device_friendly_name = target_device['name']

        self.logger.info(f"Executing action '{action}' on device '{device_friendly_name}' (ID: {device_id}) with value '{value}'")

        state_updates = {}
        success_msg = ""
        action = action.lower()

        if action == "turn_on":
            state_updates['isOn'] = True
            success_msg = f"Turned on {device_friendly_name}."
        elif action == "turn_off":
            state_updates['isOn'] = False
            success_msg = f"Turned off {device_friendly_name}."
        elif action == "set_brightness":
            try:
                brightness_val = int(value)
                if 0 <= brightness_val <= 100:
                    state_updates['brightness'] = brightness_val
                    if brightness_val > 0 and not target_device.get('state', {}).get('isOn', False) :
                        state_updates['isOn'] = True
                    success_msg = f"Set brightness of {device_friendly_name} to {brightness_val}%."
                else:
                    return False, "Brightness value must be between 0 and 100."
            except (ValueError, TypeError):
                return False, "Invalid brightness value. Must be a number."
        elif action == "set_temperature" and target_device['type'] == 'thermostat':
            try:
                temp_val = float(value)
                state_updates['thermostatTemperatureSetpoint'] = temp_val
                success_msg = f"Set {device_friendly_name} to {temp_val}°C."
            except (ValueError, TypeError):
                return False, "Invalid temperature value."
        elif action == "lock" and target_device['type'] == 'lock':
            state_updates['isLocked'] = True
            success_msg = f"Locked {device_friendly_name}."
        elif action == "unlock" and target_device['type'] == 'lock':
            state_updates['isLocked'] = False
            success_msg = f"Unlocked {device_friendly_name}."
        else:
            return False, f"Action '{action}' is not supported for device type '{target_device['type']}' or is unknown."

        if not state_updates:
            return False, "No valid state update derived from command."

        try:
            device_ref = self.firebase_rtdb_client.reference(f'device_states/{self.user_id}/{location_id}/{device_id}')
            device_ref.update(state_updates)
            self.logger.info(f"Successfully updated state for {device_friendly_name}: {state_updates}")
            if self.device_manager and target_device:
                target_device.get('state', {}).update(state_updates)

            return True, success_msg
        except Exception as e:
            self.logger.error(f"Failed to update device {device_friendly_name} state in Firebase: {e}", exc_info=True)
            return False, f"Failed to control {device_friendly_name} due to a database error."


    def speak_or_print(self, text: str):
        """Speak text using Google Text-to-Speech with direct playback."""
        self.logger.info(f"Beemo says: {text}")

        if not text.strip():
            return

        temp_file = None
        p = None
        stream = None

        with self.tts_lock:  # Block other speech or listening while TTS is running
            try:
                # Create gTTS instance
                tts = gTTS(text=text, lang='en')

                # Create a temporary file for the audio
                temp_file = tempfile.NamedTemporaryFile(suffix='.mp3', delete=False)
                temp_filename = temp_file.name
                temp_file.close()  # Close the file handle immediately

                # Save the speech to the temporary file
                tts.save(temp_filename)

                # Load the audio file with pydub
                audio_segment = AudioSegment.from_mp3(temp_filename)

                # Initialize PyAudio
                p = pyaudio.PyAudio()
                stream = p.open(
                    format=p.get_format_from_width(audio_segment.sample_width),
                    channels=audio_segment.channels,
                    rate=audio_segment.frame_rate,
                    output=True
                )

                # Play audio in chunks
                audio_chunks = make_chunks(audio_segment, 250)  # 250ms chunks
                for chunk in audio_chunks:
                    stream.write(chunk._data)

            except Exception as e:
                self.logger.error(f"TTS (gTTS) processing/playback error: {e}", exc_info=True)
                print(f"Beemo (TTS Error): {text}")
            finally:
                # Clean up resources in reverse order of creation
                if stream:
                    stream.stop_stream()
                    stream.close()
                if p:
                    p.terminate()
                # Wait a tiny bit before trying to delete the file
                time.sleep(0.1)
                if temp_file:
                    try:
                        os.unlink(temp_filename)
                    except Exception as e:
                        self.logger.warning(f"Could not delete temporary file {temp_filename}: {e}")
            print("Beemo finished speaking.")  # Print after TTS playback is complete

    def play_boot_sound(self):
        """Play boot sound on startup"""
        boot_sound_path = "/home/pi/beemo/robot/boot.mp3"
        if not os.path.exists(boot_sound_path):
            self.logger.warning(f"Boot sound file not found at {boot_sound_path}")
            return

        try:
            audio_segment = AudioSegment.from_mp3(boot_sound_path)
            p = pyaudio.PyAudio()
            stream = p.open(
                format=p.get_format_from_width(audio_segment.sample_width),
                channels=audio_segment.channels,
                rate=audio_segment.frame_rate,
                output=True
            )

            try:
                # Play audio in chunks
                audio_chunks = make_chunks(audio_segment, 250)
                for chunk in audio_chunks:
                    stream.write(chunk._data)
            finally:
                stream.stop_stream()
                stream.close()
                p.terminate()

        except Exception as e:
            self.logger.error(f"Error playing boot sound: {e}", exc_info=True)

    def run(self):
        """Main loop for the AI to listen and respond."""
        if not self.user_id:
            self.logger.error("User not authenticated. AI cannot run.")
            self.speak_or_print("I'm sorry, I couldn't log you in. Please check the configuration.")
            return

        # Start with bootup animation and sound
        if self.emotion_display:
            try:
                self.emotion_display.startup_sequence()
                # Start sensor monitoring after startup sequence
                self.emotion_display.start_sensor_monitoring()
            except Exception as e:
                self.logger.error(f"Error during emotion display startup: {e}")

        # Play boot sound
        self.play_boot_sound()

        self.speak_or_print(f"Hello! I'm Beemo, your smart home assistant. How can I help you today?")

        if self.voice_manager:
            if not self.voice_manager.start_listening():
                self.speak_or_print("Warning: I'm having trouble accessing the microphone for continuous listening.")
                if self.emotion_display:
                    self.emotion_display.display_animation('sad', loop=1)
            else:
                self.speak_or_print("I'm listening for your commands.")
                if self.emotion_display:
                    self.emotion_display.display_animation('happy', loop=1)
        else:
            self.speak_or_print("Voice input is not available. Please use text input.")
            if self.emotion_display:
                self.emotion_display.display_animation('neutral', loop=1)

        # Print initial mode
        print(">> MODE: BEEMO (assistant)")

        while self.running:
            try:
                user_input = ""
                # Get input based on current mode
                if self.current_mode == BeemoMode.ASSISTANT:
                    if self.voice_manager and self.voice_manager.is_listening:
                        self.logger.info("Waiting for voice command...")
                        # Block listening while TTS is running
                        with self.tts_lock:
                            pass  # Wait for any ongoing TTS to finish before listening
                        command_text = self.voice_manager.listen_for_command(timeout=15)
                        if command_text:
                            user_input = command_text
                        else:
                            continue
                    else:
                        # For text input, also block until TTS is done
                        with self.tts_lock:
                            pass
                        user_input = input("You: ").strip()
                else:  # Platform mode
                    with self.tts_lock:
                        pass
                    user_input = input("platform> ").strip()

                if not user_input:
                    continue

                # Handle mode switching command in either mode
                if user_input.lower() in ["switch mode", "switch"]:
                    response = self._switch_mode()
                    print(f">> Now in {'PLATFORM' if self.current_mode == BeemoMode.PLATFORM else 'BEEMO (assistant)'} mode")
                    self.speak_or_print(response)
                    continue

                # Process input based on current mode
                if self.current_mode == BeemoMode.ASSISTANT:
                    if user_input.lower() in ["exit", "quit", "shutdown beemo", "goodbye beemo"]:
                        self.speak_or_print("Goodbye! Shutting down.")
                        self.running = False
                        break
                    self.process_command(user_input)
                else:  # Platform mode
                    if user_input.lower() in ["exit", "quit"]:
                        response = self._switch_mode()  # Switch back to assistant mode
                        print(f">> Now in {'PLATFORM' if self.current_mode == BeemoMode.PLATFORM else 'BEEMO (assistant)'} mode")
                        self.speak_or_print(response)
                    else:
                        response = self.process_platform_command(user_input)
                        print(response)

            except KeyboardInterrupt:
                self.logger.info("Keyboard interrupt received. Shutting down.")
                self.speak_or_print("Shutting down as requested.")
                self.running = False
                break
            except Exception as e:
                self.logger.error(f"Error in main run loop: {e}", exc_info=True)
                self.speak_or_print("I encountered an unexpected problem. Please try again.")
                time.sleep(1)

        self.shutdown()


    def _setup_status_listener(self):
        """Listen to Firestore for remote restart/shutdown commands."""
        if not self.firestore_db_client or not self.user_id:
            self.logger.warning("Firestore client or user_id not available, cannot set up status listener.")
            return

        status_collection = self.firestore_db_client.collection('beemo_status')
        # Use a fixed doc id for this robot/user (so app can update it)
        doc_id = f"{self.user_id}_robot"
        self.status_doc_ref = status_collection.document(doc_id)

        def on_snapshot(doc_snapshot, changes, read_time):
            for doc in doc_snapshot:
                data = doc.to_dict()
                if not data:
                    continue
                # Check for remote command
                remote_cmd = data.get("remote_command")
                if remote_cmd == "restart":
                    self.logger.info("Remote restart command received from app.")
                    self._save_beemo_status_to_firestore(online=False, last_command="restart")
                    self.speak_or_print("Restarting as requested from the app.")
                    self.shutdown()
                    os.execv(sys.executable, ['python'] + sys.argv)
                elif remote_cmd == "shutdown":
                    self.logger.info("Remote shutdown command received from app.")
                    self._save_beemo_status_to_firestore(online=False, last_command="shutdown")
                    self.speak_or_print("Shutting down as requested from the app.")
                    self.running = False
                    self.shutdown()
                    os._exit(0)
                # Optionally, clear the remote_command field after handling
                if remote_cmd in ("restart", "shutdown"):
                    try:
                        self.status_doc_ref.update({"remote_command": firestore.DELETE_FIELD})
                    except Exception as e:
                        self.logger.warning(f"Could not clear remote_command: {e}")

        # Start Firestore listener
        self.status_listener = self.status_doc_ref.on_snapshot(on_snapshot)

    def _save_beemo_status_to_firestore(self, online: bool = True, last_command: str = None):
        """Save Beemo's status (online/offline), startup time, and functionality to Firestore."""
        if not self.firestore_db_client or not self.user_id:
            self.logger.warning("Firestore client or user_id not available, cannot save Beemo status.")
            return

        status_collection = self.firestore_db_client.collection('beemo_status')
        doc_id = f"{self.user_id}_robot"
        self.status_doc_ref = status_collection.document(doc_id)
        beemo_status_doc = {
            "status": "online" if online else "offline",
            "last_update": firestore.SERVER_TIMESTAMP,
            "mode": self.current_mode.value if hasattr(self, "current_mode") else "unknown",
            "voice_enabled": bool(self.voice_manager and self.voice_manager.is_listening),
            "display_enabled": bool(self.emotion_display and self.emotion_display.display_initialized),
            "servo_enabled": bool(self.emotion_display and self.emotion_display.servo_controller.servo_enabled) if self.emotion_display else False,
            "firebase_connected": bool(self.user_id and self.firebase_rtdb_client),
            "devices_synced": bool(self.device_manager and self.device_manager.last_sync),
            "pairing": bool(self.user_id and self.firestore_db_client),  # <-- Add pairing field
            "functionality": [
                "voice_commands" if self.voice_manager else None,
                "emotion_display" if self.emotion_display else None,
                "servo_control" if self.emotion_display and self.emotion_display.servo_controller.servo_enabled else None,
                "device_management" if self.device_manager else None,
                "weather_service" if self.weather_service else None,
                "news_service" if self.news_service else None,
                "joke_service" if self.joke_service else None,
                "location_service" if self.location_service else None,
            ],
            "version": "1.0",
            "platform": sys.platform,
            "hostname": os.uname().nodename if hasattr(os, "uname") else "unknown",
        }
        if last_command:
            beemo_status_doc["last_command"] = last_command
        # Remove None values from functionality
        beemo_status_doc["functionality"] = [f for f in beemo_status_doc["functionality"] if f]
        try:
            self.status_doc_ref.set(beemo_status_doc)
            self.logger.info(f"Beemo status ({'online' if online else 'offline'}) saved to Firestore.")
        except Exception as e:
            self.logger.error(f"Error saving Beemo status to Firestore: {e}")

    def shutdown(self):
        """Cleanly shut down all components of the AI."""
        self.logger.info("Initiating Beemo AI shutdown sequence...")
        self.running = False

        # Save status as offline before shutdown
        try:
            self._save_beemo_status_to_firestore(online=False)
        except Exception as e:
            self.logger.warning(f"Could not update status to offline: {e}")

        # Remove Firestore listener
        if self.status_listener:
            try:
                self.status_listener.unsubscribe()
            except Exception as e:
                self.logger.warning(f"Could not unsubscribe Firestore listener: {e}")
            self.status_listener = None

        # Trigger shutdown emotion and cleanup display
        if self.emotion_display:
            try:
                self.emotion_display.trigger_emotion('shutdown')
                time.sleep(1)  # Give time for shutdown animation
                self.emotion_display.cleanup()
                GPIO.cleanup()  # Clean up GPIO
            except Exception as e:
                self.logger.error(f"Error cleaning up emotion display: {e}")

        # Cleanup voice manager
        if self.voice_manager:
            self.logger.info("Cleaning up VoiceDetectionManager...")
            self.voice_manager.cleanup()
            self.voice_manager = None

        self.logger.info("Beemo AI shutdown complete. Have a great day!")


def main():
    """Main entry point for the Enhanced Smart Home AI."""
    ai_instance = None
    emotion_display = None
    
    # BasicConfig for early messages if AI's logger isn't up yet
    logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

    try:
        logging.info("Initializing Enhanced Smart Home AI (Beemo)...")
        
        # Remove early display initialization here to avoid double initialization.
        # The EnhancedSmartHomeAI class will handle display initialization.
        # if EMOTIONS_AVAILABLE:
        #     try:
        #         print("Initializing Beemo Display...")
        #         # Get singleton instance
        #         emotion_display = BeemoEmotionDisplay()
        #         
        #         # Display initialization message
        #         if emotion_display.display_initialized:
        #             # Initial message only
        #             emotion_display.display_text("BEEMO", duration=2)
        #             print("✅ Display initialized successfully")
        #         else:
        #             print("❌ Display failed to initialize properly")
        #             
        #     except Exception as e:
        #         logging.error(f"Failed to initialize emotion display: {e}")
        #         print(f"❌ Display Error: {e}")
        #         emotion_display = None
        
        # Create AI instance - let it use existing emotion display
        ai_instance = EnhancedSmartHomeAI()
        
        if ai_instance.user_id and ai_instance.running:
            # Let AI handle its own startup sequence
            ai_instance.run()
        else:
            if ai_instance and ai_instance.emotion_display:
                ai_instance.emotion_display.safe_display_emotion('error')
            logging.error("Beemo AI failed to initialize properly...")
            if ai_instance and not ai_instance.user_id:
                print("Startup failed: Could not authenticate user. Please check your Firebase credentials and configuration.")
            elif ai_instance and not ai_instance.model:
                print("Startup failed: Could not initialize the AI model. Please check your GEMINI_API_KEY and network connection.")
            else:
                print("Startup failed: Please check 'smart_home_ai.log' for detailed error messages.")

    except Exception as e:
        logging.critical(f"A critical unexpected error occurred in main: {e}", exc_info=True)
        print(f"A critical error occurred: {e}. Please check 'smart_home_ai.log'.")
        if emotion_display:
            emotion_display.safe_display_emotion('error')
    finally:
        if ai_instance:
            logging.info("Executing final shutdown procedures for Beemo AI...")
            ai_instance.shutdown()
        elif emotion_display:
            # Cleanup display if AI didn't initialize
            try:
                emotion_display.cleanup()
            except:
                pass
        logging.info("Application terminated.")

if __name__ == "__main__":
    main()
