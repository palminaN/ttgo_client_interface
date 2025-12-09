// lib/main.dart
import 'dart:convert';
import 'dart:math';
import 'dart:async';

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
  Timer? _timer;
  bool _isFetching = false;

  @override
  void initState() {
    super.initState();
    _refresh();

    // Rafraîchit toutes les 1 seconde, mais seulement si on n'est pas déjà
    // en train de faire une requête.
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_isFetching) return; // on attend que la requête précédente finisse
      _refresh();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _refresh() {
    _isFetching = true;
    setState(() {
      _future = widget.apiClient.fetchCurrentSensors().then((data) async {
        // Si tu remets Firestore plus tard :
        // await FirestoreService.instance.logReading(data);
        _isFetching = false;
        return data;
      }).catchError((e) {
        _isFetching = false;
        // on relance l'erreur pour que FutureBuilder l'affiche
        throw e;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CurrentSensors>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
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
                      'Couleur théorique de la LED RGB (température)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 60,
                      child: _TempColorPreview(tempC: data.temperature),
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
    );
  }
}

Color tempToRgbColor(double tempC,
    {double cold = 18.0, double hot = 26.0}) {
  if (cold >= hot) {
    cold = 0;
    hot = 50;
  }

  if (tempC <= cold) {
    // FROID -> BLEU
    return Colors.blue;
  } else if (tempC >= hot) {
    // CHAUD -> ROUGE
    return Colors.red;
  } else {
    // Entre les deux : dégradé bleu -> vert -> rouge
    final t = (tempC - cold) / (hot - cold); // 0..1

    if (t < 0.5) {
      // 0..0.5 => bleu -> vert
      final k = t / 0.5; // 0..1
      return Color.lerp(Colors.blue, Colors.green, k)!;
    } else {
      // 0.5..1 => vert -> rouge
      final k = (t - 0.5) / 0.5; // 0..1
      return Color.lerp(Colors.green, Colors.red, k)!;
    }
  }
}


class _TempColorPreview extends StatelessWidget {
  final double tempC;

  const _TempColorPreview({required this.tempC});

  @override
  Widget build(BuildContext context) {
    final color = tempToRgbColor(tempC);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: color,
        border: Border.all(color: Colors.black12),
      ),
      alignment: Alignment.center,
      child: Text(
        '${tempC.toStringAsFixed(1)} °C',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(offset: Offset(0, 0), blurRadius: 4),
          ],
        ),
      ),
    );
  }
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
  bool _rgbLightLinked = false;
  bool _rgbTempLinked = true; // par défaut, la RGB est liée à la température
  double _hue = 0; // 0..360 pour la roue de couleur

  Future<void> _toggleBlue(bool value) async {
    setState(() {
      _rgbLightLinked = value;
      if (value) {
        _rgbTempLinked = false; // exclusif : mode lumière => on coupe mode temp
      }
    });
    try {
      await widget.apiClient.setRGBLightMode(value);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur: $e')));
        // rollback visuel en cas d'erreur
        setState(() => _rgbLightLinked = !value);
      }
    }
  }

  Future<void> _toggleTemp(bool value) async {
    setState(() {
      _rgbTempLinked = value;
      if (value) {
        _rgbLightLinked = false; // exclusif : mode température => on coupe mode lumière
      }
    });
    try {
      await widget.apiClient.setRGBTempMode(value);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur: $e')));
        // rollback visuel
        setState(() => _rgbTempLinked = !value);
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

    // envoyer une couleur manuelle = sortir des modes auto
    setState(() {
      _rgbLightLinked = false;
      _rgbTempLinked = false;
    });

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
                title: const Text('Lien LED RGB / lumière'),
                subtitle: const Text(
                  'La LED RGB devient bleue plus ou moins forte selon la lumière.\n'
                      'La LED rouge séparée indique le dépassement de seuil.',
                ),
                trailing: Switch(
                  value: _rgbLightLinked,
                  onChanged: _toggleBlue,
                ),
              ),
              const Divider(height: 0),
              ListTile(
                leading: const Icon(Icons.thermostat),
                title: const Text('Lien LED RGB / température'),
                subtitle: const Text(
                  'La LED RGB affiche un dégradé froid → chaud en fonction de la température.',
                ),
                trailing: Switch(
                  value: _rgbTempLinked,
                  onChanged: _toggleTemp,
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
  late Future<Thresholds> _future;
  double? _light;
  double? _tempCold;
  double? _tempHot;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _future = widget.apiClient.fetchThresholdsFromApi();
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
      final updated = await widget.apiClient.updateThresholdsToApi(t);
      setState(() {
        _light = updated.lightThreshold;
        _tempCold = updated.tempColdThreshold;
        _tempHot = updated.tempHotThreshold;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Seuils mis à jour sur l\'ESP32')),
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
    return FutureBuilder<Thresholds>(
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

        // sécurité: cold <= hot
        if (_tempCold! > _tempHot!) {
          final mid = (_tempCold! + _tempHot!) / 2;
          _tempCold = mid - 1;
          _tempHot = mid + 1;
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Seuils de lumière & chaud/froid (ESP32)',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Text('Seuil lumière : ${_light!.toStringAsFixed(1)} %'),
            Slider(
              min: 0,
              max: 100,
              value: _light!,
              onChanged: (v) => setState(() => _light = v),
            ),
            const SizedBox(height: 24),
            const Text(
              'Zone “froid” / “chaud” (température)',
              style: TextStyle(fontWeight: FontWeight.bold),
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
              label: const Text('Enregistrer sur l\'ESP32'),
            ),
          ],
        );
      },
    );
  }
}


/*
//
// Onglet 4 – Statistiques & localisation
//

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
