import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pose_app/core/models/angle_result.dart';
import 'package:pose_app/core/models/pose_landmark.dart';
import 'package:pose_app/core/services/angle_calculator.dart';
import 'package:pose_app/core/services/camera_service.dart';
import 'package:pose_app/core/services/pose_detector_service.dart';
import 'package:pose_app/core/services/squat_counter.dart';

// ──────────────────────────────────────────────────────────────────────────────
// 摄像头 Provider
// ──────────────────────────────────────────────────────────────────────────────

/// 摄像头状态 — 直接派生自 CameraNotifier，自动响应变化
final cameraStatusProvider = Provider<CameraStatus>((ref) {
  return ref.watch(cameraNotifierProvider).status;
});

/// 摄像头控制器 — 自动响应切换
final cameraControllerProvider = Provider<CameraController?>((ref) {
  return ref.watch(cameraNotifierProvider).controller;
});

// ──────────────────────────────────────────────────────────────────────────────
// 姿态检测 Provider
// ──────────────────────────────────────────────────────────────────────────────

/// 当前姿态帧
final poseFrameProvider = StateProvider<PoseFrame>((ref) {
  return PoseFrame(landmarks: [], timestamp: DateTime.now());
});

/// 当前帧角度
final frameAnglesProvider = StateProvider<FrameAngles>((ref) {
  return FrameAngles.empty();
});

// ──────────────────────────────────────────────────────────────────────────────
// 深蹲分析 Provider
// ──────────────────────────────────────────────────────────────────────────────

/// 深蹲计数器实例（保持状态）
final squatCounterProvider = Provider<SquatCounter>((ref) {
  return SquatCounter();
});

/// 深蹲计数状态
final squatStateProvider = StateProvider<SquatCounterState>((ref) {
  return SquatCounterState.initial;
});

/// 分析是否正在进行
final isAnalyzingProvider = StateProvider<bool>((ref) => false);

// ──────────────────────────────────────────────────────────────────────────────
// 调试状态 Provider（生产环境可关闭）
// ──────────────────────────────────────────────────────────────────────────────

/// 调试面板开关
final debugOverlayEnabledProvider = StateProvider<bool>((ref) => true);

/// 调试统计数据
class DebugStats {
  final int frameCount;       // 收到的摄像头帧总数
  final int inferenceCount;   // ML Kit 完成推理次数
  final int poseCount;        // 检测到有人体的次数
  final int landmarkCount;    // 最新帧关键点数
  final String lastError;     // 最后一条错误
  final double fps;           // 近似帧率
  final int imageFormat;      // 摄像头帧格式 raw 值（35=YUV_420_888）
  final bool isAnalyzing;     // 深蹲分析是否开启
  final double? leftKnee;     // 左膝角度（调试用）
  final double? rightKnee;    // 右膝角度（调试用）
  final String squatPhase;    // 深蹲阶段（STAND/DESC/BOT/ASC）
  final double? minAngle;     // 本次下蹲最小角度（调试用）

  const DebugStats({
    this.frameCount = 0,
    this.inferenceCount = 0,
    this.poseCount = 0,
    this.landmarkCount = 0,
    this.lastError = '',
    this.fps = 0,
    this.imageFormat = 0,
    this.isAnalyzing = false,
    this.leftKnee,
    this.rightKnee,
    this.squatPhase = '-',
    this.minAngle,
  });

  DebugStats copyWith({
    int? frameCount,
    int? inferenceCount,
    int? poseCount,
    int? landmarkCount,
    String? lastError,
    double? fps,
    int? imageFormat,
    bool? isAnalyzing,
    double? leftKnee,
    double? rightKnee,
    String? squatPhase,
    double? minAngle,
  }) {
    return DebugStats(
      frameCount: frameCount ?? this.frameCount,
      inferenceCount: inferenceCount ?? this.inferenceCount,
      poseCount: poseCount ?? this.poseCount,
      landmarkCount: landmarkCount ?? this.landmarkCount,
      lastError: lastError ?? this.lastError,
      fps: fps ?? this.fps,
      imageFormat: imageFormat ?? this.imageFormat,
      isAnalyzing: isAnalyzing ?? this.isAnalyzing,
      leftKnee: leftKnee ?? this.leftKnee,
      rightKnee: rightKnee ?? this.rightKnee,
      squatPhase: squatPhase ?? this.squatPhase,
      minAngle: minAngle ?? this.minAngle,
    );
  }
}

final debugStatsProvider = StateProvider<DebugStats>((ref) => const DebugStats());

// ──────────────────────────────────────────────────────────────────────────────
// 主控制器：把所有服务串联在一起
// ──────────────────────────────────────────────────────────────────────────────

/// 管道控制器 - 负责初始化摄像头、启动帧流、驱动 ML 处理
class PipelineController {
  final Ref _ref;
  StreamSubscription<CameraImage>? _frameSub;
  StreamSubscription<PoseFrame>? _poseSub;

  final _angleCalc = const AngleCalculator();

  // 帧率计算
  int _fpsFrameCount = 0;
  DateTime _fpsTimer = DateTime.now();

  PipelineController(this._ref);

  CameraNotifier get _cameraSvc => _ref.read(cameraNotifierProvider.notifier);
  PoseDetectorService get _poseService =>
      _ref.read(poseDetectorServiceProvider);
  SquatCounter get _squatCounter => _ref.read(squatCounterProvider);

