import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/schedule_provider.dart';
import '../models/schedule.dart';

class ScheduleHistoryScreen extends StatefulWidget {
  const ScheduleHistoryScreen({super.key});

  @override
  State<ScheduleHistoryScreen> createState() => _ScheduleHistoryScreenState();
}

class _ScheduleHistoryScreenState extends State<ScheduleHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Schedule History'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Completed'),
            Tab(text: 'Expired'),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              final scheduleProvider = context.read<ScheduleProvider>();
              switch (value) {
                case 'clear_completed':
                  _showClearDialog('completed', () {
                    scheduleProvider.clearCompletedSchedules();
                  });
                  break;
                case 'clear_expired':
                  _showClearDialog('expired', () {
                    scheduleProvider.clearExpiredSchedules();
                  });
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear_completed',
                child: Row(
                  children: [
                    Icon(Icons.clear_all),
                    SizedBox(width: 8),
                    Text('Clear Completed'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear_expired',
                child: Row(
                  children: [
                    Icon(Icons.clear_all),
                    SizedBox(width: 8),
                    Text('Clear Expired'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Consumer<ScheduleProvider>(
        builder: (context, scheduleProvider, child) {
          return TabBarView(
            controller: _tabController,
            children: [
              _buildScheduleList(
                scheduleProvider.completedSchedules,
                'No completed schedules',
                'Your completed cleaning sessions will appear here',
                Icons.check_circle,
                Colors.green,
              ),
              _buildScheduleList(
                scheduleProvider.expiredSchedules,
                'No expired schedules',
                'Missed or expired schedules will appear here',
                Icons.schedule,
                Colors.red,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildScheduleList(
    List<Schedule> schedules,
    String emptyTitle,
    String emptySubtitle,
    IconData emptyIcon,
    Color emptyIconColor,
  ) {
    if (schedules.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              emptyIcon,
              size: 64,
              color: emptyIconColor.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              emptyTitle,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              emptySubtitle,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: schedules.length,
      itemBuilder: (context, index) {
        final schedule = schedules[index];
        return _buildHistoryCard(schedule);
      },
    );
  }

  Widget _buildHistoryCard(Schedule schedule) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final timeFormat = DateFormat('hh:mm a');
    final isCompleted = schedule.isCompleted;
    final isExpired = schedule.isExpired;

    Color statusColor;
    IconData statusIcon;
    String statusText;

    if (isCompleted) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
      statusText = 'Completed';
    } else if (isExpired) {
      statusColor = Colors.red;
      statusIcon = Icons.schedule;
      statusText = 'Expired';
    } else {
      statusColor = Colors.grey;
      statusIcon = Icons.help;
      statusText = 'Unknown';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.1),
          child: Icon(
            statusIcon,
            color: statusColor,
          ),
        ),
        title: Text(
          '${dateFormat.format(schedule.dateTime)} at ${timeFormat.format(schedule.dateTime)}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: schedule.mode == CleaningMode.autonomous
                        ? Colors.green.withOpacity(0.1)
                        : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    schedule.modeText,
                    style: TextStyle(
                      color: schedule.mode == CleaningMode.autonomous
                          ? Colors.green
                          : Colors.orange,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('Features: ${schedule.featuresText}'),
            Text(
              'Created: ${DateFormat('MMM dd, yyyy').format(schedule.createdAt)}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () => _showDeleteConfirmation(schedule),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(Schedule schedule) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Schedule'),
        content: const Text(
            'Are you sure you want to delete this schedule from history?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<ScheduleProvider>().deleteSchedule(schedule.id);
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showClearDialog(String type, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Clear ${type.toUpperCase()} Schedules'),
        content: Text('Are you sure you want to clear all $type schedules?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              onConfirm();
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child:
                const Text('Clear All', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
