import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:xraynow/models/exam_type.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:xraynow/supabase/supabase_config.dart';
import 'package:xraynow/theme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  bool get _isUserLoggedIn => SupabaseConfig.auth.currentUser != null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEEF2F6),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 24),
                    // EOC Logo
                    Image.asset(
                      'assets/images/logo_EOC.png',
                      height: 160,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 20),
                    // Page title
                    Text(
                      'Prenota il tuo Esame',
                      style: GoogleFonts.inter(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1F3D54),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Seleziona il tipo di esame.',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFF64748B),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          children: [
                            GridView.count(
                              crossAxisCount: 2,
                              mainAxisSpacing: 20,
                              crossAxisSpacing: 20,
                              childAspectRatio: 0.92,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              children: [
                                ExamTypeCard(
                                  title: 'RM (Risonanza)',
                                  color: const Color(0xFF5B7FB7),
                                  iconPainter: RMIconPainter(),
                                  assetIconPath: 'assets/rm_icon.png',
                                  onTap: () => context.push('/exam-selection',
                                      extra: ExamCategory.rm),
                                ),
                                ExamTypeCard(
                                  title: 'TAC (Tomografia)',
                                  color: const Color(0xFF48BDC5),
                                  iconPainter: TACIconPainter(),
                                  assetIconPath: 'assets/tac_icon.png',
                                  onTap: () => context.push('/exam-selection',
                                      extra: ExamCategory.tac),
                                ),
                                ExamTypeCard(
                                  title: 'ECO (Ecografia)',
                                  color: const Color(0xFF7AC77E),
                                  iconPainter: ECOIconPainter(),
                                  assetIconPath: 'assets/eco_icon.png',
                                  onTap: () => context.push('/exam-selection',
                                      extra: ExamCategory.eco),
                                ),
                                ExamTypeCard(
                                  title: 'RX (Radiografia)',
                                  color: const Color(0xFFFFA85C),
                                  iconPainter: RXIconPainter(),
                                  assetIconPath: 'assets/rx_icon.png',
                                  onTap: () => context.push('/exam-selection',
                                      extra: ExamCategory.rx),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            // Pacchetti Esami Section
                            _PackagesButton(
                              onTap: () => context.push('/packages'),
                              label: 'Prenotazione esami multipli',
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Login/Signup banner (solo se non loggato) - appare sopra la barra di navigazione
            if (!_isUserLoggedIn)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: LightModeColors.lightPrimary,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Accedi o registrati per prenotare',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => context.push('/login'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(
                                    color: Colors.white, width: 1.5),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Text('Accedi'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: () => context.push('/signup'),
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: LightModeColors.lightPrimary,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Text('Registrati'),
                            ),
                          ),
                        ],
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
}

class ExamTypeCard extends StatelessWidget {
  final String title;
  final Color color;
  final CustomPainter iconPainter;
  final String? assetIconPath;
  final VoidCallback onTap;

  const ExamTypeCard({
    super.key,
    required this.title,
    required this.color,
    required this.iconPainter,
    this.assetIconPath,
    required this.onTap,
  });

  // Increased icon size by 35% (from 120 to 162)
  static const double kIconSize = 162;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: Center(
              child: SizedBox(
                width: kIconSize,
                height: kIconSize,
                child: assetIconPath != null
                    ? Image.asset(
                        assetIconPath!,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          debugPrint('Failed to load asset image: ' +
                              assetIconPath! +
                              ' => ' +
                              error.toString());
                          return CustomPaint(
                            painter: iconPainter,
                            size: const Size(kIconSize, kIconSize),
                          );
                        },
                      )
                    : CustomPaint(
                        painter: iconPainter,
                        size: const Size(kIconSize, kIconSize),
                      ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1F3D54),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// RM Icon - Magnet with medical star
class RMIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Main magnet shape (horseshoe/U-shape)
    final magnetPaint = Paint()
      ..color = const Color(0xFF2D4A7C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11
      ..strokeCap = StrokeCap.round;

    final magnetPath = Path();
    magnetPath.moveTo(cx - 35, cy - 25);
    magnetPath.lineTo(cx - 35, cy + 20);
    magnetPath.quadraticBezierTo(cx - 35, cy + 35, cx - 15, cy + 35);
    magnetPath.lineTo(cx + 15, cy + 35);
    magnetPath.quadraticBezierTo(cx + 35, cy + 35, cx + 35, cy + 20);
    magnetPath.lineTo(cx + 35, cy - 25);
    canvas.drawPath(magnetPath, magnetPaint);

    // Medical star/emblem in center
    final starPaint = Paint()
      ..color = const Color(0xFF2D4A7C)
      ..style = PaintingStyle.fill;

    final starSize = 28.0;
    for (int i = 0; i < 4; i++) {
      final angle = (i * math.pi / 2) + math.pi / 4;
      final x1 = cx + math.cos(angle) * starSize * 0.4;
      final y1 = cy + math.sin(angle) * starSize * 0.4;
      final x2 = cx + math.cos(angle) * starSize * 0.15;
      final y2 = cy + math.sin(angle) * starSize * 0.15;

      canvas.drawPath(
        Path()
          ..moveTo(x2 - 3, y2)
          ..lineTo(x1 - 3, y1)
          ..lineTo(x1 + 3, y1)
          ..lineTo(x2 + 3, y2)
          ..close(),
        starPaint,
      );
    }

    // Center circle
    canvas.drawCircle(Offset(cx, cy), 8, starPaint);
    canvas.drawCircle(Offset(cx, cy), 6, Paint()..color = Colors.white);

    // Brain outline at top
    final brainPaint = Paint()
      ..color = const Color(0xFF2D4A7C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final brainPath = Path();
    brainPath.moveTo(cx - 20, cy - 30);
    brainPath.cubicTo(cx - 25, cy - 38, cx - 15, cy - 45, cx, cy - 42);
    brainPath.cubicTo(cx + 15, cy - 45, cx + 25, cy - 38, cx + 20, cy - 30);
    canvas.drawPath(brainPath, brainPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// TAC Icon - CT Scanner
class TACIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Outer ring of CT scanner
    final outerPaint = Paint()
      ..color = const Color(0xFF2B7A7F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10;
    canvas.drawCircle(Offset(cx, cy), 45, outerPaint);

    // Inner ring fill
    final innerFillPaint = Paint()
      ..color = const Color(0xFF2B7A7F).withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), 38, innerFillPaint);

    // Inner ring (the hole)
    final innerPaint = Paint()
      ..color = const Color(0xFF2B7A7F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(Offset(cx, cy), 25, innerPaint);

    // Patient silhouette in the middle
    final patientPaint = Paint()
      ..color = const Color(0xFF2B7A7F)
      ..style = PaintingStyle.fill;

    // Head
    canvas.drawCircle(Offset(cx, cy - 6), 9, patientPaint);

    // Body/torso
    final bodyPath = Path();
    bodyPath.moveTo(cx - 13, cy + 5);
    bodyPath.quadraticBezierTo(cx - 16, cy + 10, cx - 12, cy + 16);
    bodyPath.lineTo(cx + 12, cy + 16);
    bodyPath.quadraticBezierTo(cx + 16, cy + 10, cx + 13, cy + 5);
    bodyPath.close();
    canvas.drawPath(bodyPath, patientPaint);

    // Top marker/handle
    final markerPaint = Paint()
      ..color = const Color(0xFF2B7A7F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(cx, cy - 50),
      Offset(cx, cy - 42),
      markerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ECO Icon - Ultrasound probe with waves
class ECOIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    final mainColor = const Color(0xFF4F9A5E);

    // Ultrasound probe handle
    final handlePaint = Paint()
      ..color = mainColor
      ..style = PaintingStyle.fill;

    final handlePath = Path();
    handlePath.moveTo(cx - 32, cy + 38);
    handlePath.lineTo(cx - 18, cy + 12);
    handlePath.lineTo(cx - 8, cy + 18);
    handlePath.lineTo(cx - 22, cy + 44);
    handlePath.close();
    canvas.drawPath(handlePath, handlePaint);

    // Probe head (rounded transducer)
    final probePaint = Paint()
      ..color = mainColor
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(cx - 13, cy + 10), 14, probePaint);

    // Probe head outline
    final outlinePaint = Paint()
      ..color = mainColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(Offset(cx - 13, cy + 10), 14, outlinePaint);

    // Sound waves emanating from probe (3 arcs)
    for (int i = 0; i < 3; i++) {
      final radius = 25.0 + (i * 16);
      final wavePaint = Paint()
        ..color = mainColor.withValues(alpha: 0.7 - (i * 0.18))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5 - (i * 0.6)
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCenter(
            center: Offset(cx - 13, cy + 10),
            width: radius * 2,
            height: radius * 2),
        -math.pi * 0.55,
        -math.pi * 0.5,
        false,
        wavePaint,
      );
    }

    // Tissue/organ being scanned (stylized kidney/organ shape)
    final organPaint = Paint()
      ..color = mainColor.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    final organPath = Path();
    organPath.moveTo(cx + 20, cy - 15);
    organPath.cubicTo(cx + 35, cy - 20, cx + 42, cy - 5, cx + 38, cy + 8);
    organPath.cubicTo(cx + 35, cy + 15, cx + 25, cy + 12, cx + 20, cy + 5);
    organPath.cubicTo(cx + 18, cy - 2, cx + 18, cy - 10, cx + 20, cy - 15);
    organPath.close();
    canvas.drawPath(organPath, organPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// RX Icon - Hand X-ray skeleton
class RXIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    final mainColor = const Color(0xFFD67D3E);

    final bonePaint = Paint()
      ..color = mainColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final thinBonePaint = Paint()
      ..color = mainColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    // Wrist bones (carpal bones represented as short lines)
    canvas.drawLine(
        Offset(cx - 14, cy + 38), Offset(cx - 12, cy + 48), bonePaint);
    canvas.drawLine(
        Offset(cx - 5, cy + 38), Offset(cx - 3, cy + 48), bonePaint);
    canvas.drawLine(
        Offset(cx + 4, cy + 38), Offset(cx + 3, cy + 48), bonePaint);
    canvas.drawLine(
        Offset(cx + 13, cy + 38), Offset(cx + 12, cy + 48), bonePaint);

    // Metacarpal bones (palm bones) - 5 bones
    final bonePositions = [-16.0, -8.0, 0.0, 8.0, 16.0];

    for (int i = 0; i < 5; i++) {
      final x = cx + bonePositions[i];
      canvas.drawLine(Offset(x, cy + 30), Offset(x, cy + 5), bonePaint);

      // Joint circles at metacarpophalangeal joints
      canvas.drawCircle(
          Offset(x, cy + 5),
          3.5,
          Paint()
            ..color = mainColor
            ..style = PaintingStyle.fill);
    }

    // Fingers (phalanges) - anatomically correct with proper angles
    final fingerLengths = [22.0, 32.0, 36.0, 32.0, 24.0]; // Thumb to pinky
    final fingerAngles = [-0.45, -0.18, 0.0, 0.18, 0.4]; // Natural spread

    for (int i = 0; i < 5; i++) {
      final baseX = cx + bonePositions[i];
      final baseY = cy + 5;
      final angle = fingerAngles[i];
      final length = fingerLengths[i];

      // Proximal phalanx (first bone segment)
      final p1x = baseX + math.sin(angle) * (length * 0.42);
      final p1y = baseY - math.cos(angle) * (length * 0.42);
      canvas.drawLine(Offset(baseX, baseY), Offset(p1x, p1y), thinBonePaint);
      canvas.drawCircle(
          Offset(p1x, p1y),
          2.8,
          Paint()
            ..color = mainColor
            ..style = PaintingStyle.fill);

      // Middle phalanx
      final p2x = p1x + math.sin(angle) * (length * 0.36);
      final p2y = p1y - math.cos(angle) * (length * 0.36);
      canvas.drawLine(Offset(p1x, p1y), Offset(p2x, p2y), thinBonePaint);
      canvas.drawCircle(
          Offset(p2x, p2y),
          2.2,
          Paint()
            ..color = mainColor
            ..style = PaintingStyle.fill);

      // Distal phalanx (fingertip) - all fingers have this
      if (i != 0) {
        final p3x = p2x + math.sin(angle) * (length * 0.28);
        final p3y = p2y - math.cos(angle) * (length * 0.28);
        canvas.drawLine(Offset(p2x, p2y), Offset(p3x, p3y), thinBonePaint);
        canvas.drawCircle(
            Offset(p3x, p3y),
            1.8,
            Paint()
              ..color = mainColor
              ..style = PaintingStyle.fill);
      }
    }

    // Wrist joint connection lines
    canvas.drawLine(
        Offset(cx - 20, cy + 35),
        Offset(cx + 20, cy + 35),
        Paint()
          ..color = mainColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Bottone per accedere ai pacchetti esami
class _PackagesButton extends StatelessWidget {
  final VoidCallback onTap;
  final String label;

  const _PackagesButton({required this.onTap, required this.label});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              LightModeColors.lightPrimary,
              LightModeColors.lightPrimary.withValues(alpha: 0.85),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: LightModeColors.lightPrimary.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.inventory_2_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pacchetti esami combinati',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.white.withValues(alpha: 0.8),
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}
