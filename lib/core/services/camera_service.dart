import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 摄像头状态
enum CameraStatus {
  uninitialized,
  initializing,
  ready,
  streaming,
  error,
  disposed,
}

/// 摄像头状态快照（不可变，驱动 UI 更新）
class CameraState {
  final CameraController? controller;
  final CameraStatus status;
  final bool isFrontCamera;

  const CameraState({
    this.controller,
    this.status = CameraStatus.uninitialized,
    this.isFrontCamera = false,
  });

  CameraState copyWith({
    CameraController? controller,
    CameraStatus? status,
    bool? isFrontCamera,
    bool clearController = false,
  }) {
    return CameraState(
      controller: clearController ? null : (controller ?? this.controller),
      status: status ?? this.status,
      isFrontCamera: isFrontCamera ?? this.isFrontCamera,
    );
  }
}

/// 摄像头 StateNotifier —— 让 Riverpod 感知 controller 变化
class CameraNotifier extends StateNotifier<CameraState> {
  List<CameraDescription> _cameras = [];
  int _currentCameraIndex = 0;

  final _frameController = StreamController<CameraImage>.broadcast();
  Stream<CameraImage> get frameStream => _frameController.stream;

  CameraController? get controller => state.controller;
  CameraStatus get status => state.status;
  bool get isStreaming => state.status == CameraStatus.streaming;
  bool get isFrontCamera => state.isFrontCamera;

  CameraNotifier() : super(const CameraState());

  /// 初始化摄像头列表
  Future<void> initialize() async {
    state = state.copyWith(status: CameraStatus.initializing);
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        state = state.copyWith(status: CameraStatus.error);
        return;
      }
      await _initCamera(_currentCameraIndex);
    } catch (e) {
      debugPrint('[CameraNotifier] initialize error: $e');
      state = state.copyWith(status: CameraStatus.error);
    }
  }

  Future<void> _initCamera(int index) async {
    // 先停止旧的帧流再 dispose，避免并发访问
    final old = state.controller;
    if (old != null) {
      if (old.value.isStreamingImages) {
        try {
          await old.stopImageStream();
        } catch (_) {}
      }
      try {
        await old.dispose();
      } catch (_) {}
    }

    // 清除旧 controller，立即通知 UI（避免白屏/残影）
    state = state.copyWith(
      clearController: true,
      status: CameraStatus.initializing,
      isFrontCamera: _cameras[index].lensDirection == CameraLensDirection.front,
    );

    final camera = _cameras[index];
    final newController = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.nv21,
    );

    try {
      await newController.initialize();
      state = state.copyWith(
        controller: newController,
        status: CameraStatus.ready,
      );
    } catch (e) {
      debugPrint('[CameraNotifier] _initCamera error: $e');
      state = state.copyWith(status: CameraStatus.error, clearController: true);
    }
  }

  /// 开始帧流
  Future<void> startImageStream() async {
    final ctrl = state.controller;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    if (ctrl.value.isStreamingImages) {
      state = state.copyWith(status: CameraStatus.streaming);
      return;
    }

    await ctrl.startImageStream((image) {
      if (!_frameController.isClosed) {
        _frameController.add(image);
      }
    });
    state = state.copyWith(status: CameraStatus.streaming);
  }

  /// 停止帧流
  Future<void> stopImageStream() async {
    final ctrl = state.controller;
    if (ctrl == null || !ctrl.value.isStreamingImages) return;
    await ctrl.stopImageStream();
    state = state.copyWith(status: CameraStatus.ready);
  }

  /// 切换前后摄像头
  Future<void> switchCamera() async {
    if (_cameras.length < 2) return;
    _currentCameraIndex = (_currentCameraIndex + 1) % _cameras.length;
    await _initCamera(_currentCameraIndex);
  }

  @override
  void dispose() {
    _frameController.close();
    state.controller?.dispose();
    super.dispose();
  }
}

/// Riverpod provider（StateNotifierProvider）
final cameraNotifierProvider =
    StateNotifierProvider<CameraNotifier, CameraState>((ref) {
  final notifier = CameraNotifier();
  return notifier;
});

// ── 向后兼容 alias（其他文件继续可用）──────────────────────────────────────────

/// 兼容旧的 cameraServiceProvider 用法 —— 返回 CameraNotifier
final cameraServiceProvider = Provider<CameraNotifier>((ref) {
  return ref.watch(cameraNotifierProvider.notifier);
});
