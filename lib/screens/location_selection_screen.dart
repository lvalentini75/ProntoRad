import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:xraynow/models/exam_type.dart';
import 'package:xraynow/models/exam_package.dart';
import 'package:xraynow/models/organization.dart';
import 'package:geolocator/geolocator.dart';
import 'package:xraynow/theme.dart';
import 'package:xraynow/services/organization_service.dart';
import 'package:xraynow/data/locations.dart';

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
  
  String _selectedCountry = 'Svizzera';
  String? _selectedRegion;
  String? _selectedProvince;
  String? _selectedCity;
  double? _userLat;
  double? _userLon;
  
  List<Organization> _availableFacilities = [];
  bool _loadingFacilities = false;

  List<String> get _availableRegions => Locations.getRegionsByCountry(_selectedCountry);
  
  List<String> get _availableProvinces => _selectedRegion != null 
      ? Locations.getProvincesByRegion(_selectedRegion, country: _selectedCountry)
      : [];
  
  List<String> get _availableCities => _selectedProvince != null
      ? Locations.getCitiesByProvince(_selectedProvince, country: _selectedCountry)
      : [];

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
        country: _selectedCountry,
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
      
      // Mostra tutte le strutture disponibili
      setState(() {
        _availableFacilities = orgs;
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
    // Per la Svizzera: richiedi solo cantone (distretto e città opzionali)
    // Per l'Italia: richiedi regione, provincia e città
    final hasRequiredFields = _selectedRegion != null &&
        (_selectedCountry == 'Svizzera' || (_selectedProvince != null && _selectedCity != null));
    
    if (hasRequiredFields) {
      context.push(
        '/facility-list',
        extra: {
          if (widget.exam != null) 'exam': widget.exam,
          if (widget.examPackage != null) 'examPackage': widget.examPackage,
          'country': _selectedCountry,
          'region': _selectedRegion,
          if (_selectedProvince != null) 'province': _selectedProvince,
          if (_selectedCity != null) 'city': _selectedCity,
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

                          // Country dropdown
                          _buildDropdownLabel('Seleziona Paese'),
                          _buildCountryDropdown(),
                          const SizedBox(height: 16),

                          // Region dropdown
                          _buildDropdownLabel(_selectedCountry == 'Svizzera' ? 'Seleziona Cantone' : 'Seleziona Regione'),
                          _buildDropdown(
                            value: _selectedRegion,
                            hint: _selectedCountry == 'Svizzera' ? 'Ticino' : 'Lombardia',
                            items: _availableRegions,
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
                          _buildDropdownLabel(_selectedCountry == 'Svizzera' ? 'Seleziona Distretto (opzionale)' : 'Seleziona Provincia'),
                          _buildDropdown(
                            value: _selectedProvince,
                            hint: _selectedCountry == 'Svizzera' ? 'Tutti i distretti' : 'Milano',
                            items: _availableProvinces,
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
                          _buildDropdownLabel('Seleziona Comune${_selectedCountry == 'Svizzera' ? ' (opzionale)' : ''}'),
                          _buildDropdown(
                            value: _selectedCity,
                            hint: _selectedCountry == 'Svizzera' ? 'Tutti i comuni' : 'Milano',
                            items: _availableCities,
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
                        (_selectedCountry == 'Svizzera' || (_selectedProvince != null && _selectedCity != null)))
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

  Widget _buildCountryDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedCountry,
          isExpanded: true,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          borderRadius: BorderRadius.circular(12),
          items: Locations.countries.map((country) => DropdownMenuItem(
            value: country,
            child: Row(
              children: [
                Text(country == 'Italia' ? '🇮🇹' : '🇨🇭', style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 12),
                Text(
                  country,
                  style: const TextStyle(fontSize: 15),
                ),
              ],
            ),
          )).toList(),
          onChanged: (value) {
            setState(() {
              _selectedCountry = value ?? 'Italia';
              _selectedRegion = null;
              _selectedProvince = null;
              _selectedCity = null;
            });
            _loadAvailableFacilities();
          },
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
