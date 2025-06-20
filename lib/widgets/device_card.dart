import 'package:flutter/material.dart';
import 'package:teemo/services/device_service.dart';
import 'package:teemo/services/models.dart';
import 'package:teemo/widgets/colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class DeviceCard extends StatefulWidget {
  final Device device;
  final VoidCallback onToggle;

  const DeviceCard({
    Key? key,
    required this.device,
    required this.onToggle,
  }) : super(key: key);

  @override
  State<DeviceCard> createState() => _DeviceCardState();
}

class _DeviceCardState extends State<DeviceCard> {
  void _navigateToBottomSheet(BuildContext context) {
    setState(() {});

    // Add a slight delay for animation feedback
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) {
        setState(() {});

        final bottomSheet = DeviceService().getDeviceBottomSheet(
          widget.device.id,
          widget.device.type,
          category: widget.device.category,
        );

        if (bottomSheet != null) {
          showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            isScrollControlled: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            builder: (_) => bottomSheet,
          );
        } else {
          _showErrorSnackBar(context);
        }
      }
    });
  }

  void _showErrorSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(FontAwesomeIcons.circleExclamation,
                color: Colors.white, size: 16),
            const SizedBox(width: 12),
            const Text('No control available for this device'),
          ],
        ),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isOn = widget.device.isOn;
    final String status = widget.device.status.toLowerCase();

    return GestureDetector(
      onTap: () => _navigateToBottomSheet(context),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(14), // Reduced from 16 to 14
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              isOn
                  ? AppColors.cardBackground.withOpacity(0.9)
                  : AppColors.cardBackground.withOpacity(0.7),
              AppColors.cardBackground.withOpacity(0.7),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isOn
                ? AppColors.secondary.withOpacity(0.3)
                : AppColors.cardBorder.withOpacity(0.1),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isOn
                  ? AppColors.secondary.withOpacity(0.15)
                  : Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with icon and switch
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildDeviceIcon(),
                _buildToggleSwitch(),
              ],
            ),
            const SizedBox(height: 12), // Reduced from 16 to 12

            // Device name with status dot
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.device.name,
                    style: GoogleFonts.poppins(
                      textStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _getStatusColor(status),
                    boxShadow: [
                      BoxShadow(
                        color: _getStatusColor(status).withOpacity(0.5),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8), // Reduced from 10 to 8

            // Device details
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Status badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.cardDark,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: _getStatusColor(status).withOpacity(0.5),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isOn
                            ? FontAwesomeIcons.powerOff
                            : FontAwesomeIcons.plug,
                        color: isOn ? Colors.greenAccent : Colors.white70,
                        size: 12,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isOn ? 'Active' : 'Standby',
                        style: GoogleFonts.poppins(
                          textStyle: TextStyle(
                            color: isOn ? Colors.greenAccent : Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // More options button
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.cardDark.withOpacity(0.6),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    FontAwesomeIcons.ellipsisH,
                    color: Colors.grey[400],
                    size: 12,
                  ),
                ),
              ],
            ),

            // Optional: Additional device info (could be customized based on device type)
            if (_shouldShowAdditionalInfo())
              Padding(
                padding: const EdgeInsets.only(top: 8), // Reduced from 12 to 8
                child: _buildAdditionalInfo(),
              ),
          ],
        ),
      ),
    )
        .animate(onPlay: (controller) => controller.repeat())
        .shimmer(
            duration: 3.seconds,
            delay: 5.seconds,
            color: AppColors.secondary.withOpacity(0.1))
        .then(delay: 2.seconds)
        .shimmer(
            duration: 3.seconds,
            color: Colors.transparent); // End shimmer effect
  }

  Widget _buildDeviceIcon() {
    final bool isOn = widget.device.isOn;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            isOn
                ? AppColors.secondary.withOpacity(0.2)
                : AppColors.cardDark.withOpacity(0.8),
            isOn
                ? AppColors.secondary.withOpacity(0.1)
                : AppColors.cardDark.withOpacity(0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: isOn
              ? AppColors.secondary.withOpacity(0.3)
              : AppColors.cardBorder.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Icon(
        widget.device.icon,
        color: isOn ? AppColors.secondary : Colors.grey[400],
        size: 22,
      ),
    );
  }

  Widget _buildToggleSwitch() {
    final bool isOn = widget.device.isOn;

    return GestureDetector(
      onTap: widget.onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 50,
        height: 26,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          color:
              isOn ? AppColors.secondary.withOpacity(0.8) : AppColors.cardDark,
          border: Border.all(
            color: isOn
                ? AppColors.secondary.withOpacity(0.5)
                : AppColors.cardBorder.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              left: isOn ? 26 : 2,
              top: 2,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isOn ? Colors.white : Colors.grey[400],
                  boxShadow: [
                    BoxShadow(
                      color: isOn
                          ? AppColors.secondary.withOpacity(0.3)
                          : Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      spreadRadius: 1,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    isOn
                        ? FontAwesomeIcons.powerOff
                        : FontAwesomeIcons.powerOff,
                    color: isOn ? AppColors.secondary : Colors.grey[700],
                    size: 8,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _shouldShowAdditionalInfo() {
    // You can customize this based on device type or other factors
    return widget.device.type == 'thermostat' ||
        widget.device.type == 'speaker' ||
        widget.device.type == 'light';
  }

  Widget _buildAdditionalInfo() {
    // Customize based on device type
    if (widget.device.type == 'thermostat') {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          children: [
            Icon(
              FontAwesomeIcons.temperatureLow,
              color: Colors.orangeAccent,
              size: 14,
            ),
            const SizedBox(width: 8),
            Text(
              '22°C',
              style: GoogleFonts.poppins(
                textStyle: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    } else if (widget.device.type == 'speaker') {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          children: [
            Icon(
              FontAwesomeIcons.volumeHigh,
              color: Colors.blueAccent,
              size: 14,
            ),
            const SizedBox(width: 8),
            Text(
              '65%',
              style: GoogleFonts.poppins(
                textStyle: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    } else if (widget.device.type == 'light') {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          children: [
            Icon(
              FontAwesomeIcons.lightbulb,
              color: Colors.yellowAccent,
              size: 14,
            ),
            const SizedBox(width: 8),
            Text(
              'Brightness: 80%',
              style: GoogleFonts.poppins(
                textStyle: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Default case
    return const SizedBox.shrink();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'online':
        return Colors.green;
      case 'offline':
        return Colors.grey;
      case 'error':
        return Colors.redAccent;
      case 'warning':
        return Colors.orangeAccent;
      case 'updating':
        return Colors.blueAccent;
      default:
        return Colors.blueGrey;
    }
  }
}
