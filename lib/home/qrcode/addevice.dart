import 'package:flutter/material.dart';
import 'package:teemo/home/qrcode/linking.dart';
import 'package:teemo/widgets/icons.dart';
import 'package:teemo/widgets/colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart'; // Add for animations

// Constants for consistent spacing and dimensions
class UIConstants {
  // Spacing
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;
  static const double paddingXLarge = 32.0;

  // Radius
  static const double radiusSmall = 10.0;
  static const double radiusMedium = 15.0;
  static const double radiusLarge = 20.0;

  // Typography
  static const double fontSizeSmall = 12.0;
  static const double fontSizeMedium = 16.0;
  static const double fontSizeLarge = 20.0;
  static const double fontSizeXLarge = 24.0;

  // Device Circle dimensions
  static const double deviceCircleSize = 65.0;
}

// Models
class DeviceType {
  final String id;
  final String name;
  final Color color;
  final IconData icon;
  final List<DeviceOption> devices;

  const DeviceType({
    required this.id,
    required this.name,
    required this.color,
    required this.icon,
    required this.devices,
  });
}

class DeviceOption {
  final String id;
  final String name;
  final IconData icon;
  final String description;

  const DeviceOption({
    required this.id,
    required this.name,
    required this.icon,
    this.description = '',
  });
}

// Device Data Provider
class DeviceDataProvider {
  static final Map<String, DeviceType> deviceTypes = {
    'lighting': DeviceType(
      id: 'lighting',
      name: 'Lighting',
      color: const Color(0xFFFF6B6B),
      icon: DeviceIcons.getIconForType('lighting'),
      devices: [
        DeviceOption(
          id: 'smart_lamp',
          name: 'Smart Lamp',
          icon: DeviceIcons.getIconForType('smart_lamp'),
          description: 'Smart RGB lamp with adjustable brightness',
        ),
        DeviceOption(
          id: 'desk_lamp',
          name: 'Desk Lamp',
          icon: DeviceIcons.getIconForType('desk_lamp'),
          description: 'Dimmable desk lamp',
        ),
        DeviceOption(
          id: 'outdoor_lamp',
          name: 'Outdoor Lamp',
          icon: DeviceIcons.getIconForType('outdoor_lamp'),
          description: 'Weather-resistant outdoor lighting',
        ),
        DeviceOption(
          id: 'light_bulb',
          name: 'Light Bulb',
          icon: DeviceIcons.getIconForType('light_bulb'),
          description: 'Smart LED bulb',
        ),
      ],
    ),
    'security': DeviceType(
      id: 'security',
      name: 'Security',
      color: const Color(0xFF4ECDC4),
      icon: DeviceIcons.getIconForType('security'),
      devices: [
        DeviceOption(
          id: 'camera',
          name: 'Camera',
          icon: DeviceIcons.getIconForType('camera'),
          description: 'HD security camera with motion detection',
        ),
        DeviceOption(
          id: 'door_lock',
          name: 'Door Lock',
          icon: DeviceIcons.getIconForType('door_lock'),
          description: 'Smart door lock with keypad',
        ),
      ],
    ),
    'climate': DeviceType(
      id: 'climate',
      name: 'Climate',
      color: const Color(0xFF45B7D1),
      icon: DeviceIcons.getIconForType('climate'),
      devices: [
        DeviceOption(
          id: 'ac',
          name: 'Air Conditioner',
          icon: DeviceIcons.getIconForType('ac'),
          description: 'Smart AC with temperature control',
        ),
        DeviceOption(
          id: 'heater',
          name: 'Heater',
          icon: DeviceIcons.getIconForType('heater'),
          description: 'Smart heater with scheduling',
        ),
      ],
    ),
    'speakers': DeviceType(
      id: 'speakers',
      name: 'Speakers',
      color: const Color(0xFFE27D60),
      icon: DeviceIcons.getIconForType('speakers'),
      devices: [
        DeviceOption(
          id: 'smart_speaker',
          name: 'Smart Speaker',
          icon: DeviceIcons.getIconForType('smart_speaker'),
          description: 'Voice-controlled smart speaker',
        ),
        DeviceOption(
          id: 'bluetooth_speaker',
          name: 'Bluetooth Speaker',
          icon: DeviceIcons.getIconForType('bluetooth_speaker'),
          description: 'Portable Bluetooth speaker',
        ),
      ],
    ),
  };

  static String getCategoryForDeviceType(String deviceType) {
    for (var entry in deviceTypes.entries) {
      if (entry.value.devices.any((device) => device.id == deviceType)) {
        return entry.key;
      }
    }
    return '';
  }
}

