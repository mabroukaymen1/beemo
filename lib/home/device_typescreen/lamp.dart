import 'package:flutter/material.dart';
import 'dart:math' as math;

import 'package:teemo/services/device_service.dart';
import 'package:teemo/home/device_typescreen/device_bottom_sheet.dart';

// Constants
const double _wheelSize = 200.0;
const double _minTemp = 2000.0;
const double _maxTemp = 6500.0;
const Duration _glowDuration = Duration(milliseconds: 1500);

// Presets
const Map<String, Map<String, double>> presets = {
  'warm': {'temperature': 2700, 'brightness': 0.6},
  'neutral': {'temperature': 4000, 'brightness': 0.7},
  'cool': {'temperature': 6500, 'brightness': 1.0},
  'night': {'temperature': 2000, 'brightness': 0.2},
};

class ColorWheel extends StatelessWidget {
  final double temperature;
  final bool isEnabled;
  final ValueChanged<double>? onChanged;

  const ColorWheel({
    super.key,
    required this.temperature,
    this.isEnabled = true,
    this.onChanged,
  });

  void _handlePanUpdate(DragUpdateDetails details, BuildContext context) {
    if (!isEnabled || onChanged == null) return;

    final box = context.findRenderObject() as RenderBox;
    final center = Offset(box.size.width / 2, box.size.height / 2);
    final angle = (math.atan2(details.localPosition.dy - center.dy,
                details.localPosition.dx - center.dx) +
            math.pi) /
        (2 * math.pi);
    final newTemp = _minTemp + (angle * (_maxTemp - _minTemp));
    onChanged!(newTemp.clamp(_minTemp, _maxTemp));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate:
          isEnabled ? (details) => _handlePanUpdate(details, context) : null,
      child: CustomPaint(
        size: Size(_wheelSize, _wheelSize),
        painter:
            _ColorWheelPainter(temperature: temperature, isEnabled: isEnabled),
      ),
    );
  }
}

class _ColorWheelPainter extends CustomPainter {
  final double temperature;
  final bool isEnabled;

  const _ColorWheelPainter({
    required this.temperature,
    required this.isEnabled,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    _drawColorWheel(canvas, center, radius);
    _drawSelector(canvas, center, radius);
  }

  void _drawColorWheel(Canvas canvas, Offset center, double radius) {
    final rect = Rect.fromCircle(center: center, radius: radius * 0.9);
    final sweepGradient = SweepGradient(
      colors: [
        Colors.red,
        Colors.orange,
        Colors.yellow,
        Colors.green,
        Colors.blue,
        Colors.indigo,
        Colors.purple,
        Colors.red
      ],
    );
    canvas.drawArc(
        rect,
        0,
        2 * math.pi,
        true,
        Paint()
          ..shader = sweepGradient.createShader(rect)
          ..style = PaintingStyle.stroke
          ..strokeWidth = radius * 0.2);
  }

  void _drawSelector(Canvas canvas, Offset center, double radius) {
    final selectorAngle =
        ((temperature - _minTemp) / (_maxTemp - _minTemp)) * 2 * math.pi -
            math.pi / 2;
    final selectorCenter = Offset(
        center.dx + radius * 0.9 * math.cos(selectorAngle),
        center.dy + radius * 0.9 * math.sin(selectorAngle));
    canvas.drawCircle(selectorCenter, 8, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_ColorWheelPainter oldDelegate) =>
      temperature != oldDelegate.temperature ||
      isEnabled != oldDelegate.isEnabled;
}

class SmartLampBottomSheet extends DeviceBottomSheet {
  const SmartLampBottomSheet({
    super.key,
    required super.deviceId,
  });

  static Future<void> show(BuildContext context, String deviceId) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => SmartLampBottomSheet(deviceId: deviceId),
    );
  }

  @override
  State<SmartLampBottomSheet> createState() => _SmartLampBottomSheetState();
}

