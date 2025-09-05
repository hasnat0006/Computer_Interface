import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/schedule_provider.dart';
import '../providers/bluetooth_provider.dart';
import '../providers/robot_control_provider.dart';
import '../models/schedule.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cleaning Schedule'),
      ),
      body: Consumer<ScheduleProvider>(
        builder: (context, scheduleProvider, child) {
          final upcomingSchedules = scheduleProvider.upcomingSchedules;

          return Column(
            children: [
              // Header with schedule count
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: Colors.blue[50],
                child: Row(
                  children: [
                    Icon(Icons.schedule, color: Colors.blue[700]),
                    const SizedBox(width: 8),
                    Text(
                      '${upcomingSchedules.length} upcoming schedules',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.blue[700],
                      ),
                    ),
                  ],
                ),
              ),

              // Schedule list
              Expanded(
                child: upcomingSchedules.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.schedule,
                              size: 64,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No upcoming schedules',
                              style:
                                  TextStyle(fontSize: 18, color: Colors.grey),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Create a new schedule by tapping the + button',
                              style:
                                  TextStyle(fontSize: 14, color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: upcomingSchedules.length,
                        itemBuilder: (context, index) {
                          final schedule = upcomingSchedules[index];
                          return _buildScheduleCard(schedule, scheduleProvider);
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateScheduleDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildScheduleCard(
      Schedule schedule, ScheduleProvider scheduleProvider) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final timeFormat = DateFormat('hh:mm a');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: schedule.mode == CleaningMode.autonomous
              ? Colors.green
              : Colors.orange,
          child: Icon(
            schedule.mode == CleaningMode.autonomous
                ? Icons.auto_mode
                : Icons.gamepad,
            color: Colors.white,
          ),
        ),
        title: Text(
          '${dateFormat.format(schedule.dateTime)} at ${timeFormat.format(schedule.dateTime)}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mode: ${schedule.modeText}'),
            Text('Features: ${schedule.featuresText}'),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'execute':
                _showExecuteDialog(schedule, scheduleProvider);
                break;
              case 'json':
                _showJsonCommand(schedule, scheduleProvider);
                break;
              case 'delete':
                _showDeleteConfirmation(schedule, scheduleProvider);
                break;
              case 'edit':
                _showEditScheduleDialog(schedule, scheduleProvider);
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'execute',
              child: Row(
                children: [
                  Icon(Icons.play_arrow, color: Colors.green),
                  SizedBox(width: 8),
                  Text('Execute Now'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'json',
              child: Row(
                children: [
                  Icon(Icons.code, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('View JSON'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit),
                  SizedBox(width: 8),
                  Text('Edit'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateScheduleDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _ScheduleDialog(
        onSave: (schedule) {
          context.read<ScheduleProvider>().addSchedule(schedule);
        },
      ),
    );
  }

  void _showEditScheduleDialog(
      Schedule schedule, ScheduleProvider scheduleProvider) {
    showDialog(
      context: context,
      builder: (context) => _ScheduleDialog(
        schedule: schedule,
        onSave: (updatedSchedule) {
          scheduleProvider.updateSchedule(updatedSchedule);
        },
      ),
    );
  }

  void _showDeleteConfirmation(
      Schedule schedule, ScheduleProvider scheduleProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Schedule'),
        content: const Text('Are you sure you want to delete this schedule?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              scheduleProvider.deleteSchedule(schedule.id);
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showExecuteDialog(
      Schedule schedule, ScheduleProvider scheduleProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Execute Schedule'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Execute this schedule immediately?'),
            const SizedBox(height: 16),
            Text('Mode: ${schedule.modeText}',
                style: TextStyle(fontWeight: FontWeight.bold)),
            Text('Features: ${schedule.featuresText}'),
            const SizedBox(height: 8),
            Text(
              'Note: This requires active Bluetooth connection',
              style: TextStyle(color: Colors.orange[700], fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();

              final bluetoothProvider = context.read<BluetoothProvider>();
              final robotProvider = context.read<RobotControlProvider>();

              if (!bluetoothProvider.isConnected) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please connect to Bluetooth first'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              final success = await scheduleProvider.executeScheduleNow(
                  schedule.id, bluetoothProvider, robotProvider);

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(success
                      ? 'Schedule executed successfully!'
                      : 'Failed to execute schedule'),
                  backgroundColor: success ? Colors.green : Colors.red,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Execute'),
          ),
        ],
      ),
    );
  }

  void _showJsonCommand(Schedule schedule, ScheduleProvider scheduleProvider) {
    final jsonCommand = scheduleProvider.generateScheduleCommand(schedule);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('JSON Command'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This JSON command will be sent to the robot:'),
            const SizedBox(height: 16),
            Container(
              width: double.maxFinite,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: SelectableText(
                jsonCommand,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: jsonCommand));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('JSON command copied to clipboard')),
              );
            },
            child: const Text('Copy'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _ScheduleDialog extends StatefulWidget {
  final Schedule? schedule;
  final Function(Schedule) onSave;

  const _ScheduleDialog({
    this.schedule,
    required this.onSave,
  });

  @override
  State<_ScheduleDialog> createState() => _ScheduleDialogState();
}

class _ScheduleDialogState extends State<_ScheduleDialog> {
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  late CleaningMode _selectedMode;
  late bool _vacuumEnabled;
  late bool _mopEnabled;
  late bool _pumpEnabled;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();

    if (widget.schedule != null) {
      _selectedDate = widget.schedule!.dateTime;
      _selectedTime = TimeOfDay.fromDateTime(widget.schedule!.dateTime);
      _selectedMode = widget.schedule!.mode;
      _vacuumEnabled = widget.schedule!.vacuumEnabled;
      _mopEnabled = widget.schedule!.mopEnabled;
      _pumpEnabled = widget.schedule!.pumpEnabled;
    } else {
      _selectedDate = now.add(const Duration(hours: 1));
      _selectedTime = TimeOfDay.fromDateTime(_selectedDate);
      _selectedMode = CleaningMode.autonomous;
      _vacuumEnabled = true;
      _mopEnabled = false;
      _pumpEnabled = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title:
          Text(widget.schedule == null ? 'Create Schedule' : 'Edit Schedule'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date selection
            const Text('Date', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            InkWell(
              onTap: _selectDate,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today),
                    const SizedBox(width: 8),
                    Text(DateFormat('MMM dd, yyyy').format(_selectedDate)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Time selection
            const Text('Time', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            InkWell(
              onTap: _selectTime,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.access_time),
                    const SizedBox(width: 8),
                    Text(_selectedTime.format(context)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Mode selection
            const Text('Cleaning Mode',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<CleaningMode>(
              value: _selectedMode,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              items: CleaningMode.values.map((mode) {
                return DropdownMenuItem(
                  value: mode,
                  child: Text(mode == CleaningMode.autonomous
                      ? 'Autonomous'
                      : 'Manual'),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedMode = value;
                  });
                }
              },
            ),

            const SizedBox(height: 16),

            // Features
            const Text('Features',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            CheckboxListTile(
              title: const Text('Vacuum'),
              value: _vacuumEnabled,
              onChanged: (value) {
                setState(() {
                  _vacuumEnabled = value ?? false;
                });
              },
            ),
            CheckboxListTile(
              title: const Text('Mop'),
              value: _mopEnabled,
              onChanged: (value) {
                setState(() {
                  _mopEnabled = value ?? false;
                });
              },
            ),
            CheckboxListTile(
              title: const Text('Water Pump'),
              value: _pumpEnabled,
              onChanged: (value) {
                setState(() {
                  _pumpEnabled = value ?? false;
                });
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saveSchedule,
          child: const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  void _saveSchedule() {
    final dateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    if (dateTime.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Schedule time must be in the future'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final schedule = widget.schedule?.copyWith(
          dateTime: dateTime,
          mode: _selectedMode,
          vacuumEnabled: _vacuumEnabled,
          mopEnabled: _mopEnabled,
          pumpEnabled: _pumpEnabled,
        ) ??
        Schedule(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          dateTime: dateTime,
          mode: _selectedMode,
          vacuumEnabled: _vacuumEnabled,
          mopEnabled: _mopEnabled,
          pumpEnabled: _pumpEnabled,
        );

    widget.onSave(schedule);
    Navigator.of(context).pop();
  }
}
