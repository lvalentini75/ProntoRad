import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:xraynow/supabase/supabase_config.dart';
import 'package:xraynow/services/audit_log_service.dart';

/// DemoDataSeeder populates the database with consistent demo data
/// - organizations (ospedali/istituti)
/// - facilities (sedi collegate alle organizzazioni)
/// - exam_types (prestazioni)
/// - tariffs (prezzi per organizzazione)
/// - users (end_user e org_admin)
/// - bookings (prenotazioni coerenti con tariffario e disponibilità)
class DemoDataSeeder {
  final Random _rand = Random();

  /// Seed a large, but bounded, set of demo data.
  /// Returns a summary map with inserted counts per table.
  Future<Map<String, int>> seedAll({
    int targetOrganizations = 18,
    int endUsers = 120,
    int bookings = 240,
    void Function(String stage, int done, int total)? onProgress,
  }) async {
    final summary = <String, int>{
      'organizations': 0,
      'facilities': 0,
      'exam_types': 0,
      'tariffs': 0,
      'users': 0,
      'bookings': 0,
      'offerings': 0,
      'slots': 0,
    };
    try {
      // 1) Exams
      final existingExams = await _safeSelect('exam_types');
      List<Map<String, dynamic>> examRows;
      if (existingExams.isEmpty) {
        examRows = _buildExamTypes();
        final inserted = await _safeInsertMultiple('exam_types', examRows);
        summary['exam_types'] = inserted.length;
        await _auditInserted('exam_types', inserted);
      } else {
        examRows = existingExams;
      }

      // 2) Organizations
      final existingOrgs = await _safeSelect('organizations');
      List<Map<String, dynamic>> orgRows = existingOrgs;
      if (existingOrgs.length < targetOrganizations) {
        final needed = targetOrganizations - existingOrgs.length;
        final toCreate = _buildOrganizations(needed);
        final inserted = await _safeInsertMultiple('organizations', toCreate);
        orgRows = [...existingOrgs, ...inserted];
        summary['organizations'] = inserted.length;
        await _auditInserted('organizations', inserted);
      }

      // 3) Facilities (1-3 per org)
      final existingFacilities = await _safeSelect('facilities');
      final byOrgFacilitiesCount = <String, int>{};
      for (final f in existingFacilities) {
        final orgId = (f['organization_id'] ?? '') as String;
        if (orgId.isEmpty) continue;
        byOrgFacilitiesCount[orgId] = (byOrgFacilitiesCount[orgId] ?? 0) + 1;
      }
      final toCreateFacilities = <Map<String, dynamic>>[];
      for (final org in orgRows) {
        final orgId = org['id'] as String;
        final already = byOrgFacilitiesCount[orgId] ?? 0;
        final desired = 1 + _rand.nextInt(3); // 1..3
        final need = (desired - already).clamp(0, 3);
        if (need > 0) {
          toCreateFacilities.addAll(_buildFacilities(org, need, examRows));
        }
      }
      List<Map<String, dynamic>> facilityRows = existingFacilities;
      if (toCreateFacilities.isNotEmpty) {
        final inserted = await _safeInsertMultiple('facilities', toCreateFacilities);
        facilityRows = [...existingFacilities, ...inserted];
        summary['facilities'] = inserted.length;
        await _auditInserted('facilities', inserted);
      }

      // 3b) Offerings per facility per exam offered
      try {
        final existingOfferings = await _safeSelect('facility_exam_offerings');
        final offeringKeys = <String>{}; // facility|exam
        for (final o in existingOfferings) {
          offeringKeys.add('${o['facility_id']}|${o['exam_type_id']}');
        }
        final orgTariffPrice = <String, double>{}; // org|exam -> price
        try {
          final tariffsRows = await _safeSelect('tariffs');
          for (final t in tariffsRows) {
            final key = '${t['organization_id']}|${t['exam_type_id']}';
            orgTariffPrice[key] = (t['price'] as num).toDouble();
          }
        } catch (_) {}
        final toCreateOfferings = <Map<String, dynamic>>[];
        for (final f in facilityRows) {
          final facilityId = f['id'] as String;
          final orgId = (f['organization_id'] ?? '') as String;
          final exams = List<String>.from(f['available_exam_ids'] as List<dynamic>);
          for (final examId in exams) {
            final key = '$facilityId|$examId';
            if (offeringKeys.contains(key)) continue;
            final price = orgId.isNotEmpty
                ? (orgTariffPrice['$orgId|$examId'] ?? _priceByCategory(_categoryOfExam(examId, examRows)))
                : _priceByCategory(_categoryOfExam(examId, examRows));
            toCreateOfferings.add({
              'facility_id': facilityId,
              'exam_type_id': examId,
              'price': double.parse(price.toStringAsFixed(2)),
              'ssn_price': _rand.nextBool() ? double.parse((price * 0.2).toStringAsFixed(2)) : 0,
              'duration_minutes': 20 + _rand.nextInt(40),
              'preparation_notes': _rand.nextBool() ? 'Presentarsi 10 minuti prima con impegnativa.' : null,
              'is_available': true,
              'max_daily_bookings': 10 + _rand.nextInt(10),
              'created_at': DateTime.now().toUtc().toIso8601String(),
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            });
          }
        }
        if (toCreateOfferings.isNotEmpty) {
          final inserted = await _safeInsertMultiple('facility_exam_offerings', toCreateOfferings);
          summary['offerings'] = inserted.length;
          await _auditInserted('facility_exam_offerings', inserted);
        }
      } catch (e) {
        debugPrint('Offerings seed failed: $e');
      }

      // 3c) Availability slots per facility
      try {
        final existingSlots = await _safeSelect('availability_slots');
        final hasSlotsForFacility = <String, bool>{};
        for (final s in existingSlots) {
          hasSlotsForFacility[s['facility_id'] as String] = true;
        }
        final toCreateSlots = <Map<String, dynamic>>[];
        final nowIso = DateTime.now().toUtc().toIso8601String();
        for (final f in facilityRows) {
          final facilityId = f['id'] as String;
          if (hasSlotsForFacility[facilityId] == true) continue; // already has slots
          // Create recurring slots for Mon-Fri mornings and afternoons
          final recurringDays = [1, 2, 3, 4, 5]; // Mon..Fri in our 0..6 convention? We used 0=Dom..6=Sab; so Mon=1..Fri=5
          for (final d in recurringDays) {
            // Morning block: 09:00, 09:30, 10:00, 10:30, 11:00
            for (final t in ['09:00', '09:30', '10:00', '10:30', '11:00']) {
              toCreateSlots.add({
                'facility_id': facilityId,
                'exam_type_id': null,
                'day_of_week': d,
                'specific_date': null,
                'start_time': '$t:00',
                'end_time': _endFromStart(t),
                'max_bookings': 2 + _rand.nextInt(2),
                'is_active': true,
                'notes': null,
                'created_at': nowIso,
                'updated_at': nowIso,
              });
            }
            // Afternoon block: 14:00, 14:30, 15:00, 15:30, 16:00
            for (final t in ['14:00', '14:30', '15:00', '15:30', '16:00']) {
              toCreateSlots.add({
                'facility_id': facilityId,
                'exam_type_id': null,
                'day_of_week': d,
                'specific_date': null,
                'start_time': '$t:00',
                'end_time': _endFromStart(t),
                'max_bookings': 2 + _rand.nextInt(2),
                'is_active': true,
                'notes': null,
                'created_at': nowIso,
                'updated_at': nowIso,
              });
            }
          }
          // A few specific-date extra slots in the next 14 days
          for (int i = 1; i <= 14; i += 3) {
            final date = DateTime.now().add(Duration(days: i));
            for (final t in ['08:30', '12:00', '17:30']) {
              toCreateSlots.add({
                'facility_id': facilityId,
                'exam_type_id': null,
                'day_of_week': null,
                'specific_date': DateTime(date.year, date.month, date.day).toIso8601String().split('T').first,
                'start_time': '$t:00',
                'end_time': _endFromStart(t),
                'max_bookings': 1 + _rand.nextInt(2),
                'is_active': true,
                'notes': _rand.nextBool() ? 'Slot aggiuntivo' : null,
                'created_at': nowIso,
                'updated_at': nowIso,
              });
            }
          }
        }
        if (toCreateSlots.isNotEmpty) {
          final inserted = await _safeInsertMultiple('availability_slots', toCreateSlots);
          summary['slots'] = inserted.length;
          await _auditInserted('availability_slots', inserted);
        }
      } catch (e) {
        debugPrint('Slots seed failed: $e');
      }

      // 4) Users (org_admin and end_user)
      final existingUsers = await _safeSelect('users');
      final haveEndUsers = existingUsers.where((u) => (u['role'] ?? 'end_user') == 'end_user').length;
      final haveOrgAdmins = existingUsers.where((u) => (u['role'] ?? '') == 'org_admin').length;
      final toCreateUsers = <Map<String, dynamic>>[];
      // One org_admin per org if missing
      final orgIds = orgRows.map((o) => o['id'] as String).toList();
      final adminsByOrg = <String, int>{};
      for (final u in existingUsers) {
        final role = (u['role'] ?? '') as String;
        if (role == 'org_admin') {
          final oid = (u['organization_id'] ?? '') as String;
          if (oid.isNotEmpty) adminsByOrg[oid] = (adminsByOrg[oid] ?? 0) + 1;
        }
      }
      for (final oid in orgIds) {
        if ((adminsByOrg[oid] ?? 0) == 0) {
          toCreateUsers.add(_buildUser(role: 'org_admin', organizationId: oid));
        }
      }
      // End users up to requested amount
      final needEnd = (endUsers - haveEndUsers).clamp(0, endUsers);
      for (int i = 0; i < needEnd; i++) {
        toCreateUsers.add(_buildUser(role: 'end_user'));
      }
      List<Map<String, dynamic>> userRows = existingUsers;
      if (toCreateUsers.isNotEmpty) {
        final inserted = await _safeInsertMultiple('users', toCreateUsers);
        userRows = [...existingUsers, ...inserted];
        summary['users'] = inserted.length;
        await _auditInserted('users', inserted);
      }

      // 5) Tariffs per org per exam offered in their facilities
      final existingTariffs = await _safeSelect('tariffs');
      final tariffKey = <String>{}; // orgId|examId
      for (final t in existingTariffs) {
        tariffKey.add('${t['organization_id']}|${t['exam_type_id']}');
      }
      final byOrgExamOffered = _buildOrgExamAvailability(facilityRows);
      final toCreateTariffs = <Map<String, dynamic>>[];
      for (final entry in byOrgExamOffered.entries) {
        final orgId = entry.key;
        for (final examId in entry.value) {
          final key = '$orgId|$examId';
          if (tariffKey.contains(key)) continue;
          toCreateTariffs.add(_buildTariff(orgId: orgId, examId: examId, examRows: examRows));
        }
      }
      if (toCreateTariffs.isNotEmpty) {
        final inserted = await _safeInsertMultiple('tariffs', toCreateTariffs);
        summary['tariffs'] = inserted.length;
        await _auditInserted('tariffs', inserted);
      }

      // 6) Bookings using existing users, facilities, tariffs
      final existingBookings = await _safeSelect('bookings');
      final toCreateBookings = <Map<String, dynamic>>[];
      if (existingBookings.length < bookings) {
        final need = bookings - existingBookings.length;
        // pre-index helpers
        final endUserIds = userRows.where((u) => (u['role'] ?? 'end_user') == 'end_user').map((u) => u['id'] as String).toList();
        if (endUserIds.isNotEmpty) {
          // org -> facility list
          final byOrgFacilities = <String, List<Map<String, dynamic>>>{};
          for (final f in facilityRows) {
            final oid = (f['organization_id'] ?? '') as String;
            if (oid.isEmpty) continue;
            (byOrgFacilities[oid] ??= []).add(f);
          }
          // tariff map price
          final priceByOrgExam = <String, double>{};
          final tariffsNow = await _safeSelect('tariffs');
          for (final t in tariffsNow) {
            priceByOrgExam['${t['organization_id']}|${t['exam_type_id']}'] = (t['price'] as num).toDouble();
          }
          final allExamIds = examRows.map((e) => e['id'] as String).toList();
          for (int i = 0; i < need; i++) {
            final userId = endUserIds[_rand.nextInt(endUserIds.length)];
            final orgId = orgIds[_rand.nextInt(orgIds.length)];
            final facilitiesOfOrg = byOrgFacilities[orgId];
            if (facilitiesOfOrg == null || facilitiesOfOrg.isEmpty) continue;
            final facility = facilitiesOfOrg[_rand.nextInt(facilitiesOfOrg.length)];
            final offered = List<String>.from(facility['available_exam_ids'] as List<dynamic>);
            if (offered.isEmpty) {
              // fallback to any exam
              offered.add(allExamIds[_rand.nextInt(allExamIds.length)]);
            }
            final examId = offered[_rand.nextInt(offered.length)];
            final price = priceByOrgExam['$orgId|$examId'] ?? _priceByCategory(_categoryOfExam(examId, examRows));
            toCreateBookings.add(_buildBooking(userId: userId, examId: examId, facilityId: facility['id'] as String, price: price));
          }
        }
      }
      if (toCreateBookings.isNotEmpty) {
        final inserted = await _safeInsertMultiple('bookings', toCreateBookings);
        summary['bookings'] = inserted.length;
        await _auditInserted('bookings', inserted);
      }

      return summary;
    } catch (e) {
      debugPrint('Demo seeding failed: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> _safeSelect(String table) async {
    try {
      return await SupabaseService.select(table);
    } catch (e) {
      debugPrint('Select $table failed (maybe table missing or RLS): $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _safeInsertMultiple(String table, List<Map<String, dynamic>> rows) async {
    try {
      return await SupabaseService.insertMultiple(table, rows);
    } catch (e) {
      debugPrint('InsertMultiple $table failed: $e');
      return [];
    }
  }

  Future<void> _auditInserted(String table, List<Map<String, dynamic>> rows) async {
    for (final r in rows) {
      try {
        final id = (r['id'] ?? '').toString();
        if (id.isEmpty) continue;
        await AuditLogService.log(action: 'create', table: table, recordId: id, changes: r);
      } catch (e) {
        debugPrint('Audit for $table failed: $e');
      }
    }
  }

  List<Map<String, dynamic>> _buildExamTypes() {
    final now = DateTime.now().toUtc().toIso8601String();
    final list = <Map<String, dynamic>>[
      {'name': 'RM Encefalo', 'category': 'rm', 'body_district': 'testa', 'description': 'Risonanza magnetica dell\'encefalo'},
      {'name': 'RM Colonna Lombare', 'category': 'rm', 'body_district': 'estremita', 'description': 'RM della colonna lombare'},
      {'name': 'RM Ginocchio', 'category': 'rm', 'body_district': 'estremita', 'description': 'Risonanza magnetica ginocchio'},
      {'name': 'TAC Torace', 'category': 'tac', 'body_district': 'torace', 'description': 'Tomografia del torace'},
      {'name': 'TAC Addome', 'category': 'tac', 'body_district': 'addome', 'description': 'Tomografia addome completo'},
      {'name': 'Ecografia Addome Completo', 'category': 'eco', 'body_district': 'addome', 'description': 'Ecografia addome completo'},
      {'name': 'Ecografia Tiroide', 'category': 'eco', 'body_district': 'testa', 'description': 'Ecografia tiroidea'},
      {'name': 'RX Torace', 'category': 'rx', 'body_district': 'torace', 'description': 'Radiografia del torace'},
      {'name': 'RX Mano', 'category': 'rx', 'body_district': 'estremita', 'description': 'Radiografia mano'},
    ];
    return list
        .map((e) => {
              'name': e['name'],
              'category': e['category'],
              'body_district': e['body_district'],
              'description': e['description'],
              'created_at': now,
              'updated_at': now,
            })
        .toList();
  }

  List<Map<String, dynamic>> _buildOrganizations(int count) {
    final now = DateTime.now().toUtc().toIso8601String();
    final cities = _italianCities();
    final rows = <Map<String, dynamic>>[];
    for (int i = 0; i < count; i++) {
      final c = cities[_rand.nextInt(cities.length)];
      final isHospital = _rand.nextBool();
      rows.add({
        'name': isHospital ? 'Ospedale ${c['city']}' : 'Istituto Medico ${c['city']}',
        'org_type': isHospital ? 'hospital' : 'institute',
        'address': c['address'],
        'city': c['city'],
        'province': c['province'],
        'region': c['region'],
        'created_at': now,
        'updated_at': now,
      });
    }
    return rows;
  }

  List<Map<String, dynamic>> _buildFacilities(Map<String, dynamic> org, int count, List<Map<String, dynamic>> examRows) {
    final now = DateTime.now().toUtc().toIso8601String();
    final base = _italianCities().firstWhere((c) => c['city'] == org['city'], orElse: () => _italianCities()[_rand.nextInt(_italianCities().length)]);
    final orgId = org['id'] as String;
    final rows = <Map<String, dynamic>>[];
    for (int i = 0; i < count; i++) {
      final jitterLat = ((_rand.nextDouble() - 0.5) * 0.08);
      final jitterLon = ((_rand.nextDouble() - 0.5) * 0.08);
      final available = _pickExamIds(examRows, min: 3, max: 7);
      final type = _rand.nextBool() ? 'private' : 'public';
      rows.add({
        'organization_id': orgId,
        'name': '${org['name']} - Sede ${i + 1}',
        'address': base['address'],
        'city': base['city'],
        'province': base['province'],
        'region': base['region'],
        'latitude': (base['lat'] as double) + jitterLat,
        'longitude': (base['lon'] as double) + jitterLon,
        'type': type,
        'available_exam_ids': available,
        'base_price': 50 + _rand.nextInt(100),
        'created_at': now,
        'updated_at': now,
      });
    }
    return rows;
  }

  Map<String, List<String>> _buildOrgExamAvailability(List<Map<String, dynamic>> facilities) {
    final map = <String, List<String>>{}; // orgId -> examIds
    for (final f in facilities) {
      final orgId = (f['organization_id'] ?? '') as String;
      if (orgId.isEmpty) continue;
      final exams = List<String>.from(f['available_exam_ids'] as List<dynamic>);
      final dest = map.putIfAbsent(orgId, () => <String>[]);
      for (final e in exams) {
        if (!dest.contains(e)) dest.add(e);
      }
    }
    return map;
  }

  Map<String, dynamic> _buildTariff({required String orgId, required String examId, required List<Map<String, dynamic>> examRows}) {
    final now = DateTime.now().toUtc().toIso8601String();
    final cat = _categoryOfExam(examId, examRows);
    final price = _priceByCategory(cat);
    return {
      'organization_id': orgId,
      'exam_type_id': examId,
      'price': double.parse(price.toStringAsFixed(2)),
      'currency': 'EUR',
      'created_at': now,
      'updated_at': now,
    };
  }

  String _categoryOfExam(String examId, List<Map<String, dynamic>> examRows) {
    try {
      final row = examRows.firstWhere((e) => e['id'] == examId);
      return (row['category'] as String?) ?? 'rx';
    } catch (_) {
      return 'rx';
    }
  }

  double _priceByCategory(String category) {
    switch (category) {
      case 'rm':
        return (180 + _rand.nextInt(220)).toDouble(); // 180..400
      case 'tac':
        return (120 + _rand.nextInt(160)).toDouble(); // 120..280
      case 'eco':
        return (50 + _rand.nextInt(90)).toDouble(); // 50..140
      case 'rx':
      default:
        return (30 + _rand.nextInt(70)).toDouble(); // 30..100
    }
  }

  String _endFromStart(String hhmm) {
    // Simple +30 minutes end time generator in HH:mm:00
    try {
      final parts = hhmm.split(':');
      int h = int.parse(parts[0]);
      int m = int.parse(parts[1]);
      m += 30;
      if (m >= 60) {
        h += 1;
        m -= 60;
      }
      final hStr = h.toString().padLeft(2, '0');
      final mStr = m.toString().padLeft(2, '0');
      return '$hStr:$mStr:00';
    } catch (_) {
      return '00:30:00';
    }
  }

  Map<String, dynamic> _buildUser({required String role, String? organizationId}) {
    final now = DateTime.now().toUtc().toIso8601String();
    final firstNames = ['Luca', 'Marco', 'Giulia', 'Sara', 'Andrea', 'Francesca', 'Paolo', 'Chiara', 'Matteo', 'Alessia'];
    final lastNames = ['Rossi', 'Bianchi', 'Verdi', 'Russo', 'Ferrari', 'Esposito', 'Ricci', 'Marino'];
    final fn = firstNames[_rand.nextInt(firstNames.length)];
    final ln = lastNames[_rand.nextInt(lastNames.length)];
    final emailSeed = '${fn.toLowerCase()}.${ln.toLowerCase()}${100 + _rand.nextInt(900)}@demo.local';
    final map = {
      'first_name': fn,
      'last_name': ln,
      'email': emailSeed,
      'phone_number': '+39 3${_rand.nextInt(9)}${_rand.nextInt(10)} ${1000000 + _rand.nextInt(8999999)}',
      'role': role,
      'organization_id': organizationId,
      'created_at': now,
      'updated_at': now,
    };
    if (organizationId == null) map.remove('organization_id');
    return map;
  }

  Map<String, dynamic> _buildBooking({
    required String userId,
    required String examId,
    required String facilityId,
    required double price,
  }) {
    final created = DateTime.now().toUtc().subtract(Duration(days: _rand.nextInt(90)));
    final date = created.add(Duration(days: _rand.nextInt(30)));
    final time = DateTime(date.year, date.month, date.day, 8 + _rand.nextInt(9), [0, 15, 30, 45][_rand.nextInt(4)]);
    final status = ['requested', 'confirmed', 'cancelled'][_rand.nextInt(3)];
    final urgency = ['normal', 'urgent', 'veryUrgent'][_rand.nextInt(3)];
    return {
      'user_id': userId,
      'exam_type_id': examId,
      'facility_id': facilityId,
      'booking_date': date.toIso8601String(),
      'booking_time': time.toIso8601String(),
      'status': status,
      'urgency_level': urgency,
      'price': double.parse(price.toStringAsFixed(2)),
      'needs_transport': _rand.nextBool() && _rand.nextBool(),
      'is_home_service': _rand.nextBool() && !_rand.nextBool(),
      'notes': _rand.nextBool() ? 'Nota: ${['preferibilmente mattina', 'paziente claustrofobico', 'allergia contrasto', 'pregressa frattura'][_rand.nextInt(4)]}' : null,
      'created_at': created.toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  List<String> _pickExamIds(List<Map<String, dynamic>> examRows, {int min = 3, int max = 7}) {
    final count = min + _rand.nextInt(max - min + 1);
    final shuffled = [...examRows]..shuffle(_rand);
    return shuffled.take(count).map((e) => e['id'] as String).toList();
  }

  List<Map<String, dynamic>> _italianCities() => [
        {'city': 'Roma', 'province': 'RM', 'region': 'Lazio', 'address': 'Via Appia 10', 'lat': 41.9028, 'lon': 12.4964},
        {'city': 'Milano', 'province': 'MI', 'region': 'Lombardia', 'address': 'Corso Buenos Aires 25', 'lat': 45.4642, 'lon': 9.1900},
        {'city': 'Torino', 'province': 'TO', 'region': 'Piemonte', 'address': 'Via Po 5', 'lat': 45.0703, 'lon': 7.6869},
        {'city': 'Firenze', 'province': 'FI', 'region': 'Toscana', 'address': 'Viale Europa 15', 'lat': 43.7696, 'lon': 11.2558},
        {'city': 'Bologna', 'province': 'BO', 'region': 'Emilia-Romagna', 'address': 'Via Indipendenza 44', 'lat': 44.4949, 'lon': 11.3426},
        {'city': 'Napoli', 'province': 'NA', 'region': 'Campania', 'address': 'Via Toledo 100', 'lat': 40.8518, 'lon': 14.2681},
        {'city': 'Bari', 'province': 'BA', 'region': 'Puglia', 'address': 'Via Sparano 30', 'lat': 41.1171, 'lon': 16.8719},
        {'city': 'Palermo', 'province': 'PA', 'region': 'Sicilia', 'address': 'Via Libertà 12', 'lat': 38.1157, 'lon': 13.3615},
        {'city': 'Cagliari', 'province': 'CA', 'region': 'Sardegna', 'address': 'Via Roma 8', 'lat': 39.2238, 'lon': 9.1217},
        {'city': 'Verona', 'province': 'VR', 'region': 'Veneto', 'address': 'Via Mazzini 3', 'lat': 45.4384, 'lon': 10.9916},
        {'city': 'Genova', 'province': 'GE', 'region': 'Liguria', 'address': 'Via XX Settembre 50', 'lat': 44.4056, 'lon': 8.9463},
        {'city': 'Padova', 'province': 'PD', 'region': 'Veneto', 'address': 'Prato della Valle 2', 'lat': 45.4064, 'lon': 11.8768},
      ];
}
