#

## Overview

Teemo is a comprehensive smart  automation platform that allows you to control, monitor, and automate various aspects of . With its intuitive interface and powerful features, Teemo makes  automation accessible and efficient. This includes integrated support for the Beemo robot, enhancing your  automation experience.

## Key Features

### 🏠 Device Control
- Control multiple types of smart devices:
  - Lights
  - Air Conditioners
  - TVs
  - Speakers
  - And more...
- Real-time device status monitoring
- Group devices by rooms or categories

### 🤖 Robot Integration
- Connect with Beemo robots
- Easy pairing process via QR code
- Robot status monitoring and control
- Emotion-based interactions

### ⚡ Automation
- Create complex automation workflows
- Schedule-based triggers
- Location-based automation
- Multiple conditions support
- Actions include:
  - Device control
  - Notifications
  - Alarms
  - Delayed actions
  - Chained automations

### 📊 Monitoring & Logs
- Detailed activity logs
- Real-time status updates
- Historical data tracking
- Export capabilities
- Calendar view for scheduled tasks

### 🔐 Security
- Secure user authentication
- QR code device pairing
- Permission management
- Activity monitoring

### 💡 Smart Features
- Room-based organization
- Device grouping
- Custom schedules
- Real-time notifications
- Multi-user support

## Installation

1. Clone the repository
2. Install dependencies:
```bash
flutter pub get
pip install -r requirements.txt
```
3. Configure Firebase:
   - Add your `google-services.json` for Android
   - Add your `GoogleService-Info.plist` for iOS
4. Update robot connection settings
5. Run the app:
```bash
flutter run
```

## Requirements

- Flutter SDK: 2.0.0 or higher
- Dart: 2.12.0 or higher
- Firebase account
- Compatible smart devices
- Beemo robot (optional)

## Architecture

Teemo follows a clean architecture pattern with:
- Provider for state management
- Firebase for backend services
- Real-time database for device states
- Cloud Firestore for user data and automation rules
- Robot Control Layer for managing robot interactions

## Contributing

We welcome contributions! Please read our contributing guidelines before submitting pull requests.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For support, please:
- Check our [FAQ](docs/FAQ.md)
- Submit issues through GitHub
- Contact our support team

## Screenshots

<div align="center">
  <img src="screenshots/home.png" width="200" alt="Home Screen"/>
  <img src="screenshots/devices.png" width="200" alt="Devices Screen"/>
  <img src="screenshots/automation.png" width="200" alt="Automation Screen"/>
</div>

---

Made with ❤️ by the Teemo Team

## Chat Interface

A natural language command interface for managing your smart  and Beemo robot.

### Features
- Tool call acceptance/rejection
- Message threading
- Auto-scrolling chat view
- Multi-line input support
- Help dialog with usage examples

### Technical Features
- Firebase integration for message persistence
- HTTP API integration
- Session management
- Error handling and recovery
- Connection status monitoring
- Configurable API endpoints

## Usage

1. Initialize the chat screen with required parameters:
```dart
CommandCenterChatScreen(
  userId: "your-user-id",
  companyId: "your-company-id",
  baseUrl: "your-api-base-url"
)
```

2. Use natural language commands like:
- "List all databases"
- "Create a new project"
- "Show all users"
- "List files in project X"

3. For API operations requiring confirmation:
- Review the suggested action
- Click "Accept" to proceed
- Click "Reject" to cancel

4. Use command templates for quick access to common operations

## Configuration

The chat interface requires:
- Firebase configuration
- Valid API endpoints
- User and Company IDs
- Internet connection

## Dependencies
- flutter/material.dart
- http
- cloud_firestore
- firebase_core
- google_fonts

## Error Handling
- Connection monitoring
- Auto-retry functionality
- Visual error indicators
- User-friendly error messages
