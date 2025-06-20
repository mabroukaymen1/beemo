import 'dart:async';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:intl/intl.dart';
import 'package:teemo/home/logs.dart';
import 'package:teemo/home/notifscreen.dart';
import 'package:teemo/home/profile.dart';
import 'package:teemo/home/rooms.dart';
import 'package:teemo/robot/screens/robot_pairing_screen.dart';

import 'package:teemo/services/firebase_service.dart';
import 'package:teemo/services/models.dart';

import 'package:weather/weather.dart';
import '../services/location_service.dart';
import '../services/weather_service.dart';
import '../widgets/custom_drawer.dart';
import '../widgets/colors.dart';
import 'package:teemo/services/firestore_service.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../robot/services/robot_service.dart';
import '../robot/models/robot_connection.dart';

class Dashboard extends StatefulWidget {
  @override
  _DashboardState createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  final LocationService _locationService = LocationService();
  final WeatherService _weatherService =
      WeatherService('0f358e3f9f4969e7d29e8e4719814762');
  String _currentAddress = 'Loading...';
  Weather? _currentWeather;
  bool _isLoading = true;
  final Map<String, bool> _quickActionsState = {
    'Lights': false,
    'AC': false,
    'Security': false,
    'Water Heater': false,
  };

  // Animation controllers
  late AnimationController _headerAnimationController;
  late AnimationController _weatherAnimationController;
  late AnimationController _quickActionsAnimationController;
  late AnimationController _placesAnimationController;

  // PageController for smooth page transitions
  final PageController _pageController = PageController(initialPage: 0);

