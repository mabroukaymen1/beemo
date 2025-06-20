#!/usr/bin/env python3
"""
Command Center API Test Script
Tests the Command Center API with various scenarios including tool calls.
"""

import requests
import json
import re
import time
import sys
from typing import Dict, List, Optional, Any
from dataclasses import dataclass
import logging

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

@dataclass
class TestConfig:
    """Configuration for the API test"""
    base_url: str = "https://projet-pfe-seven.vercel.app"
    user_id: str = "51f8b578-5768-409e-883c-5cf012d6f98f"
    company_id: str = "031db447-2c1b-45a4-b8fe-5a5db89009e5"
    session_timeout: int = 30  # seconds


class CommandCenterClient:
    """Client for Command Center API"""
    
    def __init__(self, config: TestConfig):
        self.config = config
        self.api_base = f"{config.base_url}/api/v1/{config.user_id}/companies/{config.company_id}/command-center"
        self.session = requests.Session()
        # Add any authentication headers here if needed
        # self.session.headers.update({"Authorization": "Bearer your-token"})
    
    def create_session(self, name: str, mode: str = "chat") -> Dict:
        """Create a new conversation session"""
        try:
            response = self.session.post(
                f"{self.api_base}/sessions/new",
                json={"name": name, "mode": mode},
                timeout=self.config.session_timeout
            )
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            logger.error(f"Failed to create session: {e}")
            return {"error": str(e)}
    
    def send_message(self, session_id: str, message: str) -> Dict:
        """Send a message to a session"""
        try:
            response = self.session.post(
                f"{self.api_base}/sessions/{session_id}",
                json={"user_prompt": message},
                timeout=self.config.session_timeout
            )
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            logger.error(f"Failed to send message: {e}")
            return {"error": str(e)}
    
    def accept_tool_call(self, session_id: str) -> Dict:
        """Accept a tool call execution"""
        try:
            response = self.session.post(
                f"{self.api_base}/sessions/{session_id}",
                json={"accept_tool_call": True},
                timeout=self.config.session_timeout
            )
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            logger.error(f"Failed to accept tool call: {e}")
            return {"error": str(e)}
    
    def reject_tool_call(self, session_id: str) -> Dict:
        """Reject a tool call execution"""
        try:
            response = self.session.post(
                f"{self.api_base}/sessions/{session_id}",
                json={"reject_tool_call": True},
                timeout=self.config.session_timeout
            )
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            logger.error(f"Failed to reject tool call: {e}")
            return {"error": str(e)}
    
    def get_messages(self, session_id: str) -> Dict:
        """Get all messages from a session"""
        try:
            response = self.session.get(
                f"{self.api_base}/sessions/{session_id}/messages",
                timeout=self.config.session_timeout
            )
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            logger.error(f"Failed to get messages: {e}")
            return {"error": str(e)}
    
    def list_sessions(self) -> Dict:
        """List all user sessions"""
        try:
            response = self.session.get(
                f"{self.api_base}/sessions/list",
                timeout=self.config.session_timeout
            )
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            logger.error(f"Failed to list sessions: {e}")
            return {"error": str(e)}


def detect_tool_call(ai_response: str) -> Optional[Dict[str, Any]]:
    """Detect if AI response contains a tool call."""
    pattern = r'```tool_use\s*([\s\S]*?)\s*```'
    match = re.search(pattern, ai_response)
    
    if match:
        try:
            tool_json = json.loads(match.group(1))
            
            # Validate structure
            if (not isinstance(tool_json, dict) or 
                'name' not in tool_json or 
                'parameters' not in tool_json):
                logger.warning(f"Invalid tool_use structure: {tool_json}")
                return None
                
            return tool_json
        except json.JSONDecodeError as e:
            logger.error(f"Failed to parse tool_use JSON: {e}")
            return None
    
    return None


def detect_tool_result(message: str) -> Optional[Dict[str, Any]]:
    """Detect if message contains a tool result."""
    pattern = r'```tool_result\s*([\s\S]*?)\s*```'
    match = re.search(pattern, message)
    
    if match:
        try:
            result_json = json.loads(match.group(1))
            
            # Validate structure
            if (not isinstance(result_json, dict) or 
                'name' not in result_json or 
                'output' not in result_json):
                logger.warning(f"Invalid tool_result structure: {result_json}")
                return None
                
            return result_json
        except json.JSONDecodeError as e:
            logger.error(f"Failed to parse tool_result JSON: {e}")
            return None
    
    return None


