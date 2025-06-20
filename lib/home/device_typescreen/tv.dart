import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:teemo/services/device_service.dart';
import 'package:teemo/home/device_typescreen/device_bottom_sheet.dart';

class SmartRemoteBottomSheet extends DeviceBottomSheet {
  const SmartRemoteBottomSheet({
    super.key,
    required super.deviceId,
  });

  static Future<void> show(BuildContext context, String deviceId) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => SmartRemoteBottomSheet(deviceId: deviceId),
    );
  }

  @override
  State<SmartRemoteBottomSheet> createState() => _SmartRemoteBottomSheetState();
}

class _SmartRemoteBottomSheetState extends State<SmartRemoteBottomSheet>
    with SingleTickerProviderStateMixin, DeviceStateMixin {
  final DeviceService _deviceService = DeviceService();
  bool isPowerOn = true;
  double brightness = 0.5;
  int currentVolume = 50;
  int currentChannel = 1;
  bool isMuted = false;
  bool isPlaying = false;
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
        isPowerOn = device.isOn;
        brightness = device.properties['brightness'] ?? 0.5;
        currentVolume = device.properties['volume'] ?? 50;
        currentChannel = device.properties['channel'] ?? 1;
        isMuted = device.properties['isMuted'] ?? false;
        isPlaying = device.properties['isPlaying'] ?? false;
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
            isPowerOn = data['isOn'] ?? isPowerOn;
            brightness =
                (data['properties']?['brightness'] ?? brightness).toDouble();
            currentVolume = data['properties']?['volume'] ?? currentVolume;
            currentChannel = data['properties']?['channel'] ?? currentChannel;
            isMuted = data['properties']?['isMuted'] ?? isMuted;
            isPlaying = data['properties']?['isPlaying'] ?? isPlaying;
          });
        }
      });
    }
  }

  void _updateDeviceState() async {
    if (!isOnline) {
      _showFeedback('Device is offline');
      return;
    }

    await updateDeviceState({
      'isOn': isPowerOn,
      'brightness': brightness,
      'volume': currentVolume,
      'channel': currentChannel,
      'isMuted': isMuted,
      'isPlaying': isPlaying,
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _showFeedback(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.black87,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _handleNavigation(String direction) {
    if (!isPowerOn) return;
    _showFeedback('Navigating $direction');
    // Add your navigation logic here
    HapticFeedback.lightImpact();
  }

  void _handleVolumeChange(bool increase) {
    if (!isPowerOn || isMuted) return;
    setState(() {
      if (increase && currentVolume < 100) {
        currentVolume += 5;
      } else if (!increase && currentVolume > 0) {
        currentVolume -= 5;
      }
      _updateDeviceState();
    });
    _showFeedback('Volume: $currentVolume%');
    HapticFeedback.selectionClick();
  }

  void _handleChannelChange(bool increase) {
    if (!isPowerOn) return;
    setState(() {
      if (increase) {
        currentChannel++;
      } else if (currentChannel > 1) {
        currentChannel--;
      }
      _updateDeviceState();
    });
    _showFeedback('Channel: $currentChannel');
    HapticFeedback.selectionClick();
  }

  void _toggleMute() {
    if (!isPowerOn) return;
    setState(() {
      isMuted = !isMuted;
      _updateDeviceState();
    });
    _showFeedback(isMuted ? 'Muted' : 'Unmuted');
    HapticFeedback.mediumImpact();
  }

  void _togglePlayPause() {
    if (!isPowerOn) return;
    setState(() {
      isPlaying = !isPlaying;
      _updateDeviceState();
    });
    _showFeedback(isPlaying ? 'Playing' : 'Paused');
    HapticFeedback.mediumImpact();
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
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Main content
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24.0, vertical: 16.0),
                  child: Column(
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 40),
                      _buildNavigationPad(),
                      const SizedBox(height: 40),
                      _buildVolumeChannelControls(),
                      const SizedBox(height: 24),
                      _buildBrightnessControl(),
                      const SizedBox(height: 24),
                      _buildBottomButtons(),
                      // Add extra padding at the bottom for safe area
                      SizedBox(
                          height: MediaQuery.of(context).padding.bottom + 32),
                    ],
                  ),
                ),
              ),
            ],
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
            const Text(
              'Smart TV',
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
          onTap: () {
            HapticFeedback.heavyImpact();
            setState(() {
              isPowerOn = !isPowerOn;
              _showFeedback('TV turned ${isPowerOn ? 'on' : 'off'}');
            });
          },
          child: AnimatedBuilder(
            animation: _glowAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: isPowerOn ? _glowAnimation.value : 1.0,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isPowerOn ? Colors.blue : Colors.grey[800],
                    boxShadow: isPowerOn
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
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNavigationPad() {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: isPowerOn ? 1.0 : 0.5,
      child: Container(
        width: 200,
        height: 200,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey[900],
          boxShadow: isPowerOn
              ? [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.2),
                    blurRadius: 10,
                    spreadRadius: 1,
                  )
                ]
              : null,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            GestureDetector(
              onTap: isPowerOn
                  ? () {
                      _showFeedback('OK pressed');
                      HapticFeedback.mediumImpact();
                    }
                  : null,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isPowerOn ? Colors.blue : Colors.grey[800],
                  boxShadow: isPowerOn
                      ? [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.3),
                            blurRadius: 8,
                            spreadRadius: 1,
                          )
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    "OK",
                    style: TextStyle(
                      color: isPowerOn ? Colors.white : Colors.grey,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
            ...List.generate(4, (index) {
              final directions = ['Up', 'Right', 'Down', 'Left'];
              return Positioned(
                top: index == 0 ? 15 : null,
                bottom: index == 2 ? 15 : null,
                left: index == 3 ? 15 : null,
                right: index == 1 ? 15 : null,
                child: IconButton(
                  icon: Icon(
                    [
                      Icons.keyboard_arrow_up,
                      Icons.keyboard_arrow_right,
                      Icons.keyboard_arrow_down,
                      Icons.keyboard_arrow_left
                    ][index],
                    color: isPowerOn ? Colors.white : Colors.grey,
                    size: 40,
                  ),
                  onPressed: isPowerOn
                      ? () => _handleNavigation(directions[index])
                      : null,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildVolumeChannelControls() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Column(
            children: [
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.remove,
                      color: isPowerOn ? Colors.white : Colors.grey,
                    ),
                    onPressed:
                        isPowerOn ? () => _handleVolumeChange(false) : null,
                  ),
                  Column(
                    children: [
                      Icon(
                        Icons.volume_up,
                        color: isPowerOn ? Colors.blue : Colors.grey,
                      ),
                      Text(
                        isMuted ? 'Muted' : '$currentVolume%',
                        style: TextStyle(
                          color: isPowerOn ? Colors.white : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.add,
                      color: isPowerOn ? Colors.white : Colors.grey,
                    ),
                    onPressed:
                        isPowerOn ? () => _handleVolumeChange(true) : null,
                  ),
                ],
              ),
              const Text(
                'Volume',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
          Column(
            children: [
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.remove,
                      color: isPowerOn ? Colors.white : Colors.grey,
                    ),
                    onPressed:
                        isPowerOn ? () => _handleChannelChange(false) : null,
                  ),
                  Column(
                    children: [
                      Icon(
                        Icons.tv,
                        color: isPowerOn ? Colors.blue : Colors.grey,
                      ),
                      Text(
                        'CH $currentChannel',
                        style: TextStyle(
                          color: isPowerOn ? Colors.white : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.add,
                      color: isPowerOn ? Colors.white : Colors.grey,
                    ),
                    onPressed:
                        isPowerOn ? () => _handleChannelChange(true) : null,
                  ),
                ],
              ),
              const Text(
                'Channel',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBrightnessControl() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.wb_sunny_outlined,
                      color: isPowerOn ? Colors.blue : Colors.grey, size: 24),
                  const SizedBox(width: 12),
                  const Text(
                    'Brightness',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  '${(brightness * 100).round()}%',
                  key: ValueKey<int>((brightness * 100).round()),
                  style: TextStyle(
                      color: isPowerOn ? Colors.grey[400] : Colors.grey[600],
                      fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: Colors.blue,
              inactiveTrackColor: Colors.grey[800],
              thumbColor: Colors.blue,
              overlayColor: Colors.blue.withOpacity(0.2),
            ),
            child: Slider(
              value: brightness,
              onChanged: isPowerOn
                  ? (value) {
                      setState(() => brightness = value);
                      _showFeedback(
                          'Brightness: ${(brightness * 100).round()}%');
                    }
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButtons() {
    final buttons = [
      {
        'label': 'Mute',
        'icon': isMuted ? Icons.volume_off : Icons.volume_up,
        'onPressed': _toggleMute
      },
      {
        'label': isPlaying ? 'Pause' : 'Play',
        'icon': isPlaying ? Icons.pause : Icons.play_arrow,
        'onPressed': _togglePlayPause
      },
      {
        'label': 'Assistant',
        'icon': Icons.mic,
        'onPressed': () => _showFeedback('Voice Assistant activated')
      },
      {
        'label': 'Back',
        'icon': Icons.arrow_back,
        'onPressed': () => _showFeedback('Going back')
      },
      {
        'label': 'Home',
        'icon': Icons.home,
        'onPressed': () => _showFeedback('Going to Home')
      },
      {
        'label': 'Menu',
        'icon': Icons.menu,
        'onPressed': () => _showFeedback('Opening Menu')
      },
    ];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(24),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        alignment: WrapAlignment.center,
        children: buttons.map((button) {
          return GestureDetector(
            onTap: isPowerOn
                ? () {
                    (button['onPressed'] as VoidCallback)();
                    HapticFeedback.selectionClick();
                  }
                : null,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: isPowerOn ? 1.0 : 0.5,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isPowerOn
                          ? Colors.blue.withOpacity(0.2)
                          : Colors.grey[800],
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: isPowerOn
                          ? [
                              BoxShadow(
                                color: Colors.blue.withOpacity(0.1),
                                blurRadius: 8,
                                spreadRadius: 1,
                              )
                            ]
                          : null,
                    ),
                    child: Icon(
                      button['icon'] as IconData,
                      color: isPowerOn ? Colors.blue : Colors.grey,
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    button['label'] as String,
                    style: TextStyle(
                      color: isPowerOn ? Colors.grey[400] : Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
