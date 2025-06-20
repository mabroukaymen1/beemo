import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:teemo/widgets/colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:teemo/services/firestore_service.dart';
import 'logs_provider.dart';
import 'package:flutter/services.dart';

class AutomationLogsScreen extends StatefulWidget {
  const AutomationLogsScreen({Key? key}) : super(key: key);

  @override
  State<AutomationLogsScreen> createState() => _AutomationLogsScreenState();
}

class _AutomationLogsScreenState extends State<AutomationLogsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final FirestoreService _firestoreService = FirestoreService();
  String _filter = 'All';
  final List<String> _filterOptions = [
    'All',
    'Schedule',
    'Device',
    'Notification'
  ];

  @override
  void initState() {
    super.initState();

    // Set up animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    _animationController.forward();

    // Load days with logs for calendar indicators
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDaysWithLogs();
    });
  }

  Future<void> _loadDaysWithLogs() async {
    final provider = Provider.of<LogsProvider>(context, listen: false);
    provider.setLoading(true);

    try {
      final days = await _firestoreService.getDaysWithLogs();
      provider.setDaysWithLogs(days);
    } catch (e) {
      // Handle error
      debugPrint('Error loading days with logs: $e');
    } finally {
      provider.setLoading(false);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              _DateSelector(),
              const SizedBox(height: 16),
              _buildFilterChips(),
              const SizedBox(height: 8),
              Expanded(child: _LogsList(filter: _filter)),
            ],
          ),
        ),
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.background,
      elevation: 0,
      centerTitle: true,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(FontAwesomeIcons.listCheck, size: 18),
          const SizedBox(width: 8),
          const Text(
            "Automation Logs",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ],
      ),
      actions: [
        Builder(
          builder: (context) => IconButton(
            icon: const Icon(FontAwesomeIcons.calendarDays,
                color: Colors.white, size: 20),
            onPressed: () => Provider.of<LogsProvider>(context, listen: false)
                .showCalendarDialog(context),
            splashRadius: 24,
            tooltip: 'Calendar',
          ),
        ),
      ],
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );
  }

  Widget _buildHeader() {
    return Consumer<LogsProvider>(
      builder: (context, provider, _) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('MMMM yyyy').format(provider.selectedDay),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Showing all automation activity',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children:
              _filterOptions.map((filter) => _buildFilterChip(filter)).toList(),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String filter) {
    final isSelected = _filter == filter;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: isSelected,
        label: Text(filter),
        backgroundColor: AppColors.cardDark,
        selectedColor: AppColors.primary,
        checkmarkColor: Colors.white,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.white70,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isSelected ? Colors.transparent : AppColors.cardLight,
            width: 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        onSelected: (selected) {
          setState(() {
            _filter = filter;
          });
        },
        elevation: isSelected ? 2 : 0,
        pressElevation: 4,
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton(
      onPressed: () {
        _showExportDialog();
      },
      backgroundColor: AppColors.primary,
      child: const Icon(Icons.share_outlined),
      elevation: 4,
      tooltip: 'Export logs',
    );
  }

  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Export Logs',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildExportOption(
              icon: Icons.calendar_today_outlined,
              title: 'Current Day',
              subtitle: 'Export logs for the selected day',
              onTap: () {
                Navigator.pop(context);
                _showSnackBar('Exporting logs for selected day...');
              },
            ),
            const SizedBox(height: 8),
            _buildExportOption(
              icon: Icons.date_range_outlined,
              title: 'Current Month',
              subtitle: 'Export all logs for the current month',
              onTap: () {
                Navigator.pop(context);
                _showSnackBar('Exporting logs for current month...');
              },
            ),
            const SizedBox(height: 8),
            _buildExportOption(
              icon: Icons.history_outlined,
              title: 'All Time',
              subtitle: 'Export all historical logs',
              onTap: () {
                Navigator.pop(context);
                _showSnackBar('Exporting all logs...');
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey[400]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExportOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.primary),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: Colors.grey[400],
          fontSize: 12,
        ),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: 'DISMISS',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }
}

class _DateSelector extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<LogsProvider>(
      builder: (context, logsProvider, _) {
        final dates = logsProvider.getVisibleDays();

        return SizedBox(
          height: 90,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: dates.length,
            physics: const BouncingScrollPhysics(),
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              return logsProvider.buildDateTile(context, dates[index]);
            },
          ),
        );
      },
    );
  }
}

class _LogsList extends StatelessWidget {
  final String filter;

  const _LogsList({Key? key, required this.filter}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();

    return Consumer<LogsProvider>(
      builder: (context, logsProvider, _) {
        return StreamBuilder<QuerySnapshot>(
          stream: firestoreService.getLogsForDay(logsProvider.selectedDay,
              filter: filter != 'All' ? filter.toLowerCase() : null),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              debugPrint("Firestore Error: ${snapshot.error}");
              return _buildErrorState('Failed to load logs: ${snapshot.error}');
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingState();
            }

            final docs = snapshot.data?.docs;
            if (docs == null || docs.isEmpty) {
              return _buildEmptyState();
            }

            return _buildLogsList(docs);
          },
        );
      },
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () {
                // Implement refresh logic here
              },
              icon: const Icon(Icons.refresh, color: AppColors.primary),
              label: const Text(
                'Retry',
                style: TextStyle(color: AppColors.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            FontAwesomeIcons.calendarXmark,
            color: Colors.grey,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            filter == 'All'
                ? 'No logs for this day'
                : 'No $filter logs for this day',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try selecting a different day or filter',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogsList(List<QueryDocumentSnapshot> docs) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
          20, 8, 20, 100), // Extra bottom padding for FAB
      physics: const BouncingScrollPhysics(),
      itemCount: docs.length,
      separatorBuilder: (context, index) => const Divider(
        color: Colors.white10,
        height: 1,
        indent: 60,
      ),
      itemBuilder: (context, index) {
        var logData = docs[index].data() as Map<String, dynamic>;
        DateTime timestamp = (logData['timestamp'] as Timestamp).toDate();
        String message = logData['message'] ?? '';
        String logType = logData['type'] ?? 'default';

        return _buildLogItem(timestamp, message, logType);
      },
    );
  }

  Widget _buildLogItem(DateTime timestamp, String message, String logType) {
    IconData icon;
    Color iconColor;

    switch (logType) {
      case 'schedule':
        icon = FontAwesomeIcons.calendarCheck;
        iconColor = Colors.purple[400]!;
        break;
      case 'device':
        icon = FontAwesomeIcons.lightbulb;
        iconColor = Colors.blue[400]!;
        break;
      case 'notification':
        icon = FontAwesomeIcons.bell;
        iconColor = Colors.orange[400]!;
        break;
      default:
        icon = FontAwesomeIcons.circleInfo;
        iconColor = Colors.teal[400]!;
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Icon(
                FontAwesomeIcons.clock,
                size: 12,
                color: Colors.grey[500],
              ),
              const SizedBox(width: 4),
              Text(
                DateFormat('HH:mm:ss').format(timestamp),
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        onTap: () {
          // Show log details
        },
      ),
    );
  }
}
