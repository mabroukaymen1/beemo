import socket
import json
import time
from typing import Dict, Any

class BeemoRobotService:
    def __init__(self, host: str = '0.0.0.0', port: int = 5000):
        self.host = host
        self.port = port
        self.socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.connected = False

    def connect(self) -> bool:
        try:
            self.socket.connect((self.host, self.port))
            self.connected = True
            return True
        except Exception as e:
            print(f"Connection error: {e}")
            return False

    def send_command(self, command: Dict[str, Any]) -> Dict[str, Any]:
        if not self.connected:
            return {"status": "error", "message": "Not connected"}
        
        try:
            self.socket.send(json.dumps(command).encode())
            response = self.socket.recv(1024).decode()
            return json.loads(response)
        except Exception as e:
            return {"status": "error", "message": str(e)}

    def move(self, direction: str, speed: float = 1.0) -> Dict[str, Any]:
        command = {
            "action": "move",
            "direction": direction,
            "speed": speed
        }
        return self.send_command(command)

    def stop(self) -> Dict[str, Any]:
        command = {"action": "stop"}
        return self.send_command(command)

    def execute_task(self, task_type: str, params: Dict[str, Any]) -> Dict[str, Any]:
        command = {
            "action": "execute_task",
            "task_type": task_type,
            "params": params
        }
        return self.send_command(command)

    def disconnect(self):
        if self.connected:
            self.socket.close()
            self.connected = False