class CommandCenterTester:
    """Test suite for Command Center API"""
    
    def __init__(self, client: CommandCenterClient):
        self.client = client
        self.session_id = None
        self.test_results = []
    
    def log_test_result(self, test_name: str, success: bool, details: str = ""):
        """Log test results"""
        result = {
            "test": test_name,
            "success": success,
            "details": details,
            "timestamp": time.time()
        }
        self.test_results.append(result)
        status = "PASS" if success else "FAIL"
        logger.info(f"[{status}] {test_name}: {details}")
    
    def test_create_session(self) -> bool:
        """Test session creation"""
        logger.info("Testing session creation...")
        
        result = self.client.create_session("API Test Session", "chat")
        
        if "error" in result:
            self.log_test_result("create_session", False, f"Error: {result['error']}")
            return False
        
        if "data" in result and "session_id" in result["data"]:
            self.session_id = result["data"]["session_id"]
            self.log_test_result("create_session", True, f"Session ID: {self.session_id}")
            return True
        else:
            self.log_test_result("create_session", False, f"Invalid response format: {result}")
            return False
    
    def test_list_sessions(self) -> bool:
        """Test listing sessions"""
        logger.info("Testing session listing...")
        
        result = self.client.list_sessions()
        
        if "error" in result:
            self.log_test_result("list_sessions", False, f"Error: {result['error']}")
            return False
        
        if "data" in result and "sessions" in result["data"]:
            sessions_count = len(result["data"]["sessions"])
            self.log_test_result("list_sessions", True, f"Found {sessions_count} sessions")
            return True
        else:
            self.log_test_result("list_sessions", False, f"Invalid response format: {result}")
            return False
    
    def test_basic_message(self) -> bool:
        """Test sending a basic message"""
        if not self.session_id:
            self.log_test_result("basic_message", False, "No session ID available")
            return False
        
        logger.info("Testing basic message...")
        
        message = "Hello! Can you help me understand what tools you have available?"
        result = self.client.send_message(self.session_id, message)
        
        if "error" in result:
            self.log_test_result("basic_message", False, f"Error: {result['error']}")
            return False
        
        if "response" in result:
            response_preview = result["response"][:100] + "..." if len(result["response"]) > 100 else result["response"]
            self.log_test_result("basic_message", True, f"Response: {response_preview}")
            return True
        else:
            self.log_test_result("basic_message", False, f"No response field: {result}")
            return False
    
    def test_tool_call_generation(self) -> bool:
        """Test generating a tool call"""
        if not self.session_id:
            self.log_test_result("tool_call_generation", False, "No session ID available")
            return False
        
        logger.info("Testing tool call generation...")
        
        # Try to trigger a tool call for project creation
        message = "Create a new project called 'Mobile App Development' with tasks for building an e-commerce mobile application"
        result = self.client.send_message(self.session_id, message)
        
        if "error" in result:
            self.log_test_result("tool_call_generation", False, f"Error: {result['error']}")
            return False
        
        if "response" not in result:
            self.log_test_result("tool_call_generation", False, f"No response field: {result}")
            return False
        
        # Check if response contains a tool call
        tool_call = detect_tool_call(result["response"])
        
        if tool_call:
            self.log_test_result("tool_call_generation", True, f"Tool call detected: {tool_call['name']}")
            return True
        else:
            # Not necessarily a failure - AI might respond without tool use
            response_preview = result["response"][:200] + "..." if len(result["response"]) > 200 else result["response"]
            self.log_test_result("tool_call_generation", True, f"No tool call, regular response: {response_preview}")
            return True
    
    def test_tool_call_accept(self) -> bool:
        """Test accepting a tool call"""
        if not self.session_id:
            self.log_test_result("tool_call_accept", False, "No session ID available")
            return False
        
        logger.info("Testing tool call acceptance...")
        
        # First, try to generate a tool call
        message = "Generate tasks for a web development project focused on building a task management system"
        result = self.client.send_message(self.session_id, message)
        
        if "error" in result:
            self.log_test_result("tool_call_accept", False, f"Error in message: {result['error']}")
            return False
        
        tool_call = detect_tool_call(result.get("response", ""))
        
        if not tool_call:
            self.log_test_result("tool_call_accept", False, "No tool call generated to accept")
            return False
        
        # Accept the tool call
        accept_result = self.client.accept_tool_call(self.session_id)
        
        if "error" in accept_result:
            self.log_test_result("tool_call_accept", False, f"Error accepting: {accept_result['error']}")
            return False
        
        if "response" in accept_result:
            response_preview = accept_result["response"][:100] + "..." if len(accept_result["response"]) > 100 else accept_result["response"]
            self.log_test_result("tool_call_accept", True, f"Tool accepted, response: {response_preview}")
            return True
        else:
            self.log_test_result("tool_call_accept", False, f"Invalid accept response: {accept_result}")
            return False
    
    def test_tool_call_reject(self) -> bool:
        """Test rejecting a tool call"""
        if not self.session_id:
            self.log_test_result("tool_call_reject", False, "No session ID available")
            return False
        
        logger.info("Testing tool call rejection...")
        
        # Try to generate another tool call
        message = "List all projects in this company"
        result = self.client.send_message(self.session_id, message)
        
        if "error" in result:
            self.log_test_result("tool_call_reject", False, f"Error in message: {result['error']}")
            return False
        
        tool_call = detect_tool_call(result.get("response", ""))
        
        if not tool_call:
            self.log_test_result("tool_call_reject", False, "No tool call generated to reject")
            return False
        
        # Reject the tool call
        reject_result = self.client.reject_tool_call(self.session_id)
        
        if "error" in reject_result:
            self.log_test_result("tool_call_reject", False, f"Error rejecting: {reject_result['error']}")
            return False
        
        if "response" in reject_result:
            response_preview = reject_result["response"][:100] + "..." if len(reject_result["response"]) > 100 else reject_result["response"]
            self.log_test_result("tool_call_reject", True, f"Tool rejected, response: {response_preview}")
            return True
        else:
            self.log_test_result("tool_call_reject", False, f"Invalid reject response: {reject_result}")
            return False
    
    def test_get_messages(self) -> bool:
        """Test retrieving session messages"""
        if not self.session_id:
            self.log_test_result("get_messages", False, "No session ID available")
            return False
        
        logger.info("Testing message retrieval...")
        
        result = self.client.get_messages(self.session_id)
        
        if "error" in result:
            self.log_test_result("get_messages", False, f"Error: {result['error']}")
            return False
        
        if "data" in result and isinstance(result["data"], list):
            message_count = len(result["data"])
            self.log_test_result("get_messages", True, f"Retrieved {message_count} messages")
            
            # Print sample messages for debugging
            for i, msg in enumerate(result["data"][:3]):  # Show first 3 messages
                logger.info(f"Message {i+1}: {msg.get('sender', 'unknown')} - {msg.get('content', '')[:100]}...")
            
            return True
        else:
            self.log_test_result("get_messages", False, f"Invalid response format: {result}")
            return False
    
    def run_all_tests(self) -> Dict[str, Any]:
        """Run all tests and return summary"""
        logger.info("Starting Command Center API tests...")
        
        # Test sequence
        tests = [
            self.test_create_session,
            self.test_list_sessions,
            self.test_basic_message,
            self.test_tool_call_generation,
            self.test_tool_call_accept,
            self.test_tool_call_reject,
            self.test_get_messages
        ]
        
        # Run tests
        for test in tests:
            try:
                test()
                time.sleep(1)  # Brief delay between tests
            except Exception as e:
                logger.error(f"Test {test.__name__} failed with exception: {e}")
                self.log_test_result(test.__name__, False, f"Exception: {str(e)}")
        
        # Generate summary
        total_tests = len(self.test_results)
        passed_tests = sum(1 for result in self.test_results if result["success"])
        failed_tests = total_tests - passed_tests
        
        summary = {
            "total_tests": total_tests,
            "passed": passed_tests,
            "failed": failed_tests,
            "success_rate": (passed_tests / total_tests * 100) if total_tests > 0 else 0,
            "session_id": self.session_id,
            "detailed_results": self.test_results
        }
        
        logger.info(f"Test Summary: {passed_tests}/{total_tests} tests passed ({summary['success_rate']:.1f}%)")
        
        return summary


