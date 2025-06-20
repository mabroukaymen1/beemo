import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../widgets/colors.dart';

class PolicyScreen extends StatefulWidget {
  const PolicyScreen({Key? key}) : super(key: key);

  @override
  State<PolicyScreen> createState() => _PolicyScreenState();
}

class _PolicyScreenState extends State<PolicyScreen> {
  int? _expandedIndex;
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, dynamic>> policySections = [
    {
      "title": "1. Introduction",
      "icon": FontAwesomeIcons.circleInfo,
      "content":
          "This policy outlines the rules and guidelines for using our AI Robot Assistant application ('the App'). By using the App, you agree to comply with these policies.",
    },
    {
      "title": "2. Acceptable Use",
      "icon": FontAwesomeIcons.shieldHalved,
      "content":
          "You agree to use the App only for lawful purposes and in a manner that does not infringe the rights of others. Prohibited uses include, but are not limited to:",
      "hasList": true,
    },
    {
      "title": "3. Data Privacy",
      "icon": FontAwesomeIcons.lock,
      "content":
          "We are committed to protecting your privacy. Our Privacy Policy explains how we collect, use, and share your information. By using the App, you agree to our Privacy Policy.",
    },
    {
      "title": "4. AI Robot Interaction",
      "icon": FontAwesomeIcons.robot,
      "content":
          "The App connects to an AI Robot Assistant. You are responsible for ensuring that your interactions with the robot are respectful and appropriate.",
    },
    {
      "title": "5. Disclaimer of Warranty",
      "icon": FontAwesomeIcons.circleExclamation,
      "content":
          "The App is provided 'as is' without any warranty of any kind. We do not guarantee that the App will be error-free or that it will meet your specific requirements.",
    },
    {
      "title": "6. Limitation of Liability",
      "icon": FontAwesomeIcons.scaleBalanced,
      "content":
          "We are not liable for any damages arising out of your use of the App, including but not limited to direct, indirect, incidental, and consequential damages.",
    },
    {
      "title": "7. Changes to this Policy",
      "icon": FontAwesomeIcons.clockRotateLeft,
      "content":
          "We may update this policy from time to time. We will notify you of any changes by posting the new policy on our website or through the App.",
    },
    {
      "title": "8. Contact Us",
      "icon": FontAwesomeIcons.envelope,
      "content":
          "If you have any questions about this policy, please contact us at bemmobmo@gmail.com.",
    },
  ];

  final List<String> prohibitedUses = [
    "Engaging in any activity that is illegal, harmful, or offensive.",
    "Attempting to gain unauthorized access to the App or its related systems.",
    "Distributing malware or other harmful software through the App.",
    "Using the App to harass, threaten, or impersonate others.",
    "Collecting or harvesting data from other users without their consent.",
  ];

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _scrollToIndex(int index) async {
    final duration = Duration(milliseconds: 500);
    final offset = index * 150.0; // Approximation for scroll position
    await _scrollController.animateTo(
      offset.clamp(0, _scrollController.position.maxScrollExtent),
      duration: duration,
      curve: Curves.easeInOut,
    );
  }

