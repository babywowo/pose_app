import 'package:pose_app/core/models/angle_result.dart';
import 'package:pose_app/core/services/detection_layers/base_layer.dart';

/// 第二层：稳定性检测 (预留接口)
/// 
/// 核心目标：时间窗口内的持续性验证，过滤瞬时抖动
/// 
/// 适用场景：
/// - 生产环境（有噪声的视频输入）
/// - 需要高质量判断的场景
/// - 防止误触发的应用
/// 
/// 注意：当前为预留接口，暂不集成到主流程
class StabilityLayer implements DetectionLayer {
  @override
  final String layerName = 'StabilityLayer';
  
  /// 历史角度数据
  final Map<JointAngleType, List<double>> _angleHistory = {};
  
  /// 最大历史窗口大小
  final int maxHistorySize;
  
  /// 构造函数
  const StabilityLayer({
    this.maxHistorySize = 100,
  });
  
  @override
  bool get enabled => false; // 当前未启用
  
  @override
  DetectionResult check({
    required Map<JointAngleType, double> angles,
    required Map<String, dynamic> config,
    Map<String, dynamic>? history,
  }) {
    // 从配置中获取参数
    final minDurationMs = config['min_duration_ms'] as int? ?? 500;
    final tolerance = config['tolerance'] as double? ?? 5.0;
    final windowSize = config['window_size'] as int? ?? 30;
    final jointType = config['joint'] as JointAngleType?;
    
    if (jointType == null) {
      return DetectionResult.fail(
        layerName: layerName,
        metadata: {'reason': 'Missing joint type in config'},
      );
    }
    
    // 更新历史数据
    _updateHistory(jointType, angles[jointType] ?? 180.0);
    
    // 获取最近N帧的数据
    final recentAngles = _angleHistory[jointType] ?? [];
    final window = recentAngles.length >= windowSize
        ? recentAngles.sublist(recentAngles.length - windowSize)
        : recentAngles;
    
    if (window.isEmpty) {
      return DetectionResult.fail(
        layerName: layerName,
        metadata: {'reason': 'Insufficient history'},
      );
    }
    
    // 1. 检查是否所有角度都在阈值范围内
    final threshold = config['threshold'] as double?;
    final allInThreshold = threshold != null
        ? window.every((angle) => angle <= threshold + tolerance)
        : true;
    
    // 2. 检查是否持续足够时间
    final windowDuration = window.length * frameInterval; // 假设每帧间隔
    final enoughDuration = windowDuration >= Duration(milliseconds: minDurationMs);
    
    final passed = allInThreshold && enoughDuration;
    
    return DetectionResult(
      passed: passed,
      layerName: layerName,
      metadata: {
        'window_size': window.length,
        'min_angle': window.reduce((a, b) => a < b ? a : b),
        'max_angle': window.reduce((a, b) => a > b ? a : b),
        'avg_angle': window.reduce((a, b) => a + b) / window.length,
        'duration_ms': windowDuration.inMilliseconds,
        'min_duration_ms': minDurationMs,
        'tolerance': tolerance,
      },
    );
  }
  
  /// 更新历史数据
  void _updateHistory(JointAngleType joint, double angle) {
    if (!_angleHistory.containsKey(joint)) {
      _angleHistory[joint] = [];
    }
    
    final history = _angleHistory[joint]!;
    history.add(angle);
    
    // 限制历史大小
    if (history.length > maxHistorySize) {
      history.removeAt(0);
    }
  }
  
  /// 帧间隔时间（假设16fps）
  static const Duration frameInterval = Duration(milliseconds: 62);
  
  /// 重置历史数据
  void reset() {
    _angleHistory.clear();
  }
}
