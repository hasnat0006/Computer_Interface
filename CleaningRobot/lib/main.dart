import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'providers/bluetooth_provider.dart';
import 'providers/robot_control_provider.dart';
import 'providers/schedule_provider.dart';
import 'models/schedule.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/manual_control_screen.dart';
import 'screens/schedule_screen.dart';
import 'screens/schedule_history_screen.dart';
import 'utils/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive
  await Hive.initFlutter();

  // Register Hive adapters
  Hive.registerAdapter(ScheduleAdapter());
  Hive.registerAdapter(CleaningModeAdapter());

  // Open Hive boxes
  await Hive.openBox<Schedule>('schedules');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BluetoothProvider()),
        ChangeNotifierProvider(create: (_) => RobotControlProvider()),
        ChangeNotifierProvider(create: (_) => ScheduleProvider()),
      ],
      child:
          Consumer3<BluetoothProvider, RobotControlProvider, ScheduleProvider>(
        builder: (context, bluetoothProvider, robotProvider, scheduleProvider,
            child) {
          // Set up the response callback for JSON data processing
          bluetoothProvider
              .setResponseCallback(robotProvider.parseRobotResponse);

          // Set up providers for automatic schedule execution
          ScheduleProvider.setProviders(bluetoothProvider, robotProvider);

          return MaterialApp(
            title: 'Cleaning Robot Controller',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.system,
            debugShowCheckedModeBanner: false,
            initialRoute: '/',
            onGenerateRoute: (settings) {
              switch (settings.name) {
                case '/':
                  return MaterialPageRoute(
                      builder: (_) => const SplashScreen());
                case '/home':
                  return MaterialPageRoute(builder: (_) => const HomeScreen());
                case '/manual-control':
                  return MaterialPageRoute(
                      builder: (_) => const ManualControlScreen());
                case '/schedule':
                  return MaterialPageRoute(
                      builder: (_) => const ScheduleScreen());
                case '/schedule-history':
                  return MaterialPageRoute(
                      builder: (_) => const ScheduleHistoryScreen());
                default:
                  return MaterialPageRoute(
                    builder: (_) => const Scaffold(
                      body: Center(child: Text('Page not found')),
                    ),
                  );
              }
            },
          );
        },
      ),
    );
  }
}