  void _toggleExpanded(int index) {
    setState(() {
      _expandedIndex = _expandedIndex == index ? null : index;
    });

    if (_expandedIndex == index) {
      // Allow UI to update before scrolling
      Future.delayed(Duration(milliseconds: 100), () {
        _scrollToIndex(index);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Privacy Policy',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
            letterSpacing: 0.5,
          ),
        ),
        leading: IconButton(
          icon: const Icon(FontAwesomeIcons.chevronLeft,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(
              FontAwesomeIcons.circleQuestion,
              color: Colors.white.withOpacity(0.8),
              size: 20,
            ),
            onPressed: () {
              // Show help dialog
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    backgroundColor: AppColors.surface,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    title: Text('Policy Information',
                        style: TextStyle(color: Colors.white)),
                    content: Text(
                      'This screen contains important information about how to use our app. Tap on any section to expand and read more details.',
                      style: TextStyle(color: Colors.white.withOpacity(0.8)),
                    ),
                    actions: [
                      TextButton(
                        child: Text('OK',
                            style: TextStyle(color: AppColors.primary)),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        FontAwesomeIcons.lightbulb,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'Please read our policy carefully to understand how our app works and your rights when using it.',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(duration: 300.ms, delay: 100.ms),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16.0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    return _buildPolicyCard(
                      index: index,
                      title: policySections[index]["title"],
                      icon: policySections[index]["icon"],
                      content: policySections[index]["content"],
                      hasList: policySections[index]["hasList"] ?? false,
                    ).animate().fadeIn(
                        duration: 300.ms, delay: 150.ms + (index * 50).ms);
                  },
                  childCount: policySections.length,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: _buildLastUpdatedInfo(),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _sendEmail,
        icon: Icon(FontAwesomeIcons.envelope, size: 16),
        label: Text("Contact Support"),
        backgroundColor: AppColors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        elevation: 4,
      ).animate().slide(
            duration: 400.ms,
            delay: 200.ms,
            begin: const Offset(0, 1),
          ),
    );
  }

  void _sendEmail() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'bemmobmo@gmail.com',
      query: Uri.encodeFull(
          'subject=Support Request: AI Robot Assistant&body=Hello,\n\nI have a question about the AI Robot Assistant app.\n\nRegards,'),
    );

    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      } else {
        final Uri fallbackUri = Uri.parse(
            'https://mail.google.com/mail/?view=cm&fs=1&to=bemmobmo@gmail.com&su=Support Request: AI Robot Assistant&body=Hello,%0A%0AI have a question about the AI Robot Assistant app.%0A%0ARegards,');

        if (await canLaunchUrl(fallbackUri)) {
          await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
        } else {
          // Show error dialog
          if (context.mounted) {
            _showErrorDialog();
          }
        }
      }
    } catch (e) {
      // Show error dialog
      if (context.mounted) {
        _showErrorDialog();
      }
    }
  }

  void _showErrorDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Email Error', style: TextStyle(color: Colors.white)),
          content: Text(
            'Could not launch email client. Please send an email manually to bemmobmo@gmail.com',
            style: TextStyle(color: Colors.white.withOpacity(0.8)),
          ),
          actions: [
            TextButton(
              child: Text('Copy Email',
                  style: TextStyle(color: AppColors.primary)),
              onPressed: () async {
                await Clipboard.setData(
                    ClipboardData(text: 'bemmobmo@gmail.com'));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Email copied to clipboard'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                  Navigator.of(context).pop();
                }
              },
            ),
            TextButton(
              child: Text('OK', style: TextStyle(color: Colors.white)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildPolicyCard({
    required int index,
    required String title,
    required IconData icon,
    required String content,
    required bool hasList,
  }) {
    final bool isExpanded = _expandedIndex == index;

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExpanded
              ? AppColors.primary.withOpacity(0.5)
              : AppColors.cardBorder.withOpacity(0.3),
          width: isExpanded ? 1.5 : 1,
        ),
        boxShadow: isExpanded
            ? [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.2),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                )
              ]
            : [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _toggleExpanded(index),
          highlightColor: AppColors.primary.withOpacity(0.1),
          splashColor: AppColors.primary.withOpacity(0.05),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        icon,
                        color: AppColors.primary,
                        size: 18,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: isExpanded
                          ? AppColors.primary
                          : Colors.white.withOpacity(0.7),
                      size: 24,
                    ),
                  ],
                ),
                if (isExpanded) ...[
                  SizedBox(height: 16),
                  Divider(
                    color: AppColors.cardBorder.withOpacity(0.3),
                    thickness: 1,
                  ),
                  SizedBox(height: 16),
                  Text(
                    content,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                  if (hasList) ...[
                    SizedBox(height: 12),
                    ...prohibitedUses
                        .map((e) => _buildBulletedText(e))
                        .toList(),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBulletedText(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '•',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLastUpdatedInfo() {
    return Column(
      children: [
        Divider(color: AppColors.cardBorder.withOpacity(0.3)),
        SizedBox(height: 16),
        Text(
          'Last Updated: May 1, 2025',
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withOpacity(0.6),
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton.icon(
              onPressed: () {
                // Navigate to privacy policy web page
              },
              icon: Icon(
                FontAwesomeIcons.fileLines,
                size: 14,
                color: AppColors.primary.withOpacity(0.8),
              ),
              label: Text(
                'Full Policy',
                style: TextStyle(
                  color: AppColors.primary.withOpacity(0.8),
                ),
              ),
            ),
            SizedBox(width: 16),
            TextButton.icon(
              onPressed: () {
                // Navigate to terms of service web page
              },
              icon: Icon(
                FontAwesomeIcons.fileContract,
                size: 14,
                color: AppColors.primary.withOpacity(0.8),
              ),
              label: Text(
                'Terms of Service',
                style: TextStyle(
                  color: AppColors.primary.withOpacity(0.8),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 70), // Space for FAB
      ],
    );
  }
}
