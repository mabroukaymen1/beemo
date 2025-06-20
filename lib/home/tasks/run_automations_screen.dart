import 'package:flutter/material.dart';
import '../../widgets/colors.dart';

class RunAutomationsScreen extends StatefulWidget {
  @override
  _RunAutomationsScreenState createState() => _RunAutomationsScreenState();
}

class _RunAutomationsScreenState extends State<RunAutomationsScreen> {
  List<String> selectedAutomations = [];
  List<String> availableAutomations = [
    'Automation 1',
    'Automation 2',
    'Automation 3'
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Run Automations',
            style: TextStyle(color: AppColors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text('Select automations to run:',
                style: TextStyle(color: AppColors.white)),
            Expanded(
              child: ListView.builder(
                itemCount: availableAutomations.length,
                itemBuilder: (context, index) {
                  final automation = availableAutomations[index];
                  return CheckboxListTile(
                    title: Text(automation,
                        style: const TextStyle(color: AppColors.white)),
                    value: selectedAutomations.contains(automation),
                    onChanged: (bool? value) {
                      setState(() {
                        if (value == true) {
                          selectedAutomations.add(automation);
                        } else {
                          selectedAutomations.remove(automation);
                        }
                      });
                    },
                    checkColor: AppColors.white,
                    activeColor: AppColors.primary,
                  );
                },
              ),
            ),
            ElevatedButton(
              onPressed: selectedAutomations.isNotEmpty
                  ? () {
                      Navigator.pop(
                          context, {'automations': selectedAutomations});
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                foregroundColor: AppColors.white,
                backgroundColor: AppColors.primary,
              ),
              child: const Text('Confirm Automations'),
            ),
          ],
        ),
      ),
    );
  }
}
