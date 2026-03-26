import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pose_app/core/providers/pose_providers.dart';
import 'package:pose_app/core/services/camera_service.dart';

/// 屏幕调试面板（右上角半透明浮层）
/// 显示帧率、推理次数、关键点数、错误信息，用于无 logcat 时诊断问题
class DebugOverlay extends ConsumerWidget {
  const DebugOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(debugStatsProvider);
    final camState = ref.watch(cameraNotifierProvider);

    final rows = <_DebugRow>[
      _DebugRow(
        label: 'CAM',
        value: camState.status.name,
        color: camState.status == CameraStatus.streaming
            ? Colors.greenAccent
            : Colors.orangeAccent,
      ),
      _DebugRow(
        label: 'FPS',
        value: stats.fps.toStringAsFixed(1),
        color: stats.fps > 10 ? Colors.greenAccent : Colors.orangeAccent,
      ),
      _DebugRow(
        label: 'FRAMES',
        value: '${stats.frameCount}',
        color: stats.frameCount > 0 ? Colors.greenAccent : Colors.redAccent,
      ),
      _DebugRow(
        label: 'FMT',
        value: stats.imageFormat > 0 ? '${stats.imageFormat}' : '--',
        color: stats.imageFormat == 35
            ? Colors.greenAccent
            : Colors.orangeAccent,
        tooltip: '35=YUV_420_888',
      ),
      _DebugRow(
        label: 'INFER',
        value: '${stats.inferenceCount}',
        color: stats.inferenceCount > 0 ? Colors.greenAccent : Colors.redAccent,
      ),
      _DebugRow(
        label: 'POSE',
        value: '${stats.poseCount}',
        color: stats.poseCount > 0 ? Colors.greenAccent : Colors.orangeAccent,
      ),
      _DebugRow(
        label: 'LMK',
        value: '${stats.landmarkCount}',
        color: stats.landmarkCount >= 20
            ? Colors.greenAccent
            : stats.landmarkCount > 0
                ? Colors.orangeAccent
                : Colors.redAccent,
      ),
      _DebugRow(
        label: 'ANALYZE',
        value: stats.isAnalyzing ? 'ON' : 'OFF',
        color: stats.isAnalyzing ? Colors.greenAccent : Colors.grey,
      ),
      _DebugRow(
        label: 'PHASE',
        value: stats.squatPhase,
        color: stats.squatPhase == 'BOT' ? Colors.greenAccent : Colors.white70,
      ),
      _DebugRow(
        label: 'MIN',
        value: stats.minAngle?.toStringAsFixed(0) ?? '--',
        color: Colors.white70,
      ),
      _DebugRow(
        label: 'L-KNEE',
        value: stats.leftKnee?.toStringAsFixed(0) ?? '--',
        color: Colors.white70,
      ),
      _DebugRow(
        label: 'R-KNEE',
        value: stats.rightKnee?.toStringAsFixed(0) ?? '--',
        color: Colors.white70,
      ),
    ];

    return Container(
      width: 140,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 标题行
          Row(
            children: [
              const Icon(Icons.bug_report, color: Colors.white54, size: 11),
              const SizedBox(width: 4),
              const Text(
                'DEBUG',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 4),

          // 数据行
          ...rows.map((r) => _buildRow(r)),

          // 错误信息（有才显示）
          if (stats.lastError.isNotEmpty) ...[
            const SizedBox(height: 4),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 4),
            Text(
              'ERR: ${stats.lastError}',
              style: const TextStyle(
                color: Colors.redAccent,
                fontSize: 8,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          // 诊断提示
          const SizedBox(height: 4),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 4),
          _buildDiagnosis(stats),
        ],
      ),
    );
  }

  Widget _buildRow(_DebugRow row) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            row.label,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 9,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          Text(
            row.value,
            style: TextStyle(
              color: row.color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosis(DebugStats stats) {
    String msg;
    Color color;

    if (stats.frameCount == 0) {
      msg = '未收到摄像头帧\n→ 检查相机权限';
      color = Colors.redAccent;
    } else if (stats.inferenceCount == 0) {
      msg = '帧流 OK，推理无输出\n→ ML Kit 格式问题';
      color = Colors.orangeAccent;
    } else if (stats.poseCount == 0) {
      msg = '推理 OK，未检测到人体\n→ 对准摄像头';
      color = Colors.yellowAccent;
    } else if (stats.landmarkCount < 20) {
      msg = '检测到人体但关键点少\n→ 保证全身可见';
      color = Colors.orangeAccent;
    } else {
      msg = '骨骼检测正常 ✓';
      color = Colors.greenAccent;
    }

    return Text(
      msg,
      style: TextStyle(
        color: color,
        fontSize: 8.5,
        height: 1.5,
      ),
    );
  }
}

class _DebugRow {
  final String label;
  final String value;
  final Color color;
  final String? tooltip;
  const _DebugRow({
    required this.label,
    required this.value,
    required this.color,
    this.tooltip,
  });
}
