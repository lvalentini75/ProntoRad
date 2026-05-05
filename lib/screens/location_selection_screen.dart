import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:xraynow/models/exam_type.dart';
import 'package:xraynow/models/exam_package.dart';
import 'package:xraynow/models/organization.dart';
import 'package:geolocator/geolocator.dart';
import 'package:xraynow/theme.dart';
import 'package:xraynow/services/organization_service.dart';

class LocationSelectionScreen extends StatefulWidget {
  final ExamType? exam;
  final ExamPackage? examPackage;

  const LocationSelectionScreen({
    super.key,
    this.exam,
    this.examPackage,
  }) : assert(exam != null || examPackage != null, 'Either exam or examPackage must be provided');

  @override
  State<LocationSelectionScreen> createState() =>
      _LocationSelectionScreenState();
}

class _LocationSelectionScreenState extends State<LocationSelectionScreen> {
  final OrganizationService _orgService = OrganizationService();
  
  String? _selectedRegion;
  String? _selectedProvince;
  String? _selectedCity;
  double? _userLat;
  double? _userLon;
  
  List<Organization> _availableFacilities = [];
  bool _loadingFacilities = false;

  final List<String> _regions = [
    'Lazio',
    'Lombardia',
    'Campania',
    'Piemonte',
    'Toscana',
    'Veneto',
    'Emilia-Romagna',
    'Sicilia',
  ];

  // Province per regione - Lista completa italiana
  static const Map<String, List<String>> _provincesByRegion = {
    'Abruzzo': ['Chieti', 'L\'Aquila', 'Pescara', 'Teramo'],
    'Basilicata': ['Matera', 'Potenza'],
    'Calabria': ['Catanzaro', 'Cosenza', 'Crotone', 'Reggio Calabria', 'Vibo Valentia'],
    'Campania': ['Avellino', 'Benevento', 'Caserta', 'Napoli', 'Salerno'],
    'Emilia-Romagna': ['Bologna', 'Ferrara', 'Forlì-Cesena', 'Modena', 'Parma', 'Piacenza', 'Ravenna', 'Reggio Emilia', 'Rimini'],
    'Friuli-Venezia Giulia': ['Gorizia', 'Pordenone', 'Trieste', 'Udine'],
    'Lazio': ['Frosinone', 'Latina', 'Rieti', 'Roma', 'Viterbo'],
    'Liguria': ['Genova', 'Imperia', 'La Spezia', 'Savona'],
    'Lombardia': ['Bergamo', 'Brescia', 'Como', 'Cremona', 'Lecco', 'Lodi', 'Mantova', 'Milano', 'Monza e Brianza', 'Pavia', 'Sondrio', 'Varese'],
    'Marche': ['Ancona', 'Ascoli Piceno', 'Fermo', 'Macerata', 'Pesaro e Urbino'],
    'Molise': ['Campobasso', 'Isernia'],
    'Piemonte': ['Alessandria', 'Asti', 'Biella', 'Cuneo', 'Novara', 'Torino', 'Verbano-Cusio-Ossola', 'Vercelli'],
    'Puglia': ['Bari', 'Barletta-Andria-Trani', 'Brindisi', 'Foggia', 'Lecce', 'Taranto'],
    'Sardegna': ['Cagliari', 'Carbonia-Iglesias', 'Medio Campidano', 'Nuoro', 'Ogliastra', 'Olbia-Tempio', 'Oristano', 'Sassari'],
    'Sicilia': ['Agrigento', 'Caltanissetta', 'Catania', 'Enna', 'Messina', 'Palermo', 'Ragusa', 'Siracusa', 'Trapani'],
    'Toscana': ['Arezzo', 'Firenze', 'Grosseto', 'Livorno', 'Lucca', 'Massa-Carrara', 'Pisa', 'Pistoia', 'Prato', 'Siena'],
    'Trentino-Alto Adige': ['Bolzano', 'Trento'],
    'Umbria': ['Perugia', 'Terni'],
    'Valle d\'Aosta': ['Aosta'],
    'Veneto': ['Belluno', 'Padova', 'Rovigo', 'Treviso', 'Venezia', 'Verona', 'Vicenza'],
  };

