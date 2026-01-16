// lib/main.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'api_client.dart';
import 'firestore_service.dart';

import 'pages/stats_screen.dart';
import 'pages/leds_screen.dart';
import 'pages/temps_reel.dart';
import 'pages/seuils_screen.dart';
import 'widgets/bottom_nav.dart';



void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(TTGODashboardApp());
}

class TTGODashboardApp extends StatelessWidget {
  const TTGODashboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    final apiClient = ApiClient(
      // émulateur Android -> 10.0.2.2
      // téléphone physique -> IP de l'ESP32, ex: http://192.168.1.42/api
      baseUrl: 'http://10.246.119.175/api',
    );

    return MaterialApp(
      title: 'TTGO Dashboard',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
      ),
      home: MainScaffold(apiClient: apiClient),
    );
  }
}

class MainScaffold extends StatefulWidget {
  final ApiClient apiClient;

  const MainScaffold({super.key, required this.apiClient});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _index = 0;
  final fs = FirestoreService.instance;
  static const int intervalDB = 60;
  bool _isFetching = false;
  Timer? _timer_db;

  void registerDB() async {
    if (!mounted || _isFetching) return;

    setState(() {
      _isFetching = true;
    });

    try {
      final data = await widget.apiClient.fetchCurrentSensors();
      await fs.logReading(data);

      print("Données enregistrées avec succès");
    } catch (e) {
      print("Erreur lors de registerDB : $e");
    } finally {
      if (mounted) {
        setState(() {
          _isFetching = false;
        });
      }
    }
  }


  @override
  void initState() {
    super.initState();
    _timer_db = Timer.periodic(const Duration(seconds: intervalDB), (timer) {
      registerDB();
    });
  }

  @override
  void dispose() {
    _timer_db?.cancel();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    final pages = [
      SensorsPage(apiClient: widget.apiClient),
      LedControlScreen(apiClient: widget.apiClient),
      ThresholdsPage(apiClient: widget.apiClient),
      StatisticsScreen(apiClient: widget.apiClient),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('TTGO T-Display Dashboard'),
        centerTitle: true,
      ),
      body: pages[_index],
      bottomNavigationBar: BottomNavBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}