import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:pose_app/core/models/pose_landmark.dart';
import 'package:pose_app/core/models/angle_result.dart';
import 'package:pose_app/core/theme/app_theme.dart';

/// 骨骼覆盖层 CustomPainter
class PoseOverlayPainter extends CustomPainter {
  final PoseFrame poseFrame;
  final FrameAngles frameAngles;
  final bool isFrontCamera;

  PoseOverlayPainter({
    required this.poseFrame,
    required this.frameAngles,
    this.isFrontCamera = false,
  });

  // 画笔
  final _bonePaint = Paint()
    ..color = AppColors.accent.withValues(alpha: 0.85)
    ..strokeWidth = 2.5
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;

  final _jointPaint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.fill;

  final _jointAccentPaint = Paint()
    ..color = AppColors.accent
    ..style = PaintingStyle.fill;

  @override
  void paint(Canvas canvas, Size size) {
    if (poseFrame.isEmpty) return;

    // 前置摄像头需要水平翻转坐标
    if (isFrontCamera) {
      canvas.save();
      canvas.scale(-1, 1);
      canvas.translate(-size.width, 0);
    }

    // 绘制骨骼连线
    for (final connection in kBoneConnections) {
      final a = poseFrame.getLandmark(connection[0]);
      final b = poseFrame.getLandmark(connection[1]);
      if (a == null || b == null) continue;
      if (!a.isReliable || !b.isReliable) continue;

      final p1 = Offset(a.x * size.width, a.y * size.height);
      final p2 = Offset(b.x * size.width, b.y * size.height);

      canvas.drawLine(p1, p2, _bonePaint);
    }

    // 绘制关键点
    for (final landmark in poseFrame.landmarks) {
      if (!landmark.isReliable) continue;

      final p = Offset(landmark.x * size.width, landmark.y * size.height);
      final isJoint = _isKeyJoint(landmark.type);
      final radius = isJoint ? 5.0 : 3.0;

      canvas.drawCircle(p, radius + 1, _bonePaint);
      canvas.drawCircle(p, radius, isJoint ? _jointAccentPaint : _jointPaint);
    }

    // 绘制角度标注
    _drawAngleAnnotation(canvas, size, JointAngleType.leftKnee,
        PoseLandmarkType.leftKnee);
    _drawAngleAnnotation(canvas, size, JointAngleType.rightKnee,
        PoseLandmarkType.rightKnee);

    if (isFrontCamera) canvas.restore();
  }

  void _drawAngleAnnotation(
    Canvas canvas,
    Size size,
    JointAngleType joint,
    PoseLandmarkType landmarkType,
  ) {
    final angle = frameAngles.getAngle(joint);
    final landmark = poseFrame.getLandmark(landmarkType);

    if (angle == null || landmark == null || !landmark.isReliable) return;

    final p = Offset(landmark.x * size.width, landmark.y * size.height);
    final text = angle.formattedAngle;
    final isGood = angle.angle <= 90;
    final color = isGood ? AppColors.accent : AppColors.warning;

    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          shadows: const [
            Shadow(color: Colors.black, blurRadius: 4, offset: Offset(1, 1)),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // 背景
    final bgRect = Rect.fromLTWH(
      p.dx + 8,
      p.dy - 10,
      textPainter.width + 6,
      textPainter.height + 4,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bgRect, const Radius.circular(4)),
      Paint()..color = Colors.black.withValues(alpha: 0.6),
    );

    textPainter.paint(canvas, Offset(p.dx + 11, p.dy - 8));
  }

  bool _isKeyJoint(PoseLandmarkType type) {
    return const {
      PoseLandmarkType.leftKnee,
      PoseLandmarkType.rightKnee,
      PoseLandmarkType.leftHip,
      PoseLandmarkType.rightHip,
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.rightShoulder,
      PoseLandmarkType.leftElbow,
      PoseLandmarkType.rightElbow,
    }.contains(type);
  }

  @override
  bool shouldRepaint(PoseOverlayPainter oldDelegate) {
    return oldDelegate.poseFrame != poseFrame ||
        oldDelegate.frameAngles != frameAngles;
  }
}

/// 角度数值卡片（底部面板用）
class AngleChip extends StatelessWidget {
  final String label;
  final double? angle;
  final Color? color;

  const AngleChip({
    super.key,
    required this.label,
    required this.angle,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = angle != null;
    final displayAngle = hasValue ? '${angle!.toStringAsFixed(0)}°' : '--';
    final chipColor = color ??
        (hasValue && angle! <= 90 ? AppColors.accent : AppColors.textSecondary);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primaryBg.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: chipColor.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            displayAngle,
            style: TextStyle(
              color: chipColor,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// 脉冲动画圆点（检测中指示器）
class PulsingDot extends StatefulWidget {
  final Color color;
  final double size;

  const PulsingDot({
    super.key,
    this.color = AppColors.accent,
    this.size = 8,
  });

  @override
  State<PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: _animation.value),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: _animation.value * 0.5),
                blurRadius: widget.size * 0.8,
                spreadRadius: widget.size * 0.2,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 扫描线动画（等待检测时的视觉提示）
class ScanlineOverlay extends StatefulWidget {
  const ScanlineOverlay({super.key});

  @override
  State<ScanlineOverlay> createState() => _ScanlineOverlayState();
}

class _ScanlineOverlayState extends State<ScanlineOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return CustomPaint(
          painter: _ScanlinePainter(_animation.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _ScanlinePainter extends CustomPainter {
  final double progress;
  _ScanlinePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * progress;
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.transparent,
        AppColors.accent.withValues(alpha: 0.6),
        Colors.transparent,
      ],
      stops: const [0, 0.5, 1],
    );

    final paint = Paint()
      ..shader = gradient.createShader(
        Rect.fromLTWH(0, y - 30, size.width, 60),
      )
      ..style = PaintingStyle.fill;

    canvas.drawRect(Rect.fromLTWH(0, y - 30, size.width, 60), paint);
  }

  @override
  bool shouldRepaint(_ScanlinePainter old) => old.progress != progress;
}

/// 角度圆弧指示器
class AngleArcWidget extends StatelessWidget {
  final double angle; // 0~180
  final Color color;
  final double size;

  const AngleArcWidget({
    super.key,
    required this.angle,
    required this.color,
    this.size = 60,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _AngleArcPainter(angle: angle, color: color),
        child: Center(
          child: Text(
            '${angle.toStringAsFixed(0)}°',
            style: TextStyle(
              color: color,
              fontSize: size * 0.22,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _AngleArcPainter extends CustomPainter {
  final double angle;
  final Color color;
  _AngleArcPainter({required this.angle, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    // 背景圆
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = color.withValues(alpha: 0.1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );

    // 角度弧
    final sweepAngle = (angle / 180) * math.pi;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_AngleArcPainter old) => old.angle != angle;
}