  final Map<String, List<String>> _cities = {
    'Roma': ['Roma', 'Fiumicino', 'Guidonia Montecelio', 'Anzio'],
    'Milano': [
      'Milano',
      'Milano Centro',
      'Sesto San Giovanni',
      'Cinisello Balsamo',
      'San Donato Milanese'
    ],
    'Napoli': ['Napoli', 'Pozzuoli', 'Torre del Greco', 'Casoria'],
    'Torino': ['Torino', 'Moncalieri', 'Collegno', 'Rivoli'],
    'Firenze': ['Firenze', 'Scandicci', 'Sesto Fiorentino', 'Empoli'],
  };

  @override
  void initState() {
    super.initState();
    _loadAvailableFacilities();
  }

  Future<void> _loadAvailableFacilities() async {
    setState(() => _loadingFacilities = true);
    try {
      final examId = widget.exam?.id;
      final packageId = widget.examPackage?.id;
      debugPrint('[LocationSelection] Loading facilities for exam=$examId, package=$packageId');
      
      // Carica strutture che offrono l'esame/pacchetto nella località selezionata
      final orgs = await _orgService.searchOrganizations(
        examId: examId,
        packageId: packageId,
        region: _selectedRegion,
        province: _selectedProvince,
        city: _selectedCity,
      );
      
      // Calcola distanza per ogni struttura se abbiamo la posizione utente
      if (_userLat != null && _userLon != null) {
        for (final org in orgs) {
          if (org.latitude != null && org.longitude != null) {
            final distance = _orgService.calculateDistance(
              _userLat!,
              _userLon!,
              org.latitude!,
              org.longitude!,
            );
            // Non possiamo modificare direttamente l'oggetto, ma lo useremo per l'ordinamento
          }
        }
        
        // Ordina per distanza
        orgs.sort((a, b) {
          if (a.latitude == null || a.longitude == null) return 1;
          if (b.latitude == null || b.longitude == null) return -1;
          
          final distA = _orgService.calculateDistance(_userLat!, _userLon!, a.latitude!, a.longitude!);
          final distB = _orgService.calculateDistance(_userLat!, _userLon!, b.latitude!, b.longitude!);
          return distA.compareTo(distB);
        });
      }
      
      // Limita a 5 strutture per brevità
      setState(() {
        _availableFacilities = orgs.take(5).toList();
        _loadingFacilities = false;
      });
      
      debugPrint('[LocationSelection] Found ${_availableFacilities.length} available facilities');
    } catch (e) {
      debugPrint('[LocationSelection] Error loading facilities: $e');
      setState(() => _loadingFacilities = false);
    }
  }

