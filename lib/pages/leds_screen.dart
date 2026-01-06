import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import '../api_client.dart';


class LedControlScreen extends StatefulWidget {
  const LedControlScreen({super.key,required this.apiClient});

  final ApiClient apiClient;

  @override
  State<LedControlScreen> createState() => _LedControlScreenState();
}

class _LedControlScreenState extends State<LedControlScreen> {
  Color currentColor = const Color(0xFF21AAF9);

  // États des interrupteurs
  bool isRgbLedOn = false;
  bool isRedLedOn = true;
  bool syncWithLight = false;
  bool syncWithTemp = false;

  bool _rgbLightLinked = false;
  bool _rgbTempLinked = true; // par défaut, la RGB est liée à la température

  @override
  void initState() {
    super.initState();
    _loadInitialRgbStatus();
  }

  Future<void> _loadInitialRgbStatus() async {
    try {
      final status = await widget.apiClient.fetchRgbStatus();
      if (!mounted) return;

      setState(() {
        _rgbLightLinked = status.lightLinked;
        _rgbTempLinked  = status.tempLinked;
      });
    } catch (e) {
      // ajouter ecran si pbl
    }
  }


  Future<void> toggleRGB() async {
    if(isRgbLedOn) {
      try {
        await widget.apiClient.turnOffRgb();
        setState(() {
          isRgbLedOn = false;
        });

      } catch(e) {
        setState(() {
          isRgbLedOn = true;
        });
      }
    } else {
      _sendColor();
      setState(() {
        isRgbLedOn = true;
      });
    }
  }


  Future<void> _toggleBlue(bool value) async {
    setState(() {
      _rgbLightLinked = value;
      if (value) {
        _rgbTempLinked = false; //  mode lumière => on coupe mode temp
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
    final h = currentColor;

    final ir = (currentColor.r * 255 ).toInt();
    final ig = (currentColor.g * 255).toInt();
    final ib = (currentColor.b* 255).toInt();

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

  void changeColor(Color color) {
    setState(() => currentColor = color);
  }

  // Widget réutilisable pour un Interrupteur avec libellé
  Widget _buildSwitchItem({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor:
              Colors.black, // Le noir est utilisé pour l'état "On"
        ),
        Text(label),
      ],
    );
  }

  // Widget réutilisable pour les interrupteurs de synchronisation
  Widget _buildSyncSwitchItem({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Switch(
          value: value,
          onChanged: onChanged,
          activeTrackColor: Colors.black, // Piste noire pour l'état "On"
          inactiveTrackColor:
              Colors.grey[300], // Piste claire pour l'état "Off"
          inactiveThumbColor: Colors.white,
          activeThumbColor: Colors.white, // Bouton blanc pour les deux états
        ),
        const SizedBox(height: 4),
        Text(label),
      ],
    );
  }

  // Widget réutilisable pour l'icône de la barre de navigation inférieure
  Widget _buildNavItem({required IconData icon, required bool isSelected}) {
    // La couleur bleue est utilisée pour l'icône sélectionnée (information dans le design)
    return Icon(
      icon,
      size: 24.0,
      color: isSelected ? Colors.blue : Colors.black,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              const SizedBox(height: 20),

              // --- Titre Principal ---
              const Center(
                child: Text(
                  'Contrôle des LEDs',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),

              const SizedBox(height: 40),

              // --- Titre du Sélecteur ---
              const Text(
                'Choisissez la couleur de la LED RGB',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 20),

              // --- Sélecteur de Couleur (Color Picker) ---
              // On utilise le "Hue Ring" pour correspondre au design du cercle

              // GestureDetector pour rendre le cercle cliquable et afficher un dialog
              GestureDetector(
                onTap: () {
                  // Afficher le sélecteur de couleur complet dans une boîte de dialogue
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: const Text('Sélectionner la couleur'),
                        content: SingleChildScrollView(
                          child: ColorPicker(
                            pickerColor: currentColor,
                            onColorChanged: changeColor,
                            pickerAreaHeightPercent: 0.8,
                            enableAlpha:
                                false, // Pas de canal Alpha dans le design
                            labelTypes:
                                const [], // Cache les libellés de couleur
                            displayThumbColor: true,
                            paletteType:
                                PaletteType.hsv, // Utilise la roue de couleur
                          ),
                        ),
                        actions: <Widget>[
                          ElevatedButton(
                            child: const Text('OK'),
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                          ),
                        ],
                      );
                    },
                  );
                },
                // Affichage du cercle de couleur simple (Hue Ring)
                child: ColorPicker(
                  pickerColor: currentColor,
                  onColorChanged: (color) {
                    setState(() {
                      currentColor = color;
                    });
                  }, // Ne pas changer la couleur au toucher ici
                  pickerAreaBorderRadius: BorderRadius.circular(100),
                  pickerAreaHeightPercent: 0.5,
                  enableAlpha: false,
                  labelTypes: const [],
                  displayThumbColor: true,
                  paletteType: PaletteType.hueWheel, // La roue de couleur
                  // Définition de la taille du picker pour qu'il ressemble au cercle du design
                ),
              ),

              const SizedBox(height: 16),

              // --- Code Hexadécimal de la Couleur ---
              Text(
                '#${currentColor.toARGB32().toRadixString(16).toUpperCase().substring(2)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              ElevatedButton(
                // Le style du bouton est défini au niveau de l'application (main.dart)
                // ou dans le ThemeData, mais est stylisé ici pour le rendre noir.
                onPressed: _sendColor,
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadiusGeometry.all(Radius.zero),
                  ),
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.black,
                  minimumSize: const Size(240, 40),
                ),
                child: const Text('Envoyer au TTGO'),
              ),

              const SizedBox(height: 40),

              // --- Interrupteurs LEDs ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // LED RGB
                  _buildSwitchItem(
                    label: 'Led RGB',
                    value: isRgbLedOn,
                    onChanged: (bool value) {
                      setState(() {
                        toggleRGB();
                      });
                    },
                  ),

                  // LED Rouge
                  _buildSwitchItem(
                    label: 'Led Rouge',
                    value: isRedLedOn,
                    onChanged: (bool value) {
                      setState(() {
                        isRedLedOn = value;
                      });
                    },
                  ),
                ],
              ),

              const SizedBox(height: 50),

              // --- Titre Synchronisation ---
              const Text('Synchroniser avec :', style: TextStyle(fontSize: 16)),

              const SizedBox(height: 20),

              // --- Interrupteurs Synchronisation ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // Lumière
                  _buildSyncSwitchItem(
                    label: 'lumiere',
                    value: syncWithLight,
                    onChanged: (bool value) {
                      setState(() {
                        syncWithLight = value;
                      });
                    },
                  ),

                  // Température
                  _buildSyncSwitchItem(
                    label: 'temperature',
                    value: syncWithTemp,
                    onChanged: (bool value) {
                      setState(() {
                        syncWithTemp = value;
                      });
                    },
                  ),
                ],
              ),

              const SizedBox(height: 50),

            ],
          ),
        ),
      ),

    );
  }
}
