// lib/main.dart
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
//import 'package:firebase_core/firebase_core.dart';

import 'api_client.dart';
import 'firestore_service.dart';

// TODO: après avoir fait `flutterfire configure`,
// importe ton fichier firebase_options.dart ici et utilise
// DefaultFirebaseOptions.currentPlatform.

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  //await Firebase.initializeApp();
  runApp(const TTGODashboardApp());
}

class TTGODashboardApp extends StatelessWidget {
  const TTGODashboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    final apiClient = ApiClient(
      // émulateur Android -> 10.0.2.2
      // téléphone physique -> IP de l'ESP32, ex: http://192.168.1.42/api
      baseUrl: 'http://10.106.12.175/api',
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

  @override
  Widget build(BuildContext context) {
    final pages = [
      SensorsPage(apiClient: widget.apiClient),
      LedControlPage(apiClient: widget.apiClient),
      ThresholdsPage(apiClient: widget.apiClient),
      //StatsPage(apiClient: widget.apiClient),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('TTGO T-Display Dashboard'),
        centerTitle: true,
      ),
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.sensors),
            label: 'Capteurs',
          ),
          NavigationDestination(
            icon: Icon(Icons.lightbulb),
            label: 'LED & Couleurs',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune),
            label: 'Seuils',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics),
            label: 'Statistiques',
          ),
        ],
      ),
    );
  }
}

//
// Onglet 1 – Capteurs
//

class SensorsPage extends StatefulWidget {
  final ApiClient apiClient;

  const SensorsPage({super.key, required this.apiClient});

  @override
  State<SensorsPage> createState() => _SensorsPageState();
}

class _SensorsPageState extends State<SensorsPage> {
  late Future<CurrentSensors> _future;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _future = widget.apiClient.fetchCurrentSensors().then((data) async {
        // On enregistre chaque lecture dans Firestore (persistance)
        //await FirestoreService.instance.logReading(data);
        return data;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => _refresh(),
      child: FutureBuilder<CurrentSensors>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return ListView(
              children: [
                SizedBox(
                  height: 200,
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
            );
          }
          if (snapshot.hasError) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Erreur: ${snapshot.error}'),
              ],
            );
          }

