import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:teemo/home/home.dart';
import 'package:teemo/widgets/colors.dart';
import 'package:teemo/services/device_service.dart';

/// Represents the various states during the device linking process
enum LinkingState { initial, connecting, success, failed }

/// A screen that handles the process of linking a new device to the user's account
class LinkingDeviceScreen extends StatefulWidget {
  final String deviceType;
  final String placeId;
  final String deviceId;
  final String deviceName;
  final String category;
  final int timeoutSeconds;

  const LinkingDeviceScreen({
    Key? key,
    required this.deviceType,
    required this.placeId,
    required this.deviceId,
    required this.deviceName,
    required this.category,
    this.timeoutSeconds = 30,
  }) : super(key: key);

  @override
  _LinkingDeviceScreenState createState() => _LinkingDeviceScreenState();
}

class _LinkingDeviceScreenState extends State<LinkingDeviceScreen>
    with SingleTickerProviderStateMixin {
  double _progress = 0.0;
  late Timer _timer;
  late AnimationController _animationController;
  LinkingState _linkingState = LinkingState.initial;
  bool _isTimedOut = false;
  String? _errorMessage;

  final DeviceService _deviceService = DeviceService();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // Start the linking process after a short delay
    _setupLinkingProcess();
  }

  /// Sets up and begins the device linking process
  void _setupLinkingProcess() {
    // Short delay to allow screen transition to complete
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;

      setState(() => _linkingState = LinkingState.connecting);
      _startProgress();
      _startTimeout();

      // Start the actual device linking process
      _attemptDeviceLinking();
    });
  }

  /// Starts the visual progress indicator
  void _startProgress() {
    const int updateInterval = 500;
    const double progressIncrement = 0.02;

    _timer = Timer.periodic(
      const Duration(milliseconds: updateInterval),
      (timer) {
        if (!mounted) return;

        setState(() {
          if (_progress >= 1.0) {
            _timer.cancel();
          } else if (!_isTimedOut) {
            _progress += progressIncrement;
          }
        });
      },
    );
  }

  /// Sets up a timeout for the linking process
  void _startTimeout() {
    Future.delayed(Duration(seconds: widget.timeoutSeconds), () {
      if (mounted && _linkingState == LinkingState.connecting) {
        _isTimedOut = true;
        _onLinkingFailed(
            'Connection timed out. Please check your device and try again.');
      }
    });
  }

  /// Attempts to link the device with the backend service
  Future<void> _attemptDeviceLinking() async {
    try {
      // Simulate network delay for better UX
      await Future.delayed(const Duration(seconds: 2));

      // Add the device using the service
      await _deviceService.addDevice(
        widget.placeId,
        widget.deviceName,
        widget.deviceType,
        deviceId: widget.deviceId,
        category: widget.category,
        initialProperties: {
          'name': widget.deviceName,
          'type': widget.deviceType,
          'category': widget.category,
        },
      );

      if (mounted) {
        _onLinkingComplete();
      }
    } catch (e) {
      if (mounted) {
        _onLinkingFailed('Failed to link device: ${e.toString()}');
      }
    }
  }

  /// Handles successful device linking
  void _onLinkingComplete() {
    if (_timer.isActive) _timer.cancel();

    setState(() {
      _progress = 1.0;
      _linkingState = LinkingState.success;
    });

    _animationController.repeat();

    // Navigate to success screen after a short delay
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => Dashboard(),
        ),
        (route) => false,
      );
    });
  }

  /// Handles device linking failure
  void _onLinkingFailed(String reason) {
    if (_timer.isActive) _timer.cancel();

    setState(() {
      _linkingState = LinkingState.failed;
      _errorMessage = reason;
    });

    // Show error dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildErrorDialog(),
    );
  }

  /// Builds the error dialog when linking fails
  Widget _buildErrorDialog() {
    return Dialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              'Connection Failed',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'An unknown error occurred',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: Colors.grey[400],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _DialogButton(
                  label: 'Cancel',
                  isPrimary: false,
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pop();
                  },
                ),
                _DialogButton(
                  label: 'Retry',
                  isPrimary: true,
                  onPressed: () {
                    Navigator.of(context).pop();
                    setState(() {
                      _progress = 0.0;
                      _isTimedOut = false;
                      _linkingState = LinkingState.initial;
                      _errorMessage = null;
                    });
                    _setupLinkingProcess();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    if (_timer.isActive) _timer.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: _buildAppBar(),
      body: SafeArea(
        child: Column(
          children: [
            LinearProgressIndicator(
              value: _progress,
              backgroundColor: Colors.grey[900],
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
            Expanded(
              child: _buildLinkingContent(),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the app bar for the screen
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.maybePop(context),
      ),
      title: Text(
        "Linking Device",
        style: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      centerTitle: true,
    );
  }

  /// Builds the main linking status UI
  Widget _buildLinkingContent() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildProgressIndicator(),
          const SizedBox(height: 40),
          Text(
            _getLinkingStateText(),
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _getLinkingStateSubtext(),
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: Colors.grey[400],
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the circular progress indicator
  Widget _buildProgressIndicator() {
    return CircularPercentIndicator(
      animation: true,
      animateFromLastPercent: true,
      animationDuration: 500,
      radius: 70.0,
      lineWidth: 10.0,
      percent: _progress.clamp(0.0, 1.0),
      circularStrokeCap: CircularStrokeCap.round,
      center: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: _getLinkingStateColor().withOpacity(0.3),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Icon(
          _getLinkingStateIcon(),
          size: 48,
          color: _getLinkingStateColor(),
        ),
      ),
      backgroundColor: Colors.grey[800]!,
      progressColor: _getLinkingStateColor(),
    );
  }

  /// Returns the appropriate icon based on linking state
  IconData _getLinkingStateIcon() {
    switch (_linkingState) {
      case LinkingState.connecting:
        return Icons.link;
      case LinkingState.success:
        return Icons.check_circle;
      case LinkingState.failed:
        return Icons.error_outline;
      default:
        return Icons.link;
    }
  }

  /// Returns the appropriate color based on linking state
  Color _getLinkingStateColor() {
    switch (_linkingState) {
      case LinkingState.connecting:
        return AppColors.primary;
      case LinkingState.success:
        return Colors.green;
      case LinkingState.failed:
        return Colors.red;
      default:
        return AppColors.primary;
    }
  }

  /// Returns the appropriate header text based on linking state
  String _getLinkingStateText() {
    switch (_linkingState) {
      case LinkingState.connecting:
        return "Linking Your Device";
      case LinkingState.success:
        return "Successfully Linked!";
      case LinkingState.failed:
        return "Connection Failed";
      default:
        return "Preparing to Link";
    }
  }

  /// Returns the appropriate subtext based on linking state
  String _getLinkingStateSubtext() {
    switch (_linkingState) {
      case LinkingState.connecting:
        return "Please wait while we establish a secure connection with your ${widget.deviceName}";
      case LinkingState.success:
        return "Your ${widget.deviceName} has been successfully connected to your account";
      case LinkingState.failed:
        return "We encountered an error while trying to link your ${widget.deviceName}";
      default:
        return "Getting everything ready for you";
    }
  }
}

/// A reusable button for dialogs
class _DialogButton extends StatelessWidget {
  final String label;
  final bool isPrimary;
  final VoidCallback onPressed;

  const _DialogButton({
    required this.label,
    required this.isPrimary,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return isPrimary
        ? ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
              elevation: 4,
            ),
            child: Text(
              label,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        : TextButton(
            onPressed: onPressed,
            child: Text(
              label,
              style: GoogleFonts.inter(color: Colors.grey[400]),
            ),
          );
  }
}

/// A screen displayed after successful device linking
class LinkingSuccessScreen extends StatelessWidget {
  final String deviceName;
  final String deviceType;

  const LinkingSuccessScreen({
    Key? key,
    required this.deviceName,
    required this.deviceType,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildSuccessIcon(),
              const SizedBox(height: 40),
              Text(
                "Setup Complete!",
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "Your $deviceName has been successfully added to your home",
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: Colors.grey[400],
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 48),
              _buildDoneButton(context),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the success icon with animation
  Widget _buildSuccessIcon() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.2),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: const Icon(
        Icons.check_circle_outline,
        color: Colors.green,
        size: 80,
      ),
    );
  }

  /// Builds the done button
  Widget _buildDoneButton(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        Navigator.of(context).pop();
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 4,
      ),
      child: Text(
        "Done",
        style: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
