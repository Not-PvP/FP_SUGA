import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/power_interruption_provider.dart';
import 'routes/app_routes.dart';
import 'services/notification_service.dart';

// Lets a tapped phone notification open a screen from outside the widget tree.
final navigatorKey = GlobalKey<NavigatorState>();
final notificationService = NotificationService();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  notificationService.onTap = _openFromNotification;
  runApp(const MyApp());
}

// The payload of every SUGA notification is the advisory id.
Future<void> _openFromNotification(String advisoryId) async {
  final context = navigatorKey.currentContext;
  if (context == null) {
    // Tapped before the app finished starting: try again after the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => _openFromNotification(advisoryId));
    return;
  }
  final advisories = context.read<PowerInterruptionProvider>();
  if (!advisories.hasLoaded) await advisories.loadInterruptions();
  final advisory = advisories.findById(advisoryId);
  final navigator = navigatorKey.currentState;
  if (navigator == null) return;
  if (advisory != null) {
    navigator.pushNamed(AppRoutes.brownoutDetails, arguments: advisory);
  } else {
    navigator.pushNamed(AppRoutes.notifications);
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Providers above MaterialApp are shared by every screen and route.
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..restoreSession()),
        // Rebuilt whenever AuthProvider changes, so admin requests always carry the
        // current session token, and a 401 from the server signs the admin out.
        ChangeNotifierProxyProvider<AuthProvider, PowerInterruptionProvider>(
          create: (_) => PowerInterruptionProvider(),
          update: (_, auth, interruptions) => interruptions!
            ..authToken = auth.token
            ..onUnauthorized = auth.handleUnauthorized,
        ),
        // Follows the advisories and saved areas to build alerts and phone reminders.
        ChangeNotifierProxyProvider<PowerInterruptionProvider, NotificationProvider>(
          create: (_) => NotificationProvider(device: notificationService)..load(),
          update: (_, advisories, notifications) => notifications!..updateFrom(advisories),
        ),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        title: 'SUGA',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          fontFamily: 'PlusJakartaSans',
        ),
        routes: AppRoutes.routes,
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
