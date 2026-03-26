import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pose_app/core/models/angle_result.dart';
import 'package:pose_app/core/providers/pose_providers.dart';
import 'package:pose_app/core/services/camera_service.dart';
import 'package:pose_app/core/theme/app_theme.dart';
import 'package:pose_app/features/camera/widgets/pose_overlay_painter.dart';
import 'package:pose_app/features/camera/widgets/debug_overlay.dart';

class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _init();
    });
  }

  Future<void> _init() async {
    final pipeline = ref.read(pipelineControllerProvider);
    await pipeline.initCamera();
    if (mounted) {
      await pipeline.startDetection();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final pipeline = ref.read(pipelineControllerProvider);
    if (state == AppLifecycleState.inactive) {
      pipeline.stopDetection();
    } else if (state == AppLifecycleState.resumed) {
      pipeline.startDetection();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 直接 watch CameraNotifier 的完整状态，保证 controller 变化时 UI 重建
    final camState = ref.watch(cameraNotifierProvider);
    final poseFrame = ref.watch(poseFrameProvider);
    final frameAngles = ref.watch(frameAnglesProvider);
    final debugEnabled = ref.watch(debugOverlayEnabledProvider);

    final status = camState.status;
    final controller = camState.controller;
    final isFront = camState.isFrontCamera;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(context, status),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 摄像头预览
          _buildCameraPreview(context, controller),

          // 骨骼覆盖层
          if (status == CameraStatus.streaming && !poseFrame.isEmpty)
            Positioned.fill(
              child: CustomPaint(
                painter: PoseOverlayPainter(
                  poseFrame: poseFrame,
                  frameAngles: frameAngles,
                  isFrontCamera: isFront,
                ),
              ),
            ),

          // 扫描线（等待人体出现时）
          if (status == CameraStatus.streaming && poseFrame.isEmpty)
            const Positioned.fill(child: ScanlineOverlay()),

          // 底部角度面板
          if (status == CameraStatus.streaming)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildBottomPanel(frameAngles),
            ),

          // 调试面板（右上角浮层）
          if (debugEnabled)
            const Positioned(
              top: 80,
              right: 8,
              child: DebugOverlay(),
            ),

          // 初始化中遮罩
          if (status == CameraStatus.uninitialized ||
              status == CameraStatus.initializing)
            _buildLoadingOverlay(),

          // 错误提示
          if (status == CameraStatus.error) _buildErrorOverlay(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, CameraStatus status) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status == CameraStatus.streaming) ...[
            const PulsingDot(),
            const SizedBox(width: 8),
          ],
          const Text(
            'PoseApp',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 20,
            ),
          ),
        ],
      ),
      actions: [
        // 调试开关
        IconButton(
          icon: Icon(
            Icons.bug_report_outlined,
            color: ref.watch(debugOverlayEnabledProvider)
                ? AppColors.accent
                : Colors.white54,
          ),
          onPressed: () {
            ref.read(debugOverlayEnabledProvider.notifier).state =
                !ref.read(debugOverlayEnabledProvider);
          },
          tooltip: '调试面板',
        ),
        IconButton(
          icon: const Icon(Icons.flip_camera_android_outlined,
              color: Colors.white),
          onPressed: status == CameraStatus.ready ||
                  status == CameraStatus.streaming
              ? () => ref.read(pipelineControllerProvider).switchCamera()
              : null,
          tooltip: '切换摄像头',
        ),
      ],
    );
  }

  Widget _buildCameraPreview(
      BuildContext context, CameraController? controller) {
    if (controller == null || !controller.value.isInitialized) {
      return Container(color: Colors.black);
    }

    // 关键修复：竖屏下需要用 previewSize 而不是 aspectRatio
    // camera 的 aspectRatio = previewWidth / previewHeight（横向比）
    // 竖屏显示时需要取倒数
    final screenSize = MediaQuery.of(context).size;
    final previewAspectRatio = controller.value.aspectRatio; // 宽/高（横向）
    // 竖屏: 屏幕 width / height = 0.46 左右，预览横向比 = 1.78
    // 需要把预览旋转展示，所以实际比例 = 1 / previewAspectRatio
    final double displayAspectRatio = 1.0 / previewAspectRatio;

    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: screenSize.width,
          height: screenSize.width / displayAspectRatio,
          child: CameraPreview(controller),
        ),
      ),
    );
  }

  Widget _buildBottomPanel(FrameAngles frameAngles) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withValues(alpha: 0.85),
            Colors.transparent,
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              AngleChip(
                label: '左膝',
                angle: frameAngles.getAngleValue(JointAngleType.leftKnee),
                color: _angleColor(
                    frameAngles.getAngleValue(JointAngleType.leftKnee)),
              ),
              AngleChip(
                label: '右膝',
                angle: frameAngles.getAngleValue(JointAngleType.rightKnee),
                color: _angleColor(
                    frameAngles.getAngleValue(JointAngleType.rightKnee)),
              ),
              AngleChip(
                label: '左髋',
                angle: frameAngles.getAngleValue(JointAngleType.leftHip),
              ),
              AngleChip(
                label: '右髋',
                angle: frameAngles.getAngleValue(JointAngleType.rightHip),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _StartAnalysisButton(),
        ],
      ),
    );
  }

  Color? _angleColor(double? angle) {
    if (angle == null) return null;
    if (angle <= 90) return AppColors.accent;
    if (angle <= 120) return AppColors.warning;
    return AppColors.textSecondary;
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.accent),
            SizedBox(height: 16),
            Text(
              '正在初始化摄像头…',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorOverlay() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam_off, size: 56, color: AppColors.error),
            const SizedBox(height: 16),
            const Text(
              '无法访问摄像头',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              '请检查摄像头权限后重试',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                final pipeline = ref.read(pipelineControllerProvider);
                await pipeline.initCamera();
                await pipeline.startDetection();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 开始分析按钮（独立 ConsumerWidget 避免整体重建）
class _StartAnalysisButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAnalyzing = ref.watch(isAnalyzingProvider);
    final exerciseState = ref.watch(exerciseStateProvider);

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
            label: Text(
              isAnalyzing
                  ? '停止分析  ·  ${exerciseState.repCount} 次'
                  : '开始深蹲分析',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  isAnalyzing ? AppColors.warning : AppColors.accent,
              foregroundColor:
                  isAnalyzing ? Colors.black : AppColors.primaryBg,
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        if (isAnalyzing) ...[
          const SizedBox(width: 8),
          IconButton(
            onPressed: () {
              ref.read(pipelineControllerProvider).resetCount();
            },
            icon: const Icon(Icons.restart_alt, color: Colors.white),
            tooltip: '重置',
            style: IconButton.styleFrom(
              backgroundColor: AppColors.surfaceBg,
            ),
          ),
        ],
      ],
    );
  }
}
