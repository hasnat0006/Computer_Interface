import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/bluetooth_provider.dart';
import '../providers/robot_control_provider.dart';
import '../models/robot_models.dart';

class ManualControlScreen extends StatefulWidget {
  const ManualControlScreen({super.key});

  @override
  State<ManualControlScreen> createState() => _ManualControlScreenState();
}

class _ManualControlScreenState extends State<ManualControlScreen> {
  bool _isRobotOn = false;
  DateTime? _lastCommandTime;
  bool _isCommandInProgress = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bluetoothProvider = context.read<BluetoothProvider>();
      final robotProvider = context.read<RobotControlProvider>();

      if (bluetoothProvider.isConnected) {
        // Set robot to manual mode
        robotProvider.setManualMode(bluetoothProvider);
        _showToast('Manual control mode activated', isSuccess: true);
      }
    });
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
        title: const Text('Manual Control'),
        actions: [
          Consumer<BluetoothProvider>(
            builder: (context, bluetoothProvider, child) {
              return IconButton(
                icon: Icon(
                  bluetoothProvider.isConnected
                      ? Icons.bluetooth_connected
                      : Icons.bluetooth_disabled,
                  color:
                      bluetoothProvider.isConnected ? Colors.green : Colors.red,
                ),
                onPressed: () {
                  if (!bluetoothProvider.isConnected) {
                    Navigator.pushReplacementNamed(context, '/bluetooth');
                  }
                },
              );
            },
          ),
        ],
      ),
      body: Consumer2<BluetoothProvider, RobotControlProvider>(
        builder: (context, bluetoothProvider, robotProvider, child) {
          if (!bluetoothProvider.isConnected) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.bluetooth_disabled,
                    size: 80,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Bluetooth Not Connected',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please connect to Bluetooth from the home screen to use manual control',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Go Back'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Status Section
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Robot Status',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                    'State: ${robotProvider.status.stateText}'),
                                Text(
                                    'Vacuum: ${robotProvider.status.vacuumActive ? "On" : "Off"}'),
                                Text(
                                    'Mop: ${robotProvider.status.mopActive ? "On" : "Off"}'),
                                Text(
                                    'Pump: ${robotProvider.status.pumpActive ? "On" : "Off"}'),
                                Text('Robot: ${_isRobotOn ? "On" : "Off"}'),
                              ],
                            ),
                            Column(
                              children: [
                                // Start/Stop Toggle
                                ElevatedButton(
                                  onPressed: () async {
                                    setState(() {
                                      _isRobotOn = !_isRobotOn;
                                    });

                                    if (_isRobotOn) {
                                      // Start robot
                                      await robotProvider
                                          .setManualMode(bluetoothProvider);
                                    } else {
                                      // Stop robot
                                      await robotProvider
                                          .stopRobot(bluetoothProvider);
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        _isRobotOn ? Colors.red : Colors.green,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: Text(_isRobotOn ? 'STOP' : 'START'),
                                ),
                                const SizedBox(height: 8),
                                // Connection Status with Signal Strength
                                Row(
                                  children: [
                                    Icon(
                                      Icons.signal_cellular_4_bar,
                                      color: bluetoothProvider.isConnected
                                          ? Colors.green
                                          : Colors.red,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      bluetoothProvider.isConnected
                                          ? 'Strong'
                                          : 'Disconnected',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: bluetoothProvider.isConnected
                                            ? Colors.green
                                            : Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Feature Controls Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Column(
                              children: [
                                Switch(
                                  value: robotProvider.status.vacuumActive,
                                  onChanged: (value) async {
                                    if (!bluetoothProvider.isConnected) {
                                      _showToast('Connect to Bluetooth first!',
                                          isError: true);
                                      return;
                                    }
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
                                const Text('Vacuum',
                                    style: TextStyle(fontSize: 12)),
                              ],
                            ),
                            Column(
                              children: [
                                Switch(
                                  value: robotProvider.status.mopActive,
                                  onChanged: (value) async {
                                    if (!bluetoothProvider.isConnected) {
                                      _showToast('Connect to Bluetooth first!',
                                          isError: true);
                                      return;
                                    }
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
                                const Text('Mop',
                                    style: TextStyle(fontSize: 12)),
                              ],
                            ),
                            Column(
                              children: [
                                Switch(
                                  value: robotProvider.status.pumpActive,
                                  onChanged: (value) async {
                                    if (!bluetoothProvider.isConnected) {
                                      _showToast('Connect to Bluetooth first!',
                                          isError: true);
                                      return;
                                    }
                                    bool success = await robotProvider
                                        .togglePump(bluetoothProvider);
                                    _showToast(
                                      success
                                          ? (robotProvider.status.pumpActive
                                              ? "Pump activated!"
                                              : "Pump deactivated!")
                                          : 'Failed to toggle pump',
                                      isSuccess: success,
                                      isError: !success,
                                    );
                                  },
                                ),
                                const Text('Water Pump',
                                    style: TextStyle(fontSize: 12)),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Control Pad
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Forward Button
                      _buildControlButton(
                        icon: Icons.keyboard_arrow_up,
                        label: 'Forward',
                        onPressed: () => _sendMovementCommand(
                            RobotCommands.forward,
                            robotProvider,
                            bluetoothProvider),
                      ),

                      const SizedBox(height: 16),

                      // Left, Stop, Right Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildControlButton(
                            icon: Icons.keyboard_arrow_left,
                            label: 'Left',
                            onPressed: () => _sendMovementCommand(
                                RobotCommands.left,
                                robotProvider,
                                bluetoothProvider),
                          ),
                          _buildControlButton(
                            icon: Icons.stop,
                            label: 'Stop',
                            color: Colors.red,
                            onPressed: () => _sendMovementCommand(
                                RobotCommands.stop,
                                robotProvider,
                                bluetoothProvider),
                          ),
                          _buildControlButton(
                            icon: Icons.keyboard_arrow_right,
                            label: 'Right',
                            onPressed: () => _sendMovementCommand(
                                RobotCommands.right,
                                robotProvider,
                                bluetoothProvider),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Backward Button
                      _buildControlButton(
                        icon: Icons.keyboard_arrow_down,
                        label: 'Backward',
                        onPressed: () => _sendMovementCommand(
                            RobotCommands.backward,
                            robotProvider,
                            bluetoothProvider),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Emergency Stop - Only visible when robot is on
                if (_isRobotOn)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        await robotProvider.emergencyStop(bluetoothProvider);
                        setState(() {
                          _isRobotOn = false;
                        });
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Emergency stop activated'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.emergency),
                          SizedBox(width: 8),
                          Text('EMERGENCY STOP',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    Color? color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton(
          onPressed: _isCommandInProgress
              ? null
              : () {
                  // Prevent rapid button presses
                  if (_lastCommandTime != null &&
                      DateTime.now()
                              .difference(_lastCommandTime!)
                              .inMilliseconds <
                          200) {
                    return;
                  }
                  _lastCommandTime = DateTime.now();
                  onPressed();
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: color ?? Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(24),
            elevation: 4,
          ),
          child: Icon(
            icon,
            size: 36,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Future<void> _sendMovementCommand(
    String command,
    RobotControlProvider robotProvider,
    BluetoothProvider bluetoothProvider,
  ) async {
    if (_isCommandInProgress) return;

    if (!bluetoothProvider.isConnected) {
      _showToast('Connect to Bluetooth first!', isError: true);
      return;
    }

    setState(() {
      _isCommandInProgress = true;
    });

    bool success =
        await robotProvider.sendMovementCommand(command, bluetoothProvider);

    setState(() {
      _isCommandInProgress = false;
    });

    if (success) {
      String commandName = _getCommandName(command);
      _showToast('$commandName command sent!', isSuccess: true);
    } else {
      _showToast('Failed to send movement command!', isError: true);
    }
  }

  String _getCommandName(String command) {
    if (command == RobotCommands.forward) {
      return 'Forward';
    } else if (command == RobotCommands.backward) {
      return 'Backward';
    } else if (command == RobotCommands.left) {
      return 'Left';
    } else if (command == RobotCommands.right) {
      return 'Right';
    } else if (command == RobotCommands.stop) {
      return 'Stop';
    } else {
      return 'Movement';
    }
  }
}
