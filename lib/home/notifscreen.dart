import 'package:flutter/material.dart';
import 'package:teemo/widgets/colors.dart';

class NotificationScreen extends StatefulWidget {
  @override
  _NotificationScreenState createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  bool _areNotificationsEnabled = true;
  bool _isSoundEnabled = true;
  bool _isVibrationEnabled = true;

  void _toggleNotificationSetting(String setting) {
    setState(() {
      switch (setting) {
        case 'notifications':
          _areNotificationsEnabled = !_areNotificationsEnabled;
          break;
        case 'sound':
          _isSoundEnabled = !_isSoundEnabled;
          break;
        case 'vibration':
          _isVibrationEnabled = !_isVibrationEnabled;
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Notifications',
          style: TextStyle(
              color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('General'),
            _buildNotificationTile(
                'Enable Notifications',
                _areNotificationsEnabled,
                () => _toggleNotificationSetting('notifications')),
            _buildDivider(),
            _buildSectionTitle('Preferences'),
            _buildNotificationTile('Sound', _isSoundEnabled,
                () => _toggleNotificationSetting('sound')),
            _buildDivider(),
            _buildNotificationTile('Vibration', _isVibrationEnabled,
                () => _toggleNotificationSetting('vibration')),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.white70,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildNotificationTile(String title, bool value, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
        margin: EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            Switch(
              value: value,
              onChanged: (bool newValue) {
                _toggleNotificationSetting(
                    title.toLowerCase().replaceAll(' ', ''));
              },
              activeColor: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(color: AppColors.cardBorder, thickness: 1);
  }
}
