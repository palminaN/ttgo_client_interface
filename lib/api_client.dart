// lib/api_client.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Mesure courante (température + lumière + LED indicateur)
class CurrentSensors {
  final double temperature;
  final double light;
  final bool ledIndicatorOn;

  CurrentSensors({
    required this.temperature,
    required this.light,
    required this.ledIndicatorOn,
  });
}

class RgbStatus {
  final bool lightLinked;
  final bool tempLinked;
  final String mode; // "manual" | "light" | "temp"

  RgbStatus({
    required this.lightLinked,
    required this.tempLinked,
    required this.mode,
  });
}

/// Seuils utilisés par le firmware (lumière + froid/chaud).
class Thresholds {
  final double lightThreshold;
  final double tempColdThreshold;
  final double tempHotThreshold;

  Thresholds({
    required this.lightThreshold,
    required this.tempColdThreshold,
    required this.tempHotThreshold,
  });

  factory Thresholds.fromJson(Map<String, dynamic> json) {
    return Thresholds(
      lightThreshold: (json['light_threshold'] as num).toDouble(),
      tempColdThreshold: (json['temp_cold_threshold'] as num).toDouble(),
      tempHotThreshold: (json['temp_hot_threshold'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'light_threshold': lightThreshold,
    'temp_cold_threshold': tempColdThreshold,
    'temp_hot_threshold': tempHotThreshold,
  };
}

/// Client HTTP pour ton ESP32 (routes /api/...).
class ApiClient {
  final String baseUrl;
  final http.Client _client;

  Future<RgbStatus> fetchRgbStatus() async {
    final uri = Uri.parse('$baseUrl/sensors');
    final response = await _client.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Erreur /api/sensors (${response.statusCode})');
    }

    final Map<String, dynamic> data =
    jsonDecode(response.body) as Map<String, dynamic>;
    final List<dynamic> sensors = data['sensors'] as List<dynamic>;

    bool lightLinked = false;
    bool tempLinked = false;
    String mode = 'manual';

    for (final s in sensors) {
      final obj = s as Map<String, dynamic>;
      final id = obj['id']?.toString();
      if (id == 'rgb_led') {
        lightLinked = obj['light_linked'] == true;
        tempLinked  = obj['temp_linked'] == true;

        if (obj['mode'] is String) {
          mode = obj['mode'] as String;
        } else {
          // fallback au cas où
          if (tempLinked) {
            mode = 'temp';
          } else if (lightLinked) {
            mode = 'light';
          } else {
            mode = 'manual';
          }
        }
        break;
      }
    }

    return RgbStatus(
      lightLinked: lightLinked,
      tempLinked: tempLinked,
      mode: mode,
    );
  }

  ApiClient({
    required this.baseUrl,
    http.Client? client,
  }) : _client = client ?? http.Client();

  /// Utilise GET /api/sensors pour récupérer toutes les infos.
  ///
  /// Réponse attendue (simplifiée) :
  /// {
  ///   "sensors": [
  ///     {"id": "temperature", "value": 23.5, ...},
  ///     {"id": "light", "value": 50.0, ...},
  ///     {"id": "led_indicator", "state": 1, ...}
  ///   ]
  /// }
  Future<CurrentSensors> fetchCurrentSensors() async {
    final uri = Uri.parse('$baseUrl/sensors');
    final response = await _client.get(uri);

    if (response.statusCode != 200) {
      throw Exception(
          'Erreur lors du chargement des capteurs (${response.statusCode})');
    }

    final Map<String, dynamic> data =
    jsonDecode(response.body) as Map<String, dynamic>;
    final List<dynamic> sensors = data['sensors'] as List<dynamic>;

    double? temp;
    double? light;
    bool ledOn = false;

    for (final s in sensors) {
      final obj = s as Map<String, dynamic>;
      final id = obj['id']?.toString();

      if (id == 'temperature') {
        temp = (obj['value'] as num).toDouble();
      } else if (id == 'light') {
        light = (obj['value'] as num).toDouble();
      } else if (id == 'led_indicator') {
        final state = obj['state'];
        ledOn = state == 1 || state == true;
      }
    }

    if (temp == null || light == null) {
      throw Exception('Capteurs manquants dans /api/sensors');
    }

    return CurrentSensors(
      temperature: temp,
      light: light,
      ledIndicatorOn: ledOn,
    );
  }

  /// Si tu veux les routes séparées :
  Future<double> fetchLightOnly() async {
    final uri = Uri.parse('$baseUrl/photoresistance');
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Erreur lumière (${response.statusCode})');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (data['value'] as num).toDouble();
  }

  Future<double> fetchTemperatureOnly() async {
    final uri = Uri.parse('$baseUrl/thermoresistance');
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Erreur température (${response.statusCode})');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (data['value'] as num).toDouble();
  }

  /// Change la couleur de la LED RGB avec les routes actuelles :
  /// 'r' -> PATCH /api/ledrgb/r
  /// 'g' -> PATCH /api/ledrgb/g
  /// 'b' -> PATCH /api/ledrgb/b
  Future<void> setLedColorBasic(String color) async {
    late final String path;
    if (color == 'r') {
      path = '/ledrgb/r';
    } else if (color == 'g') {
      path = '/ledrgb/g';
    } else if (color == 'b') {
      path = '/ledrgb/b';
    } else {
      throw ArgumentError('Couleur invalide: $color');
    }

    final uri = Uri.parse('$baseUrl$path');
    final response = await _client.patch(uri);
    if (response.statusCode != 200) {
      throw Exception(
          'Erreur changement couleur (${response.statusCode})');
    }
  }

  Future<void> setLedColorRgb(int r, int g, int b) async {
    final uri = Uri.parse('$baseUrl/ledrgb/color');
    final response = await _client.patch(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'r': r, 'g': g, 'b': b}),
    );

    if (response.statusCode != 200) {
      throw Exception(
          'Erreur changement couleur RGB (${response.statusCode})');
    }
  }

