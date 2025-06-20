import os
import time
import random
import glob
import threading
import queue
from PIL import Image, ImageDraw, ImageFont
import logging
import RPi.GPIO as GPIO
import firebase_admin
from firebase_admin import firestore
from datetime import datetime

# Import luma libraries for OLED display
from luma.core.interface.serial import spi
from luma.oled.device import ssd1309

# Import for servo control
try:
    import board
    import busio
    from adafruit_pca9685 import PCA9685
    from adafruit_motor import servo
    SERVO_AVAILABLE = True
except ImportError:
    print("⚠️  Servo libraries not found. Install with: pip install adafruit-circuitpython-pca9685 adafruit-circuitpython-motor")
    SERVO_AVAILABLE = False

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class BeemoServoController:
    """Servo control system using PCA9685 PWM controller"""
    
    def __init__(self):
        self.pca = None
        self.servos = {}
        self.continuous_servo = None
        self.servo_enabled = False
        
        # Servo channel assignments
        self.CONTINUOUS_SERVO_CHANNEL = 0  # Channel 0 - continuous rotation
        self.STANDARD_SERVO1_CHANNEL = 1   # Channel 1 - standard servo
        self.STANDARD_SERVO2_CHANNEL = 2   # Channel 2 - standard servo
        
        # Servo movement parameters
        self.SERVO_MIN_ANGLE = 0
        self.SERVO_MAX_ANGLE = 180
        self.SERVO_CENTER = 90
        self.CONTINUOUS_STOP_VALUE = 0  # Value to stop continuous servo
        
        # Movement speeds and timing
        self.MOVEMENT_DELAY = 0.02  # 20ms between servo steps
        self.EMOTION_MOVEMENTS = {
            'happy': {'servo1': 45, 'servo2': 135, 'continuous': 90},
            'excited': {'servo1': 30, 'servo2': 150, 'continuous': 120},
            'sad': {'servo1': 135, 'servo2': 45, 'continuous': -30},
            'angry': {'servo1': 0, 'servo2': 180, 'continuous': -90},
            'neutral': {'servo1': 90, 'servo2': 90, 'continuous': 0},
            'dizzy': {'servo1': 'oscillate', 'servo2': 'oscillate', 'continuous': 180},
            'blink': {'servo1': 90, 'servo2': 90, 'continuous': 0},
            'sleep': {'servo1': 180, 'servo2': 0, 'continuous': 0}
        }
        
        self.setup_servos()
    
    def setup_servos(self):
        """Initialize PCA9685 and servo objects"""
        if not SERVO_AVAILABLE:
            print("   ❌ Servo libraries not available")
            return
            
        try:
            print("🔧 Setting up servo controller...")
            
            # Initialize I2C bus
            i2c = busio.I2C(board.SCL, board.SDA)
            
            # Initialize PCA9685
            self.pca = PCA9685(i2c)
            self.pca.frequency = 50  # 50Hz for servos
            
            # Initialize standard servos
            self.servos['servo1'] = servo.Servo(self.pca.channels[self.STANDARD_SERVO1_CHANNEL])
            self.servos['servo2'] = servo.Servo(self.pca.channels[self.STANDARD_SERVO2_CHANNEL])
            
            # Initialize continuous rotation servo
            self.continuous_servo = servo.ContinuousServo(self.pca.channels[self.CONTINUOUS_SERVO_CHANNEL])
            
            # Set all servos to neutral position
            self.move_to_neutral()
            
            self.servo_enabled = True
            print("   ✅ Servo controller initialized successfully")
            print(f"      🔄 Continuous servo on channel {self.CONTINUOUS_SERVO_CHANNEL}")
            print(f"      📐 Standard servo 1 on channel {self.STANDARD_SERVO1_CHANNEL}")
            print(f"      📐 Standard servo 2 on channel {self.STANDARD_SERVO2_CHANNEL}")
            
        except Exception as e:
            logger.error(f"Servo setup failed: {e}")
            print(f"   ❌ Servo setup error: {e}")
            self.servo_enabled = False
    
    def move_servo_smooth(self, servo_obj, target_angle, duration=1.0, servo_name=None):
        """Smoothly move a standard servo to target angle"""
        if not self.servo_enabled or servo_obj is None:
            return

        try:
            # Only move, don't print intermediate steps
            servo_obj.angle = target_angle
            # Print only the final angle and which servo
            print(f"[Servo] {servo_name or 'servo'} angle set to {target_angle:.1f}°")
            time.sleep(duration)
        except Exception as e:
            logger.error(f"Error moving servo: {e}")
    
    def set_continuous_servo(self, speed):
        """Set continuous servo speed (-1.0 to 1.0, 0 = stop)"""
        if not self.servo_enabled or self.continuous_servo is None:
            return
            
        try:
            # Convert speed to throttle value
            # Speed 0 = stop, positive = forward, negative = reverse
            if speed == 0:
                self.continuous_servo.throttle = 0
                print(f"[Servo] Continuous servo stopped (speed=0)")
            else:
                # Map speed to throttle range
                throttle = max(-1.0, min(1.0, speed / 180.0))  # Convert degrees to throttle
                self.continuous_servo.throttle = throttle
                print(f"[Servo] Continuous servo set to speed {speed} (throttle={throttle:.2f})")
                
        except Exception as e:
            logger.error(f"Error setting continuous servo: {e}")
    
    def stop_continuous_servo(self):
        """Stop the continuous rotation servo"""
        self.set_continuous_servo(0)
    
    def move_to_neutral(self):
        """Move all servos to neutral position"""
        if not self.servo_enabled:
            return
            
        print("   🏠 Moving servos to neutral position...")
        try:
            # Move standard servos to center
            if self.servos.get('servo1'):
                self.servos['servo1'].angle = self.SERVO_CENTER
            if self.servos.get('servo2'):
                self.servos['servo2'].angle = self.SERVO_CENTER
            
            # Stop continuous servo
            self.stop_continuous_servo()
            
            time.sleep(0.5)  # Allow servos to reach position
            
        except Exception as e:
            logger.error(f"Error moving to neutral: {e}")
    
    def oscillate_servo(self, servo_obj, duration=2.0, amplitude=45):
        """Make a servo oscillate back and forth"""
        if not self.servo_enabled or servo_obj is None:
            return
            
        try:
            center = self.SERVO_CENTER
            end_time = time.time() + duration
            
            while time.time() < end_time:
                servo_obj.angle = center + amplitude
                time.sleep(0.3)
                servo_obj.angle = center - amplitude
                time.sleep(0.3)
            
            servo_obj.angle = center
        except Exception as e:
            logger.error(f"Error oscillating servo: {e}")
    
    def move_servos_synchronized(self, angle1, angle2, duration=1.0):
        """Move both standard servos together in sync to their target angles."""
        if not self.servo_enabled:
            return
        try:
            # Move both servos at the same time
            if self.servos.get('servo1'):
                self.servos['servo1'].angle = angle1
            if self.servos.get('servo2'):
                self.servos['servo2'].angle = angle2
            print(f"[Servo] servo1 angle set to {angle1:.1f}°, servo2 angle set to {angle2:.1f}° (synchronized)")
            time.sleep(duration)
        except Exception as e:
            logger.error(f"Error moving servos synchronized: {e}")

    def oscillate_servos_synchronized(self, duration=2.0, amplitude=45):
        """Oscillate both servos together in sync."""
        if not self.servo_enabled or not (self.servos.get('servo1') and self.servos.get('servo2')):
            return
        try:
            center = self.SERVO_CENTER
            end_time = time.time() + duration
            while time.time() < end_time:
                self.servos['servo1'].angle = center + amplitude
                self.servos['servo2'].angle = center + amplitude
                time.sleep(0.3)
                self.servos['servo1'].angle = center - amplitude
                self.servos['servo2'].angle = center - amplitude
                time.sleep(0.3)
            self.servos['servo1'].angle = center
            self.servos['servo2'].angle = center
        except Exception as e:
            logger.error(f"Error oscillating servos synchronized: {e}")

    def move_all_servos_synchronized(self, angle1, angle2, continuous_speed, duration=1.0):
        """Move both standard servos and the continuous servo together in sync."""
        if not self.servo_enabled:
            return
        try:
            # Set continuous servo speed
            if self.continuous_servo is not None:
                throttle = max(-1.0, min(1.0, continuous_speed / 180.0))
                self.continuous_servo.throttle = throttle
                print(f"[Servo] Continuous servo set to speed {continuous_speed} (throttle={throttle:.2f})")
            # Move both standard servos
            if self.servos.get('servo1'):
                self.servos['servo1'].angle = angle1
            if self.servos.get('servo2'):
                self.servos['servo2'].angle = angle2
            print(f"[Servo] servo1 angle set to {angle1:.1f}°, servo2 angle set to {angle2:.1f}° (all synchronized)")
            time.sleep(duration)
            # Stop continuous servo after movement
            if self.continuous_servo is not None:
                self.continuous_servo.throttle = 0
        except Exception as e:
            logger.error(f"Error moving all servos synchronized: {e}")

    def oscillate_all_servos_synchronized(self, duration=2.0, amplitude=45, continuous_speed=180):
        """Oscillate both standard servos and run continuous servo together in sync."""
        if not self.servo_enabled or not (self.servos.get('servo1') and self.servos.get('servo2') and self.continuous_servo):
            return
        try:
            center = self.SERVO_CENTER
            throttle = max(-1.0, min(1.0, continuous_speed / 180.0))
            self.continuous_servo.throttle = throttle
            end_time = time.time() + duration
            while time.time() < end_time:
                self.servos['servo1'].angle = center + amplitude
                self.servos['servo2'].angle = center + amplitude
                time.sleep(0.3)
                self.servos['servo1'].angle = center - amplitude
                self.servos['servo2'].angle = center - amplitude
                time.sleep(0.3)
            self.servos['servo1'].angle = center
            self.servos['servo2'].angle = center
            self.continuous_servo.throttle = 0
        except Exception as e:
            logger.error(f"Error oscillating all servos synchronized: {e}")

    def execute_emotion_movement(self, emotion):
        """Execute servo movements for a specific emotion, synchronizing all servos."""
        if not self.servo_enabled or emotion not in self.EMOTION_MOVEMENTS:
            return

        print(f"   🤖 Executing synchronized movement for: {emotion}")

        movements = self.EMOTION_MOVEMENTS[emotion]

        try:
            servo1_action = movements.get('servo1')
            servo2_action = movements.get('servo2')
            continuous_speed = movements.get('continuous', 0)

            if servo1_action == 'oscillate' or servo2_action == 'oscillate':
                # If either is oscillate, oscillate all in sync
                self.oscillate_all_servos_synchronized(duration=2.0, amplitude=30, continuous_speed=continuous_speed)
                print(f"[Servo] All servos synchronized and centered after oscillate")
            elif servo1_action is not None and servo2_action is not None:
                # Move all servos together
                self.move_all_servos_synchronized(servo1_action, servo2_action, continuous_speed, duration=1.0)
            else:
                # Fallback: move individually if not all values present
                if self.continuous_servo is not None:
                    throttle = max(-1.0, min(1.0, continuous_speed / 180.0))
                    self.continuous_servo.throttle = throttle
                    if abs(continuous_speed) > 30:
                        time.sleep(1.0)
                        self.continuous_servo.throttle = 0
                if servo1_action is not None:
                    self.move_servo_smooth(self.servos['servo1'], servo1_action, 1.0, servo_name="servo1")
                if servo2_action is not None:
                    self.move_servo_smooth(self.servos['servo2'], servo2_action, 1.0, servo_name="servo2")
            # --- Add this to always return servos to neutral after movement ---
            self.move_to_neutral()
        except Exception as e:
            logger.error(f"Error executing synchronized emotion movement: {e}")

    def cleanup(self):
        """Clean up servo controller"""
        if self.servo_enabled:
            print("   🧹 Cleaning up servos...")
            try:
                # Move to neutral and stop
                self.move_to_neutral()
                
                # Deinitialize PCA9685
                if self.pca:
                    self.pca.deinit()
                    
            except Exception as e:
                logger.error(f"Servo cleanup error: {e}")

