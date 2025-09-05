import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/bluetooth_provider.dart';
import '../providers/robot_control_provider.dart';
import '../providers/schedule_provider.dart';
import '../models/robot_models.dart';

import '../widgets/status_card.dart';
import '../widgets/quick_action_button.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  void _showBluetoothDevicesDialog() async {
    final bluetoothProvider = context.read<BluetoothProvider>();

    // Load paired devices instead of scanning
    await bluetoothProvider.loadPairedDevices();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Paired Bluetooth Devices'),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: Consumer<BluetoothProvider>(
              builder: (context, provider, child) {
                if (provider.pairedDevices.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.bluetooth_disabled,
                          size: 48,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No paired devices found',
                          style: TextStyle(fontSize: 16),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Please pair your cleaning robot with this device first using Android/iOS Bluetooth settings',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: provider.pairedDevices.length,
                  itemBuilder: (context, index) {
                    final device = provider.pairedDevices[index];
                    final isCurrentDevice =
                        provider.connectedDevice?.remoteId == device.remoteId;

                    return ListTile(
                      leading: Icon(
                        isCurrentDevice
                            ? Icons.bluetooth_connected
                            : Icons.bluetooth,
                        color: isCurrentDevice ? Colors.green : Colors.blue,
                      ),
                      title: Text(
                        device.platformName.isNotEmpty
                            ? device.platformName
                            : 'Unknown Device',
                        style: TextStyle(
                          fontWeight: isCurrentDevice
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isCurrentDevice ? Colors.green : null,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(device.remoteId.toString()),
                          if (isCurrentDevice)
                            const Text(
                              'Currently Connected',
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      ),
                      onTap: isCurrentDevice
                          ? null // Don't allow tapping if already connected
                          : () async {
                              Navigator.pop(context);
                              _showToast(
                                  'Connecting to ${device.platformName.isNotEmpty ? device.platformName : "device"}...');

                              bool success =
                                  await provider.connectToDevice(device);
                              if (success) {
                                _showToast('Connected successfully!',
                                    isSuccess: true);
                              } else {
                                _showToast('Failed to connect!', isError: true);
                              }
                            },
                      trailing: isCurrentDevice
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : const Icon(Icons.arrow_forward_ios, size: 16),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                await bluetoothProvider.loadPairedDevices();
              },
              child: const Text('Refresh'),
            ),
          ],
        );
      },
    );
  }

  void _testLED() async {
    final bluetoothProvider = context.read<BluetoothProvider>();
    final robotProvider = context.read<RobotControlProvider>();

    if (!bluetoothProvider.isConnected) {
      _showToast('Please connect to Bluetooth first!', isError: true);
      return;
    }

    _showToast('Testing LED...');
    bool success = await robotProvider.testLED(bluetoothProvider);

    if (success) {
      _showToast('LED test command sent!', isSuccess: true);
    } else {
      _showToast('Failed to send LED test command!', isError: true);
    }
  }

  void _showToast(String message,
      {bool isSuccess = false, bool isError = false}) {
    Color backgroundColor = Colors.blue;
    IconData icon = Icons.info;

    if (isSuccess) {
      backgroundColor = Colors.green;
      icon = Icons.check_circle;
    } else if (isError) {
      backgroundColor = Colors.red;
      icon = Icons.error;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: Duration(milliseconds: isError ? 1500 : 1000),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cleaning Robot Control'),
        automaticallyImplyLeading: false,
        actions: [
          // Bluetooth button
          Consumer<BluetoothProvider>(
            builder: (context, bluetoothProvider, child) {
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: IconButton(
                  onPressed: _showBluetoothDevicesDialog,
                  icon: Icon(
                    bluetoothProvider.isConnected
                        ? Icons.bluetooth_connected
                        : Icons.bluetooth,
                  ),
                  color: bluetoothProvider.isConnected
                      ? Colors.green
                      : Colors.grey,
                  iconSize: 28,
                ),
              );
            },
          ),
          // Test button
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Consumer<BluetoothProvider>(
              builder: (context, bluetoothProvider, child) {
                return IconButton(
                  onPressed: _testLED,
                  icon: const Icon(Icons.lightbulb),
                  color: bluetoothProvider.isConnected
                      ? Colors.orange
                      : Colors.grey,
                  iconSize: 28,
                );
              },
            ),
          ),
        ],
      ),
      body:
          Consumer3<BluetoothProvider, RobotControlProvider, ScheduleProvider>(
        builder: (context, bluetoothProvider, robotProvider, scheduleProvider,
            child) {
          return RefreshIndicator(
            onRefresh: () async {
              if (bluetoothProvider.isConnected) {
                await robotProvider.requestStatus(bluetoothProvider);
                _showToast('Status refreshed');
              } else {
                _showToast('Connect to Bluetooth to refresh status',
                    isError: true);
              }
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Robot Status Section (only show if connected)
                  if (bluetoothProvider.isConnected) ...[
                    const Text(
                      'Robot Status',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),

                    StatusCard(
                      title: 'Robot State',
                      value: robotProvider.status.stateText,
                      icon: Icons.android,
                      color: _getStateColor(robotProvider.status.state),
                    ),
                    StatusCard(
                      title: 'Vacuum',
                      value: robotProvider.status.vacuumActive
                          ? 'Active'
                          : 'Inactive',
                      icon: Icons.cleaning_services,
                      color: robotProvider.status.vacuumActive
                          ? Colors.blue
                          : Colors.grey,
                    ),
                    StatusCard(
                      title: 'Mop',
                      value: robotProvider.status.mopActive
                          ? 'Active'
                          : 'Inactive',
                      icon: Icons.water_drop,
                      color: robotProvider.status.mopActive
                          ? Colors.blue
                          : Colors.grey,
                    ),

                    const SizedBox(height: 24),

                    // Quick Actions Section
                    const Text(
                      'Quick Actions',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        QuickActionButton(
                          icon: robotProvider.status.state ==
                                  RobotState.autonomous
                              ? Icons.stop
                              : Icons.play_arrow,
                          label: robotProvider.status.state ==
                                  RobotState.autonomous
                              ? 'Stop Auto'
                              : 'Autonomous',
                          color: robotProvider.status.state ==
                                  RobotState.autonomous
                              ? Colors.red
                              : Colors.green,
                          onPressed: () async {
                            bool success = await robotProvider
                                .toggleAutonomousMode(bluetoothProvider);
                            _showToast(
                              success
                                  ? (robotProvider.status.state ==
                                          RobotState.autonomous
                                      ? 'Autonomous mode activated!'
                                      : 'Autonomous mode stopped!')
                                  : 'Failed to toggle autonomous mode',
                              isSuccess: success,
                              isError: !success,
                            );
                          },
                        ),
                        QuickActionButton(
                          icon: Icons.gamepad,
                          label: 'Manual',
                          color: Colors.orange,
                          onPressed: () {
                            Navigator.pushNamed(context, '/manual-control');
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Vacuum and Mop Controls
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: QuickActionButton(
                              icon: Icons.cleaning_services,
                              label: robotProvider.status.vacuumActive
                                  ? 'Vacuum Off'
                                  : 'Vacuum On',
                              color: robotProvider.status.vacuumActive
                                  ? Colors.grey
                                  : Colors.blue,
                              onPressed: () async {
                                bool success = await robotProvider
                                    .toggleVacuum(bluetoothProvider);
                                _showToast(
                                  success
                                      ? (robotProvider.status.vacuumActive
                                          ? "Vacuum activated!"
                                          : "Vacuum deactivated!")
                                      : 'Failed to toggle vacuum',
                                  isSuccess: success,
                                  isError: !success,
                                );
                              },
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: QuickActionButton(
                              icon: Icons.water_drop,
                              label: robotProvider.status.mopActive
                                  ? 'Mop Off'
                                  : 'Mop On',
                              color: robotProvider.status.mopActive
                                  ? Colors.grey
                                  : Colors.cyan,
                              onPressed: () async {
                                bool success = await robotProvider
                                    .toggleMop(bluetoothProvider);
                                _showToast(
                                  success
                                      ? (robotProvider.status.mopActive
                                          ? "Mop activated!"
                                          : "Mop deactivated!")
                                      : 'Failed to toggle mop',
                                  isSuccess: success,
                                  isError: !success,
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Schedule Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pushNamed(context, '/schedule');
                            },
                            icon: const Icon(Icons.schedule),
                            label: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('Schedule'),
                                Text(
                                  '${scheduleProvider.upcomingSchedules.length} upcoming',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pushNamed(context, '/schedule-history');
                            },
                            icon: const Icon(Icons.history),
                            label: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('History'),
                                Text(
                                  '${scheduleProvider.completedSchedules.length} completed',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    // Not connected message
                    const SizedBox(height: 50),
                    Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.bluetooth_disabled,
                            size: 80,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Connect to Bluetooth',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap the Connect button to view and connect to your paired cleaning robot',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 32),
                          ElevatedButton.icon(
                            onPressed: _showBluetoothDevicesDialog,
                            icon: const Icon(Icons.bluetooth),
                            label: const Text('Show Paired Devices'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Color _getStateColor(RobotState state) {
    switch (state) {
      case RobotState.idle:
        return Colors.grey;
      case RobotState.moving:
        return Colors.orange;
      case RobotState.cleaning:
        return Colors.blue;
      case RobotState.autonomous:
        return Colors.green;
      case RobotState.manual:
        return Colors.purple;
      case RobotState.error:
        return Colors.red;
      case RobotState.disconnected:
        return Colors.red;
    }
  }
}