  Future<void> _useCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        debugPrint('Location permission not granted');
        // Keep fallback selection for demo
        setState(() {
          _selectedRegion = 'Lombardia';
          _selectedProvince = 'Milano';
          _selectedCity = 'Milano';
          _userLat = null;
          _userLon = null;
        });
        _loadAvailableFacilities();
        return;
      }

      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _userLat = pos.latitude;
        _userLon = pos.longitude;
        // Keep simple region/province/city defaults; data filtering relies mainly on province/region
        _selectedRegion = _selectedRegion ?? 'Lombardia';
        _selectedProvince = _selectedProvince ?? 'Milano';
        _selectedCity = _selectedCity ?? 'Milano';
      });
      _loadAvailableFacilities();
    } catch (e) {
      debugPrint('Failed to get current location: $e');
      // Fallback to defaults without lat/lon
      setState(() {
        _selectedRegion = 'Lombardia';
        _selectedProvince = 'Milano';
        _selectedCity = 'Milano';
        _userLat = null;
        _userLon = null;
      });
      _loadAvailableFacilities();
    }
  }

  void _continueToFacilities() {
    if (_selectedRegion != null &&
        _selectedProvince != null &&
        _selectedCity != null) {
      context.push(
        '/facility-list',
        extra: {
          if (widget.exam != null) 'exam': widget.exam,
          if (widget.examPackage != null) 'examPackage': widget.examPackage,
          'region': _selectedRegion,
          'province': _selectedProvince,
          'city': _selectedCity,
          if (_userLat != null && _userLon != null) 'userLat': _userLat,
          if (_userLat != null && _userLon != null) 'userLon': _userLon,
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F4FC),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.chevron_left,
                          color: LightModeColors.lightPrimary,
                          size: 28,
                        ),
                        Text(
                          'Back',
                          style: TextStyle(
                            color: LightModeColors.lightPrimary,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        'Cerca Ospedale',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 80), // Balance the back button
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Location selection card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header with icon
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: LightModeColors.lightPrimary
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.location_on,
                                  color: LightModeColors.lightPrimary,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'Dove vuoi fare l\'esame',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Region dropdown
                          _buildDropdownLabel('Seleziona Regione'),
                          _buildDropdown(
                            value: _selectedRegion,
                            hint: 'Lombardia',
                            items: _regions,
                            onChanged: (value) {
                              setState(() {
                                _selectedRegion = value;
                                _selectedProvince = null;
                                _selectedCity = null;
                              });
                              _loadAvailableFacilities();
                            },
                          ),
                          const SizedBox(height: 16),

                          // Province dropdown
                          _buildDropdownLabel('Seleziona Provincia'),
                          _buildDropdown(
                            value: _selectedProvince,
                            hint: 'Milano',
                            items: _selectedRegion != null
                                ? _provincesByRegion[_selectedRegion!] ?? []
                                : [],
                            onChanged: (value) {
                              setState(() {
                                _selectedProvince = value;
                                _selectedCity = null;
                              });
                              _loadAvailableFacilities();
                            },
                            enabled: _selectedRegion != null,
                          ),
                          const SizedBox(height: 16),

                          // City dropdown
                          _buildDropdownLabel('Seleziona Comune'),
                          _buildDropdown(
                            value: _selectedCity,
                            hint: 'Milano Centro',
                            items: _selectedProvince != null
                                ? _cities[_selectedProvince!] ?? []
                                : [],
                            onChanged: (value) {
                              setState(() {
                                _selectedCity = value;
                              });
                              _loadAvailableFacilities();
                            },
                            enabled: _selectedProvince != null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Use current location button
                    ElevatedButton.icon(
                      onPressed: _useCurrentLocation,
                      icon: const Icon(Icons.navigation,
                          color: Colors.white, size: 20),
                      label: const Text('Usa la mia posizione attuale'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: LightModeColors.lightPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Available facilities section
                    const Text(
                      'Strutture Disponibili',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Facility cards
                    if (_loadingFacilities)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (_availableFacilities.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.grey.shade600),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Nessuna struttura disponibile. Seleziona una località.',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ...(_availableFacilities.map((org) {
                        final distance = _userLat != null && 
                                       _userLon != null && 
                                       org.latitude != null && 
                                       org.longitude != null
                            ? _orgService.calculateDistance(
                                _userLat!,
                                _userLon!,
                                org.latitude!,
                                org.longitude!,
                              )
                            : null;
                        
                        return NearbyFacilityCard(
                          name: org.name,
                          address: org.address,
                          city: '${org.city}, ${org.province}',
                          distance: distance,
                          onTap: () {
                            setState(() {
                              _selectedRegion = org.region;
                              _selectedProvince = org.province;
                              _selectedCity = org.city;
                            });
                            _continueToFacilities();
                          },
                        );
                      })),

                    const SizedBox(height: 16),

                    // Search button
                    if (_selectedRegion != null &&
                        _selectedProvince != null &&
                        _selectedCity != null)
                      ElevatedButton(
                        onPressed: _continueToFacilities,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: LightModeColors.lightPrimary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Cerca strutture disponibili',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey.shade600,
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String? value,
    required String hint,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    bool enabled = true,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(
            hint,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 15,
            ),
          ),
          isExpanded: true,
          icon: Icon(
            Icons.check,
            color: value != null
                ? LightModeColors.lightPrimary
                : Colors.transparent,
          ),
          items: items
              .map((item) => DropdownMenuItem(
                    value: item,
                    child: Text(
                      item,
                      style: const TextStyle(fontSize: 15),
                    ),
                  ))
              .toList(),
          onChanged: enabled ? onChanged : null,
        ),
      ),
    );
  }
}

class NearbyFacilityCard extends StatelessWidget {
  final String name;
  final String address;
  final String city;
  final double? distance;
  final VoidCallback onTap;

  const NearbyFacilityCard({
    super.key,
    required this.name,
    required this.address,
    required this.city,
    this.distance,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      address,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      city,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              if (distance != null)
                Column(
                  children: [
                    Icon(
                      Icons.location_on,
                      color: LightModeColors.lightPrimary,
                      size: 24,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${distance!.toStringAsFixed(1)} km',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
