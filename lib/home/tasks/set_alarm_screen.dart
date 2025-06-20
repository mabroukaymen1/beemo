import 'package:flutter/material.dart';
import 'package:teemo/widgets/colors.dart';

class SetAlarmScreen extends StatefulWidget {
  @override
  _SetAlarmScreenState createState() => _SetAlarmScreenState();
}

class _SetAlarmScreenState extends State<SetAlarmScreen> {
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _vibrate = true;
  String _selectedSound = 'Default';
  bool _repeat = false;

  final List<String> _alarmSounds = ['Default', 'Chimes', 'Bell', 'Digital'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon:
              Icon(Icons.arrow_back_ios_new, color: AppColors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Set Alarm',
          style: TextStyle(color: AppColors.white, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTimeSelector(),
            SizedBox(height: 24),
            _buildOptions(),
            SizedBox(height: 32),
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeSelector() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          Text(
            'Alarm Time',
            style: TextStyle(
              color: AppColors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 16),
          InkWell(
            onTap: _selectTime,
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  _selectedTime.format(context),
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptions() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Options',
            style: TextStyle(
              color: AppColors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          SwitchListTile(
            title: Text('Vibrate', style: TextStyle(color: AppColors.white)),
            value: _vibrate,
            onChanged: (value) => setState(() => _vibrate = value),
            activeColor: AppColors.primary,
          ),
          SwitchListTile(
            title:
                Text('Repeat Daily', style: TextStyle(color: AppColors.white)),
            value: _repeat,
            onChanged: (value) => setState(() => _repeat = value),
            activeColor: AppColors.primary,
          ),
          ListTile(
            title: Text('Sound', style: TextStyle(color: AppColors.white)),
            subtitle: Text(_selectedSound,
                style: TextStyle(color: AppColors.textSecondary)),
            trailing: Icon(Icons.arrow_forward_ios,
                color: AppColors.textSecondary, size: 16),
            onTap: _showSoundPicker,
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _saveAlarm,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          'Save Alarm',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: AppColors.surface,
              hourMinuteTextColor: AppColors.white,
              dayPeriodTextColor: AppColors.white,
              dialHandColor: AppColors.primary,
              dialBackgroundColor: AppColors.background,
              dialTextColor: AppColors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  void _showSoundPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => ListView.builder(
        shrinkWrap: true,
        itemCount: _alarmSounds.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(
              _alarmSounds[index],
              style: TextStyle(color: AppColors.white),
            ),
            trailing: _alarmSounds[index] == _selectedSound
                ? Icon(Icons.check, color: AppColors.primary)
                : null,
            onTap: () {
              setState(() => _selectedSound = _alarmSounds[index]);
              Navigator.pop(context);
            },
          );
        },
      ),
    );
  }

  void _saveAlarm() {
    final alarmData = {
      'time': _selectedTime,
      'vibrate': _vibrate,
      'sound': _selectedSound,
      'repeat': _repeat,
    };
    Navigator.pop(context, alarmData);
  }
}
