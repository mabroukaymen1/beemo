import 'package:flutter/material.dart';
import 'dart:math' as math;

import 'package:teemo/services/device_service.dart';
import 'package:teemo/home/device_typescreen/device_bottom_sheet.dart';

class AirConditionerBottomSheet extends DeviceBottomSheet {
  final String deviceId;

  const AirConditionerBottomSheet({
    Key? key,
    required this.deviceId,
  }) : super(key: key, deviceId: deviceId);

  static Future<void> show(BuildContext context, String deviceId) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => AirConditionerBottomSheet(deviceId: deviceId),
    );
  }

  @override
  State<AirConditionerBottomSheet> createState() =>
      _AirConditionerBottomSheetState();
}

class _AirConditionerBottomSheetState extends State<AirConditionerBottomSheet>
    with SingleTickerProviderStateMixin, DeviceStateMixin {
  final DeviceService _deviceService = DeviceService();
  bool isOn = true;
  int temperature = 19;
  String activeMode = 'cooling';
  double sliderValue = 0.3;
  late final AnimationController _animationController;
  late final Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _initDeviceState();
    _setupAnimation();
    _setupDeviceListener();
  }

  void _initDeviceState() {
    final device = _deviceService.getDeviceById(widget.deviceId);
    if (device != null) {
      setState(() {
        isOn = device.isOn;
        temperature = device.properties['temperature'] ?? 19;
        activeMode = device.properties['mode'] ?? 'cooling';
        sliderValue = device.properties['fanSpeed'] ?? 0.3;
      });
    }
  }

  void _setupAnimation() {
    _animationController = AnimationController(
        duration: const Duration(milliseconds: 1500), vsync: this)
      ..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));
  }

  void _setupDeviceListener() {
    String? placeId;
    final places = _deviceService.getAllPlaces();
    for (var place in places) {
      if (place.devices.any((d) => d.id == widget.deviceId)) {
        placeId = place.id;
        break;
      }
    }

    if (placeId != null) {
      _deviceService
          .getDeviceStateStream(placeId, widget.deviceId)
          .listen((event) {
        if (!mounted) return;

        final data = event.snapshot.value as Map?;
        if (data != null) {
          setState(() {
            isOn = data['isOn'] ?? isOn;
            temperature = data['properties']?['temperature'] ?? temperature;
            activeMode = data['properties']?['mode'] ?? activeMode;
            sliderValue =
                (data['properties']?['fanSpeed'] ?? sliderValue).toDouble();
          });
        }
      });
    }
  }

  void _updateDeviceState({
    bool? isDeviceOn,
    int? temp,
    String? mode,
    double? fanSpeed,
  }) async {
    if (!isOnline) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Device is offline')));
      return;
    }

    final Map<String, dynamic> properties = {};

    if (isDeviceOn != null) {
      setState(() => isOn = isDeviceOn);
      properties['isOn'] = isDeviceOn;
    }

    if (temp != null) {
      setState(() => temperature = temp);
      properties['temperature'] = temp;
    }

    if (mode != null) {
      setState(() => activeMode = mode);
      properties['mode'] = mode;
    }

    if (fanSpeed != null) {
      setState(() => sliderValue = fanSpeed);
      properties['fanSpeed'] = fanSpeed;
    }

    if (properties.isNotEmpty) {
      await updateDeviceState(properties);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          // Bottom sheet handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 40),
                  _buildTemperatureControl(),
                  const SizedBox(height: 40),
                  _buildModeButtons(),
                  const SizedBox(height: 40),
                  _buildInfoCards(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Air Conditioner',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.room, color: Colors.blue, size: 16),
                  SizedBox(width: 4),
                  Text('Living Room', style: TextStyle(color: Colors.blue)),
                ],
              ),
            ),
          ],
        ),
        GestureDetector(
          onTap: () => setState(() {
            isOn = !isOn;
            _updateDeviceState();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('AC turned ${isOn ? 'on' : 'off'}'),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
                backgroundColor: Colors.black87,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            );
          }),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isOn ? Colors.blue : Colors.grey[800],
              boxShadow: isOn
                  ? [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.3),
                        blurRadius: 12,
                        spreadRadius: 2,
                      )
                    ]
                  : null,
            ),
            child: const Icon(
              Icons.power_settings_new,
              color: Colors.white,
              size: 28,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTemperatureControl() {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 280,
            height: 280,
            child: CustomPaint(
              painter: CircularSliderPainter(
                value: sliderValue,
                isEnabled: isOn,
              ),
            ),
          ),
          Positioned(
            left: 0,
            child: _buildControlButton(
              icon: Icons.remove,
              onPressed: isOn
                  ? () {
                      setState(() {
                        if (temperature > 16) {
                          temperature--;
                          sliderValue = (temperature - 16) / 14;
                          _updateDeviceState();
                        }
                      });
                    }
                  : null,
            ),
          ),
          Positioned(
            right: 0,
            child: _buildControlButton(
              icon: Icons.add,
              onPressed: isOn
                  ? () {
                      setState(() {
                        if (temperature < 30) {
                          temperature++;
                          sliderValue = (temperature - 16) / 14;
                          _updateDeviceState();
                        }
                      });
                    }
                  : null,
            ),
          ),
          AnimatedBuilder(
            animation: _glowAnimation,
            builder: (context, child) {
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey[900],
                  boxShadow: isOn
                      ? [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.3),
                            blurRadius: 30 * _glowAnimation.value,
                            spreadRadius: 10 * _glowAnimation.value,
                          )
                        ]
                      : null,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      temperature.toString(),
                      style: TextStyle(
                        color: isOn ? Colors.white : Colors.grey,
                        fontSize: 64,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '°Celsius',
                      style: TextStyle(
                        color: isOn ? Colors.grey[400] : Colors.grey[600],
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    VoidCallback? onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        shape: BoxShape.circle,
        boxShadow: isOn
            ? [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.2),
                  blurRadius: 8,
                  spreadRadius: 1,
                )
              ]
            : null,
      ),
      child: IconButton(
        icon: Icon(icon, color: isOn ? Colors.white : Colors.grey),
        onPressed: onPressed,
        padding: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _buildModeButtons() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildModeButton(
            icon: Icons.ac_unit,
            label: 'Cooling',
            isActive: activeMode == 'cooling',
            onTap: () => setState(() {
              activeMode = 'cooling';
              _updateDeviceState();
            }),
          ),
          _buildModeButton(
            icon: Icons.local_fire_department,
            label: 'Heating',
            isActive: activeMode == 'heating',
            onTap: () => setState(() {
              activeMode = 'heating';
              _updateDeviceState();
            }),
          ),
          _buildModeButton(
            icon: Icons.air,
            label: 'Airwave',
            isActive: activeMode == 'airwave',
            onTap: () => setState(() {
              activeMode = 'airwave';
              _updateDeviceState();
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildModeButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: isOn ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: isActive && isOn ? Colors.blue : Colors.grey[800],
          borderRadius: BorderRadius.circular(20),
          boxShadow: isActive && isOn
              ? [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                  )
                ]
              : null,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isOn
                  ? (isActive ? Colors.white : Colors.grey[400])
                  : Colors.grey[600],
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: isOn
                    ? (isActive ? Colors.white : Colors.grey[400])
                    : Colors.grey[600],
                fontSize: 12,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCards() {
    return Row(
      children: [
        Expanded(
          child: _buildInfoCard(
            icon: Icons.timer,
            label: 'Timer',
            value: '12',
            unit: 'hours',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildInfoCard(
            icon: Icons.water_drop,
            label: 'Humidity',
            value: '40',
            unit: '%',
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
    required String unit,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: isOn ? Colors.blue : Colors.grey),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: isOn ? Colors.grey[400] : Colors.grey[600],
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: isOn ? Colors.white : Colors.grey,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: TextStyle(
                  color: isOn ? Colors.grey[400] : Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class CircularSliderPainter extends CustomPainter {
  final double value;
  final bool isEnabled;

  CircularSliderPainter({
    required this.value,
    required this.isEnabled,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Background circle
    final bgPaint = Paint()
      ..color = Colors.grey[900]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(center, radius - 2, bgPaint);

    if (isEnabled) {
      // Progress arc with gradient
      final rect = Rect.fromCircle(center: center, radius: radius - 2);
      final gradient = SweepGradient(
        colors: [Colors.blue, Colors.blue.shade300],
        stops: const [0.0, 1.0],
        startAngle: -math.pi / 2,
        endAngle: 3 * math.pi / 2,
      );

      final progressPaint = Paint()
        ..shader = gradient.createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * value,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
