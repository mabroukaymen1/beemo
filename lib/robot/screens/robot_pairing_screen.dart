import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:teemo/widgets/colors.dart';
import '../services/firebase_service.dart';
import '../models/beemo_robot.dart';

class RobotPairingScreen extends StatefulWidget {
  @override
  _RobotPairingScreenState createState() => _RobotPairingScreenState();
}

class _RobotPairingScreenState extends State<RobotPairingScreen>
    with TickerProviderStateMixin {
  final FirebaseService _firebaseService = FirebaseService();
  final TextEditingController _robotIdController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late AnimationController _pulseAnimation;
  StreamSubscription<DocumentSnapshot>? _statusListener;
  StreamSubscription<BeemoRobot?>? _robotStatusSubscription;

  bool _isLoading = true;
  bool _isPairing = false;
  BeemoRobot? _currentRobot;
  String? _errorMessage;

  // Add new state variables
  bool _robotConfirmed = false;
  Timer? _pairingTimer;
  int _pairingAttempts = 0;
  final int _maxPairingAttempts = 30;

  @override
  void initState() {
    super.initState();
    _pulseAnimation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _checkExistingConnection();
    _setupStatusListener();
  }

  @override
  void dispose() {
    _pairingTimer?.cancel();
    _statusListener?.cancel();
    _robotStatusSubscription?.cancel();
    _robotIdController.dispose();
    _pulseAnimation.dispose();
    super.dispose();
  }

  Future<void> _checkExistingConnection() async {
    setState(() => _isLoading = true);

    try {
      final robot = await _firebaseService.getConnectedRobot();
      if (robot != null) {
        setState(() {
          _currentRobot = robot;
          _robotIdController.text = robot.id;
        });
        _listenToRobotStatus(robot.id);
      }
    } catch (e) {
      setState(() => _errorMessage = 'Failed to check connection: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _setupStatusListener() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final statusDoc = FirebaseFirestore.instance
        .collection('beemo_status')
        .doc('${user.uid}_robot');

    _statusListener = statusDoc.snapshots().listen(
      (snapshot) {
        if (!snapshot.exists) return;

        final data = snapshot.data();
        if (data == null) return;

        final status = data['status'] as String?;
        final isOnline = status == 'online';

        if (mounted) {
          setState(() {
            if (_currentRobot != null) {
              _currentRobot = _currentRobot!.copyWith(
                isOnline: isOnline,
                status: status ?? 'unknown',
                lastSeen: DateTime.now(),
              );
            }
          });
        }
      },
      onError: (error) {
        print('Error in robot status listener: $error');
      },
    );
  }

  void _listenToRobotStatus(String robotId) {
    _firebaseService.robotStatusStream(robotId).listen(
      (robot) {
        if (mounted) {
          setState(() => _currentRobot = robot);
        }
      },
      onError: (error) {
        setState(() => _errorMessage = 'Lost connection: $error');
      },
    );
  }

  Future<void> _handlePairRobot() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isPairing = true;
      _errorMessage = null;
      _robotConfirmed = false;
      _pairingAttempts = 0;
    });

    final robotId = _robotIdController.text.trim();

    try {
      // Update status in Firestore to indicate app is ready to pair
      await _firebaseService.updateRobotStatus(robotId, 'pairing_requested');

      // Start polling for robot confirmation
      _pairingTimer = Timer.periodic(Duration(seconds: 1), (timer) async {
        _pairingAttempts++;

        if (_pairingAttempts > _maxPairingAttempts) {
          timer.cancel();
          if (mounted) {
            setState(() {
              _isPairing = false;
              _errorMessage = 'Pairing timed out. Please try again.';
            });
          }
          return;
        }

        final status = await _firebaseService.getRobotStatus(robotId);

        if (status == 'pairing_confirmed') {
          timer.cancel();
          if (mounted) {
            setState(() => _robotConfirmed = true);
            // Complete the pairing process
            final success = await _firebaseService.pairWithRobot(robotId);
            if (success) {
              _listenToRobotStatus(robotId);
              _showSuccessSnackBar('Successfully paired with BEEMO!');
              HapticFeedback.lightImpact();
              Navigator.of(context).pop(true);
            }
          }
        } else if (status == 'pairing_rejected') {
          timer.cancel();
          if (mounted) {
            setState(() {
              _isPairing = false;
              _errorMessage = 'Pairing rejected by robot.';
            });
          }
        }
      });
    } catch (e) {
      setState(() {
        _isPairing = false;
        _errorMessage = 'Error: $e';
      });
    }
  }

  Widget _buildPairingStatus() {
    if (!_isPairing) return SizedBox.shrink();

    final progress = (_pairingAttempts / _maxPairingAttempts) * 100;

    return Container(
      margin: EdgeInsets.symmetric(vertical: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _robotConfirmed ? Color(0xFF00FF88) : Colors.orange,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          if (!_robotConfirmed)
            LinearProgressIndicator(
              value: progress / 100,
              backgroundColor: Colors.grey[800],
              valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
            ),
          SizedBox(height: 16),
          Text(
            _robotConfirmed
                ? 'Robot confirmed! Completing pairing...'
                : 'Waiting for robot confirmation...',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Timeout in ${_maxPairingAttempts - _pairingAttempts} seconds',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0A0A0A),
      appBar: _buildAppBar(),
      body: _isLoading
          ? _buildLoadingIndicator()
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    physics: BouncingScrollPhysics(),
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_currentRobot == null) _buildRobotIdInput(),
                          _buildPairingStatus(), // Add the new status widget
                          _buildStatusCard(),
                          if (_currentRobot != null && !_isPairing) ...[
                            _buildSoftwareVersionCard(),
                            _buildVoiceCommandCard(),
                            _buildMoodSelectionCard(),
                            _buildSystemControlCard(),
                            _buildDiagnosticsCard(),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                _buildBottomButton(),
              ],
            ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final status = _isPairing
        ? 'PAIRING...'
        : (_currentRobot?.isOnline == true ? 'CONNECTED' : 'NOT CONNECTED');
    final statusColor = _isPairing
        ? Colors.orange
        : (_currentRobot?.isOnline == true
            ? Color(0xFF00FF88)
            : Colors.grey[500]);

    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'BEEMO Robot',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          Text(
            status,
            style: TextStyle(
              color: statusColor,
              fontSize: 12,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
      actions: [
        if (_currentRobot != null && !_isPairing)
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: _refreshRobotStatus,
          ),
      ],
    );
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00FF88)),
          ),
          SizedBox(height: 16),
          Text(
            'Checking for existing connections...',
            style: TextStyle(color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  Widget _buildRobotIdInput() {
    if (_isPairing || (_currentRobot?.status == 'pairing')) {
      return Container(
        margin: EdgeInsets.only(bottom: 16),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Color(0xFF00FF88).withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00FF88)),
            ),
            SizedBox(height: 16),
            Text(
              'Pairing with BEEMO...',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Please confirm pairing on the robot',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    if (_currentRobot != null) {
      return Container(
        margin: EdgeInsets.only(bottom: 16),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Color(0xFF00FF88).withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: Color(0xFF00FF88),
                  size: 24,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Connected to BEEMO',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'ID: ${_currentRobot!.id}',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Color(0xFF0F0F0F),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.grey[400],
                    size: 20,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'You can now control BEEMO using voice commands or the app interface',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Robot ID',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
            SizedBox(height: 12),
            TextFormField(
              controller: _robotIdController,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Enter BEEMO Robot ID',
                hintStyle: TextStyle(color: Colors.grey[500]),
                filled: true,
                fillColor: Color(0xFF0F0F0F),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Color(0xFF00FF88)),
                ),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a robot ID';
                }
                if (value.trim().length < 3) {
                  return 'Robot ID must be at least 3 characters';
                }
                return null;
              },
              onFieldSubmitted: (_) => _handlePairRobot(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    final isOnline = _currentRobot?.isOnline == true;
    final statusColor = isOnline ? Color(0xFF00FF88) : Colors.red;
    final status =
        _isPairing ? 'Pairing...' : (_currentRobot?.status ?? 'Not Connected');

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: isOnline
            ? Border.all(color: Color(0xFF00FF88).withOpacity(0.3), width: 1)
            : null,
      ),
      child: Row(
        key: ValueKey('status_card'), // Add unique key
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: statusColor
                      .withOpacity(isOnline ? _pulseAnimation.value : 1.0),
                  shape: BoxShape.circle,
                  boxShadow: isOnline
                      ? [
                          BoxShadow(
                            color: statusColor.withOpacity(0.5),
                            blurRadius: 4,
                            spreadRadius: 1,
                          )
                        ]
                      : null,
                ),
              );
            },
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BEEMO Robot is ${_isPairing ? 'Connecting' : (isOnline ? 'Online' : 'Offline')}',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Status: $status',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
                if (_currentRobot?.lastSeen != null)
                  Text(
                    'Last seen: ${_formatLastSeen(_currentRobot!.lastSeen)}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          if (isOnline)
            Icon(
              Icons.check_circle,
              color: Color(0xFF00FF88),
              size: 20,
            ),
        ],
      ),
    );
  }

  Widget _buildSoftwareVersionCard() {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.settings, color: Colors.grey[400], size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Software Version',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
          Text(
            _currentRobot?.softwareVersion ?? 'N/A',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceCommandCard() {
    final isEnabled = _currentRobot?.isOnline == true;

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.mic,
                color: isEnabled ? Color(0xFF00FF88) : Colors.grey[600],
                size: 20,
              ),
              SizedBox(width: 12),
              Text(
                'Voice Command',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              Spacer(),
              Switch(
                value: isEnabled,
                onChanged:
                    isEnabled ? (value) => _toggleVoiceCommand(value) : null,
                activeColor: Color(0xFF00FF88),
              ),
            ],
          ),
          SizedBox(height: 12),
          GestureDetector(
            onTap: isEnabled ? _testVoiceCommand : null,
            child: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Color(0xFF0F0F0F),
                borderRadius: BorderRadius.circular(8),
                border: isEnabled
                    ? Border.all(color: Color(0xFF00FF88).withOpacity(0.3))
                    : null,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      isEnabled
                          ? 'Tap to test voice command'
                          : 'Robot must be online to use voice commands',
                      style: TextStyle(
                        color: isEnabled ? Colors.grey[400] : Colors.grey[600],
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    color: isEnabled ? Colors.grey[400] : Colors.grey[600],
                    size: 14,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoodSelectionCard() {
    final isEnabled = _currentRobot?.isOnline == true;

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.emoji_emotions,
                color: isEnabled ? Color(0xFF00FF88) : Colors.grey[600],
                size: 20,
              ),
              SizedBox(width: 12),
              Text(
                "Set Beemo's Mood",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Opacity(
            opacity: isEnabled ? 1.0 : 0.5,
            child: GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.2,
              children: [
                _buildMoodButton(
                    'Happy', Icons.sentiment_very_satisfied, isEnabled),
                _buildMoodButton(
                    'Sad', Icons.sentiment_very_dissatisfied, isEnabled),
                _buildMoodButton('Angry', Icons.mood_bad, isEnabled),
                _buildMoodButton('Excited', Icons.celebration, isEnabled),
                _buildMoodButton('Neutral', Icons.sentiment_neutral, isEnabled),
                _buildMoodButton('Dizzy', Icons.motion_photos_on, isEnabled),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemControlCard() {
    final isEnabled = _currentRobot?.isOnline == true;

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.settings_applications,
                color: isEnabled ? Colors.grey[400] : Colors.grey[600],
                size: 20,
              ),
              SizedBox(width: 12),
              Text(
                'Beemo System Control',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Opacity(
            opacity: isEnabled ? 1.0 : 0.5,
            child: Row(
              children: [
                Expanded(
                  child: _buildSystemButton('Reboot', Icons.refresh, isEnabled),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _buildSystemButton(
                      'Shutdown', Icons.power_settings_new, isEnabled),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosticsCard() {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics, color: Colors.grey[400], size: 20),
              SizedBox(width: 12),
              Text(
                'Diagnostics',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          // Add any other diagnostic information here if needed
        ],
      ),
    );
  }

  Widget _buildMoodButton(String mood, IconData icon, bool isEnabled) {
    bool isSelected =
        _currentRobot?.currentEmotion.toLowerCase() == mood.toLowerCase();

    return GestureDetector(
      onTap: isEnabled ? () => _sendEmotion(mood.toLowerCase()) : null,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Color(0xFF0F0F0F),
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? Border.all(color: Color(0xFF00FF88), width: 2)
              : Border.all(color: Colors.transparent, width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? Color(0xFF00FF88)
                  : (isEnabled ? Colors.grey[400] : Colors.grey[600]),
              size: 24,
            ),
            SizedBox(height: 4),
            Text(
              mood,
              style: TextStyle(
                color: isSelected
                    ? Color(0xFF00FF88)
                    : (isEnabled ? Colors.grey[400] : Colors.grey[600]),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemButton(String label, IconData icon, bool isEnabled) {
    return GestureDetector(
      onTap:
          isEnabled ? () => _confirmSystemCommand(label.toLowerCase()) : null,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: Color(0xFF0F0F0F),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isEnabled ? Colors.transparent : Colors.grey[800]!,
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isEnabled ? Colors.grey[400] : Colors.grey[600],
              size: 24,
            ),
            SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isEnabled ? Colors.grey[400] : Colors.grey[600],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomButton() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: _getButtonAction(),
          style: ElevatedButton.styleFrom(
            backgroundColor: _getButtonColor(),
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
            elevation: 0,
          ),
          child: _getButtonChild(),
        ),
      ),
    );
  }

  VoidCallback? _getButtonAction() {
    if (_isPairing) return null;
    if (_currentRobot == null) return _handlePairRobot;
    return _handleDisconnectRobot;
  }

  Future<void> _handleDisconnectRobot() async {
    if (_currentRobot == null) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await _firebaseService.disconnectRobot(_currentRobot!.id);
      setState(() {
        _currentRobot = null;
      });
      _showInfoSnackBar('Robot disconnected successfully.');
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to disconnect robot: $e';
      });
      _showErrorSnackBar('Failed to disconnect robot: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Color _getButtonColor() {
    if (_currentRobot == null) return AppColors.secondary;
    return Colors.red[400]!;
  }

  Widget _getButtonChild() {
    if (_isPairing) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }

    if (_currentRobot == null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bluetooth_searching_rounded, size: 20),
          SizedBox(width: 8),
          Text(
            'Pair with Robot',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              letterSpacing: 0.5,
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.link_off_rounded, size: 20),
        SizedBox(width: 8),
        Text(
          'Disconnect Robot',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  // Helper methods
  String _formatLastSeen(DateTime lastSeen) {
    final now = DateTime.now();
    final difference = now.difference(lastSeen);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  }

  // Action methods

  Future<void> _refreshRobotStatus() async {
    if (_currentRobot == null) return;

    HapticFeedback.lightImpact();
    try {
      await _firebaseService.refreshRobotStatus(_currentRobot!.id);
    } catch (e) {
      _showErrorSnackBar('Failed to refresh status: ${e.toString()}');
    }
  }

  Future<void> _sendCommand(String command) async {
    if (_currentRobot == null || !_currentRobot!.isOnline) {
      _showErrorSnackBar('Robot is not online');
      return;
    }

    try {
      await _firebaseService.sendCommandToRobot(_currentRobot!.id, command);
      HapticFeedback.lightImpact();
    } catch (e) {
      _showErrorSnackBar('Failed to send command: ${e.toString()}');
    }
  }

  Future<void> _sendEmotion(String emotion) async {
    if (_currentRobot == null || !_currentRobot!.isOnline) {
      _showErrorSnackBar('Robot is not online');
      return;
    }

    try {
      await _firebaseService.sendEmotionCommand(_currentRobot!.id, emotion);
      HapticFeedback.selectionClick();
    } catch (e) {
      _showErrorSnackBar('Failed to set emotion: ${e.toString()}');
    }
  }

  Future<void> _confirmSystemCommand(String command) async {
    final shouldExecute = await _showConfirmationDialog(
      'System Command',
      'Are you sure you want to $command the robot?',
    );

    if (shouldExecute) {
      await _sendCommand(command);
    }
  }

  Future<void> _toggleVoiceCommand(bool enabled) async {
    // Implement voice command toggle logic
    try {
      await _firebaseService.toggleVoiceCommand(_currentRobot!.id, enabled);
      HapticFeedback.lightImpact();
    } catch (e) {
      _showErrorSnackBar('Failed to toggle voice command: ${e.toString()}');
    }
  }

  Future<void> _testVoiceCommand() async {
    // Implement voice command test
    _showInfoSnackBar('Voice command test initiated');
  }

  // UI Helper methods
  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Color(0xFF00FF88),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showInfoSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Future<bool> _showConfirmationDialog(String title, String message) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1A1A1A),
        title: Text(
          title,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          message,
          style: TextStyle(color: Colors.grey[300]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'CANCEL',
              style: TextStyle(color: Colors.grey[400]),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.black,
              backgroundColor: Color(0xFF00FF88),
            ),
            child: Text('YES'),
          ),
        ],
      ),
    ).then((value) => value ?? false);
  }
}
