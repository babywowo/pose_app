import 'dart:async';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_app/core/models/pose_landmark.dart' as app_model;

/// MediaPipe / ML Kit 姿态检测服务
class PoseDetectorService {
  final PoseDetector _detector;
  bool _isProcessing = false;
  int _processCount = 0;
  bool _loggedFirstFrame = false;

  /// 错误回调：当内部发生异常时通知外部（用于调试面板）
  void Function(String error)? onError;

  final _poseController =
      StreamController<app_model.PoseFrame>.broadcast();

  Stream<app_model.PoseFrame> get poseStream => _poseController.stream;

  PoseDetectorService()
      : _detector = PoseDetector(
          options: PoseDetectorOptions(
            model: PoseDetectionModel.base,
            mode: PoseDetectionMode.stream,
          ),
        );

  /// 处理单帧 CameraImage
  Future<void> processFrame(
    CameraImage frame,
    int sensorOrientation, {
    bool isFrontCamera = false,
  }) async {
    if (_isProcessing) return; // 丢帧保护
    _isProcessing = true;
    _processCount++;

    try {
      // ── 步骤1：格式转换（通用适配）─────────────────────────────────────────
      InputImage? inputImage;
      try {
        inputImage = _convertToInputImage(frame, sensorOrientation, isFrontCamera);
      } catch (e, st) {
        final msg = 'convert失败: $e';
        debugPrint('[PoseDetector] $msg\n$st');
        onError?.call(msg);
        return;
      }

      if (inputImage == null) {
        const msg = 'convert返回null（格式不支持）';
        debugPrint('[PoseDetector] #$_processCount $msg '
            'planes=${frame.planes.length} fmt=${frame.format.raw}');
        onError?.call(msg);
        return;
      }

      // ── 步骤2：ML Kit 推理 ──────────────────────────────────────────────────
      List<Pose> poses;
      try {
        poses = await _detector.processImage(inputImage);
      } catch (e, st) {
        final msg = 'processImage失败: $e';
        debugPrint('[PoseDetector] $msg\n$st');
        onError?.call(msg);
        return;
      }

      // ── 步骤3：结果推送 ─────────────────────────────────────────────────────
      if (!_poseController.isClosed) {
        if (poses.isNotEmpty) {
          _poseController.add(_convertPose(poses.first));
        } else {
          _poseController.add(
            app_model.PoseFrame(landmarks: [], timestamp: DateTime.now()),
          );
        }
      }
    } catch (e) {
      final msg = 'processFrame未预期错误: $e';
      debugPrint('[PoseDetector] $msg');
      onError?.call(msg);
    } finally {
      _isProcessing = false;
    }
  }

