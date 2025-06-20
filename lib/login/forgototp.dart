import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import 'package:teemo/login/resetpassword.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String email;
  final String expectedOtp; // Add this parameter
  const OtpVerificationScreen(
      {Key? key, required this.email, required this.expectedOtp})
      : super(key: key);

  @override
  _OtpVerificationScreenState createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _otpController = TextEditingController();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  int _counter = 59;
  late Timer _timer;
  bool _isResendAvailable = false;
  bool _isLoading = false;
  String? _errorMessage;
  final int _otpLength = 4;
  bool? _isOtpValid; // Add this property

  @override
  void initState() {
    super.initState();
    _startTimer();
    _setupAnimation();
  }

  void _setupAnimation() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();
  }

  void _startTimer() {
    setState(() {
      _isResendAvailable = false;
      _counter = 59;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_counter > 0) {
        setState(() => _counter--);
      } else {
        _timer.cancel();
        setState(() => _isResendAvailable = true);
      }
    });
  }

  Future<void> _verifyOtp() async {
    if (_otpController.text.length != _otpLength) {
      setState(() {
        _errorMessage = 'Please enter a valid OTP';
        _isOtpValid = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Validate OTP
      bool isValid = _otpController.text == widget.expectedOtp;

      setState(() {
        _isOtpValid = isValid;
        if (!isValid) {
          _errorMessage = 'Invalid OTP. Please try again.';
        }
      });

      if (isValid) {
        // Wait for the green animation to show
        await Future.delayed(const Duration(milliseconds: 500));
        // Navigate to NewPasswordScreen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const NewPasswordScreen()),
        );
      }
    } catch (e) {
      setState(() {
        _isOtpValid = false;
        _errorMessage = 'Invalid OTP. Please try again.';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    _otpController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0F12),
      appBar: _buildAppBar(),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              const SizedBox(height: 40),
              _buildHeader(),
              const SizedBox(height: 40),
              _buildOtpInput(),
              const SizedBox(height: 20),
              _buildResendSection(),
              const SizedBox(height: 30),
              _buildVerifyButton(),
              const Spacer(),
              _buildBottomIndicator(),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        const Text(
          'OTP Verification',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Enter the verification code sent to\n${widget.email}',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildOtpInput() {
    Color getBorderColor() {
      if (_isOtpValid == null) return Colors.white24;
      return _isOtpValid! ? Colors.green : Colors.red;
    }

    return Column(
      children: [
        Pinput(
          length: _otpLength,
          controller: _otpController,
          onChanged: (_) => setState(() {
            _errorMessage = null;
            _isOtpValid = null;
          }),
          defaultPinTheme: PinTheme(
            width: 60,
            height: 60,
            textStyle: const TextStyle(
              fontSize: 24,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1B1E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: getBorderColor(),
                width: _isOtpValid != null ? 2 : 1,
              ),
            ),
          ),
          focusedPinTheme: PinTheme(
            width: 60,
            height: 60,
            textStyle: const TextStyle(
              fontSize: 24,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1B1E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isOtpValid == null
                    ? const Color(0xFF65E4C3)
                    : getBorderColor(),
                width: 2,
              ),
            ),
          ),
          submittedPinTheme: PinTheme(
            width: 60,
            height: 60,
            textStyle: const TextStyle(
              fontSize: 24,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1B1E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: getBorderColor(),
                width: 2,
              ),
            ),
          ),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            style: const TextStyle(
              color: Colors.redAccent,
              fontSize: 14,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildResendSection() {
    return Column(
      children: [
        const Text(
          "Didn't receive the code?",
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 8),
        _isResendAvailable
            ? GestureDetector(
                onTap: _startTimer,
                child: const Text(
                  "Resend Code",
                  style: TextStyle(
                    color: Color(0xFF65E4C3),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              )
            : Text(
                "Wait $_counter seconds to resend",
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 14,
                ),
              ),
      ],
    );
  }

  Widget _buildVerifyButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF65E4C3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: _isLoading ? null : _verifyOtp,
        child: _isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                  strokeWidth: 2,
                ),
              )
            : const Text(
                'Verify',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Widget _buildBottomIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Container(
        height: 4,
        width: 80,
        decoration: BoxDecoration(
          color: Colors.white24,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}
