import 'package:flutter/material.dart';
import 'dart:async';

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(Duration(seconds: 5), () {
      // Delay for 5 seconds
      Navigator.of(context)
          .pushReplacementNamed('/defaultHome'); // Change to defaultHome route
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0D0F14), // Dark background
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Spacer(flex: 3),
            Image.asset(
              'assets/images/logo.png', // Replace with your actual logo path
              width: 150,
            ),
            SizedBox(height: 24),
            Text(
              'BEEMO',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 2,
              ),
            ),
            Spacer(flex: 3),
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6ae0c8)),
            ),
            Spacer(flex: 3),
          ],
        ),
      ),
    );
  }
}