  @override
  void initState() {
    super.initState();
    _loadLocationAndWeather();

    // Initialize animation controllers
    _headerAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _weatherAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _quickActionsAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _placesAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    // Start animations
    Future.delayed(const Duration(milliseconds: 100), () {
      _headerAnimationController.forward();
      Future.delayed(const Duration(milliseconds: 200), () {
        _weatherAnimationController.forward();
        Future.delayed(const Duration(milliseconds: 300), () {
          _quickActionsAnimationController.forward();
          Future.delayed(const Duration(milliseconds: 400), () {
            _placesAnimationController.forward();
          });
        });
      });
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _headerAnimationController.dispose();
    _weatherAnimationController.dispose();
    _quickActionsAnimationController.dispose();
    _placesAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadLocationAndWeather() async {
    try {
      final position = await _locationService.getCurrentLocation();
      final address =
          await _locationService.getAddressFromCoordinates(position);
      final weather = await _weatherService.getCurrentWeather(
          position.latitude, position.longitude);

      setState(() {
        _currentAddress = address;
        _currentWeather = weather;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading location/weather: $e');
      setState(() => _isLoading = false);
    }
  }

  void _addNewPlace(String name, String image, String type) {
    final currentUser = FirebaseService().currentUser;
    if (currentUser == null) return;
    FirestoreService().addPlace(currentUser.uid, {
      'name': name,
      'image': image,
      'type': type,
    });
  }

  void _showPlaceDetail(Place place) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => PlacesScreen(
          place: place,
          deviceName: '',
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOutQuart;

          var tween =
              Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);

          return SlideTransition(position: offsetAnimation, child: child);
        },
      ),
    );
  }

  void _showAddPlaceDialog(BuildContext context) {
    final nameController = TextEditingController();
    String selectedRoomType = 'Living Room';
    final roomTypeToImage = {
      'Living Room': 'assets/images/livingroom.jpg',
      'Kitchen': 'assets/images/kitchen.jpg',
      'Bedroom': 'assets/images/bedroom.jpg',
      'Bathroom': 'assets/images/bathroom.jpg',
      'Office': 'assets/images/office.jpg',
    };

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1C1F26),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Add New Place',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Place Name',
                  labelStyle: TextStyle(color: Colors.grey[400]),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey[600]!),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.tealAccent),
                  ),
                  prefixIcon:
                      const Icon(Icons.home_outlined, color: Colors.tealAccent),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[700]!),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: selectedRoomType,
                    dropdownColor: const Color(0xFF252930),
                    style: const TextStyle(color: Colors.white),
                    iconEnabledColor: Colors.tealAccent,
                    onChanged: (String? value) {
                      if (value != null) {
                        setState(() {
                          selectedRoomType = value;
                        });
                      }
                    },
                    items: roomTypeToImage.keys.map((roomType) {
                      return DropdownMenuItem(
                        value: roomType,
                        child: Row(
                          children: [
                            Icon(
                              _getRoomTypeIcon(roomType),
                              color: Colors.tealAccent,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(roomType),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text('Cancel', style: TextStyle(color: Colors.grey[400])),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.tealAccent.withOpacity(0.2),
                foregroundColor: Colors.tealAccent,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                if (nameController.text.isNotEmpty) {
                  final selectedImage = roomTypeToImage[selectedRoomType]!;
                  _addNewPlace(
                    nameController.text,
                    selectedImage,
                    selectedRoomType,
                  );
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Add Room',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        );
      },
    );
  }

  IconData _getRoomTypeIcon(String roomType) {
    switch (roomType) {
      case 'Living Room':
        return Icons.weekend_outlined;
      case 'Kitchen':
        return Icons.kitchen_outlined;
      case 'Bedroom':
        return Icons.bed_outlined;
      case 'Bathroom':
        return Icons.bathroom_outlined;
      case 'Office':
        return Icons.desk_outlined;
      default:
        return Icons.home_outlined;
    }
  }

  IconData _getWeatherIcon(int condition) {
    if (condition < 300) return Icons.thunderstorm_outlined;
    if (condition < 600) return Icons.umbrella_outlined;
    if (condition < 700) return Icons.ac_unit_outlined;
    if (condition < 800) return Icons.cloud_outlined;
    if (condition == 800) return Icons.wb_sunny_outlined;
    return Icons.cloud_outlined;
  }

  IconData _getQuickActionIcon(String action) {
    switch (action) {
      case 'Lights':
        return Icons.lightbulb_outline;
      case 'AC':
        return Icons.ac_unit_outlined;
      case 'Security':
        return Icons.security_outlined;
      case 'Water Heater':
        return Icons.hot_tub_outlined;
      default:
        return Icons.device_unknown;
    }
  }

  Future<void> _refreshDashboard() async {
    await _loadLocationAndWeather();
  }

  // Extract original dashboard content into a helper method
  Widget _buildDashboardContent() {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _refreshDashboard,
        color: AppColors.secondary,
        backgroundColor: AppColors.surface,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with fade-in animation
              SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, -0.2),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: _headerAnimationController,
                  curve: Curves.easeOut,
                )),
                child: FadeTransition(
                  opacity: _headerAnimationController,
                  child: _buildHeader(),
                ),
              ),
              const SizedBox(height: 24),
              // Weather card with scale animation
              ScaleTransition(
                scale: Tween<double>(
                  begin: 0.8,
                  end: 1.0,
                ).animate(CurvedAnimation(
                  parent: _weatherAnimationController,
                  curve: Curves.easeOutBack,
                )),
                child: FadeTransition(
                  opacity: _weatherAnimationController,
                  child: _buildWeatherCard(),
                ),
              ),
              const SizedBox(height: 30),
              // Quick actions with slide-in animation
              SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(-0.2, 0),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: _quickActionsAnimationController,
                  curve: Curves.easeOut,
                )),
                child: FadeTransition(
                  opacity: _quickActionsAnimationController,
                  child: _buildQuickActions(),
                ),
              ),
              const SizedBox(height: 30),
              // Places section with fade-in animation
              FadeTransition(
                opacity: _placesAnimationController,
                child: _buildPlacesSection(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: CustomDrawer(
        initialIndex: _selectedIndex,
        onItemSelected: (index) {
          setState(() => _selectedIndex = index);
          _pageController.jumpToPage(index);
          Navigator.pop(context);
        },
      ),
      appBar: _buildAppBar(),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() => _selectedIndex = index);
        },
        children: [
          _buildDashboardContent(),
          AutomationLogsScreen(),
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: _buildBottomNavBar(),
      floatingActionButton:
          _selectedIndex == 0 ? _buildFloatingActionButton() : null,
    );
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton.extended(
      onPressed: () => _showAddPlaceDialog(context),
      label: const Text("Add Place",
          style: TextStyle(
              color: AppColors.onPrimary, fontWeight: FontWeight.w600)),
      icon: const Icon(Icons.add, color: AppColors.onPrimary),
      backgroundColor: AppColors.primary,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: CurvedNavigationBar(
        backgroundColor: Colors.transparent,
        color: AppColors.surface,
        buttonBackgroundColor: AppColors.secondary,
        height: 60,
        animationDuration: const Duration(milliseconds: 400),
        animationCurve: Curves.easeInOutQuad,
        items: const [
          Icon(Icons.home_rounded, color: Colors.white, size: 28),
          Icon(Icons.analytics_rounded, color: Colors.white, size: 28),
          Icon(Icons.person_rounded, color: Colors.white, size: 28),
        ],
        onTap: (index) {
          setState(() => _selectedIndex = index);
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOutQuad,
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.background,
      elevation: 0,
      centerTitle: true,
      leading: Builder(
        builder: (BuildContext context) {
          return IconButton(
            icon: const Icon(Icons.sort_rounded, color: Colors.white, size: 30),
            splashRadius: 28,
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
          );
        },
      ),
      title: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'BEEMO',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              fontSize: 22,
            ),
          ),
          SizedBox(width: 8),
          Icon(Icons.home_work_rounded, color: Colors.tealAccent, size: 24),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined, color: Colors.white70),
          splashRadius: 28,
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => NotificationScreen()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildHeader() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return _buildGuestHeader();
    }
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorHeader();
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingHeader();
        }
        final userData = snapshot.data?.data() as Map<String, dynamic>?;
        final userName = userData?['name'] ?? 'Guest';
        return _buildUserHeader(userName);
      },
    );
  }

  Widget _buildGuestHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Text(
              "Hello, Guest",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1,
              ),
            ),
            SizedBox(width: 10),
            Text(
              "👋",
              style: TextStyle(fontSize: 28),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          "Welcome to your world",
          style: TextStyle(
            color: Colors.grey[500],
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 12),
        DateTimeDisplay(),
      ],
    );
  }

  Widget _buildErrorHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red),
          SizedBox(width: 12),
          Text(
            'Error loading profile',
            style: TextStyle(color: Colors.red, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 180,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: 150,
          height: 18,
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.2),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ],
    );
  }

  Widget _buildUserHeader(String userName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              "Hello, $userName",
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              "👋",
              style: TextStyle(fontSize: 28),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          "Welcome back to your world",
          style: TextStyle(color: Colors.grey[500], fontSize: 16),
        ),
        const SizedBox(height: 12),
        DateTimeDisplay(),
        const SizedBox(height: 16),
        _buildConnectButton(context),
      ],
    );
  }

  Widget _buildConnectButton(BuildContext context) {
    final robotService = RobotService();
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return _buildConnectButtonContent(null, 'Sign in to connect');
    }

    return StreamBuilder<RobotConnection?>(
      stream: robotService.getRobotConnectionStream(currentUser.uid),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildConnectButtonContent(null, 'Connection Error');
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildConnectButtonContent(null, 'Checking Connection...');
        }

        final connection = snapshot.data;
        String statusText = 'Connect to BEEMO';

        if (connection != null) {
          if (connection.isConnected && connection.isOnline) {
            statusText = 'Connected to ${connection.name ?? 'BEEMO'}';
          } else if (connection.isConnected) {
            statusText = '${connection.name ?? 'BEEMO'} (Offline)';
          } else {
            statusText = 'Reconnect to BEEMO';
          }
        }

        return _buildConnectButtonContent(connection, statusText);
      },
    );
  }

  Widget _buildConnectButtonContent(
      RobotConnection? connection, String statusText) {
    final isConnected = connection?.isConnected ?? false;
    final isOnline = connection?.isOnline ?? false;
    final isHealthy = isConnected && isOnline;

    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _getButtonGradientColors(isConnected, isOnline),
        ),
        boxShadow: [
          BoxShadow(
            color: _getButtonShadowColor(isConnected, isOnline),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () =>
              _handleConnectButtonTap(context, connection, isConnected),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildButtonIcon(isConnected, isOnline),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: Colors.white.withOpacity(0.95),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (connection != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          _getStatusSubtext(connection),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.7),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                if (isHealthy) ...[
                  const SizedBox(width: 8),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.greenAccent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.greenAccent.withOpacity(0.5),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Color> _getButtonGradientColors(bool isConnected, bool isOnline) {
    if (isConnected && isOnline) {
      return [Colors.green.shade400, Colors.green.shade600];
    } else if (isConnected) {
      return [Colors.orange.shade400, Colors.orange.shade600];
    } else {
      return [AppColors.secondary, AppColors.primary];
    }
  }

  Color _getButtonShadowColor(bool isConnected, bool isOnline) {
    if (isConnected && isOnline) {
      return Colors.green.withOpacity(0.3);
    } else if (isConnected) {
      return Colors.orange.withOpacity(0.3);
    } else {
      return AppColors.primary.withOpacity(0.3);
    }
  }

  Widget _buildButtonIcon(bool isConnected, bool isOnline) {
    IconData iconData;

    if (isConnected && isOnline) {
      iconData = Icons.check_circle;
    } else if (isConnected) {
      iconData = Icons.warning;
    } else {
      iconData = Icons.bluetooth;
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Icon(
        iconData,
        key: ValueKey<IconData>(iconData),
        color: Colors.white,
        size: 24,
      ),
    );
  }

  String _getStatusSubtext(RobotConnection connection) {
    if (connection.isConnected && connection.isOnline) {
      return 'Health: ${connection.status}';
    } else if (connection.isConnected) {
      return 'Robot offline';
    } else {
      return 'Tap to reconnect';
    }
  }

  Future<void> _handleConnectButtonTap(BuildContext context,
      RobotConnection? connection, bool isConnected) async {
    if (isConnected) {
      // Show connection management dialog
      await _showConnectionManagementDialog(context, connection!);
    } else {
      // Navigate to connect screen with default values
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RobotPairingScreen(),
        ),
      );

      // Handle result if needed
      if (result != null && result is bool && result) {
        _showSuccessSnackBar('Robot connected successfully!');
      }
    }
  }

  Future<void> _showConnectionManagementDialog(
      BuildContext context, RobotConnection connection) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1F26),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            const Icon(Icons.warning, color: Colors.orange),
            const SizedBox(width: 8),
            Text(
              'Robot Management',
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This will disconnect you from the robot. You can reconnect anytime.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Connected Robot: ${connection.name ?? 'Beemo'}',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Text(
              'Status: ${connection.isOnline ? 'Online' : 'Offline'}',
              style: TextStyle(
                color: connection.isOnline ? Colors.green : Colors.orange,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey,
            ),
            child: const Text('CANCEL'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.link_off),
            label: const Text('DISCONNECT'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.withOpacity(0.2),
              foregroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

// Additional helper method for the Dashboard class

  Widget _buildWeatherCard() {
    if (_isLoading) return _buildShimmerWeatherCard();
    final weather = _currentWeather;
    if (weather == null) return const SizedBox();

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF2C635B).withOpacity(0.9),
            const Color(0xFF6ae0c8).withOpacity(0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6ae0c8).withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(25),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat('EEEE')
                              .format(weather.date ?? DateTime.now()),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          DateFormat('h:mm a')
                              .format(weather.date ?? DateTime.now()),
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Icon(
                          _getWeatherIcon(weather.weatherConditionCode ?? 0),
                          key: ValueKey<int>(weather.weatherConditionCode ?? 0),
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${weather.temperature?.celsius?.toStringAsFixed(1) ?? '--'}',
                              style: const TextStyle(
                                fontSize: 46,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const Text(
                              '°C',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            weather.weatherDescription?.toUpperCase() ?? '',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withOpacity(0.9),
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.arrow_downward,
                                color: Colors.white70, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              '${weather.tempMin?.celsius?.toStringAsFixed(1) ?? '--'}°C',
                              style: const TextStyle(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.05),
                          Colors.white.withOpacity(0.3),
                          Colors.white.withOpacity(0.05),
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                    ),
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      _buildWeatherInfo('Humidity', '${weather.humidity}%',
                          Icons.water_drop_outlined),
                      const SizedBox(width: 22),
                      _buildWeatherInfo('Wind', '${weather.windSpeed} km/h',
                          Icons.air_outlined),
                      const SizedBox(width: 22),
                      _buildWeatherInfo(
                          'Feels like',
                          '${weather.tempFeelsLike?.celsius?.toStringAsFixed(1) ?? '--'}°C',
                          Icons.thermostat_outlined),
                      const SizedBox(width: 22),
                      _buildWeatherInfo(
                          'Pressure',
                          '${weather.pressure?.round() ?? '--'} hPa',
                          Icons.speed_outlined),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerWeatherCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        color: const Color(0xFF1C1F26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 150,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 120,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              Container(
                width: 80,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            height: 1,
            color: Colors.grey[700],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
                4,
                (index) => Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(12),
                      ),
                    )),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherInfo(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white70, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.flash_on, color: Colors.tealAccent, size: 22),
            SizedBox(width: 8),
            Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 110,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _quickActionsState.keys.length,
            itemBuilder: (context, index) {
              final action = _quickActionsState.keys.elementAt(index);
              final isActive = _quickActionsState[action]!;

              return AnimationConfiguration.staggeredList(
                position: index,
                duration: const Duration(milliseconds: 500),
                child: SlideAnimation(
                  horizontalOffset: 50.0,
                  child: FadeInAnimation(
                    child: _buildQuickActionButton(
                      _getQuickActionIcon(action),
                      action,
                      isActive,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionButton(IconData icon, String label, bool isActive) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _quickActionsState[label] = !isActive;
        });
      },
      child: Container(
        width: 85,
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 68,
              width: 68,
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(0xFF6ae0c8)
                    : const Color(0xFF1C1F26),
                borderRadius: BorderRadius.circular(20),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: const Color(0xFF6ae0c8).withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Icon(
                icon,
                color: isActive ? Colors.white : Colors.grey[500],
                size: 30,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.white70,
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlacesSection() {
    final currentUser = FirebaseService().currentUser;
    if (currentUser == null) {
      return _buildSignInPrompt();
    }

    return StreamBuilder(
      stream: FirestoreService().getPlaces(currentUser.uid),
      builder: (context,
          AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildPlacesLoadingState();
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyPlacesState();
        }

        final docs = snapshot.data!.docs;
        final places = docs.map((doc) {
          final data = doc.data();
          return Place(
            id: doc.id,
            name: data['name'] ?? 'Unnamed Place',
            image: data['image'] ?? '',
            devices: [],
          );
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.home_rounded,
                        color: Colors.tealAccent, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Places',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: () {
                    _showAddPlaceDialog(context);
                  },
                  icon: const Icon(
                    Icons.add_rounded,
                    color: Color(0xFF6ae0c8),
                    size: 18,
                  ),
                  label: const Text(
                    'Add Place',
                    style: TextStyle(
                      color: Color(0xFF6ae0c8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            AnimationLimiter(
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount:
                      MediaQuery.of(context).size.width > 600 ? 3 : 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.1,
                ),
                itemCount: places.length,
                itemBuilder: (context, index) {
                  return AnimationConfiguration.staggeredGrid(
                    position: index,
                    duration: const Duration(milliseconds: 600),
                    columnCount:
                        MediaQuery.of(context).size.width > 600 ? 3 : 2,
                    child: ScaleAnimation(
                      scale: 0.9,
                      child: FadeInAnimation(
                        child: _buildPlaceCard(places[index]),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSignInPrompt() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.login_rounded,
            color: Colors.tealAccent,
            size: 48,
          ),
          const SizedBox(height: 16),
          const Text(
            "Please sign in to view your places",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            "Sign in to access your smart home places and devices",
            style: TextStyle(color: Colors.grey[400], fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              // Handle sign in
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.tealAccent.withOpacity(0.2),
              foregroundColor: Colors.tealAccent,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              "Sign In",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlacesLoadingState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 100,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const Spacer(),
            Container(
              width: 80,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.1,
          ),
          itemCount: 4,
          itemBuilder: (context, index) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildEmptyPlacesState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.tealAccent.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.home_outlined,
              color: Colors.tealAccent,
              size: 48,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "No places found",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Tap 'Add Place' to add a new one",
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showAddPlaceDialog(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.tealAccent.withOpacity(0.2),
              foregroundColor: Colors.tealAccent,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.add),
            label: const Text(
              "Add Your First Place",
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceCard(Place place) {
    return Hero(
      tag: 'place-${place.id}',
      child: GestureDetector(
        onTap: () => _showPlaceDetail(place),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            image: DecorationImage(
              image: AssetImage(place.image),
              fit: BoxFit.cover,
              colorFilter:
                  const ColorFilter.mode(Colors.black45, BlendMode.darken),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 0.5, sigmaY: 0.5),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.3),
                      Colors.black.withOpacity(0.6),
                    ],
                  ),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getRoomTypeIcon(
                                _getRoomTypeFromImage(place.image)),
                            color: Colors.white,
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _getRoomTypeFromImage(place.image),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Text(
                      place.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            color: Colors.black,
                            blurRadius: 2,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: place.devices.any((device) => device.isOn)
                                ? Colors.tealAccent
                                : Colors.grey[400],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${place.devices.where((device) => device.isOn).length} activated',
                          style: TextStyle(
                            color: Colors.grey[300],
                            fontSize: 12,
                            shadows: const [
                              Shadow(
                                color: Colors.black,
                                blurRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _getRoomTypeFromImage(String imagePath) {
    if (imagePath.contains('livingroom')) return 'Living Room';
    if (imagePath.contains('kitchen')) return 'Kitchen';
    if (imagePath.contains('bedroom')) return 'Bedroom';
    if (imagePath.contains('bathroom')) return 'Bathroom';
    if (imagePath.contains('office')) return 'Office';
    return 'Room';
  }
}

class PatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Draw diagonal lines
    for (var i = -size.height; i <= size.width; i += 30) {
      canvas.drawLine(
        Offset(i.toDouble(), 0),
        Offset(i.toDouble() + size.height, size.height),
        paint,
      );
    }

    // Draw opposite diagonal lines
    for (var i = 0; i <= size.width + size.height; i += 30) {
      canvas.drawLine(
        Offset(i.toDouble(), 0),
        Offset(i.toDouble() - size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class DateTimeDisplay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DateTime>(
      stream:
          Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now()),
      builder: (context, snapshot) {
        final now = snapshot.data ?? DateTime.now();
        final formattedDate = DateFormat('EEEE, d MMMM y').format(now);
        final formattedTime = DateFormat('HH:mm:ss').format(now);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.calendar_today,
                  color: Colors.tealAccent, size: 16),
              const SizedBox(width: 8),
              Text(
                formattedDate,
                style: TextStyle(color: Colors.grey[300], fontSize: 14),
              ),
              const SizedBox(width: 10),
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[500],
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.access_time, color: Colors.tealAccent, size: 16),
              const SizedBox(width: 8),
              Text(
                formattedTime,
                style: TextStyle(color: Colors.grey[300], fontSize: 14),
              ),
            ],
          ),
        );
      },
    );
  }
}
