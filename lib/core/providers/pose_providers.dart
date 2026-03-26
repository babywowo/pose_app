import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pose_app/core/models/angle_result.dart';
import 'package:pose_app/core/models/pose_landmark.dart';
import 'package:pose_app/core/models/exercise_state.dart';
import 'package:pose_app/core/services/angle_calculator.dart';
import 'package:pose_app/core/services/camera_service.dart';
import 'package:pose_app/core/services/pose_detector_service.dart';
import 'package:pose_app/core/services/squat_counter.dart';
import 'package:pose_app/core/services/exercise_analyzer.dart';
import 'package:pose_app/core/services/squat_analyzer.dart';

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
/// @deprecated 使用 exerciseAnalyzerProvider 替代
/// 迁移指南：使用 exerciseAnalyzerProvider 获取通用分析器实例
@Deprecated('使用 exerciseAnalyzerProvider 替代')
final squatCounterProvider = Provider<SquatCounter>((ref) {
  return SquatCounter();
});

/// 深蹲计数状态
/// @deprecated 使用 exerciseStateProvider 替代
/// 迁移指南：使用 exerciseStateProvider 获取通用动作状态
@Deprecated('使用 exerciseStateProvider 替代')
final squatStateProvider = StateProvider<SquatCounterState>((ref) {
  return SquatCounterState.initial;
});

/// 分析是否正在进行
final isAnalyzingProvider = StateProvider<bool>((ref) => false);

// ──────────────────────────────────────────────────────────────────────────────
// 通用动作分析 Provider
// ──────────────────────────────────────────────────────────────────────────────

/// 当前激活的动作分析器（通用）
final exerciseAnalyzerProvider = StateProvider<ExerciseAnalyzer?>((ref) => null);

/// 当前动作状态（通用）
final exerciseStateProvider = StateProvider<ExerciseState>((ref) =>
  ExerciseState.initial(exerciseType: 'none'),
);

/// 动作类型选择器（目前只支持深蹲）
final selectedExerciseProvider = StateProvider<String>((ref) => 'squat');

/// 动作注册表：动作ID → 分析器工厂
final exerciseRegistryProvider = Provider<Map<String, ExerciseAnalyzerFactory>>((ref) {
  return {
    'squat': () async {
      final analyzer = await SquatAnalyzer.create();
      return analyzer as ExerciseAnalyzer;
    },
    // 'pushup': PushupAnalyzer.create,  // 未来扩展
  };
});

/// 根据选择创建分析器（异步）
final createAnalyzerProvider = FutureProvider<ExerciseAnalyzer>((ref) async {
  final exerciseType = ref.watch(selectedExerciseProvider);
  final registry = ref.watch(exerciseRegistryProvider);
  final factory = registry[exerciseType];

  if (factory == null) {
    throw ArgumentError('Unknown exercise type: $exerciseType');
  }

  return factory();
});

// ──────────────────────────────────────────────────────────────────────────────
// 调试状态 Provider（生产环境可关闭）
// ──────────────────────────────────────────────────────────────────────────────

/// 调试面板开关
final debugOverlayEnabledProvider = StateProvider<bool>((ref) => true);

/// 调试统计数据（通用化）
class DebugStats {
  final int frameCount;       // 收到的摄像头帧总数
  final int inferenceCount;   // ML Kit 完成推理次数
  final int poseCount;        // 检测到有人体的次数
  final int landmarkCount;    // 最新帧关键点数
  final String lastError;     // 最后一条错误
  final double fps;           // 近似帧率
  final int imageFormat;      // 摄像头帧格式 raw 值（35=YUV_420_888）
  final bool isAnalyzing;     // 动作分析是否开启

  // 通用字段（替代深蹲专属）
  final String exerciseType;      // 'squat', 'pushup'...
  final String currentPhase;      // 'standing', 'bottom'...
  final int repCount;             // 当前计数
  final Map<String, double> keyAngles;  // 关键角度值

  // 旧版字段（向后兼容，标记为废弃）
  @Deprecated('Use currentPhase instead')
  final String squatPhase;
  @Deprecated('Use keyAngles instead')
  final double? leftKnee;
  @Deprecated('Use keyAngles instead')
  final double? rightKnee;
  @Deprecated('Use keyMetrics instead')
  final double? minAngle;

  const DebugStats({
    this.frameCount = 0,
    this.inferenceCount = 0,
    this.poseCount = 0,
    this.landmarkCount = 0,
    this.lastError = '',
    this.fps = 0,
    this.imageFormat = 0,
    this.isAnalyzing = false,
    this.exerciseType = '-',
    this.currentPhase = '-',
    this.repCount = 0,
    this.keyAngles = const {},
    this.squatPhase = '-',
    this.leftKnee,
    this.rightKnee,
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
    String? exerciseType,
    String? currentPhase,
    int? repCount,
    Map<String, double>? keyAngles,
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
      exerciseType: exerciseType ?? this.exerciseType,
      currentPhase: currentPhase ?? this.currentPhase,
      repCount: repCount ?? this.repCount,
      keyAngles: keyAngles ?? this.keyAngles,
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

  /// 获取当前动作分析器
  ExerciseAnalyzer? get _analyzer => _ref.read(exerciseAnalyzerProvider);

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

        // 通用分析流程
        final analyzing = _ref.read(isAnalyzingProvider);
        final analyzer = _analyzer;

        final oldStats = _ref.read(debugStatsProvider);
        final keyAngles = analyzer?.getKeyAngles(angles) ?? {};

        if (analyzing && analyzer != null) {
          final state = analyzer.update(angles);
          _ref.read(exerciseStateProvider.notifier).state = state;

          // 更新调试面板
          _ref.read(debugStatsProvider.notifier).state = oldStats.copyWith(
            isAnalyzing: analyzing,
            exerciseType: state.exerciseType,
            currentPhase: state.currentPhase,
            repCount: state.repCount,
            keyAngles: keyAngles,
          );
        } else {
          _ref.read(debugStatsProvider.notifier).state = oldStats.copyWith(
            isAnalyzing: analyzing,
            exerciseType: '-',
            currentPhase: '-',
            repCount: 0,
            keyAngles: keyAngles,
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

  /// 开始/停止分析
  Future<void> toggleAnalysis() async {
    final current = _ref.read(isAnalyzingProvider);
    if (!current) {
      // 创建分析器
      final analyzer = await _ref.read(createAnalyzerProvider.future);
      analyzer.reset();
      _ref.read(exerciseAnalyzerProvider.notifier).state = analyzer;
      _ref.read(exerciseStateProvider.notifier).state = analyzer.currentState;
    }
    _ref.read(isAnalyzingProvider.notifier).state = !current;
  }

  /// 重置计数
  void resetCount() {
    final analyzer = _analyzer;
    analyzer?.reset();
    _ref.read(exerciseStateProvider.notifier).state = analyzer?.currentState ??
      ExerciseState.initial(exerciseType: 'none');
  }

  /// 切换动作类型（未来扩展）
  Future<void> switchExercise(String exerciseType) async {
    // 先停止分析
    if (_ref.read(isAnalyzingProvider)) {
      await toggleAnalysis();
    }

    // 切换类型
    _ref.read(selectedExerciseProvider.notifier).state = exerciseType;

    // 如果之前在分析，自动重新开始
    if (_ref.read(isAnalyzingProvider)) {
      await toggleAnalysis();
    }
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
