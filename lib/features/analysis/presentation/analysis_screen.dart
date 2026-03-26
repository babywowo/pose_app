import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pose_app/core/models/angle_result.dart';
import 'package:pose_app/core/models/exercise_state.dart';
import 'package:pose_app/core/models/workout_session.dart';
import 'package:pose_app/core/providers/pose_providers.dart';
import 'package:pose_app/core/repositories/workout_repository.dart';
import 'package:pose_app/core/theme/app_theme.dart';
import 'package:pose_app/features/camera/widgets/pose_overlay_painter.dart';

class AnalysisScreen extends ConsumerStatefulWidget {
  const AnalysisScreen({super.key});

  @override
  ConsumerState<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends ConsumerState<AnalysisScreen>
    with TickerProviderStateMixin {
  late AnimationController _countAnimController;
  late Animation<double> _countScaleAnim;
  int _lastRepCount = 0;
  bool _showDebugComparison = false;

  @override
  void initState() {
    super.initState();
    _countAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _countScaleAnim = Tween<double>(begin: 1.0, end: 1.4).animate(
      CurvedAnimation(parent: _countAnimController, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _countAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final exerciseState = ref.watch(exerciseStateProvider);
    final isAnalyzing = ref.watch(isAnalyzingProvider);
    final frameAngles = ref.watch(frameAnglesProvider);

    // 计数增加时触发弹跳动画
    if (exerciseState.repCount > _lastRepCount) {
      _lastRepCount = exerciseState.repCount;
      _countAnimController.forward(from: 0);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('深蹲分析'),
        centerTitle: true,
        actions: [
          if (isAnalyzing)
            TextButton.icon(
              onPressed: _saveSession,
              icon: const Icon(Icons.save_outlined, size: 18),
              label: const Text('保存'),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 大计数器卡片
            _CounterCard(
              repCount: exerciseState.repCount,
              currentPhase: exerciseState.currentPhase,
              phaseLabel: exerciseState.phaseLabel,
              scaleAnim: _countScaleAnim,
            ),
            const SizedBox(height: 16),

            // 反馈卡
            _FeedbackCard(
              state: exerciseState,
              isAnalyzing: isAnalyzing,
              phaseLabel: exerciseState.phaseLabel,
            ),
            const SizedBox(height: 16),

            // 关节角度仪表盘
            _AngleDashboard(frameAngles: frameAngles),
            const SizedBox(height: 16),

            // 控制按钮
            _ControlButtons(isAnalyzing: isAnalyzing),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Future<void> _saveSession() async {
    final exerciseState = ref.read(exerciseStateProvider);
    final analyzer = ref.read(exerciseAnalyzerProvider);

    if (exerciseState.repCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('没有可保存的记录')),
      );
      return;
    }

    if (analyzer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('分析器未初始化')),
      );
      return;
    }

    final session = WorkoutSession.start()
      ..totalReps = exerciseState.repCount
      ..reps = analyzer.getCompletedReps()
          .map((rep) => SquatRep(
                minKneeAngle: rep.metrics['minKneeAngle'] ?? 180,
                maxKneeAngle: rep.metrics['maxKneeAngle'] ?? 0,
                isGoodForm: rep.metrics['isGoodForm'] == 1.0,
                timestamp: rep.timestamp,
              ))
          .toList()
      ..goodFormReps = analyzer.getCompletedReps().where((r) => r.metrics['isGoodForm'] == 1.0).length
      ..endTime = DateTime.now();

    if (session.totalReps > 0) {
      final avgAngle = session.reps.isEmpty
          ? 0.0
          : session.reps.map((r) => r.minKneeAngle).reduce((a, b) => a + b) /
              session.reps.length;
      session.avgKneeAngle = avgAngle;
    }

    try {
      final repo = ref.read(workoutRepositoryProvider);
      await repo.saveSession(session);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已保存 ${exerciseState.repCount} 次深蹲记录'),
            backgroundColor: AppColors.accent,
          ),
        );
        ref.read(pipelineControllerProvider).resetCount();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('保存失败，请重试')),
        );
      }
    }
  }
}

