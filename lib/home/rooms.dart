import 'package:flutter/material.dart';
import 'package:teemo/services/device_service.dart';
import 'package:teemo/services/models.dart';
import 'package:teemo/widgets/colors.dart';
import 'package:teemo/widgets/device_card.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'qrcode/addevice.dart';

class PlacesScreen extends StatefulWidget {
  final Place place;
  final String deviceName;

  const PlacesScreen({Key? key, required this.place, required this.deviceName})
      : super(key: key);

  @override
  _PlacesScreenState createState() => _PlacesScreenState();
}

class _PlacesScreenState extends State<PlacesScreen>
    with SingleTickerProviderStateMixin {
  final DeviceService _deviceService = DeviceService();
  List<Device> devices = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  late TabController _tabController;
  String _selectedCategory = 'All';
  bool _isRefreshing = false;

  // Categories for filtering devices
  final List<String> categories = [
    'All',
    'Lighting',
    'Climate',
    'Security',
    'Entertainment'
  ];

  // Statistics
  int _activeDevices = 0;
  double _energyUsage = 0.0; // in kWh

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: categories.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _selectedCategory = categories[_tabController.index];
        });
      }
    });
    _loadDevices();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDevices() async {
    if (_isRefreshing) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
      _isRefreshing = true;
    });

    try {
      final updatedPlace = await _deviceService.getPlace(widget.place.id);
      if (mounted) {
        setState(() {
          devices = updatedPlace.devices;
          _isLoading = false;
          _isRefreshing = false;
          _calculateStatistics();
        });
      }
    } catch (e) {
      print('Error loading devices: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'Failed to load devices. Please try again.';
          _isRefreshing = false;
        });
      }
    }
  }

  void _calculateStatistics() {
    _activeDevices = devices.where((device) => device.isOn).length;

    // Calculate approximate energy usage based on device types and states
    _energyUsage = 0.0;
    for (var device in devices) {
      if (device.isOn) {
        switch (device.type) {
          case 'light':
            _energyUsage += 0.06; // approx 60W per hour
            break;
          case 'thermostat':
            _energyUsage += 1.5; // approx 1.5kWh
            break;
          case 'speaker':
            _energyUsage += 0.02; // approx 20W per hour
            break;
          case 'tv':
            _energyUsage += 0.15; // approx 150W per hour
            break;
          default:
            _energyUsage += 0.05; // default consumption
        }
      }
    }
  }

  Future<void> _toggleDevice(String deviceId, bool currentState) async {
    try {
      await _deviceService.toggleDevice(
        widget.place.id,
        deviceId,
        !currentState,
      );
      _loadDevices(); // Refresh the devices after toggle
    } catch (e) {
      print('Error toggling device: $e');
      _showErrorSnackBar('Failed to toggle device. Please try again.');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(FontAwesomeIcons.circleExclamation,
                color: Colors.white, size: 16),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  List<Device> get _filteredDevices {
    if (_selectedCategory == 'All') {
      return devices;
    }
    return devices
        .where((device) => device.category == _selectedCategory)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _loadDevices,
        color: AppColors.secondary,
        backgroundColor: AppColors.cardDark,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Animated app bar with image
            _buildSliverAppBar(),

            // Statistics section
            SliverToBoxAdapter(
              child: _buildStatisticsSection()
                  .animate()
                  .fadeIn(duration: 300.ms, delay: 200.ms),
            ),

            // Categories tabs
            SliverToBoxAdapter(
              child: _buildCategoriesTabs()
                  .animate()
                  .fadeIn(duration: 300.ms, delay: 300.ms),
            ),

            // Devices grid
            _isLoading
                ? SliverFillRemaining(
                    child: Center(
                      child: _buildLoadingIndicator(),
                    ),
                  )
                : _hasError
                    ? SliverFillRemaining(
                        child: _buildErrorView(),
                      )
                    : _filteredDevices.isEmpty
                        ? SliverFillRemaining(
                            child: _buildEmptyState(),
                          )
                        : SliverPadding(
                            padding: const EdgeInsets.all(16),
                            sliver: SliverGrid(
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                childAspectRatio: 0.85,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final device = _filteredDevices[index];
                                  return DeviceCard(
                                    key: ValueKey(device.id),
                                    device: device,
                                    onToggle: () =>
                                        _toggleDevice(device.id, device.isOn),
                                  ).animate().fadeIn(
                                        duration: 300.ms,
                                        delay: 100.ms + (index * 50).ms,
                                      );
                                },
                                childCount: _filteredDevices.length,
                              ),
                            ),
                          ),
          ],
        ),
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 240,
      pinned: true,
      stretch: true,
      backgroundColor: AppColors.cardDark,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: CircleAvatar(
          backgroundColor: Colors.black.withOpacity(0.4),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundColor: Colors.black.withOpacity(0.4),
            child: IconButton(
              icon: const Icon(FontAwesomeIcons.ellipsisVertical,
                  color: Colors.white, size: 20),
              onPressed: () => _showOptionsMenu(context),
            ),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Hero(
          tag: 'place-${widget.place.id}',
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background image with gradient overlay
              Image.asset(
                widget.place.image,
                fit: BoxFit.cover,
              ),
              // Gradient overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.1),
                      Colors.black.withOpacity(0.7),
                    ],
                  ),
                ),
              ),
              // Content overlay
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Room name with icon
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            _getRoomIcon(widget.place.name),
                            color: AppColors.secondary,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.place.name,
                            style: GoogleFonts.poppins(
                              textStyle: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Room details
                    Row(
                      children: [
                        // Remove temperature and humidity chips, only show lightbulb (on/off)
                        _buildInfoChip(
                          FontAwesomeIcons.lightbulb,
                          '${_activeDevices > 0 ? 'On' : 'Off'}',
                          _activeDevices > 0
                              ? Colors.yellowAccent
                              : Colors.grey,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        stretchModes: const [
          StretchMode.zoomBackground,
          StretchMode.blurBackground,
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: color.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: color,
            size: 12,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getRoomIcon(String roomName) {
    final name = roomName.toLowerCase();
    if (name.contains('living')) return FontAwesomeIcons.couch;
    if (name.contains('bed')) return FontAwesomeIcons.bed;
    if (name.contains('kitchen')) return FontAwesomeIcons.kitchenSet;
    if (name.contains('bath')) return FontAwesomeIcons.bath;
    if (name.contains('office')) return FontAwesomeIcons.briefcase;
    if (name.contains('garage')) return FontAwesomeIcons.car;
    if (name.contains('game')) return FontAwesomeIcons.gamepad;
    if (name.contains('garden')) return FontAwesomeIcons.leaf;
    return FontAwesomeIcons.house;
  }

  Widget _buildStatisticsSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.cardDark.withOpacity(0.8),
              AppColors.cardDark.withOpacity(0.6),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.cardBorder.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem(
              icon: FontAwesomeIcons.plugCircleBolt,
              value: '${devices.length}',
              label: 'Devices',
              iconColor: AppColors.secondary,
            ),
            _buildVerticalDivider(),
            _buildStatItem(
              icon: FontAwesomeIcons.powerOff,
              value: '$_activeDevices',
              label: 'Active',
              iconColor: Colors.greenAccent,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      height: 40,
      width: 1,
      color: AppColors.cardBorder.withOpacity(0.3),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color iconColor,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: iconColor,
            size: 18,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildCategoriesTabs() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  FontAwesomeIcons.layerGroup,
                  color: AppColors.primary,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Device Categories',
                style: GoogleFonts.poppins(
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 40,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                color: AppColors.secondary,
              ),
              labelColor: Colors.black,
              unselectedLabelColor: Colors.white,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.normal,
                fontSize: 14,
              ),
              tabs: categories.map((category) {
                return Tab(text: category);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 50,
          height: 50,
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.secondary),
            strokeWidth: 3,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Loading devices...',
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            FontAwesomeIcons.circleExclamation,
            color: Colors.redAccent,
            size: 40,
          ),
          const SizedBox(height: 16),
          Text(
            'Oops!',
            style: GoogleFonts.poppins(
              textStyle: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadDevices,
            icon: const Icon(FontAwesomeIcons.arrowsRotate),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: MediaQuery.of(context).size.height * 0.5,
      ),
      child: Center(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.cardDark.withOpacity(0.6),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  FontAwesomeIcons.ghost,
                  color: Colors.grey[400],
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'No devices found',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _selectedCategory == 'All'
                    ? 'Add your first device to get started'
                    : 'No ${_selectedCategory.toLowerCase()} devices found',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 160,
                child: ElevatedButton.icon(
                  onPressed: () => _navigateToAddDevice(context),
                  icon: const Icon(FontAwesomeIcons.plus, size: 16),
                  label: const Text('Add Device'),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: AppColors.secondary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton(
      onPressed: () => _navigateToAddDevice(context),
      backgroundColor: AppColors.secondary,
      elevation: 4,
      child: const Icon(FontAwesomeIcons.plus, color: Colors.white),
    ).animate().scale(
          duration: 300.ms,
          delay: 500.ms,
          curve: Curves.elasticOut,
        );
  }

  void _navigateToAddDevice(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddDeviceScreen(
          deviceType: '',
          placeId: widget.place.id,
          onDeviceAdded: (String deviceId) {
            _loadDevices(); // Refresh devices when new one is added
          },
        ),
      ),
    );
  }

  void _showOptionsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              widget.place.name,
              style: GoogleFonts.poppins(
                textStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 20),
            _buildOptionItem(
              icon: FontAwesomeIcons.penToSquare,
              title: 'Edit Room',
              onTap: () {
                Navigator.pop(context);
                // Navigate to edit room screen
              },
            ),
            _buildOptionItem(
              icon: FontAwesomeIcons.bolt,
              title: 'Power Management',
              onTap: () {
                Navigator.pop(context);
                // Navigate to power management screen
              },
            ),
            _buildOptionItem(
              icon: FontAwesomeIcons.clockRotateLeft,
              title: 'Activity History',
              onTap: () {
                Navigator.pop(context);
                // Navigate to activity history screen
              },
            ),
            _buildOptionItem(
              icon: FontAwesomeIcons.trash,
              title: 'Delete Room',
              color: Colors.redAccent,
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmationDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: color ?? Colors.white,
        size: 20,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: color ?? Colors.white,
          fontSize: 16,
        ),
      ),
      onTap: onTap,
    );
  }

  void _showDeleteConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(
              FontAwesomeIcons.triangleExclamation,
              color: Colors.redAccent,
              size: 24,
            ),
            const SizedBox(width: 12),
            Text(
              'Delete Room',
              style: GoogleFonts.poppins(
                textStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete ${widget.place.name}? This action cannot be undone and all associated devices will be removed.',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 16,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Handle room deletion
              Navigator.pop(
                  context); // Return to previous screen after deletion
            },
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
