import 'package:pose_app/core/models/angle_result.dart';

/// 姿态检测层的基础接口
/// 
/// 三层架构：
/// - 第一层：触发机制 (TriggerLayer) - 瞬时阈值判断
/// - 第二层：稳定性检测 (StabilityLayer) - 时间窗口内的持续性验证
/// - 第三层：过渡平滑 (TransitionLayer) - 姿态转换的连续性处理
abstract class DetectionLayer {
  /// 检查是否满足条件
  /// 
  /// [angles] 当前关节角度值
  /// [config] 层次配置参数
  /// [history] 历史数据（用于第二层和第三层）
  /// 
  /// 返回检测结果
  DetectionResult check({
    required Map<JointAngleType, double> angles,
    required Map<String, dynamic> config,
    Map<String, dynamic>? history,
  });
  
  /// 是否启用该层次
  bool get enabled;
  
  /// 层次名称（用于日志和调试）
  String get layerName;
}

/// 检测结果
class DetectionResult {
  /// 是否满足条件
  final bool passed;
  
  /// 层次名称
  final String layerName;
  
  /// 附加信息（如质量评分、持续时间等）
  final Map<String, dynamic> metadata;
  
  /// 检测时间戳
  final DateTime timestamp;
  
  DetectionResult({
    required this.passed,
    required this.layerName,
    this.metadata = const {},
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
  
  factory DetectionResult.pass({
    required String layerName,
    Map<String, dynamic> metadata = const {},
  }) {
    return DetectionResult(
      passed: true,
      layerName: layerName,
      metadata: metadata,
    );
  }
  
  factory DetectionResult.fail({
    required String layerName,
    Map<String, dynamic> metadata = const {},
  }) {
    return DetectionResult(
      passed: false,
      layerName: layerName,
      metadata: metadata,
    );
  }
  
  @override
  String toString() {
    return 'DetectionResult($layerName: ${passed ? "PASS" : "FAIL"}, metadata: $metadata)';
  }
}

/// 层次检测配置
class DetectionLayerConfig {
  /// 是否启用该层次
  final bool enabled;
  
  /// 层次特定的配置参数
  final Map<String, dynamic> params;
  
  const DetectionLayerConfig({
    required this.enabled,
    this.params = const {},
  });
  
  factory DetectionLayerConfig.fromMap(Map<String, dynamic> map) {
    return DetectionLayerConfig(
      enabled: map['enabled'] as bool? ?? false,
      params: map['config'] as Map<String, dynamic>? ?? {},
    );
  }
}