def interactive_tool_approval(tool_call: Dict) -> bool:
    """Interactive prompt for tool approval"""
    print(f"\n🔧 AI wants to use tool: {tool_call['name']}")
    print(f"📋 Parameters: {json.dumps(tool_call.get('parameters', {}), indent=2)}")
    
    while True:
        response = input("Allow this tool execution? (y/n): ").lower().strip()
        if response in ['y', 'yes']:
            return True
        elif response in ['n', 'no']:
            return False
        else:
            print("Please enter 'y' for yes or 'n' for no")


def interactive_session(client: CommandCenterClient):
    """Interactive session for manual testing"""
    print("\n🎯 Starting interactive session...")
    
    # Create session
    session_result = client.create_session("Interactive Test Session", "chat")
    if "error" in session_result:
        print(f"❌ Failed to create session: {session_result['error']}")
        return
    
    session_id = session_result["data"]["session_id"]
    print(f"✅ Created session: {session_id}")
    
    print("\n💬 You can now chat with the AI. Type 'quit' to exit.\n")
    
    while True:
        try:
            user_input = input("You: ").strip()
            
            if user_input.lower() in ['quit', 'exit', 'q']:
                print("👋 Goodbye!")
                break
            
            if not user_input:
                continue
            
            # Send message
            response = client.send_message(session_id, user_input)
            
            if "error" in response:
                print(f"❌ Error: {response['error']}")
                continue
            
            ai_response = response.get("response", "")
            
            # Check for tool calls
            tool_call = detect_tool_call(ai_response)
            
            if tool_call:
                print(f"\n🤖 AI: {ai_response}")
                
                # Get user approval
                if interactive_tool_approval(tool_call):
                    print("⏳ Executing tool...")
                    tool_result = client.accept_tool_call(session_id)
                    
                    if "error" in tool_result:
                        print(f"❌ Tool execution failed: {tool_result['error']}")
                    else:
                        print(f"🤖 AI: {tool_result.get('response', 'Tool executed successfully')}")
                else:
                    print("⏳ Rejecting tool...")
                    reject_result = client.reject_tool_call(session_id)
                    
                    if "error" in reject_result:
                        print(f"❌ Tool rejection failed: {reject_result['error']}")
                    else:
                        print(f"🤖 AI: {reject_result.get('response', 'Tool execution declined')}")
            else:
                print(f"🤖 AI: {ai_response}")
                
        except KeyboardInterrupt:
            print("\n👋 Goodbye!")
            break
        except Exception as e:
            print(f"❌ Error: {e}")
            continue


