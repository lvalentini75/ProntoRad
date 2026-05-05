import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:xraynow/models/exam_type.dart';
import 'package:xraynow/services/exam_service.dart';
import 'package:xraynow/theme.dart';
import 'package:xraynow/supabase/supabase_config.dart';

class ExamSelectionScreen extends StatefulWidget {
  final ExamCategory category;

  const ExamSelectionScreen({super.key, required this.category});

  @override
  State<ExamSelectionScreen> createState() => _ExamSelectionScreenState();
}

class _ExamSelectionScreenState extends State<ExamSelectionScreen> {
  final ExamService _examService = ExamService();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _indicationController = TextEditingController();
  
  List<ExamType> _allExams = [];
  List<ExamType> _filteredExams = [];
  String? _selectedDistrict;
  bool _isLoading = true;
  bool _isDropdownOpen = false;

  final List<String> _districts = ['Testa', 'Torace', 'Addome', 'Estremità'];

  @override
  void initState() {
    super.initState();
    _loadExams();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _indicationController.dispose();
    super.dispose();
  }

  Future<void> _loadExams() async {
    setState(() => _isLoading = true);
    try {
      final exams = await _examService.getExamsByCategory(widget.category);
      setState(() {
        _allExams = exams;
        _filteredExams = exams;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading exams: $e');
      setState(() => _isLoading = false);
    }
  }

  void _filterExams() {
    setState(() {
      _filteredExams = _allExams.where((exam) {
        final matchesSearch = _searchController.text.isEmpty ||
            exam.name.toLowerCase().contains(_searchController.text.toLowerCase());
        
        bool matchesDistrict = true;
        if (_selectedDistrict != null) {
          switch (_selectedDistrict) {
            case 'Testa':
              matchesDistrict = exam.bodyDistrict == BodyDistrict.testa;
              break;
            case 'Torace':
              matchesDistrict = exam.bodyDistrict == BodyDistrict.torace;
              break;
            case 'Addome':
              matchesDistrict = exam.bodyDistrict == BodyDistrict.addome;
              break;
            case 'Estremità':
              matchesDistrict = exam.bodyDistrict == BodyDistrict.estremita;
              break;
          }
        }
        return matchesSearch && matchesDistrict;
      }).toList();
    });
  }

  IconData _getExamIcon(ExamCategory category) {
    switch (category) {
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

  Color _getCategoryColor() {
    switch (widget.category) {
      case ExamCategory.rm:
        return LightModeColors.rmColor;
      case ExamCategory.tac:
        return LightModeColors.tacColor;
      case ExamCategory.eco:
        return LightModeColors.ecoColor;
      case ExamCategory.rx:
        return LightModeColors.rxColor;
    }
  }

  bool get _isUserLoggedIn => SupabaseConfig.auth.currentUser != null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F4FC),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
              decoration: const BoxDecoration(
                color: Color(0xFFE8F4FC),
              ),
              child: Column(
                children: [
                  // Back button and title
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => context.pop(),
                        child: Icon(
                          Icons.chevron_left,
                          color: LightModeColors.lightPrimary,
                          size: 32,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Prenota Esame',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F3D54),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Search field
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Cerca esame specifico...',
                        hintStyle: TextStyle(color: Colors.grey.shade400),
                        prefixIcon: Icon(Icons.search, color: Colors.grey.shade400),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      onChanged: (_) => _filterExams(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // District dropdown
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Seleziona Distretto Corporeo',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () {
                      setState(() => _isDropdownOpen = !_isDropdownOpen);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _selectedDistrict ?? 'Scegli distretto',
                            style: TextStyle(
                              fontSize: 15,
                              color: _selectedDistrict != null 
                                  ? Colors.black87 
                                  : Colors.grey.shade500,
                            ),
                          ),
                          Icon(
                            _isDropdownOpen ? Icons.expand_less : Icons.expand_more,
                            color: Colors.grey.shade400,
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Dropdown options
                  if (_isDropdownOpen)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: _districts.map((district) {
                          final isSelected = _selectedDistrict == district;
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedDistrict = _selectedDistrict == district ? null : district;
                                _isDropdownOpen = false;
                              });
                              _filterExams();
                            },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: isSelected 
                                    ? LightModeColors.lightPrimary.withValues(alpha: 0.1) 
                                    : Colors.transparent,
                              ),
                              child: Text(
                                district,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                  color: isSelected 
                                      ? LightModeColors.lightPrimary 
                                      : Colors.black87,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Indicazione all’esame',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _indicationController,
                      minLines: 2,
                      maxLines: 4,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText: 'Es. sospetta lesione meniscale, dolore persistente, referto clinico...',
                        hintStyle: TextStyle(color: Colors.grey.shade400),
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
                ],
              ),
            ),
            
            // Exam list
            Expanded(
              child: Container(
                color: Colors.white,
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredExams.isEmpty
                        ? Center(
                            child: Text(
                              'Nessun esame trovato',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          )
                        : ListView.separated(
                            padding: EdgeInsets.only(
                              top: 8,
                              bottom: _isUserLoggedIn ? 8 : 88,
                            ),
                            itemCount: _filteredExams.length,
                            separatorBuilder: (context, index) => Divider(
                              height: 1,
                              color: Colors.grey.shade200,
                            ),
                            itemBuilder: (context, index) {
                              final exam = _filteredExams[index];
                              return ExamListTile(
                                exam: exam,
                                icon: _getExamIcon(exam.category),
                                color: _getCategoryColor(),
                                onTap: () => context.push('/location-selection', extra: exam),
                              );
                            },
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ExamListTile extends StatelessWidget {
  final ExamType exam;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const ExamListTile({
    super.key,
    required this.exam,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 24),
      ),
      title: Text(
        exam.name,
        style: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 15,
          color: Colors.black87,
        ),
      ),
      subtitle: Text(
        exam.bodyDistrict.displayName,
        style: TextStyle(
          fontSize: 13,
          color: Colors.grey.shade500,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: Colors.grey.shade400,
      ),
      onTap: onTap,
    );
  }
}