class BeemoEmotionDisplay:
    """BEEMO Robot Emotion Display System with GPIO Sensors and Servo Control"""
    
    _instance = None
    
    def __new__(cls):
        if cls._instance is None:
            cls._instance = super(BeemoEmotionDisplay, cls).__new__(cls)
            cls._instance.initialized = False
        return cls._instance
    
    def __init__(self):
        if self.initialized:
            return
            
        self.initialized = True
        self.display_width = 128
        self.display_height = 64
        self.current_emotion = 'neutral'
        self.last_emotion_time = time.time()
        self.is_running = False
        
        # GPIO Pin Configuration
        self.TOUCH_SENSOR_PIN = 4  # Changed from 17 to 4
        self.VIBRATION_SENSOR_PIN = 22
        
        # OLED uses pins: SPI (SCLK=11, MOSI=10, MISO=9, CE0=8), DC=25, RST=27
        # I2C uses pins: SCL=3, SDA=2 (for PCA9685)
        self.OLED_PINS = [8, 9, 10, 11, 25, 27]
        self.I2C_PINS = [2, 3]  # SDA, SCL
        
        # GPIO state tracking
        self.gpio_initialized = False
        self.sensors_enabled = False
        self.display_initialized = False
        
        # Initialize servo controller
        self.servo_controller = BeemoServoController()
        
        # Frame counts for each emotion
        self.FRAME_COUNT = {
            'blink': 39, 'happy': 44, 'sad': 47, 'dizzy': 67,
            'excited': 24, 'neutral': 61, 'happy2': 20, 'angry': 20,
            'happy3': 26, 'bootup3': 97, 'blink2': 20, 'sleep': 44
        }
        
        # Natural emotion transitions
        self.EMOTION_TRANSITIONS = {
            'happy': ['excited', 'neutral', 'happy2', 'happy3'],
            'angry': ['neutral', 'sad'],
            'sad': ['neutral', 'blink'],
            'excited': ['happy', 'neutral', 'happy2'],
            'neutral': ['blink', 'blink2'],
            'happy2': ['happy', 'excited', 'neutral'],
            'happy3': ['happy', 'happy2', 'neutral'],
            'blink': ['neutral', 'blink2'],
            'blink2': ['neutral', 'blink'],
            'dizzy': ['neutral', 'sad'],
            'sleep': ['neutral', 'blink']
        }
        
        # Sensor-triggered emotions
        self.TOUCH_EMOTIONS = ['happy', 'excited', 'happy2', 'happy3']
        self.VIBRATION_EMOTIONS = ['dizzy', 'angry', 'sad']
        
        # Animation parameters
        self.DEFAULT_FPS = 15
        self.EMOTION_COOLDOWN = 2.0  # Increased from 1.0 to 2.0 seconds
        self.SERVO_MOVEMENT_DELAY = 0.5  # Add delay before/after servo movements
        self.IDLE_TIMEOUT = 10
        self.BLINK_INTERVAL = 7
        
        # Base path for emotion frames
        self.base_path = "/home/pi/beemo/robot/emotions"
        
        # Threading components
        self.emotion_queue = queue.Queue()
        self.display_thread = None
        self.sensor_thread = None
        self.polling_thread = None
        
        # Initialize everything in the right order
        self.setup_gpio_base()
        self.setup_display()
        self.setup_sensor_gpio()
        
        # Initialize Firestore
        try:
            self.db = firestore.client()
            self.emotion_states_collection = self.db.collection('emotion_states')
            self.emotion_stats_collection = self.db.collection('emotion_stats')
            print("   ✅ Firestore collections initialized")
        except Exception as e:
            logger.error(f"Failed to initialize Firestore: {e}")
            self.db = None

        logger.info("BEEMO Emotion Display with Servo Control initialized")

    def setup_gpio_base(self):
        """Set up basic GPIO configuration"""
        print("🔧 Setting up base GPIO configuration...")
        
        try:
            # Set GPIO mode first
            GPIO.setmode(GPIO.BCM)
            GPIO.setwarnings(False)
            
            self.gpio_initialized = True
            print("   ✅ GPIO base configuration complete")
            
        except Exception as e:
            logger.error(f"GPIO base setup failed: {e}")
            raise Exception(f"GPIO initialization failed: {e}")

    def setup_display(self):
        """Initialize OLED display"""
        try:
            print("🖥️  Setting up OLED display...")
            
            # Initialize SPI interface for OLED
            # This will configure the necessary GPIO pins for SPI and control
            serial = spi(port=0, device=0, gpio_DC=25, gpio_RST=27, bus_speed_hz=1000000)
            
            # Initialize SSD1309 OLED device
            self.device = ssd1309(serial, width=128, height=64)
            
            # Clear display
            self.device.clear()
            
            self.display_initialized = True
            print("   ✅ OLED display initialized successfully")
            logger.info("OLED hardware display initialized")
            
        except Exception as e:
            logger.error(f"Failed to initialize OLED display: {e}")
            raise Exception(f"OLED initialization failed: {e}")

    def setup_sensor_gpio(self):
        """Initialize GPIO pins for sensors (after OLED is set up)"""
        print("🔧 Setting up sensor GPIO pins...")
        
        try:
            # Verify our sensor pins don't conflict with OLED or I2C pins
            reserved_pins = self.OLED_PINS + self.I2C_PINS
            if self.TOUCH_SENSOR_PIN in reserved_pins:
                raise Exception(f"Touch sensor pin {self.TOUCH_SENSOR_PIN} conflicts with reserved pins")
            if self.VIBRATION_SENSOR_PIN in reserved_pins:
                raise Exception(f"Vibration sensor pin {self.VIBRATION_SENSOR_PIN} conflicts with reserved pins")
                
            # Setup touch sensor (GPIO 17) - should be safe
            GPIO.setup(self.TOUCH_SENSOR_PIN, GPIO.IN, pull_up_down=GPIO.PUD_UP)
            print(f"   👆 Touch sensor pin {self.TOUCH_SENSOR_PIN} configured")
            
            # Setup vibration sensor (GPIO 22) - should be safe
            GPIO.setup(self.VIBRATION_SENSOR_PIN, GPIO.IN, pull_up_down=GPIO.PUD_UP)
            print(f"   🫨 Vibration sensor pin {self.VIBRATION_SENSOR_PIN} configured")
            
            # Test GPIO read capability
            touch_state = GPIO.input(self.TOUCH_SENSOR_PIN)
            vibration_state = GPIO.input(self.VIBRATION_SENSOR_PIN)
            print(f"   📊 Initial states - Touch: {touch_state}, Vibration: {vibration_state}")
            
            print("   ✅ Sensor GPIO setup complete")
            
            # Try to add event detection
            self.setup_event_detection()
            
        except Exception as e:
            logger.error(f"Sensor GPIO setup failed: {e}")
            print(f"   ❌ Sensor GPIO error: {e}")
            print("   ⚠️  Sensors will be disabled")
            self.sensors_enabled = False

    def setup_event_detection(self):
        """Setup GPIO event detection with fallback to polling"""
        try:
            print("   🔔 Setting up interrupt-based sensors...")
            
            # Add event detection for touch sensor
            GPIO.add_event_detect(self.TOUCH_SENSOR_PIN, GPIO.FALLING, 
                                callback=self.touch_sensor_callback, bouncetime=300)
            print(f"   ✅ Touch sensor interrupt enabled on GPIO {self.TOUCH_SENSOR_PIN}")
            
            # Add event detection for vibration sensor
            GPIO.add_event_detect(self.VIBRATION_SENSOR_PIN, GPIO.FALLING,
                                callback=self.vibration_sensor_callback, bouncetime=500)
            print(f"   ✅ Vibration sensor interrupt enabled on GPIO {self.VIBRATION_SENSOR_PIN}")
            
            self.sensors_enabled = True
            print("   🚀 Interrupt-based sensors active")
            
        except Exception as e:
            logger.warning(f"Failed to setup event detection: {e}")
            print(f"   ⚠️  Event detection failed: {e}")
            print("   🔄 Switching to polling mode...")
            
            # Clean up any partial event detection
            try:
                GPIO.remove_event_detect(self.TOUCH_SENSOR_PIN)
                GPIO.remove_event_detect(self.VIBRATION_SENSOR_PIN)
            except:
                pass
            
            self.sensors_enabled = False
            print("   ✅ Will use polling mode for sensors")

    def touch_sensor_callback(self, channel):
        """Handle touch sensor events (interrupt mode)"""
        print("\n👆 TOUCH SENSOR TRIGGERED!")
        print("   Touch detected - BEEMO is happy to see you!")
        
        # Select a happy emotion
        emotion = random.choice(self.TOUCH_EMOTIONS)
        print(f"   Triggering emotion: {emotion}")
        
        # Queue the emotion for display
        try:
            self.emotion_queue.put(('touch', emotion), block=False)
        except queue.Full:
            print("   Emotion queue full, skipping...")

    def vibration_sensor_callback(self, channel):
        """Handle vibration sensor events (interrupt mode)"""
        print("\n🫨 VIBRATION SENSOR TRIGGERED!")
        print("   Vibration detected - BEEMO is startled!")
        
        # Select a startled/dizzy emotion
        emotion = random.choice(self.VIBRATION_EMOTIONS)
        print(f"   Triggering emotion: {emotion}")
        
        # Show message on OLED
        try:
            self.display_text("Vibration\ndetected!", duration=2)
        except Exception as e:
            logger.error(f"Error displaying vibration text: {e}")
        
        # Queue the emotion for display
        try:
            self.emotion_queue.put(('vibration', emotion), block=False)
        except queue.Full:
            print("   Emotion queue full, skipping...")

    def poll_sensors(self):
        """Poll sensors manually (fallback mode)"""
        try:
            previous_touch = GPIO.input(self.TOUCH_SENSOR_PIN)
            previous_vibration = GPIO.input(self.VIBRATION_SENSOR_PIN)
        except:
            print("   ❌ Cannot read sensor states - sensors disabled")
            return
        
        touch_debounce_time = 0
        vibration_debounce_time = 0
        
        print("   🔄 Sensor polling started")
        
        while self.is_running and not self.sensors_enabled:
            try:
                current_time = time.time()
                
                # Read current sensor states
                current_touch = GPIO.input(self.TOUCH_SENSOR_PIN)
                current_vibration = GPIO.input(self.VIBRATION_SENSOR_PIN)
                
                # Check touch sensor (falling edge detection)
                if previous_touch == 1 and current_touch == 0:
                    if current_time - touch_debounce_time > 0.3:  # 300ms debounce
                        print("\n👆 TOUCH SENSOR TRIGGERED (polling)!")
                        emotion = random.choice(self.TOUCH_EMOTIONS)
                        try:
                            self.emotion_queue.put(('touch', emotion), block=False)
                        except queue.Full:
                            pass
                        touch_debounce_time = current_time
                
                # Check vibration sensor (falling edge detection)
                if previous_vibration == 1 and current_vibration == 0:
                    if current_time - vibration_debounce_time > 0.5:  # 500ms debounce
                        print("\n🫨 VIBRATION SENSOR TRIGGERED (polling)!")
                        emotion = random.choice(self.VIBRATION_EMOTIONS)
                        try:
                            self.emotion_queue.put(('vibration', emotion), block=False)
                        except queue.Full:
                            pass
                        vibration_debounce_time = current_time
                
                # Update previous states
                previous_touch = current_touch
                previous_vibration = current_vibration
                
                # Small delay for polling
                time.sleep(0.05)  # 50ms polling interval
                
            except Exception as e:
                logger.error(f"Sensor polling error: {e}")
                time.sleep(1)

    def load_animation_frames(self, emotion):
        """Load all frames for a specific emotion"""
        print(f"\n🎬 Loading {emotion} animation...")
        
        emotion_path = os.path.join(self.base_path, emotion)
        frames = []
        
        # Check if path exists
        if not os.path.exists(emotion_path):
            logger.error(f"❌ Path {emotion_path} does not exist")
            return frames
        
        # Get PNG files and sort by frame number
        frame_files = glob.glob(os.path.join(emotion_path, "frame*.png"))
        frame_files.sort(key=lambda x: int(os.path.basename(x).replace("frame", "").replace(".png", "")))
        
        print(f"   📁 Found {len(frame_files)} frames")
        
        # Process each frame (silently)
        for frame_file in frame_files:
            try:
                processed_frame = self.process_frame(frame_file, verbose=False)
                frames.append(processed_frame)
            except Exception as e:
                logger.error(f"   ❌ Error processing {frame_file}: {e}")
        
        print(f"   ✅ Successfully loaded {len(frames)} frames")
        return frames

    def process_frame(self, frame_file, verbose=False):
        """Process individual frame for display"""
        if verbose:
            print(f"   🖼️  Processing: {os.path.basename(frame_file)}")
        
        # Load image
        img = Image.open(frame_file)
        orig_width, orig_height = img.size
        
        # Calculate scaling (95% of display, max 1.5x upscaling)
        max_width = int(self.display_width * 0.95)
        max_height = int(self.display_height * 0.95)
        
        scale_w = max_width / orig_width if orig_width > max_width else 1.5
        scale_h = max_height / orig_height if orig_height > max_height else 1.5
        scale = min(scale_w, scale_h, 1.5)  # Cap at 1.5x
        
        # Resize and center
        new_width = int(orig_width * scale)
        new_height = int(orig_height * scale)
        img = img.resize((new_width, new_height), Image.LANCZOS)
        
        # Create black background and center image
        background = Image.new("RGB", (self.display_width, self.display_height), "black")
        position = ((self.display_width - new_width) // 2, (self.display_height - new_height) // 2)
        background.paste(img, position, img if img.mode == 'RGBA' else None)
        
        # Convert to 1-bit for OLED
        background = background.convert("1")
        
        if verbose:
            print(f"      📏 Scaled to {new_width}x{new_height}")
            
        return background
    
    def save_emotion_state(self, emotion, trigger_type=None, duration=None):
        """Save emotion state to Firestore"""
        if not self.db:
            return

        try:
            state_doc = {
                'emotion': emotion,
                'timestamp': firestore.SERVER_TIMESTAMP,
                'trigger_type': trigger_type,
                'duration': duration,
                'servo_enabled': self.servo_controller.servo_enabled,
                'display_initialized': self.display_initialized
            }
            self.emotion_states_collection.add(state_doc)

            # Update emotion statistics
            stats_ref = self.emotion_stats_collection.document(emotion)
            stats_ref.set({
                'count': firestore.Increment(1),
                'last_triggered': firestore.SERVER_TIMESTAMP
            }, merge=True)

        except Exception as e:
            logger.error(f"Failed to save emotion state: {e}")

    def trigger_emotion(self, emotion_type, command=None):
        """Trigger emotion based on command or event"""
        start_time = time.time()
        
        try:
            # Map command types to emotions
            emotion_mapping = {
                'command': 'neutral',
                'startup': 'bootup3',
                'shutdown': 'sleep',
                'error': 'sad',
                'success': 'happy',
                'weather': 'neutral',
                'joke': 'happy2',
                'default': 'neutral'
            }
            
            # Check command context for better emotion selection
            if emotion_type == 'command':
                if command:
                    if 'weather' in command.lower():
                        emotion_mapping['command'] = 'neutral'
                    elif any(word in command.lower() for word in ['on', 'off', 'set']):
                        emotion_mapping['command'] = 'excited'
                    elif 'joke' in command.lower():
                        emotion_mapping['command'] = 'happy'
            
            # Get the actual emotion to display
            display_emotion = emotion_mapping.get(emotion_type, emotion_mapping['default'])
            
            # Display the emotion with animation
            success = self.display_animation(display_emotion, loop=1)
            if not success:
                print(f"⚠️ Failed to display emotion: {display_emotion}")
                # Try fallback to neutral
                if display_emotion != 'neutral':
                    self.display_animation('neutral', loop=1)
                    
        except Exception as e:
            print(f"❌ Error in trigger_emotion: {e}")
            logger.error(f"Error triggering emotion {emotion_type}: {e}")
            # Try to recover by showing neutral expression
            try:
                self.display_animation('neutral', loop=1)
            except:
                pass
        # Save emotion state after display
        duration = time.time() - start_time
        self.save_emotion_state(
            emotion=display_emotion,
            trigger_type=emotion_type,
            duration=duration
        )

    def get_emotion_history(self, limit=10):
        """Get recent emotion history from Firestore"""
        if not self.db:
            return []

        try:
            docs = self.emotion_states_collection.order_by(
                'timestamp', direction=firestore.Query.DESCENDING
            ).limit(limit).get()
            
            return [{
                'emotion': doc.get('emotion'),
                'timestamp': doc.get('timestamp'),
                'trigger_type': doc.get('trigger_type'),
                'duration': doc.get('duration')
            } for doc in docs]
        except Exception as e:
            logger.error(f"Failed to get emotion history: {e}")
            return []

    def get_emotion_stats(self):
        """Get emotion statistics from Firestore"""
        if not self.db:
            return {}

        try:
            docs = self.emotion_stats_collection.get()
            return {
                doc.id: {
                    'count': doc.get('count', 0),
                    'last_triggered': doc.get('last_triggered')
                } for doc in docs
            }
        except Exception as e:
            logger.error(f"Failed to get emotion stats: {e}")
            return {}

    def display_animation(self, emotion, fps=None, loop=1, random_next=False):
        """Display animation with hardware output and servo movements"""
        start_time = time.time()
        
        if not hasattr(self, 'device') or not self.display_initialized:
            print(f"   ❌ Display not initialized, cannot show {emotion}")
            return False
        
        fps = fps or self.DEFAULT_FPS
        
        print(f"\n🎭 STARTING ANIMATION: {emotion.upper()}")
        print(f"   ⚙️  Settings: {fps} FPS, {loop} loop(s), random_next={random_next}")
        
        # Check cooldown
        current_time = time.time()
        if current_time - self.last_emotion_time < self.EMOTION_COOLDOWN:
            print(f"   ⏳ Cooldown active ({self.EMOTION_COOLDOWN}s), skipping...")
            return False
        
        # Add delay before starting servo movement
        time.sleep(self.SERVO_MOVEMENT_DELAY)
        
        # Start servo movement in parallel with display animation
        servo_thread = None
        if self.servo_controller.servo_enabled:
            servo_thread = threading.Thread(target=self.servo_controller.execute_emotion_movement, 
                                          args=(emotion,))
            servo_thread.start()
            # Add small delay after starting servo movement
            time.sleep(0.2)
        
        # Load frames
        frames = self.load_animation_frames(emotion)
        if not frames:
            print(f"   ❌ No frames loaded for {emotion}")
            return False
        
        # Animation playback
        print(f"\n🎬 ANIMATION PLAYBACK:")
        frame_delay = 1.0 / fps
        
        try:
            for loop_num in range(loop):
                if loop > 1:
                    print(f"   🔄 Loop {loop_num + 1}/{loop}")
                
                for i, frame in enumerate(frames):
                    # Display frame on OLED hardware
                    self.device.display(frame)
                    
                    time.sleep(frame_delay)
                        
                    # Show progress for long animations
                    if len(frames) > 50 and (i + 1) % 20 == 0:
                        print(f"      Progress: {i+1}/{len(frames)} frames")
        
        except Exception as e:
            logger.error(f"Error during animation playback: {e}")
            return False
        
        # Wait for servo movement to complete with timeout
        if servo_thread:
            servo_thread.join(timeout=5.0)
            # Add delay after servo movement completes
            time.sleep(self.SERVO_MOVEMENT_DELAY)
        
        # Update tracking
        self.current_emotion = emotion
        self.last_emotion_time = time.time()
        print(f"   ✅ Animation complete: {emotion}")
        
        # Add final delay before next emotion can start
        time.sleep(0.3)
        
        if random_next:
            next_emotion = self.get_random_next_emotion(emotion)
            print(f"   🎲 Random transition to: {next_emotion}")
            time.sleep(self.SERVO_MOVEMENT_DELAY)  # Add delay before next animation
            return self.display_animation(next_emotion, fps, 1, False)
        
        # Save final emotion state
        duration = time.time() - start_time
        self.save_emotion_state(
            emotion=emotion,
            trigger_type='animation',
            duration=duration
        )
        
        return True

    def get_random_next_emotion(self, current_emotion):
        """Get next emotion based on natural transitions"""
        if current_emotion in self.EMOTION_TRANSITIONS:
            transitions = self.EMOTION_TRANSITIONS[current_emotion]
            next_emotion = random.choice(transitions)
            print(f"   🔄 Natural transition: {current_emotion} → {next_emotion}")
            return next_emotion
        return 'neutral'

    def display_text(self, message, duration=2):
        """Display text message on OLED"""
        if not self.display_initialized:
            print(f"   ❌ Display not initialized, cannot show text: {message}")
            return
            
        print(f"\n💬 TEXT DISPLAY: '{message}' for {duration}s")
        
        try:
            # Create image for text
            image = Image.new("1", (self.display_width, self.display_height), "black")
            draw = ImageDraw.Draw(image)
            
            try:
                # Try to load a font, fallback to default if not available
                font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 12)
            except:
                font = ImageFont.load_default()
            
            # Handle multi-line text
            lines = message.split('\n')
            line_height = 15
            total_height = len(lines) * line_height
            start_y = (self.display_height - total_height) // 2
            
            for i, line in enumerate(lines):
                # Get text size and center it
                bbox = draw.textbbox((0, 0), line, font=font)
                text_width = bbox[2] - bbox[0]
                x = (self.display_width - text_width) // 2
                y = start_y + (i * line_height)
                
                draw.text((x, y), line, font=font, fill="white")
            
            # Display on OLED
            self.device.display(image)
            time.sleep(duration)
            
        except Exception as e:
            logger.error(f"Error displaying text: {e}")

    def process_sensor_events(self):
        """Process queued sensor events"""
        while self.is_running:
            try:
                # Get sensor event from queue (non-blocking with timeout)
                sensor_type, emotion = self.emotion_queue.get(timeout=1.0)
                
                print(f"\n🎯 Processing {sensor_type} sensor event: {emotion}")
                
                # Display the triggered emotion with servo movement
                self.display_animation(emotion)
                
                # Brief pause before returning to neutral
                time.sleep(1)
                print("[Emotion] Returning to neutral emotion after interruption.")
                self.display_animation('neutral')
                
                self.emotion_queue.task_done()
                
            except queue.Empty:
                continue
            except Exception as e:
                logger.error(f"Error processing sensor event: {e}")

    def start_sensor_monitoring(self):
        """Start the sensor monitoring thread"""
        print("🚀 Starting sensor monitoring...")
        self.is_running = True
        
        # Start sensor event processing thread
        self.sensor_thread = threading.Thread(target=self.process_sensor_events, daemon=True)
        self.sensor_thread.start()
        
        # Start polling thread if interrupts are not available
        if not self.sensors_enabled and self.gpio_initialized:
            print("   🔄 Starting polling mode for sensors...")
            self.polling_thread = threading.Thread(target=self.poll_sensors, daemon=True)
            self.polling_thread.start()
        
        sensor_mode = "interrupt" if self.sensors_enabled else "polling"
        print(f"   ✅ Sensor monitoring active ({sensor_mode} mode)")

    def stop_sensor_monitoring(self):
        """Stop sensor monitoring and cleanup"""
        print("🛑 Stopping sensor monitoring...")
        self.is_running = False
        
        if self.sensor_thread:
            self.sensor_thread.join(timeout=2)
        
        if self.polling_thread:
            self.polling_thread.join(timeout=2)
        
        # Clear display but don't cleanup GPIO (OLED display needs it)
        if hasattr(self, 'device') and self.display_initialized:
            try:
                self.device.clear()
            except:
                pass
        
        # Cleanup servos
        self.servo_controller.cleanup()
        
        if self.gpio_initialized:
            try:
                # Remove event detection if it was set up
                if self.sensors_enabled:
                    GPIO.remove_event_detect(self.TOUCH_SENSOR_PIN)
                    GPIO.remove_event_detect(self.VIBRATION_SENSOR_PIN)
            except:
                pass
            
            # Don't cleanup GPIO as OLED display still needs it
            print("   ✅ Sensor cleanup complete (preserving OLED GPIO)")

    def startup_sequence(self):
        """Complete startup sequence with servo movements"""
        print("\n" + "="*50)
        print("🚀 BEEMO STARTUP SEQUENCE")
        print("="*50)
        
        # Initialize servos to neutral position
        if self.servo_controller.servo_enabled:
            print("   🤖 Initializing servo positions...")
            self.servo_controller.move_to_neutral()
        
        # Step 1: Display BEEMO text
        self.display_text("BEEMO")
        
        # Step 2: Starting up message with servo test
        self.display_text("BEEMO\nStarting up...")
        
        # Test servo movements during startup
        if self.servo_controller.servo_enabled:
            print("   🧪 Testing servo movements...")
            # Quick servo test - move to different positions
            threading.Thread(target=self.servo_controller.execute_emotion_movement, 
                           args=('excited',)).start()
        
        # Step 3: Bootup animation (97 frames)
        self.display_animation('bootup3')
        
        # Step 4: Ready message
        self.display_text("Ready!")
        
        # Step 5: Transition to neutral with servos
        self.display_animation('neutral', loop=1)
        
        print("✅ Startup sequence complete!")

    def emotion_loop(self, emotion='happy'):
        """
        Continuously display the given emotion, returning to neutral after each animation.
        Can be interrupted by setting self.is_running = False or by sensor events.
        """
        print(f"\n🔁 Starting emotion loop for '{emotion}'. Press Ctrl+C or set self.is_running = False to exit.")
        self.is_running = True
        try:
            while self.is_running:
                # Display the chosen emotion
                interrupted = False
                try:
                    # Check for sensor events before animation
                    try:
                        sensor_event = self.emotion_queue.get_nowait()
                        if sensor_event:
                            sensor_type, sensor_emotion = sensor_event
                            print(f"\n🎯 Interrupt: {sensor_type} sensor triggered!")
                            if sensor_type == "vibration":
                                self.display_text("Vibration\ndetected!", duration=2)
                            self.display_animation(sensor_emotion)
                            time.sleep(0.5)
                            print("[Emotion] Returning to neutral emotion after interruption.")
                            self.display_animation('neutral')
                            self.emotion_queue.task_done()
                            interrupted = True
                    except queue.Empty:
                        pass

                    if interrupted:
                        continue

                    self.display_animation(emotion)
                    # After emotion, always return to neutral
                    self.display_animation('neutral')
                except KeyboardInterrupt:
                    print("\n🛑 Exiting emotion loop by user request.")
                    break
                except Exception as e:
                    logger.error(f"Error in emotion loop: {e}")
                    break
                # Short pause before next loop, can be adjusted
                time.sleep(0.5)
        finally:
            print("Emotion loop ended. Cleaning up...")
            self.stop_sensor_monitoring()
            self.servo_controller.cleanup()

    def run_interactive_mode(self):
        """Run in interactive mode with sensor monitoring and servo control"""
        print("\n" + "🤖" * 20)
        print("BEEMO INTERACTIVE MODE WITH SERVO CONTROL")
        print("🤖" * 20)
        
        try:
            # Startup
            self.startup_sequence()
            
            # Start sensor monitoring
            self.start_sensor_monitoring()
            
            print("\n🎯 BEEMO is now active with full servo control!")
            
            if self.gpio_initialized:
                sensor_mode = "interrupt" if self.sensors_enabled else "polling"
                print(f"👆 Touch sensor (GPIO {self.TOUCH_SENSOR_PIN}) - {sensor_mode} mode")
                print(f"🫨 Vibration sensor (GPIO {self.VIBRATION_SENSOR_PIN}) - {sensor_mode} mode")
            else:
                print("⚠️  Sensors disabled due to GPIO issues")
            
            if self.servo_controller.servo_enabled:
                print("🤖 Servo control active:")
                print(f"   🔄 Continuous servo (channel {self.servo_controller.CONTINUOUS_SERVO_CHANNEL})")
                print(f"   📐 Standard servo 1 (channel {self.servo_controller.STANDARD_SERVO1_CHANNEL})")
                print(f"   📐 Standard servo 2 (channel {self.servo_controller.STANDARD_SERVO2_CHANNEL})")
            else:
                print("⚠️  Servo control disabled")
            
            print("Press Ctrl+C to exit")
            
            # Main loop: now uses emotion_loop for continuous emotion display
            while True:
                print("\n[Loop] Entering emotion loop. Type 'exit' to quit or 'change' to switch emotion.")
                # Default emotion for loop
                loop_emotion = 'happy'
                self.is_running = True
                loop_thread = threading.Thread(target=self.emotion_loop, args=(loop_emotion,))
                loop_thread.start()
                # Wait for user input to exit or change emotion
                while loop_thread.is_alive():
                    user_input = input("Type 'exit' to stop loop, 'change' to switch emotion: ").strip().lower()
                    if user_input == 'exit':
                        self.is_running = False
                        loop_thread.join()
                        print("Exited emotion loop. Goodbye!")
                        return
                    elif user_input == 'change':
                        self.is_running = False
                        loop_thread.join()
                        new_emotion = input("Enter new emotion to loop: ").strip().lower()
                        if new_emotion in self.FRAME_COUNT:
                            loop_emotion = new_emotion
                        else:
                            print(f"Emotion '{new_emotion}' not found. Using 'happy'.")
                            loop_emotion = 'happy'
                        self.is_running = True
                        loop_thread = threading.Thread(target=self.emotion_loop, args=(loop_emotion,))
                        loop_thread.start()
                # If loop exits naturally, break
                break

        except KeyboardInterrupt:
            print("\n🛑 BEEMO shutting down...")
        except Exception as e:
            logger.error(f"Interactive mode error: {e}")
        finally:
            self.stop_sensor_monitoring()
            print("👋 Goodbye!")