  Future<void> turnOffRgb() async {
    final uri = Uri.parse('$baseUrl/ledrgb/off');
    final response = await _client.patch(uri);
    if (response.statusCode != 200) {
      throw Exception('Erreur extinction LED RGB (${response.statusCode})');
    }
  }



  /// Lier / délier la LED bleue à la lumière.
  Future<void> setRGBLightMode(bool enable) async {
    final path = enable ? '/ledrgb/link_light' : '/ledrgb/unlink_light';
    final uri = Uri.parse('$baseUrl$path');
    final response = await _client.patch(uri);
    if (response.statusCode != 200) {
      throw Exception('Erreur lien rgb/lumière (${response.statusCode})');
    }
  }

  /// Lier / délier la LED rouge à la température.
  Future<void> setRGBTempMode(bool enable) async {
    final path = enable ? '/ledrgb/link_temp' : '/ledrgb/unlink_temp';
    final uri = Uri.parse('$baseUrl$path');
    final response = await _client.patch(uri);
    if (response.statusCode != 200) {
      throw Exception('Erreur lien rgb/temp (${response.statusCode})');
    }
  }

  /// Seuils (light + cold/hot) – future route côté ESP.
  Future<Thresholds> fetchThresholdsFromApi() async {
    final uri = Uri.parse('$baseUrl/config/thresholds');
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw Exception(
          'Erreur chargement seuils API (${response.statusCode})');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return Thresholds.fromJson(data);
  }

  Future<Thresholds> updateThresholdsToApi(Thresholds thresholds) async {
    final uri = Uri.parse('$baseUrl/config/thresholds');
    final response = await _client.patch(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(thresholds.toJson()),
    );
    if (response.statusCode != 200) {
      throw Exception(
          'Erreur mise à jour seuils API (${response.statusCode})');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return Thresholds.fromJson(data);
  }
}