          final data = snapshot.data!;
          final jsonRaw = jsonEncode({
            'temperature': data.temperature,
            'light': data.light,
            'ledIndicatorOn': data.ledIndicatorOn,
          });
          final prettyJson =
          const JsonEncoder.withIndent('  ').convert(jsonDecode(jsonRaw));

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Valeurs des résistances',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Chip(
                            avatar: const Icon(Icons.thermostat),
                            label: Text(
                              '${data.temperature.toStringAsFixed(1)} °C',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Chip(
                            avatar: const Icon(Icons.light_mode),
                            label: Text(
                              '${data.light.toStringAsFixed(1)} %',
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.circle,
                            size: 12,
                            color: data.ledIndicatorOn
                                ? Colors.green
                                : Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            data.ledIndicatorOn ? 'LED ON' : 'LED OFF',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Mini “chart” température (simulation)',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 60,
                        child: CustomPaint(
                          painter: _MiniBarPainter(value: data.temperature),
                          child: Container(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: ExpansionTile(
                  title: const Text('Voir JSON brut (pretty)'),
                  childrenPadding: const EdgeInsets.all(16),
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Text(
                        prettyJson,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Un tout petit "chart" juste pour avoir un visuel.
class _MiniBarPainter extends CustomPainter {
  final double value;

  _MiniBarPainter({required this.value});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.blue;

    // on mappe -10..60°C à 0..1
    final clamped = value.clamp(-10, 60);
    final ratio = (clamped + 10) / 70;
    final barHeight = size.height * ratio;

    final rect = Rect.fromLTWH(
      0,
      size.height - barHeight,
      size.width,
      barHeight,
    );
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant _MiniBarPainter oldDelegate) =>
      oldDelegate.value != value;
}

//
// Onglet 2 – LED & Couleurs
//

class LedControlPage extends StatefulWidget {
  final ApiClient apiClient;

  const LedControlPage({super.key, required this.apiClient});

  @override
  State<LedControlPage> createState() => _LedControlPageState();
}

class _LedControlPageState extends State<LedControlPage> {
  bool _blueLinked = false;
  bool _redLinked = false;
  double _hue = 0; // 0..360 pour la roue de couleur

  Future<void> _toggleBlue(bool value) async {
    setState(() => _blueLinked = value);
    try {
      await widget.apiClient.setBlueLinkedToLight(value);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }

  Future<void> _toggleRed(bool value) async {
    setState(() => _redLinked = value);
    try {
      await widget.apiClient.setRedLinkedToTemp(value);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }

  Future<void> _sendColor() async {
    // conversion H -> RGB simple (teinte uniquement)
    final h = _hue;
    final c = 1.0;
    final x = c * (1 - ((h / 60) % 2 - 1).abs());
    double r = 0, g = 0, b = 0;

    if (h < 60) {
      r = c;
      g = x;
    } else if (h < 120) {
      r = x;
      g = c;
    } else if (h < 180) {
      g = c;
      b = x;
    } else if (h < 240) {
      g = x;
      b = c;
    } else if (h < 300) {
      r = x;
      b = c;
    } else {
      r = c;
      b = x;
    }

    final ir = (r * 255).round();
    final ig = (g * 255).round();
    final ib = (b * 255).round();

    try {
      await widget.apiClient.setLedColorRgb(ir, ig, ib);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Couleur envoyée: R$ir G$ig B$ib')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = HSVColor.fromAHSV(1, _hue, 1, 1).toColor();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.light_mode),
                title: const Text('Lien LED bleue / lumière'),
                subtitle:
                const Text('Active le mode auto sur la lumière'),
                trailing: Switch(
                  value: _blueLinked,
                  onChanged: _toggleBlue,
                ),
              ),
              const Divider(height: 0),
              ListTile(
                leading: const Icon(Icons.thermostat),
                title: const Text('Lien LED rouge / température'),
                subtitle:
                const Text('Active le mode auto sur la température'),
                trailing: Switch(
                  value: _redLinked,
                  onChanged: _toggleRed,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Roue de couleur LED RGB',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(
                        colors: List.generate(
                          13,
                              (i) => HSVColor.fromAHSV(
                            1,
                            i * 30.0,
                            1,
                            1,
                          ).toColor(),
                        ),
                      ),
                    ),
                    child: Center(
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Slider(
                  min: 0,
                  max: 360,
                  value: _hue,
                  onChanged: (v) => setState(() => _hue = v),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _sendColor,
                  icon: const Icon(Icons.send),
                  label: const Text('Envoyer la couleur à la LED'),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Pour l’instant, la couleur est approximée vers R/G/B '
                      'selon la composante dominante (en attendant une route '
                      '/api/ledrgb/color complète côté ESP).',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

//
// Onglet 3 – Seuils lumière & chaud/froid
//

class ThresholdsPage extends StatefulWidget {
  final ApiClient apiClient;

  const ThresholdsPage({super.key, required this.apiClient});

  @override
  State<ThresholdsPage> createState() => _ThresholdsPageState();
}

class _ThresholdsPageState extends State<ThresholdsPage> {
  late Future<Thresholds?> _future;
  double? _light;
  double? _tempCold;
  double? _tempHot;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Thresholds?> _load() async {
    // 1) on tente Firestore
    //final fs = await FirestoreService.instance.getThresholdsFromFirestore();
    //if (fs != null) return fs;

    // 2) si l’API ESP est prête, tu peux aussi faire :
    //return await widget.apiClient.fetchThresholdsFromApi();

    // 3) sinon, valeurs par défaut
    return Thresholds(
      lightThreshold: 30,
      tempColdThreshold: 18,
      tempHotThreshold: 26,
    );
  }

  Future<void> _save() async {
    if (_light == null || _tempCold == null || _tempHot == null) return;
    final t = Thresholds(
      lightThreshold: _light!,
      tempColdThreshold: _tempCold!,
      tempHotThreshold: _tempHot!,
    );
    setState(() => _saving = true);
    try {
      // on stocke dans Firestore (pour stats + persistance)
      //await FirestoreService.instance.saveThresholdsToFirestore(t);
      // et plus tard, quand tu auras la route ESP :
      // await widget.apiClient.updateThresholdsToApi(t);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Seuils enregistrés')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Thresholds?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            _light == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError && _light == null) {
          return Center(child: Text('Erreur: ${snapshot.error}'));
        }

        final t = snapshot.data;
        _light ??= t?.lightThreshold ?? 30;
        _tempCold ??= t?.tempColdThreshold ?? 18;
        _tempHot ??= t?.tempHotThreshold ?? 26;

        // garantie tempCold <= tempHot
        if (_tempCold! > _tempHot!) {
          final mid = (_tempCold! + _tempHot!) / 2;
          _tempCold = mid - 1;
          _tempHot = mid + 1;
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Seuils de lumière & chaud/froid',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Text(
              'Seuil lumière : ${_light!.toStringAsFixed(1)} %',
            ),
            Slider(
              min: 0,
              max: 100,
              value: _light!,
              onChanged: (v) => setState(() => _light = v),
            ),
            const SizedBox(height: 24),
            Text(
              'Zone “froid” / “chaud” (température)',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Froid en-dessous de ${_tempCold!.toStringAsFixed(1)} °C,\n'
                  'Chaud au-dessus de ${_tempHot!.toStringAsFixed(1)} °C',
            ),
            const SizedBox(height: 8),
            const Text('Seuil froid'),
            Slider(
              min: -10,
              max: 40,
              value: _tempCold!,
              onChanged: (v) => setState(() {
                _tempCold = min(v, _tempHot! - 0.5);
              }),
            ),
            const Text('Seuil chaud'),
            Slider(
              min: -10,
              max: 60,
              value: _tempHot!,
              onChanged: (v) => setState(() {
                _tempHot = max(v, _tempCold! + 0.5);
              }),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Icon(Icons.save),
              label: const Text('Enregistrer'),
            ),
            const SizedBox(height: 16),
            const Text(
              'Ces seuils pourront être utilisés par le firmware ESP32 pour '
                  'choisir la couleur de la LED RGB (bleu = froid, rouge = chaud, '
                  'autre couleur entre les deux), et par l’application pour la '
                  'visualisation et le debug.',
            ),
          ],
        );
      },
    );
  }
}

//
// Onglet 4 – Statistiques & localisation
//
/*
class StatsPage extends StatelessWidget {
  final ApiClient apiClient;

  const StatsPage({super.key, required this.apiClient});

  @override
  Widget build(BuildContext context) {
    //final fs = FirestoreService.instance;

    return FutureBuilder<StatsResult>(
      //future: fs.computeStats(),
      builder: (context, statsSnap) {
        if (statsSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (statsSnap.hasError) {
          return Center(child: Text('Erreur stats: ${statsSnap.error}'));
        }
        final stats = statsSnap.data!;


        return FutureBuilder<List<SensorLocation>>(
          future: fs.getSensorLocations(),
          builder: (context, locSnap) {
            if (locSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (locSnap.hasError) {
              return Center(child: Text('Erreur localisation: ${locSnap.error}'));
            }
            final locations = locSnap.data ?? [];

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Statistiques d’usage',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        Chip(
                          avatar: const Icon(Icons.storage),
                          label: Text(
                              'Mesures stockées: ${stats.totalReadings}'),
                        ),
                        Chip(
                          avatar: const Icon(Icons.thermostat),
                          label: Text(
                            'Temp moyenne: ${stats.avgTemperature.toStringAsFixed(1)} °C',
                          ),
                        ),
                        Chip(
                          avatar: const Icon(Icons.light_mode),
                          label: Text(
                            'Lumière moyenne: ${stats.avgLight.toStringAsFixed(1)} %',
                          ),
                        ),
                        Chip(
                          avatar: const Icon(Icons.access_time),
                          label: Text(
                            stats.lastReading == null
                                ? 'Dernière mesure: N/A'
                                : 'Dernière mesure: ${stats.lastReading}',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Localisation des capteurs',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (locations.isEmpty)
                  const Text(
                    'Aucun capteur localisé dans Firestore.\n'
                        'Ajoute des documents dans la collection "sensors" '
                        'avec sensorId, location, lat, lng, lastSeen.',
                  )
                else
                  Card(
                    child: Column(
                      children: locations.map((loc) {
                        return ListTile(
                          leading: const Icon(Icons.sensors),
                          title: Text('${loc.name} (${loc.sensorId})'),
                          subtitle: Text(
                            '${loc.location}\n'
                                'Coordonnées: ${loc.lat ?? "?"}, ${loc.lng ?? "?"}\n'
                                'Dernière activité: ${loc.lastSeen ?? "?"}',
                          ),
                          isThreeLine: true,
                        );
                      }).toList(),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}
*/