  /// 初始化摄像头
  Future<void> initCamera() async {
    await _cameraSvc.initialize();

    // 把底层错误接入调试面板
    _poseService.onError = (msg) {
      final old = _ref.read(debugStatsProvider);
      _ref.read(debugStatsProvider.notifier).state =
          old.copyWith(lastError: msg);
    };

    // 监听姿态帧 → 更新 providers
    _poseSub?.cancel();
    _poseSub = _poseService.poseStream.listen((frame) {
      _ref.read(poseFrameProvider.notifier).state = frame;

      // 调试：更新推理次数 + 关键点数
      final old = _ref.read(debugStatsProvider);
      _ref.read(debugStatsProvider.notifier).state = old.copyWith(
        inferenceCount: old.inferenceCount + 1,
        poseCount: frame.isEmpty ? old.poseCount : old.poseCount + 1,
        landmarkCount: frame.landmarks.length,
      );

      if (!frame.isEmpty) {
        final angles = _angleCalc.calculate(frame);
        _ref.read(frameAnglesProvider.notifier).state = angles;

        // 更新膝角到调试面板
        final analyzing = _ref.read(isAnalyzingProvider);
        final leftKnee = angles.getAngleValue(JointAngleType.leftKnee);
        final rightKnee = angles.getAngleValue(JointAngleType.rightKnee);
        final oldStats = _ref.read(debugStatsProvider);

        if (analyzing) {
          final squatState = _squatCounter.update(angles);
          _ref.read(squatStateProvider.notifier).state = squatState;

          // 将深蹲阶段和最小角度同步到调试面板
          String phaseStr = '-';
          switch (squatState.phase) {
            case SquatPhase.standing:
              phaseStr = 'STAND';
              break;
            case SquatPhase.descending:
              phaseStr = 'DESC';
              break;
            case SquatPhase.bottom:
              phaseStr = 'BOT';
              break;
            case SquatPhase.ascending:
              phaseStr = 'ASC';
              break;
          }

          _ref.read(debugStatsProvider.notifier).state = oldStats.copyWith(
            isAnalyzing: analyzing,
            leftKnee: leftKnee,
            rightKnee: rightKnee,
            squatPhase: phaseStr,
            minAngle: (squatState.leftKneeAngle + squatState.rightKneeAngle) / 2,
          );
        } else {
          _ref.read(debugStatsProvider.notifier).state = oldStats.copyWith(
            isAnalyzing: analyzing,
            leftKnee: leftKnee,
            rightKnee: rightKnee,
            squatPhase: '-',
            minAngle: null,
          );
        }
      }
    }, onError: (dynamic e) {
      final old = _ref.read(debugStatsProvider);
      _ref.read(debugStatsProvider.notifier).state =
          old.copyWith(lastError: 'poseStream: $e');
    });
  }

  /// 开始检测
  Future<void> startDetection() async {
    await _cameraSvc.startImageStream();

    final controller = _cameraSvc.controller;
    if (controller == null) return;

    final sensorOrientation = controller.description.sensorOrientation;
    final isFront = _cameraSvc.isFrontCamera;

    // 重置调试计数
    _fpsFrameCount = 0;
    _fpsTimer = DateTime.now();
    _ref.read(debugStatsProvider.notifier).state = const DebugStats();

    await _frameSub?.cancel();
    int frameCount = 0;
    _frameSub = _cameraSvc.frameStream.listen((image) {
      frameCount++;
      _fpsFrameCount++;

      // 第一帧记录图像格式
      if (frameCount == 1) {
        final old = _ref.read(debugStatsProvider);
        _ref.read(debugStatsProvider.notifier).state =
            old.copyWith(imageFormat: image.format.raw);
      }

      // 每秒计算一次 FPS
      final now = DateTime.now();
      final elapsed = now.difference(_fpsTimer).inMilliseconds;
      if (elapsed >= 1000) {
        final fps = _fpsFrameCount * 1000.0 / elapsed;
        _fpsFrameCount = 0;
        _fpsTimer = now;
        final old = _ref.read(debugStatsProvider);
        _ref.read(debugStatsProvider.notifier).state =
            old.copyWith(frameCount: frameCount, fps: fps);
      }

      if (frameCount <= 3) {
        debugPrint(
          '[Pipeline] frame #$frameCount '
          '${image.width}x${image.height} '
          'planes=${image.planes.length} '
          'format=${image.format.raw} '
          'sensorOrientation=$sensorOrientation isFront=$isFront',
        );
      }

      _poseService.processFrame(
        image,
        sensorOrientation,
        isFrontCamera: isFront,
      );
    });
  }

  /// 停止检测
  Future<void> stopDetection() async {
    await _frameSub?.cancel();
    _frameSub = null;
    await _cameraSvc.stopImageStream();
  }

  /// 切换摄像头
  Future<void> switchCamera() async {
    final wasStreaming = _cameraSvc.isStreaming;
    if (wasStreaming) {
      await _frameSub?.cancel();
      _frameSub = null;
    }
    await _cameraSvc.switchCamera();
    if (wasStreaming) {
      await startDetection();
    }
  }

  /// 开始/停止分析（深蹲计数）
  void toggleAnalysis() {
    final current = _ref.read(isAnalyzingProvider);
    if (!current) {
      _squatCounter.reset();
      _ref.read(squatStateProvider.notifier).state = SquatCounterState.initial;
    }
    _ref.read(isAnalyzingProvider.notifier).state = !current;
  }

  /// 重置计数
  void resetCount() {
    _squatCounter.reset();
    _ref.read(squatStateProvider.notifier).state = SquatCounterState.initial;
  }

  Future<void> dispose() async {
    await _frameSub?.cancel();
    await _poseSub?.cancel();
  }
}

final pipelineControllerProvider = Provider<PipelineController>((ref) {
  final controller = PipelineController(ref);
  ref.onDispose(controller.dispose);
  return controller;
});
