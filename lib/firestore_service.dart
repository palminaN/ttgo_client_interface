// lib/firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'api_client.dart';

class FirestoreService {
  FirestoreService._();
  static final instance = FirestoreService._();

  final _db = FirebaseFirestore.instance;

  /// Enregistre une mesure dans la collection "readings".
  Future<void> logReading(CurrentSensors data) async {
    await _db.collection('readings').add({
      'temperature': data.temperature,
      'light': data.light,
      'ledIndicatorOn': data.ledIndicatorOn,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Statistiques simples calculées côté client
  /// (sur toutes les mesures ou les N dernières).
  Future<StatsResult> computeStats() async {
    final query = await _db
        .collection('readings')
        .orderBy('timestamp', descending: true)
        .limit(200) // évite de charger tout Firestore
        .get();

    if (query.docs.isEmpty) {
      return StatsResult.empty();
    }

    double sumTemp = 0;
    double sumLight = 0;
    int count = 0;
    DateTime? lastTs;

    for (final doc in query.docs) {
      final data = doc.data();
      final t = (data['temperature'] as num).toDouble();
      final l = (data['light'] as num).toDouble();
      sumTemp += t;
      sumLight += l;
      count++;

      final ts = (data['timestamp'] as Timestamp?)?.toDate();
      if (ts != null) {
        lastTs ??= ts;
        if (ts.isAfter(lastTs!)) lastTs = ts;
      }
    }

    return StatsResult(
      totalReadings: count,
      avgTemperature: sumTemp / count,
      avgLight: sumLight / count,
      lastReading: lastTs,
    );
  }

  /// Liste des capteurs avec localisation (collection "sensors").
  /// Documents attendus :
  /// { "sensorId": "ttgo-1", "name": "Capteur bureau",
  ///   "location": "Bureau", "lat": 48.8566, "lng": 2.3522,
  ///   "lastSeen": Timestamp(...) }
  Future<List<SensorLocation>> getSensorLocations() async {
    final query = await _db.collection('sensors').get();
    return query.docs.map((doc) {
      final data = doc.data();
      return SensorLocation(
        sensorId: data['sensorId']?.toString() ?? doc.id,
        name: data['name']?.toString() ?? 'Capteur',
        location: data['location']?.toString() ?? '',
        lat: (data['lat'] as num?)?.toDouble(),
        lng: (data['lng'] as num?)?.toDouble(),
        lastSeen: (data['lastSeen'] as Timestamp?)?.toDate(),
      );
    }).toList();
  }

  /// Seuils dans Firestore (collection "config", doc "thresholds")
  Future<Thresholds?> getThresholdsFromFirestore() async {
    final doc =
    await _db.collection('config').doc('thresholds').get();
    if (!doc.exists) return null;
    final data = doc.data()!;
    return Thresholds(
      lightThreshold:
      (data['light_threshold'] as num).toDouble(),
      tempColdThreshold:
      (data['temp_cold_threshold'] as num).toDouble(),
      tempHotThreshold:
      (data['temp_hot_threshold'] as num).toDouble(),
    );
  }

  Future<void> saveThresholdsToFirestore(Thresholds t) async {
    await _db.collection('config').doc('thresholds').set(
      t.toJson(),
      SetOptions(merge: true),
    );
  }
}

/// Modèle de stats calculées.
class StatsResult {
  final int totalReadings;
  final double avgTemperature;
  final double avgLight;
  final DateTime? lastReading;

  StatsResult({
    required this.totalReadings,
    required this.avgTemperature,
    required this.avgLight,
    required this.lastReading,
  });

  factory StatsResult.empty() => StatsResult(
    totalReadings: 0,
    avgTemperature: 0,
    avgLight: 0,
    lastReading: null,
  );
}

/// Modèle de capteur localisé.
class SensorLocation {
  final String sensorId;
  final String name;
  final String location;
  final double? lat;
  final double? lng;
  final DateTime? lastSeen;

  SensorLocation({
    required this.sensorId,
    required this.name,
    required this.location,
    required this.lat,
    required this.lng,
    required this.lastSeen,
  });
}