/// 大计数器卡片
class _CounterCard extends StatelessWidget {
  final int repCount;
  final String currentPhase;
  final String phaseLabel;
  final Animation<double> scaleAnim;

  const _CounterCard({
    required this.repCount,
    required this.currentPhase,
    required this.phaseLabel,
    required this.scaleAnim,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.surfaceBg, AppColors.cardBg],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.accent.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            '深蹲次数',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          ScaleTransition(
            scale: scaleAnim,
            child: Text(
              '$repCount',
              style: const TextStyle(
                color: AppColors.accent,
                fontSize: 96,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _PhaseIndicator(currentPhase: currentPhase, phaseLabel: phaseLabel),
        ],
      ),
    );
  }
}

class _PhaseIndicator extends StatelessWidget {
  final String currentPhase;
  final String phaseLabel;
  const _PhaseIndicator({
    required this.currentPhase,
    required this.phaseLabel,
  });

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (currentPhase.toLowerCase()) {
      'standing' => ('站立', AppColors.textSecondary),
      'descending' => ('下蹲中↓', AppColors.warning),
      'bottom' => ('底部', AppColors.accent),
      'ascending' => ('起身中↑', AppColors.accent),
      _ => (phaseLabel, AppColors.textSecondary),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// 实时反馈卡片
class _FeedbackCard extends StatelessWidget {
  final ExerciseState state;
  final bool isAnalyzing;
  final String phaseLabel;

  const _FeedbackCard({
    required this.state,
    required this.isAnalyzing,
    required this.phaseLabel,
  });

  @override
  Widget build(BuildContext context) {
    if (!isAnalyzing) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline, color: AppColors.textSecondary, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                '切换到"摄像头"页开始检测，或点击下方"开始分析"',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
            ),
          ],
        ),
      );
    }

    final color = state.isGoodForm ? AppColors.accent : AppColors.warning;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
        children: [
          Icon(
            state.isGoodForm ? Icons.check_circle_outline : Icons.info_outline,
            color: color,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              state.feedback.isEmpty ? phaseLabel : state.feedback,
              style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 角度仪表盘
class _AngleDashboard extends StatelessWidget {
  final FrameAngles frameAngles;
  const _AngleDashboard({required this.frameAngles});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.accent.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '关节角度',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildArcItem('左膝',
                  frameAngles.getAngleValue(JointAngleType.leftKnee)),
              _buildArcItem('右膝',
                  frameAngles.getAngleValue(JointAngleType.rightKnee)),
              _buildArcItem(
                  '左髋', frameAngles.getAngleValue(JointAngleType.leftHip)),
              _buildArcItem(
                  '右髋', frameAngles.getAngleValue(JointAngleType.rightHip)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildArcItem(String label, double? angle) {
    final v = angle ?? 180.0;
    final color = v <= 90
        ? AppColors.accent
        : v <= 120
            ? AppColors.warning
            : AppColors.textSecondary;

    return Column(
      children: [
        AngleArcWidget(angle: v, color: color, size: 64),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

/// 控制按钮组
class _ControlButtons extends ConsumerWidget {
  final bool isAnalyzing;
  const _ControlButtons({required this.isAnalyzing});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              ref.read(pipelineControllerProvider).toggleAnalysis();
            },
            icon: Icon(
              isAnalyzing
                  ? Icons.stop_circle_outlined
                  : Icons.play_circle_outline,
              size: 20,
            ),
            label: Text(isAnalyzing ? '停止分析' : '开始分析'),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  isAnalyzing ? AppColors.warning : AppColors.accent,
              foregroundColor:
                  isAnalyzing ? Colors.black : AppColors.primaryBg,
              minimumSize: const Size(0, 48),
            ),
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          onPressed: () {
            ref.read(pipelineControllerProvider).resetCount();
          },
          icon: const Icon(Icons.restart_alt, size: 18),
          label: const Text('重置'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
            side: const BorderSide(color: AppColors.textSecondary),
            minimumSize: const Size(0, 48),
          ),
        ),
      ],
    );
  }
}
