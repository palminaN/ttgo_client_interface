
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../api_client.dart';

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
          padding: const EdgeInsets.all(20),
          children: [Center(
              child: const Text(
                'Reglage des seuils',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              )),

            const SizedBox(height: 48),
            const Text(
              'Seuils de temperature de la thermistance',
              style: TextStyle(fontSize: 16,fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Text('Seuil froid : ${_tempCold!.toStringAsFixed(1)} °C,\n',style: TextStyle(fontWeight: FontWeight.bold),),
            Slider(
              activeColor: Colors.black,
              inactiveColor: Colors.black,
              min: -10,
              max: 40,
              value: _tempCold!,
              onChanged: (v) => setState(() {
                _tempCold = min(v, _tempHot! - 0.5);
              }),
            ),
            Text('Seuil chaud : ${_tempHot!.toStringAsFixed(1)} °C',style:TextStyle(fontWeight: FontWeight.bold),),

            Slider(
              activeColor: Colors.black,
              inactiveColor: Colors.black,
              min: -10,
              max: 60,
              value: _tempHot!,
              onChanged: (v) => setState(() {
                _tempHot = max(v, _tempCold! + 0.5);
              }),
            ),
            const SizedBox(height: 48),
            Text('Seuil de luminosité de la photoresistance : ${_light!.toStringAsFixed(1)} %',style: TextStyle(fontSize: 16,fontWeight: FontWeight.bold),),
            const SizedBox(height: 24),
            Slider(
              activeColor: Colors.black,
              inactiveColor: Colors.black,
              min: 0,
              max: 100,
              value: _light!,
              onChanged: (v) => setState(() => _light = v),
            ),
            const SizedBox(height: 72,),
            FilledButton.icon(
              style:ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadiusGeometry.all(Radius.zero),
                ),
                foregroundColor: Colors.white,
                backgroundColor: Colors.black,
                minimumSize: const Size(120, 40),
              ),
              onPressed: _saving ? null : _save,

              label: const Text('Valider'),
            ),
          ],
        );
      },
    );
  }
}