  /// 将 CameraImage 转为 ML Kit InputImage
  ///
  /// 通用适配：支持 YUV_420_888（3 planes）、NV21（1 plane）、YV12、JPEG
  InputImage? _convertToInputImage(
      CameraImage frame, int sensorOrientation, bool isFrontCamera) {
    // 第一帧打印格式信息
    if (!_loggedFirstFrame) {
      _loggedFirstFrame = true;
      debugPrint(
        '[PoseDetector] 第一帧格式诊断: '
        'planes=${frame.planes.length} '
        'fmtRaw=${frame.format.raw} '
        '${frame.width}x${frame.height} '
        'plane0=${frame.planes[0].bytes.length} '
        'plane1=${frame.planes.length > 1 ? frame.planes[1].bytes.length : "N/A"} '
        'plane2=${frame.planes.length > 2 ? frame.planes[2].bytes.length : "N/A"}',
      );
    }

    final rotation = _rotationFromDegrees(sensorOrientation, isFrontCamera);
    final fmtRaw = frame.format.raw;

    // ── 分支1：NV21（单平面，直接传）────────────────────────────────
    if (fmtRaw == 17 && frame.planes.length == 1) {
      return InputImage.fromBytes(
        bytes: frame.planes[0].bytes,
        metadata: InputImageMetadata(
          size: Size(frame.width.toDouble(), frame.height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.nv21,
          bytesPerRow: frame.planes[0].bytesPerRow,
        ),
      );
    }

    // ── 分支2：YUV_420_888（3 planes）→ NV21 ───────────────────
    if (fmtRaw == 35 && frame.planes.length == 3) {
      final nv21 = _yuv420ToNv21(frame);
      return InputImage.fromBytes(
        bytes: nv21,
        metadata: InputImageMetadata(
          size: Size(frame.width.toDouble(), frame.height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.nv21,
          bytesPerRow: frame.width,
        ),
      );
    }

    // ── 分支3：YV12（3 planes）→ NV21 ─────────────────────────
    if (fmtRaw == 842094169 && frame.planes.length == 3) {
      final nv21 = _yv12ToNv21(frame);
      return InputImage.fromBytes(
        bytes: nv21,
        metadata: InputImageMetadata(
          size: Size(frame.width.toDouble(), frame.height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.nv21,
          bytesPerRow: frame.width,
        ),
      );
    }

    // ── 不支持的格式 ─────────────────────────────────────────────────────────
    debugPrint('[PoseDetector] 不支持的格式: fmtRaw=$fmtRaw planes=${frame.planes.length}');
    return null;
  }

  /// YUV_420_888（3 planes）→ NV21（单平面）
  ///
  /// YUV_420_888 结构：
  ///   plane[0] = Y  宽×高，可能有 rowStride padding
  ///   plane[1] = U  宽/2 × 高/2，pixelStride 可能为 1(planar) 或 2(semi-planar)
  ///   plane[2] = V  同上
  /// NV21 结构：
  ///   [Y × width×height] + [VU 交错 × width/2 × height/2 × 2]
  Uint8List _yuv420ToNv21(CameraImage image) {
    final int width = image.width;
    final int height = image.height;

    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    final int yRowStride = yPlane.bytesPerRow;
    final int uvRowStride = uPlane.bytesPerRow;
    final int uvPixelStride = uPlane.bytesPerPixel ?? 1;

    final nv21 = Uint8List(width * height + (width * height) ~/ 2);
    int idx = 0;

    // ── 拷贝 Y 平面 ──
    if (yRowStride == width) {
      // 无 padding，整块拷贝
      nv21.setRange(0, width * height, yPlane.bytes);
      idx = width * height;
    } else {
      // 有 row padding，逐行拷贝去掉 padding
      for (int row = 0; row < height; row++) {
        nv21.setRange(idx, idx + width, yPlane.bytes, row * yRowStride);
        idx += width;
      }
    }

    // ── 拷贝 VU 交错平面（NV21 = V 在前，U 在后）──
    final int uvHeight = height ~/ 2;
    final int uvWidth = width ~/ 2;

    for (int row = 0; row < uvHeight; row++) {
      for (int col = 0; col < uvWidth; col++) {
        final int uIdx = row * uvRowStride + col * uvPixelStride;
        final int vIdx = row * uvRowStride + col * uvPixelStride;
        nv21[idx++] = vPlane.bytes[vIdx]; // V 在前
        nv21[idx++] = uPlane.bytes[uIdx]; // U 在后
      }
    }

    return nv21;
  }

  /// YV12（3 planes）→ NV21
  ///
  /// YV12 结构：
  ///   plane[0] = Y
  ///   plane[1] = V（与 YUV_420_888 的 U/V 顺序相反）
  ///   plane[2] = U
  /// NV21 = Y + VU 交错
  Uint8List _yv12ToNv21(CameraImage image) {
    final int width = image.width;
    final int height = image.height;

    final yPlane = image.planes[0];
    final vPlane = image.planes[1]; // YV12 中 plane[1] 是 V
    final uPlane = image.planes[2]; // YV12 中 plane[2] 是 U

    final int yRowStride = yPlane.bytesPerRow;
    final int uvRowStride = vPlane.bytesPerRow;
    final int uvPixelStride = vPlane.bytesPerPixel ?? 1;

    final nv21 = Uint8List(width * height + (width * height) ~/ 2);
    int idx = 0;

    // ── 拷贝 Y 平面 ──
    if (yRowStride == width) {
      nv21.setRange(0, width * height, yPlane.bytes);
      idx = width * height;
    } else {
      for (int row = 0; row < height; row++) {
        nv21.setRange(idx, idx + width, yPlane.bytes, row * yRowStride);
        idx += width;
      }
    }

    // ── 拷贝 VU 交错平面（YV12 的 V/U 顺序已经对 NV21）──
    final int uvHeight = height ~/ 2;
    final int uvWidth = width ~/ 2;

    for (int row = 0; row < uvHeight; row++) {
      for (int col = 0; col < uvWidth; col++) {
        final int vIdx = row * uvRowStride + col * uvPixelStride;
        final int uIdx = row * uvRowStride + col * uvPixelStride;
        nv21[idx++] = vPlane.bytes[vIdx]; // V 在前
        nv21[idx++] = uPlane.bytes[uIdx]; // U 在后
      }
    }

    return nv21;
  }

  InputImageRotation _rotationFromDegrees(int degrees, bool isFrontCamera) {
    final adjusted = isFrontCamera ? (360 - degrees) % 360 : degrees;
    switch (adjusted) {
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
        return InputImageRotation.rotation0deg;
    }
  }

  app_model.PoseFrame _convertPose(Pose pose) {
    final landmarks = <app_model.PoseLandmark>[];
    pose.landmarks.forEach((mlKitType, landmark) {
      final appType = _kLandmarkMap[mlKitType];
      if (appType != null) {
        landmarks.add(app_model.PoseLandmark(
          type: appType,
          x: landmark.x,
          y: landmark.y,
          z: landmark.z,
          likelihood: landmark.likelihood,
        ));
      }
    });
    return app_model.PoseFrame(
      landmarks: landmarks,
      timestamp: DateTime.now(),
    );
  }

  static const _kLandmarkMap = <PoseLandmarkType, app_model.PoseLandmarkType>{
    PoseLandmarkType.nose: app_model.PoseLandmarkType.nose,
    PoseLandmarkType.leftEyeInner: app_model.PoseLandmarkType.leftEyeInner,
    PoseLandmarkType.leftEye: app_model.PoseLandmarkType.leftEye,
    PoseLandmarkType.leftEyeOuter: app_model.PoseLandmarkType.leftEyeOuter,
    PoseLandmarkType.rightEyeInner: app_model.PoseLandmarkType.rightEyeInner,
    PoseLandmarkType.rightEye: app_model.PoseLandmarkType.rightEye,
    PoseLandmarkType.rightEyeOuter: app_model.PoseLandmarkType.rightEyeOuter,
    PoseLandmarkType.leftEar: app_model.PoseLandmarkType.leftEar,
    PoseLandmarkType.rightEar: app_model.PoseLandmarkType.rightEar,
    PoseLandmarkType.leftMouth: app_model.PoseLandmarkType.mouthLeft,
    PoseLandmarkType.rightMouth: app_model.PoseLandmarkType.mouthRight,
    PoseLandmarkType.leftShoulder: app_model.PoseLandmarkType.leftShoulder,
    PoseLandmarkType.rightShoulder: app_model.PoseLandmarkType.rightShoulder,
    PoseLandmarkType.leftElbow: app_model.PoseLandmarkType.leftElbow,
    PoseLandmarkType.rightElbow: app_model.PoseLandmarkType.rightElbow,
    PoseLandmarkType.leftWrist: app_model.PoseLandmarkType.leftWrist,
    PoseLandmarkType.rightWrist: app_model.PoseLandmarkType.rightWrist,
    PoseLandmarkType.leftPinky: app_model.PoseLandmarkType.leftPinky,
    PoseLandmarkType.rightPinky: app_model.PoseLandmarkType.rightPinky,
    PoseLandmarkType.leftIndex: app_model.PoseLandmarkType.leftIndex,
    PoseLandmarkType.rightIndex: app_model.PoseLandmarkType.rightIndex,
    PoseLandmarkType.leftThumb: app_model.PoseLandmarkType.leftThumb,
    PoseLandmarkType.rightThumb: app_model.PoseLandmarkType.rightThumb,
    PoseLandmarkType.leftHip: app_model.PoseLandmarkType.leftHip,
    PoseLandmarkType.rightHip: app_model.PoseLandmarkType.rightHip,
    PoseLandmarkType.leftKnee: app_model.PoseLandmarkType.leftKnee,
    PoseLandmarkType.rightKnee: app_model.PoseLandmarkType.rightKnee,
    PoseLandmarkType.leftAnkle: app_model.PoseLandmarkType.leftAnkle,
    PoseLandmarkType.rightAnkle: app_model.PoseLandmarkType.rightAnkle,
    PoseLandmarkType.leftHeel: app_model.PoseLandmarkType.leftHeel,
    PoseLandmarkType.rightHeel: app_model.PoseLandmarkType.rightHeel,
    PoseLandmarkType.leftFootIndex: app_model.PoseLandmarkType.leftFootIndex,
    PoseLandmarkType.rightFootIndex: app_model.PoseLandmarkType.rightFootIndex,
  };

  Future<void> dispose() async {
    await _detector.close();
    await _poseController.close();
  }
}

/// Riverpod provider
final poseDetectorServiceProvider = Provider<PoseDetectorService>((ref) {
  final service = PoseDetectorService();
  ref.onDispose(service.dispose);
  return service;
});