// Main Screen Widget
class AddDeviceScreen extends StatefulWidget {
  final String deviceType;
  final String placeId;
  final Function(String deviceId)? onDeviceAdded;

  const AddDeviceScreen({
    Key? key,
    required this.deviceType,
    required this.placeId,
    this.onDeviceAdded,
  }) : super(key: key);

  @override
  _AddDeviceScreenState createState() => _AddDeviceScreenState();
}

class _AddDeviceScreenState extends State<AddDeviceScreen>
    with SingleTickerProviderStateMixin {
  String? selectedType;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    selectedType = widget.deviceType.isEmpty
        ? DeviceDataProvider.deviceTypes.keys.first
        : widget.deviceType.toLowerCase();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleDeviceAddition(String deviceName, String deviceId,
      String deviceType, String category) async {
    try {
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => LinkingDeviceScreen(
            deviceId: deviceId,
            deviceName: deviceName,
            deviceType: deviceType,
            placeId: widget.placeId,
            category: category,
          ),
        ),
      );

      if (result == true && widget.onDeviceAdded != null) {
        widget.onDeviceAdded!(deviceId);
      }
    } catch (e) {
      _showErrorDialog('Failed to add device: ${e.toString()}');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
        ),
        title: Text(
          'Error',
          style: GoogleFonts.lato(
            textStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        content: Text(
          message,
          style: GoogleFonts.lato(
            textStyle: const TextStyle(
              color: Colors.white70,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
            ),
            child: Text(
              'OK',
              style: GoogleFonts.lato(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeviceIdInput(BuildContext context, DeviceOption device) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _DeviceIdInputSheet(
        device: device,
        onSubmit: (deviceName, deviceId) async {
          Navigator.pop(context);
          final category =
              DeviceDataProvider.getCategoryForDeviceType(device.id);
          await _handleDeviceAddition(
              deviceName, deviceId, device.id, category);
        },
      ),
    );
  }

  void _handleNewDeviceType() {
    // Future feature: add custom device type
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Custom device types coming soon!',
          style: GoogleFonts.lato(),
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(UIConstants.radiusSmall),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Add Device',
          style: GoogleFonts.lato(
            textStyle: const TextStyle(
              color: Colors.white,
              fontSize: UIConstants.fontSizeLarge,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: UIConstants.paddingLarge),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: UIConstants.paddingLarge),
              child: _DeviceTypeSelector(
                selectedType: selectedType,
                onTypeSelected: (type) => setState(() => selectedType = type),
                onAddType: _handleNewDeviceType,
              ),
            ),
            const SizedBox(height: UIConstants.paddingXLarge),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: UIConstants.paddingLarge),
              child: Text(
                'Select a device type',
                style: GoogleFonts.lato(
                  textStyle: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: UIConstants.fontSizeMedium,
                  ),
                ),
              ),
            ),
            const SizedBox(height: UIConstants.paddingMedium),
            Expanded(
              child: FadeTransition(
                opacity: _animationController,
                child: _DeviceGrid(
                  selectedType: selectedType,
                  onDeviceSelected: _showDeviceIdInput,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceTypeSelector extends StatelessWidget {
  final String? selectedType;
  final Function(String) onTypeSelected;
  final VoidCallback onAddType;

  const _DeviceTypeSelector({
    Key? key,
    required this.selectedType,
    required this.onTypeSelected,
    required this.onAddType,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ...DeviceDataProvider.deviceTypes.entries.map((entry) => Padding(
                padding:
                    const EdgeInsets.only(right: UIConstants.paddingMedium),
                child: _DeviceTypeCircle(
                  deviceType: entry.value,
                  isSelected: selectedType == entry.key,
                  onTap: () => onTypeSelected(entry.key),
                ),
              )),
          _AddDeviceTypeButton(onTap: onAddType),
        ],
      ),
    );
  }
}

class _DeviceTypeCircle extends StatelessWidget {
  final DeviceType deviceType;
  final bool isSelected;
  final VoidCallback onTap;

  const _DeviceTypeCircle({
    Key? key,
    required this.deviceType,
    required this.isSelected,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: UIConstants.deviceCircleSize,
            height: UIConstants.deviceCircleSize,
            decoration: BoxDecoration(
              color: deviceType.color.withOpacity(isSelected ? 1.0 : 0.7),
              shape: BoxShape.circle,
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: deviceType.color.withOpacity(0.5),
                        blurRadius: 8,
                        spreadRadius: 2,
                      )
                    ]
                  : null,
              border:
                  isSelected ? Border.all(color: Colors.white, width: 2) : null,
            ),
            child: Center(
              child: Icon(
                deviceType.icon,
                color: Colors.white,
                size: 30,
              ),
            ),
          )
              .animate(target: isSelected ? 1 : 0)
              .scale(
                  begin: const Offset(0.9, 0.9),
                  end: const Offset(1.0, 1.0),
                  duration: 300.ms)
              .fadeIn(duration: 200.ms),
          const SizedBox(height: UIConstants.paddingSmall),
          Text(
            deviceType.name,
            style: GoogleFonts.lato(
              textStyle: TextStyle(
                fontSize: UIConstants.fontSizeSmall,
                color: isSelected ? Colors.white : Colors.white60,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddDeviceTypeButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AddDeviceTypeButton({
    Key? key,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: UIConstants.deviceCircleSize,
            height: UIConstants.deviceCircleSize,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.8),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 6,
                  spreadRadius: 1,
                )
              ],
            ),
            child: const Icon(
              Icons.add,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(height: UIConstants.paddingSmall),
          Text(
            'Custom',
            style: GoogleFonts.lato(
              textStyle: const TextStyle(
                fontSize: UIConstants.fontSizeSmall,
                color: Colors.white60,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceGrid extends StatelessWidget {
  final String? selectedType;
  final Function(BuildContext, DeviceOption) onDeviceSelected;

  const _DeviceGrid({
    Key? key,
    required this.selectedType,
    required this.onDeviceSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (selectedType == null) return const SizedBox.shrink();

    final devices = DeviceDataProvider.deviceTypes[selectedType]?.devices ?? [];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: UIConstants.paddingLarge),
      child: devices.isEmpty
          ? _buildEmptyState()
          : GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: UIConstants.paddingMedium,
                mainAxisSpacing: UIConstants.paddingMedium,
                childAspectRatio: 1.4,
              ),
              itemCount: devices.length,
              itemBuilder: (context, index) => _DeviceCard(
                device: devices[index],
                onTap: () => onDeviceSelected(context, devices[index]),
                index: index,
              ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.devices_other,
            size: 80,
            color: Colors.white.withOpacity(0.3),
          ),
          const SizedBox(height: UIConstants.paddingMedium),
          Text(
            'No devices available in this category',
            style: GoogleFonts.lato(
              textStyle: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: UIConstants.fontSizeMedium,
              ),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  final DeviceOption device;
  final VoidCallback onTap;
  final int index;

  const _DeviceCard({
    Key? key,
    required this.device,
    required this.onTap,
    required this.index,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final category = DeviceDataProvider.getCategoryForDeviceType(device.id);
    final categoryColor = category.isNotEmpty
        ? DeviceDataProvider.deviceTypes[category]?.color
        : AppColors.primary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            if (categoryColor != null)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: categoryColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(UIConstants.radiusMedium),
                      topRight: Radius.circular(UIConstants.radiusMedium),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(UIConstants.paddingMedium),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(UIConstants.paddingSmall),
                        decoration: BoxDecoration(
                          color: categoryColor?.withOpacity(0.2) ??
                              Colors.white.withOpacity(0.1),
                          borderRadius:
                              BorderRadius.circular(UIConstants.radiusSmall),
                        ),
                        child: Icon(
                          device.icon,
                          color: categoryColor ?? Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: UIConstants.paddingSmall),
                      Expanded(
                        child: Text(
                          device.name,
                          style: GoogleFonts.lato(
                            textStyle: const TextStyle(
                              color: Colors.white,
                              fontSize: UIConstants.fontSizeMedium,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (device.description.isNotEmpty) ...[
                    const SizedBox(height: UIConstants.paddingSmall),
                    Text(
                      device.description,
                      style: GoogleFonts.lato(
                        textStyle: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: UIConstants.fontSizeSmall,
                        ),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(
          delay: Duration(milliseconds: index * 50),
          duration: 300.ms,
        )
        .slideY(
          begin: 0.2,
          end: 0,
          delay: Duration(milliseconds: index * 50),
          duration: 300.ms,
          curve: Curves.easeOutQuad,
        );
  }
}

class _DeviceIdInputSheet extends StatelessWidget {
  final DeviceOption device;
  final Function(String, String) onSubmit;
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _nameController = TextEditingController();

  _DeviceIdInputSheet({
    Key? key,
    required this.device,
    required this.onSubmit,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final category = DeviceDataProvider.getCategoryForDeviceType(device.id);
    final categoryColor = category.isNotEmpty
        ? DeviceDataProvider.deviceTypes[category]?.color
        : AppColors.primary;

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(UIConstants.radiusLarge),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(UIConstants.paddingLarge),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle indicator
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius:
                        BorderRadius.circular(UIConstants.radiusSmall),
                  ),
                ),
              ),
              const SizedBox(height: UIConstants.paddingLarge),

              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(UIConstants.paddingSmall),
                    decoration: BoxDecoration(
                      color: categoryColor?.withOpacity(0.2) ??
                          Colors.white.withOpacity(0.1),
                      borderRadius:
                          BorderRadius.circular(UIConstants.radiusSmall),
                    ),
                    child: Icon(
                      device.icon,
                      color: categoryColor ?? Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: UIConstants.paddingMedium),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add ${device.name}',
                          style: GoogleFonts.lato(
                            textStyle: const TextStyle(
                              color: Colors.white,
                              fontSize: UIConstants.fontSizeLarge,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (device.description.isNotEmpty)
                          Text(
                            device.description,
                            style: GoogleFonts.lato(
                              textStyle: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: UIConstants.fontSizeSmall,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: UIConstants.paddingXLarge),

              // Name Field
              Text(
                'Device Name',
                style: GoogleFonts.lato(
                  textStyle: const TextStyle(
                    color: Colors.white,
                    fontSize: UIConstants.fontSizeMedium,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: UIConstants.paddingSmall),
              TextFormField(
                controller: _nameController,
                style: GoogleFonts.lato(
                  textStyle: const TextStyle(color: Colors.white),
                ),
                decoration: InputDecoration(
                  hintText: 'Enter a name (3-20 characters)',
                  hintStyle: GoogleFonts.lato(
                    textStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                  ),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(UIConstants.radiusSmall),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: const Icon(
                    Icons.edit,
                    color: AppColors.textSecondary,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: UIConstants.paddingMedium,
                    horizontal: UIConstants.paddingMedium,
                  ),
                ),
                maxLength: 20,
                validator: (value) {
                  if (value == null || value.trim().length < 3) {
                    return 'Name must be at least 3 characters';
                  }
                  return null;
                },
                autofocus: true,
              ),
              const SizedBox(height: UIConstants.paddingLarge),

              // Device ID Field
              Text(
                'Device ID',
                style: GoogleFonts.lato(
                  textStyle: const TextStyle(
                    color: Colors.white,
                    fontSize: UIConstants.fontSizeMedium,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: UIConstants.paddingSmall),
              TextFormField(
                controller: _idController,
                style: GoogleFonts.lato(
                  textStyle: const TextStyle(color: Colors.white),
                ),
                decoration: InputDecoration(
                  hintText: 'Enter device ID (6-12 characters)',
                  hintStyle: GoogleFonts.lato(
                    textStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                  ),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(UIConstants.radiusSmall),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: const Icon(
                    Icons.vpn_key,
                    color: AppColors.textSecondary,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: UIConstants.paddingMedium,
                    horizontal: UIConstants.paddingMedium,
                  ),
                ),
                maxLength: 12,
                validator: (value) {
                  if (value == null || value.trim().length < 6) {
                    return 'ID must be at least 6 characters';
                  }
                  return null;
                },
                keyboardType: TextInputType.visiblePassword,
              ),
              const SizedBox(height: UIConstants.paddingXLarge),

              // Add Button
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState?.validate() ?? false) {
                      final deviceName = _nameController.text.trim();
                      final deviceId = _idController.text.trim();
                      if (deviceName.isNotEmpty && deviceId.isNotEmpty) {
                        onSubmit(deviceName, deviceId);
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(UIConstants.radiusSmall),
                    ),
                  ),
                  child: Text(
                    'Add Device',
                    style: GoogleFonts.lato(
                      textStyle: const TextStyle(
                        fontSize: UIConstants.fontSizeMedium,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),

              // Info text
              const SizedBox(height: UIConstants.paddingMedium),
              Center(
                child: Text(
                  'You can find the device ID on the device packaging or manual',
                  style: GoogleFonts.lato(
                    textStyle: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: UIConstants.fontSizeSmall,
                    ),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .slide(
          begin: const Offset(0, 1),
          end: Offset.zero,
          duration: 400.ms,
          curve: Curves.easeOutQuad,
        )
        .fadeIn(duration: 300.ms);
  }
}