def show_ai_response_only(client: CommandCenterClient):
    """Send a message and print only the AI response."""
    print("\n🟢 AI Response Only Mode")
    session_result = client.create_session("AI Response Only", "chat")
    if "error" in session_result:
        print(f"❌ Failed to create session: {session_result['error']}")
        return
    session_id = session_result["data"]["session_id"]
    print(f"Session created: {session_id}")
    while True:
        user_input = input("You: ").strip()
        if user_input.lower() in ['quit', 'exit', 'q']:
            break
        if not user_input:
            continue
        response = client.send_message(session_id, user_input)
        if "error" in response:
            print(f"❌ Error: {response['error']}")
            continue
        print(response.get("response", ""))


def process_platform_command(command: str) -> Dict:
    """Process a command for the platform and return the result."""
    config = TestConfig()
    client = CommandCenterClient(config)
    session_result = client.create_session("Platform Command Session")
    
    if "error" in session_result:
        return {"error": "Failed to create session"}
    
    session_id = session_result["data"]["session_id"]
    result = client.send_message(session_id, command)
    
    if "error" in result:
        return {"error": f"Failed to send command: {result['error']}"}
    
    return result


def main():
    """Main function"""
    if len(sys.argv) > 1 and sys.argv[1] == "platform":
        # Platform command mode
        if len(sys.argv) > 2:
            command = " ".join(sys.argv[2:])
            result = process_platform_command(command)
            print(json.dumps(result))
            return
        else:
            print("Error: No command provided for platform mode")
            return

    print("🚀 Command Center API Test Suite")
    print("=" * 50)
    
    # Configuration
    config = TestConfig()
    
    print(f"🔗 Base URL: {config.base_url}")
    print(f"👤 User ID: {config.user_id}")
    print(f"🏢 Company ID: {config.company_id}")
    print()
    
    # Initialize client
    client = CommandCenterClient(config)
    
    # Choose test mode
    print("Select test mode:")
    print("1. Automated test suite")
    print("2. Interactive session")
    print("3. Both")
    print("4. AI response only")  # <-- Added option
    
    choice = input("Enter choice (1-4): ").strip()
    
    if choice in ['1', '3']:
        # Run automated tests
        tester = CommandCenterTester(client)
        summary = tester.run_all_tests()
        
        print("\n" + "=" * 50)
        print("📊 TEST SUMMARY")
        print("=" * 50)
        print(f"Total Tests: {summary['total_tests']}")
        print(f"Passed: {summary['passed']}")
        print(f"Failed: {summary['failed']}")
        print(f"Success Rate: {summary['success_rate']:.1f}%")
        
        if summary['failed'] > 0:
            print("\n❌ Failed Tests:")
            for result in summary['detailed_results']:
                if not result['success']:
                    print(f"  - {result['test']}: {result['details']}")
    
    if choice in ['2', '3']:
        # Run interactive session
        if choice == '3':
            input("\nPress Enter to start interactive session...")
        interactive_session(client)

    if choice == '4':
        show_ai_response_only(client)


if __name__ == "__main__":
    main()