import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:teemo/services/device_service.dart';
import 'package:teemo/home/device_typescreen/device_bottom_sheet.dart';

class SpeakerBottomSheet extends DeviceBottomSheet {
  const SpeakerBottomSheet({
    super.key,
    required super.deviceId,
  });

  static Future<void> show(BuildContext context, String deviceId) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => SpeakerBottomSheet(deviceId: deviceId),
    );
  }

  @override
  State<SpeakerBottomSheet> createState() => _SpeakerBottomSheetState();
}

class _SpeakerBottomSheetState extends State<SpeakerBottomSheet>
    with SingleTickerProviderStateMixin, DeviceStateMixin {
  final DeviceService _deviceService = DeviceService();
  bool isPowerOn = true;
  double currentVolume = 50.0;
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
        currentVolume = device.properties['volume']?.toDouble() ?? 50.0;
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
            currentVolume =
                (data['properties']?['volume'] ?? currentVolume).toDouble();
            isMuted = data['properties']?['isMuted'] ?? isMuted;
            isPlaying = data['properties']?['isPlaying'] ?? isPlaying;
          });
        }
      });
    }
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

  void _updateDeviceState({
    bool? isOn,
    double? volume,
    bool? muted,
    bool? playing,
  }) async {
    if (!isOnline) {
      _showFeedback('Device is offline');
      return;
    }

    final Map<String, dynamic> properties = {};

    if (isOn != null) {
      setState(() => isPowerOn = isOn);
      properties['isOn'] = isOn;
    }

    if (volume != null) {
      setState(() => currentVolume = volume);
      properties['volume'] = volume;
    }

    if (muted != null) {
      setState(() => isMuted = muted);
      properties['isMuted'] = muted;
    }

    if (playing != null) {
      setState(() => isPlaying = playing);
      properties['isPlaying'] = playing;
    }

    if (properties.isNotEmpty) {
      await updateDeviceState(properties);
    }
  }

  void _handleVolumeChange(bool increase) {
    if (!isPowerOn || isMuted) return;
    final newVolume = increase && currentVolume < 100
        ? currentVolume + 5.0
        : !increase && currentVolume > 0
            ? currentVolume - 5.0
            : currentVolume;

    _updateDeviceState(volume: newVolume);
    _showFeedback('Volume: ${newVolume.round()}%');
    HapticFeedback.selectionClick();
  }

  void _toggleMute() {
    if (!isPowerOn) return;
    _updateDeviceState(muted: !isMuted);
    _showFeedback(isMuted ? 'Unmuted' : 'Muted');
    HapticFeedback.mediumImpact();
  }

  void _togglePlayPause() {
    if (!isPowerOn) return;
    _updateDeviceState(playing: !isPlaying);
    _showFeedback(isPlaying ? 'Paused' : 'Playing');
    HapticFeedback.mediumImpact();
  }

  void _nextSong() {
    if (!isPowerOn) return;
    _showFeedback('Next Song');
    HapticFeedback.lightImpact();
  }

  void _previousSong() {
    if (!isPowerOn) return;
    _showFeedback('Previous Song');
    HapticFeedback.lightImpact();
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
                      _buildMusicControls(),
                      const SizedBox(height: 40),
                      _buildVolumeControl(),
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
              'Smart Speaker',
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
              _updateDeviceState();
              _showFeedback('Speaker turned ${isPowerOn ? 'on' : 'off'}');
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

  Widget _buildMusicControls() {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: isPowerOn ? 1.0 : 0.5,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: Icon(Icons.skip_previous,
                size: 40, color: isPowerOn ? Colors.white : Colors.grey),
            onPressed: isPowerOn ? _previousSong : null,
          ),
          const SizedBox(width: 16),
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isPowerOn ? Colors.blue : Colors.grey[800],
            ),
            child: IconButton(
              padding: const EdgeInsets.all(16),
              icon: Icon(
                isPlaying ? Icons.pause : Icons.play_arrow,
                size: 48,
                color: Colors.white,
              ),
              onPressed: isPowerOn ? _togglePlayPause : null,
            ),
          ),
          const SizedBox(width: 16),
          IconButton(
            icon: Icon(Icons.skip_next,
                size: 40, color: isPowerOn ? Colors.white : Colors.grey),
            onPressed: isPowerOn ? _nextSong : null,
          ),
        ],
      ),
    );
  }

  Widget _buildVolumeControl() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(
                  Icons.remove,
                  color: isPowerOn ? Colors.white : Colors.grey,
                ),
                onPressed: isPowerOn ? () => _handleVolumeChange(false) : null,
              ),
              const SizedBox(width: 16),
              Column(
                children: [
                  Icon(
                    isMuted ? Icons.volume_off : Icons.volume_up,
                    color: isPowerOn ? Colors.blue : Colors.grey,
                  ),
                  Text(
                    isMuted ? 'Muted' : '${currentVolume.round()}%',
                    style: TextStyle(
                      color: isPowerOn ? Colors.white : Colors.grey,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: Icon(
                  Icons.add,
                  color: isPowerOn ? Colors.white : Colors.grey,
                ),
                onPressed: isPowerOn ? () => _handleVolumeChange(true) : null,
              ),
            ],
          ),
          Slider(
            value: currentVolume,
            min: 0.0,
            max: 100.0,
            activeColor: Colors.blue,
            inactiveColor: Colors.grey[700],
            onChanged: isPowerOn
                ? (value) {
                    setState(() {
                      currentVolume = value;
                      _updateDeviceState();
                    });
                  }
                : null,
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
        'label': 'Shuffle',
        'icon': Icons.shuffle,
        'onPressed': () => _showFeedback('Shuffle')
      },
      {
        'label': 'Repeat',
        'icon': Icons.repeat,
        'onPressed': () => _showFeedback('Repeat')
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
