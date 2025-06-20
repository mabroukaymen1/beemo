import 'package:flutter/material.dart';
import '../../widgets/colors.dart';

class DelayActionScreen extends StatefulWidget {
  @override
  _DelayActionScreenState createState() => _DelayActionScreenState();
}

class _DelayActionScreenState extends State<DelayActionScreen> {
  int delay = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Delay Action',
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
            const Text('Enter delay in seconds:',
                style: TextStyle(color: AppColors.white)),
            TextField(
              keyboardType: TextInputType.number,
              style: const TextStyle(color: AppColors.white),
              decoration: const InputDecoration(
                hintText: 'Delay in seconds',
                hintStyle: TextStyle(color: Colors.grey),
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey)),
                focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: AppColors.primary)),
              ),
              onChanged: (value) {
                setState(() {
                  delay = int.tryParse(value) ?? 0;
                });
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, {'delay': delay});
              },
              style: ElevatedButton.styleFrom(
                foregroundColor: AppColors.white,
                backgroundColor: AppColors.primary,
              ),
              child: const Text('Confirm Delay'),
            ),
          ],
        ),
      ),
    );
  }
}