class _SmartLampBottomSheetState extends State<SmartLampBottomSheet>
    with SingleTickerProviderStateMixin {
  final DeviceService _deviceService = DeviceService();
  bool _isOn = true;
  double _brightness = 0.7;
  double _temperature = 4000;
  String _selectedPreset = 'neutral';
  late final AnimationController _animationController;
  late final Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _initDeviceState();
    _setupAnimation();
  }

  @override
  void dispose() {
    _animationController.stop();
    _animationController.dispose();
    super.dispose();
  }

  void _initDeviceState() {
    final device = _deviceService.getDeviceById(widget.deviceId);
    if (device != null) {
      if (!mounted) return;
      setState(() {
        _isOn = device.isOn;
        _brightness =
            (device.properties['brightness'] as num?)?.toDouble() ?? 0.7;
        _temperature =
            (device.properties['temperature'] as num?)?.toDouble() ?? 4000.0;
        _selectedPreset = device.properties['preset'] as String? ?? 'neutral';
      });
    }
  }

  void _setupAnimation() {
    _animationController = AnimationController(
      duration: _glowDuration,
      vsync: this,
    );
    if (mounted) {
      _animationController.repeat(reverse: true);
    }
    _glowAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  void _updateDeviceState({
    bool? isOn,
    double? brightness,
    double? temperature,
    String? preset,
  }) {
    final Map<String, dynamic> properties = {};

    if (isOn != null) {
      setState(() => _isOn = isOn);
      properties['isOn'] = isOn;
    }

    if (brightness != null) {
      setState(() => _brightness = brightness);
      properties['brightness'] = brightness;
    }

    if (temperature != null) {
      setState(() => _temperature = temperature);
      properties['temperature'] = temperature;
    }

    if (preset != null) {
      setState(() => _selectedPreset = preset);
      properties['preset'] = preset;
    }

    if (properties.isNotEmpty) {
      _deviceService.updateDeviceProperties(widget.deviceId, properties);
    }
  }

  Color _getTemperatureColor() {
    if (!_isOn) return Colors.grey[800]!;
    if (_temperature <= 3000) {
      return Color.fromRGBO(255, (_temperature / 3000 * 200).round(),
          (_temperature / 3000 * 100).round(), _brightness);
    } else if (_temperature <= 5000) {
      return Color.fromRGBO(
          255, 240, ((_temperature - 3000) / 2000 * 255).round(), _brightness);
    }
    return Color.fromRGBO(255, 240, 255, _brightness);
  }

  void _togglePower() {
    _updateDeviceState(isOn: !_isOn);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Lamp turned ${_isOn ? 'on' : 'off'}'),
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.black87,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  void _updatePreset(String preset) {
    if (!_isOn) return;
    _updateDeviceState(
      preset: preset,
      temperature: presets[preset]!['temperature']!,
      brightness: presets[preset]!['brightness']!,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding:
                const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[600],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                _buildHeader(),
                const SizedBox(height: 30),
                _buildMainControls(),
                const SizedBox(height: 30),
                _buildControlsSection(),
                const SizedBox(height: 24),
                _buildQuickActions(),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
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
            const Text('Smart Lamp',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20)),
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
          onTap: _togglePower,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isOn ? Colors.blue : Colors.grey[800],
              boxShadow: _isOn
                  ? [
                      BoxShadow(
                          color: Colors.blue.withOpacity(0.3),
                          blurRadius: 12,
                          spreadRadius: 2)
                    ]
                  : null,
            ),
            child: const Icon(Icons.power_settings_new,
                color: Colors.white, size: 28),
          ),
        ),
      ],
    );
  }

  Widget _buildMainControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        ColorWheel(
          temperature: _temperature,
          isEnabled: _isOn,
          onChanged: (value) => setState(() {
            _temperature = value;
            _selectedPreset = 'custom';
            _updateDeviceState();
          }),
        ),
        AnimatedBuilder(
          animation: _glowAnimation,
          builder: (context, child) {
            final lampColor = _getTemperatureColor();
            return Container(
              width: 120,
              height: 160,
              decoration: BoxDecoration(
                color: lampColor,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(60), bottom: Radius.circular(30)),
                boxShadow: _isOn
                    ? [
                        BoxShadow(
                            color: lampColor.withOpacity(0.5),
                            blurRadius: 30 * _glowAnimation.value,
                            spreadRadius: 10 * _glowAnimation.value)
                      ]
                    : null,
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildControlsSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: Colors.grey[900], borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBrightnessControl(),
          const SizedBox(height: 24),
          _buildPresetButtons(),
        ],
      ),
    );
  }

  Widget _buildBrightnessControl() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.wb_sunny_outlined, color: Colors.amber, size: 24),
                SizedBox(width: 12),
                Text('Brightness',
                    style: TextStyle(color: Colors.white, fontSize: 16)),
              ],
            ),
            Text('${(_brightness * 100).round()}%',
                style: TextStyle(color: Colors.grey[400], fontSize: 16)),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: Colors.amber,
            inactiveTrackColor: Colors.grey[800],
            thumbColor: Colors.amber,
            overlayColor: Colors.amber.withOpacity(0.2),
          ),
          child: Slider(
            value: _brightness,
            onChanged: _isOn
                ? (value) => setState(() {
                      _brightness = value;
                      _updateDeviceState();
                    })
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildPresetButtons() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: presets.keys.map((preset) {
        final isSelected = _selectedPreset == preset;
        return GestureDetector(
          onTap: _isOn ? () => _updatePreset(preset) : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? Colors.blue : Colors.grey[800],
              borderRadius: BorderRadius.circular(20),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                          color: Colors.blue.withOpacity(0.3),
                          blurRadius: 8,
                          spreadRadius: 1)
                    ]
                  : null,
            ),
            child: Text(preset.toUpperCase(),
                style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey[400],
                    fontWeight: FontWeight.bold)),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        _QuickActionCard(
            icon: Icons.timer_outlined,
            title: 'Timer',
            subtitle: 'Not Set',
            color: Colors.purple),
        const SizedBox(width: 16),
        _QuickActionCard(
            icon: Icons.auto_awesome_outlined,
            title: 'Scene',
            subtitle: 'Choose',
            color: Colors.green),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.grey[900], borderRadius: BorderRadius.circular(20)),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                Text(subtitle,
                    style: TextStyle(color: Colors.grey[400], fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
