import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../api_client.dart';
import '../firestore_service.dart';

class SensorsPage extends StatefulWidget {
  final ApiClient apiClient;


  const SensorsPage({super.key, required this.apiClient});


  @override
  State<SensorsPage> createState() => _SensorsPageState();
}

class _SensorsPageState extends State<SensorsPage> {
  late Future<CurrentSensors> _future;
  final fs = FirestoreService.instance;

  Timer? _timer;
  bool _isFetching = false;
  static const int intervalDB = 60;

  @override
  void initState() {
    super.initState();
    Timer? _timer_db = Timer.periodic(const Duration(seconds: intervalDB), (timer) {
      registerDB();
    });
    _refresh();

    // Rafraîchit toutes les 1 seconde, mais seulement si on n'est pas déjà
    // en train de faire une requête.
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_isFetching) return; // on attend que la requête précédente finisse
      _refresh();
    });




  }

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
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _refresh() {
    _isFetching = true;
    setState(() {
      _future = widget.apiClient.fetchCurrentSensors().then((data) async {
        _isFetching = false;
        return data;
      }).catchError((e) {
        _isFetching = false;
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
                      'Donnees de nos capteurs en temps reel',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    SizedBox(height: 50,),
                    Container(
                        child: Row(children: [ Text(
                          'Luminosite : ${data.light.toStringAsFixed(1)} %',
                        ),
                          SizedBox(width: 150,),
                          Container(child: Row(children: [Icon(
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
                            ),],),),],)


                    ),
                    const SizedBox(height: 50),
                    Container(
                      child: Text(
                        'Temperature : ${data.temperature.toStringAsFixed(1)} °C',
                      ),
                    ),

                    const SizedBox(height: 24),
                    const Text(
                      'Couleur de led RGB',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 10,
                      child: _TempColorPreview(tempC: data.temperature),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

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
        height: 10.0,
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: Colors.black12),
        ),
        alignment: Alignment.center,
        child: Text("")
    );
  }
}
