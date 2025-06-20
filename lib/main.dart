import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:teemo/home/home.dart';
import 'package:teemo/home/logs_provider.dart';
import 'package:teemo/login/login.dart';
import 'package:teemo/services/firebase_service.dart';
import 'package:teemo/welcome/splash.dart';
import 'package:teemo/welcome/welcome.dart';
import 'package:teemo/theme/custom_theme.dart';
import 'package:provider/provider.dart';
import 'package:teemo/services/device_state.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // OneSignal Initialization
  OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
  OneSignal.initialize("2c84bbed-832b-4866-bf8a-cd6cc5478816");

  // Request Permissions
  OneSignal.Notifications.requestPermission(true);

  if (!await hasInternetConnection()) {
    runApp(NoInternetApp());
    return;
  }

  if (kIsWeb) {
    await Firebase.initializeApp(
      options: FirebaseOptions(
          apiKey: "AIzaSyBD4jhnPrF2UMiPe1TpJJY7jQpNeGlLVxM",
          authDomain: "beemo-ccbba.firebaseapp.com",
          projectId: "beemo-ccbba",
          storageBucket: "beemo-ccbba.firebasestorage.app",
          messagingSenderId: "394573353933",
          appId: "1:394573353933:web:2eb9c06d7f791d49a6aa84"),
    );
  } else {
    await Firebase.initializeApp();
  }

  final firebaseService = FirebaseService();
  if (FirebaseAuth.instance.currentUser != null) {
    await firebaseService.updateUserOnlineStatus(true);
  }

  WidgetsBinding.instance.addObserver(AppLifecycleObserver(firebaseService));

  Widget defaultHome;
  if (!await hasInternetConnection()) {
    defaultHome = NoInternetApp();
  } else if (FirebaseAuth.instance.currentUser != null) {
    defaultHome = Dashboard();
  } else {
    final hasSeenDiscoverScreen = await DiscoverScreen.hasSeenDiscoverScreen();
    defaultHome = hasSeenDiscoverScreen ? LoginScreen() : DiscoverScreen();
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DeviceState()),
        ChangeNotifierProvider(create: (_) => LogsProvider()), // Add this line
        // Other providers...
      ],
      child: MyApp(defaultHome: defaultHome),
    ),
  );
}

Future<bool> hasInternetConnection() async {
  try {
    final result = await InternetAddress.lookup('google.com');
    return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
  } catch (_) {
    return false;
  }
}

class NoInternetApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Color(0xFF0D0F14),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF6ae0c8).withOpacity(0.2),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFF6ae0c8).withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.wifi_off,
                    size: 40,
                    color: Color(0xFF6ae0c8),
                  ),
                ),
                SizedBox(height: 24),
                Text(
                  'No Internet Connection',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6ae0c8),
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Please check your internet connection and restart the app.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[400],
                    height: 1.5,
                  ),
                ),
                SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF6ae0c8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () => exit(0),
                    child: Text(
                      'Exit',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  final Widget defaultHome;

  const MyApp({required this.defaultHome, super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Home App',
      theme: CustomTheme.lightTheme,
      home: SplashScreen(), // Set SplashScreen as the initial screen
      routes: {
        '/discoverScreen': (context) => DiscoverScreen(),
        // Add a route for the default home screen
        '/defaultHome': (context) => defaultHome,
      },
    );
  }
}

class AppLifecycleObserver with WidgetsBindingObserver {
  final FirebaseService _firebaseService;

  AppLifecycleObserver(this._firebaseService) {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (FirebaseAuth.instance.currentUser != null) {
      _firebaseService
          .updateUserOnlineStatus(state == AppLifecycleState.resumed);
    }
  }
}
