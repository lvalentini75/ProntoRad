import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:xraynow/models/exam_package.dart';
import 'package:xraynow/models/exam_type.dart';
import 'package:xraynow/services/exam_package_service.dart';
import 'package:xraynow/services/exam_service.dart';
import 'package:xraynow/theme.dart';

/// Schermata per la selezione di pacchetti esami
class PackageSelectionScreen extends StatefulWidget {
  const PackageSelectionScreen({super.key});

  @override
  State<PackageSelectionScreen> createState() => _PackageSelectionScreenState();
}

class _PackageSelectionScreenState extends State<PackageSelectionScreen> {
  final _packageService = ExamPackageService();
  final _examService = ExamService();
  
  List<ExamPackage> _packages = [];
  List<ExamType> _allExams = [];
  bool _loading = true;
  String? _error;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadPackages();
  }

  Future<void> _loadPackages() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    
    try {
      // Carica tutti i pacchetti attivi da tutte le organizzazioni
      final packages = await _packageService.getAllActivePackages();
      final exams = await _examService.getAllExams();
      
      setState(() {
        _packages = packages;
        _allExams = exams;
        _loading = false;
      });
    } catch (e) {
      debugPrint('[PackageSelectionScreen] Errore: $e');
      setState(() {
        _error = 'Errore nel caricamento dei pacchetti';
        _loading = false;
      });
    }
  }

  List<ExamPackage> get _filteredPackages {
    if (_searchQuery.isEmpty) return _packages;
    final query = _searchQuery.toLowerCase();
    return _packages.where((p) => 
      p.name.toLowerCase().contains(query) ||
      p.description.toLowerCase().contains(query)
    ).toList();
  }

  String _getExamNames(List<String> examIds) {
    final names = examIds.map((id) {
      final exam = _allExams.firstWhere(
        (e) => e.id == id,
        orElse: () => ExamType(
          id: id,
          name: 'Esame',
          category: ExamCategory.rm,
          bodyDistrict: BodyDistrict.testa,
          description: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      return exam.name;
    }).toList();
    if (names.length > 3) {
      return '${names.take(3).join(', ')} +${names.length - 3} altri';
    }
    return names.join(', ');
  }

  Color _getPackageColor(ExamPackage package) {
    // Determina il colore in base alla categoria degli esami inclusi
    if (package.examIds.isEmpty) return LightModeColors.lightPrimary;
    
    final firstExamId = package.examIds.first;
    final exam = _allExams.firstWhere(
      (e) => e.id == firstExamId,
      orElse: () => ExamType(
        id: '',
        name: '',
        category: ExamCategory.rm,
        bodyDistrict: BodyDistrict.testa,
        description: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    
    switch (exam.category) {
      case ExamCategory.rm:
        return const Color(0xFF5B7FB7);
      case ExamCategory.tac:
        return const Color(0xFF48BDC5);
      case ExamCategory.eco:
        return const Color(0xFF7AC77E);
      case ExamCategory.rx:
        return const Color(0xFFFFA85C);
    }
  }

  IconData _getPackageIcon(ExamPackage package) {
    if (package.examIds.isEmpty) return Icons.inventory_2;
    
    final firstExamId = package.examIds.first;
    final exam = _allExams.firstWhere(
      (e) => e.id == firstExamId,
      orElse: () => ExamType(
        id: '',
        name: '',
        category: ExamCategory.rm,
        bodyDistrict: BodyDistrict.testa,
        description: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    
    switch (exam.category) {
      case ExamCategory.rm:
        return Icons.psychology;
      case ExamCategory.tac:
        return Icons.radar;
      case ExamCategory.eco:
        return Icons.waves;
      case ExamCategory.rx:
        return Icons.pan_tool;
    }
  }

  void _selectPackage(ExamPackage package) {
    // Naviga alla selezione località con il pacchetto
    context.push('/location-selection-package', extra: package);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEEF2F6),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF1F3D54)),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Pacchetti Esami',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1F3D54),
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Cerca pacchetto...',
                hintStyle: GoogleFonts.inter(color: Colors.grey),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
          
          // Content
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(_error!, style: GoogleFonts.inter(color: Colors.grey[600])),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _loadPackages,
              icon: const Icon(Icons.refresh),
              label: const Text('Riprova'),
            ),
          ],
        ),
      );
    }
    
    final packages = _filteredPackages;
    
    if (packages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty 
                ? 'Nessun pacchetto disponibile'
                : 'Nessun pacchetto trovato',
              style: GoogleFonts.inter(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            if (_searchQuery.isEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'I pacchetti saranno disponibili presto',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: packages.length,
      itemBuilder: (context, index) {
        final package = packages[index];
        return _PackageCard(
          package: package,
          examNames: _getExamNames(package.examIds),
          color: _getPackageColor(package),
          icon: _getPackageIcon(package),
          onTap: () => _selectPackage(package),
        );
      },
    );
  }
}

class _PackageCard extends StatelessWidget {
  final ExamPackage package;
  final String examNames;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _PackageCard({
    required this.package,
    required this.examNames,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(width: 16),
                
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        package.name,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1F3D54),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        examNames,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _InfoChip(
                            icon: Icons.timer_outlined,
                            label: '${package.totalDurationMinutes} min',
                            color: color,
                          ),
                          const SizedBox(width: 8),
                          _InfoChip(
                            icon: Icons.medical_services_outlined,
                            label: '${package.examIds.length} esami',
                            color: color,
                          ),
                          if (package.packagePrice != null) ...[
                            const SizedBox(width: 8),
                            _InfoChip(
                              icon: Icons.euro,
                              label: '${package.packagePrice!.toStringAsFixed(0)}',
                              color: color,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Arrow
                Icon(Icons.chevron_right, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
