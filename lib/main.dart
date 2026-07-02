import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:geofence_service/geofence_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart' as geo;

const double jobbLatitude = 69.684218;
const double jobbLongitude = 18.973769;
const double jobbRadiusMeters = 300.0;

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const AndroidInitializationSettings androidInit =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const DarwinInitializationSettings iosInit = DarwinInitializationSettings();

  const InitializationSettings initializationSettings = InitializationSettings(
    android: androidInit,
    iOS: iosInit,
  );

  await flutterLocalNotificationsPlugin.initialize(
    settings: initializationSettings,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
      ?.requestPermissions(alert: true, badge: true, sound: true);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) => const MaterialApp(home: HomeScreen());
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool monitoring = false;
  Geofence? jobbGeofence; // Endret til nullable for å unngå tidlig minne-konflikt

  @override
  void initState() {
    super.initState();
    // Vi initialiserer geofencen trygt i minnet
    jobbGeofence = Geofence(
      id: 'jobb_zone',
      latitude: jobbLatitude,
      longitude: jobbLongitude,
      radius: [GeofenceRadius(id: 'r', length: jobbRadiusMeters)],
    );
  }

  Future<void> _sendLocalNotification(String title, String body) async {
    const androidDetails = AndroidNotificationDetails(
      'parkering_channel',
      'Parkering-varsler',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'default',
    );

    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await flutterLocalNotificationsPlugin.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }

  Future<void> _startMonitoring() async {
    var perm = await geo.Geolocator.checkPermission();
    if (perm == geo.LocationPermission.denied) {
      perm = await geo.Geolocator.requestPermission();
      if (perm == geo.LocationPermission.denied) return;
    }
    
    if (!await geo.Geolocator.isLocationServiceEnabled()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Slå på posisjonstjenester først')));
      return;
    }

    setState(() => monitoring = true);

    geo.Geolocator.getPositionStream(
      locationSettings: const geo.LocationSettings(
        accuracy: geo.LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((geo.Position position) async {
      if (!monitoring) return;
      
      double distanceInMeters = geo.Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        jobbLatitude,
        jobbLongitude,
      );

      if (distanceInMeters <= jobbRadiusMeters) {
        await _sendLocalNotification('Du er ved jobb', 'Husk å starte parkering og betaling');
        _stopMonitoring();
      }
    });
  }

  Future<void> _stopMonitoring() async {
    if (!mounted) return;
    setState(() => monitoring = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Parkeringsvarsler')),
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(monitoring ? 'Overvåkning aktiv' : 'Overvåkning stoppet'),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: monitoring ? _stopMonitoring : _startMonitoring,
            child: Text(monitoring ? 'Stopp overvåkning' : 'Start overvåkning'),
          ),
        ]),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await _sendLocalNotification('Testvarsel', 'Dette er et testvarsel');
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Testvarsel sendt')));
        },
        child: const Icon(Icons.notification_add),
      ),
    );
  }
}
