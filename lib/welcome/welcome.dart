import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Add this import
import 'package:teemo/login/login.dart';

class DiscoverScreen extends StatelessWidget {
  static Future<bool> hasSeenDiscoverScreen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('hasSeenDiscoverScreen') ?? false;
  }

  static Future<void> setSeenDiscoverScreen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenDiscoverScreen', true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0D0F14), // Dark background
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Spacer(flex: 3),
            Image.asset(
              'assets/images/logo.png', // Replace with your actual robot image path
              width: 200,
            ),
            Spacer(flex: 2),
            Text(
              'BEEMO, AI Assistant Robot',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                height: 1.4,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Enhance productivity with AI-driven voice\nrecognition, task execution, and an\nintelligent configuration interface.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[500],
              ),
            ),
            Spacer(flex: 3),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  await setSeenDiscoverScreen();
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => LoginScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF6ae0c8), // Mint green button
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Next',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            Spacer(flex: 3),
          ],
        ),
      ),
    );
  }
}
