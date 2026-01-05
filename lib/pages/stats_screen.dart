import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:ttgo_interface/firestore_service.dart';

import '../api_client.dart';

class StatisticsScreen extends StatefulWidget {
   const StatisticsScreen({super.key,required this.apiClient});
  final ApiClient apiClient;


  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  // 0 = Température, 1 = Lumière
  var selectedTabIndex = 0;
  DateTime selectedDate = DateTime.now();
  final fs = FirebaseFirestore.instance;



  List<FlSpot> temperatureData = [];
  List<FlSpot> luminosityData = [];
  List<String> monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2025),
      lastDate: DateTime(2030),
    );

    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
        fetchData();
      });
    }
  }

  void fetchData() {
    List<FlSpot> temperature = [];
    List<FlSpot>  luminosity = [];
    DateTime startOfDay = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    DateTime endOfDay = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, 23, 59, 59);
    fs.collection("capteurs").where("timestamp",isGreaterThanOrEqualTo: startOfDay)
        .where('timestamp', isLessThanOrEqualTo: endOfDay).get().then(
          (querySnapshot) {
        print("Successfully completed");
        for (var docSnapshot in querySnapshot.docs) {

          var temp_timestamp = docSnapshot.get("timestamp");
          DateTime date = temp_timestamp.toDate();
          var hour = date.hour;
          var minute = date.minute;
          var x = hour + (minute / 60);

          luminosity.add(FlSpot(minute % 23,docSnapshot.get("light")));
          temperature.add(FlSpot(minute % 23, docSnapshot.get("temperature")));
        }
        setState(() {
          luminosityData = luminosity;
          temperatureData = temperature;

        });

      },
      onError: (e) => print("Error completing: $e"),
    );
  }

  @override
  void initState() {
    fetchData();

    super.initState();
  }


  // Widget réutilisable pour un bouton d'onglet (Température / Lumière)
  Widget _buildTabButton({required String label, required int index}) {


    final bool isSelected = selectedTabIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedTabIndex = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({required IconData icon, required bool isSelected}) {
    return Icon(
      icon,
      size: 24.0,
      color: isSelected ? Colors.black : Colors.black54,
    );
  }

  Widget _buildLineChart() {
    final List<FlSpot> data = selectedTabIndex == 0
        ? temperatureData
        : luminosityData;
    final String yAxisTitle = selectedTabIndex == 0 ? '°C' : '%';
    final double maxY = selectedTabIndex == 0 ? 30 : 100;
    final double minY = selectedTabIndex == 0 ? 0 : 0;

    return AspectRatio(
      aspectRatio: 1.5,
      child: Padding(
        padding: const EdgeInsets.only(
          right: 18,
          left: 12,
          top: 24,
          bottom: 12,
        ),
        child: LineChart(
          LineChartData(
            gridData: const FlGridData(
              show: false,
            ), // Cache les lignes de grille
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 3, // Afficher à chaque heure
                  getTitlesWidget: (value, meta) {
                    // Afficher les heures (8h, 9h, 10h, ...)
                    if (value >= 0 && value <= 23 && value.floor() == value) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          '${value.toInt()}h',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                          ),
                        ),
                      );
                    } else if (value == 7) {
                    }
                    return Container();
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 32, // Taille réservée pour les titres
                  interval: selectedTabIndex == 0
                      ? 5
                      : 20, // Intervalle 5°C ou 20%
                  getTitlesWidget: (value, meta) {
                    if (value < minY || value > maxY) return Container();
                    return Text(
                      '${value.toInt()}$yAxisTitle',
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                      textAlign: TextAlign.left,
                    );
                  },
                ),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
            ),
            borderData: FlBorderData(show: false), // Cache les bordures
            minX: 0, // Début à 7h
            maxX: 23, // Fin à 14h
            minY: minY,
            maxY: maxY,
            lineBarsData: [
              LineChartBarData(
                spots: data,
                isCurved: true, // Courbe lisse
                color: Colors.blue, // Couleur de la ligne
                barWidth: 2.5,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, barData, index) {
                    // Afficher uniquement le point final
                    if (index == data.length - 1) {
                      return FlDotCirclePainter(
                        radius: 5,
                        color: Colors.blue,
                        strokeWidth: 2,
                        strokeColor: Colors.white,
                      );
                    }
                    return FlDotCirclePainter(
                      radius: 0,
                    ); // Masquer les autres points
                  },
                ),
                belowBarData: BarAreaData(
                  show: true,
                  // Dégradé de bleu sous la ligne
                  gradient: LinearGradient(
                    colors: [
                      Colors.blue.withOpacity(0.3),
                      Colors.blue.withOpacity(0),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Déterminer le titre du graphique en fonction de l'onglet
    final String chartTitle = selectedTabIndex == 0
        ? 'Variations de la température'
        : 'Variations de la luminosité';

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const SizedBox(height: 20),

              // --- Titre Principal ---
              const Center(
                child: Text(
                  'Statistiques',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),

              const SizedBox(height: 40),

              // --- Boutons d'Onglet ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Row(
                  children: [
                    _buildTabButton(label: 'Température', index: 0),
                    const SizedBox(width: 8),
                    _buildTabButton(label: 'Lumière', index: 1),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // --- Sélecteur de Date ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Row(

                  children: [
                    ElevatedButton(
                        onPressed: (){
                          _selectDate(context);
                        },
                      child: const Icon(Icons.calendar_today_outlined, size: 24),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent,
                        foregroundColor: Colors.black,
                        shadowColor: Colors.transparent,),)
                    ,
                    const SizedBox(width: 12),
                    // Affichage de la date simulée
                    Text(
                      '${monthNames[selectedDate.month - 1]}. ${selectedDate.day} ${selectedDate.year}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // --- Conteneur du Graphique ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Card(
                  color: Colors.white,
                  elevation: 0, // Pas d'ombre visible dans le design
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Titre du graphique
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0, top: 8.0),
                          child: Text(
                            chartTitle,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                        // Le graphique lui-même
                        _buildLineChart(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),

      // --- Barre de Navigation Inférieure ---
    );
  }
}
