import 'package:pose_app/core/models/angle_result.dart';
import 'package:pose_app/core/services/detection_layers/base_layer.dart';

/// 第一层：触发机制
/// 
/// 核心目标：瞬时角度阈值判断，零延迟响应
/// 
/// 适用场景：
/// - 集成测试（无噪声环境）
/// - 快速响应的应用
/// - 需要即时反馈的场景
class TriggerLayer implements DetectionLayer {
  @override
  final String layerName = 'TriggerLayer';
  
  /// EMA平滑因子
  /// 
  /// - 1.0: 完全无平滑 (集成测试)
  /// - 0.3-0.5: 中等平滑 (生产环境)
  /// - 0.1-0.3: 强平滑 (高噪声环境)
  final double emaAlpha;
  
  /// 历史平滑值
  final Map<JointAngleType, double> _smoothedValues = {};
  /// 构造函数
  TriggerLayer({
    this.emaAlpha = 1.0,
  });
  
  @override
  bool get enabled => true; // 第一层始终启用
  
  @override
  DetectionResult check({
    required Map<JointAngleType, double> angles,
    required Map<String, dynamic> config,
    Map<String, dynamic>? history,
  }) {
    // 从配置中获取触发条件
    final operator = config['operator'] as String?;
    final minThreshold = config['min'] as double?;
    final maxThreshold = config['max'] as double?;
    final jointType = config['joint'] as JointAngleType?;
    final aggregation = config['aggregation'] as String? ?? 'avg';
    
    if (operator == null || jointType == null) {
      return DetectionResult.fail(
        layerName: layerName,
        metadata: {'reason': 'Missing required config'},
      );
    }
    
    // 执行EMA平滑
    final smoothedAngle = _applyEMA(angles, jointType, emaAlpha);
    
    // 执行聚合 (avg/left/right)
    final finalAngle = _executeAggregation(smoothedAngle, aggregation, angles);
    
    // 执行阈值判断
    final passed = _checkThreshold(finalAngle, operator, minThreshold, maxThreshold);
    
    return DetectionResult(
      passed: passed,
      layerName: layerName,
      metadata: {
        'angle': finalAngle,
        'operator': operator,
        'min': minThreshold,
        'max': maxThreshold,
        'ema_alpha': emaAlpha,
      },
    );
  }
  
  /// 应用EMA平滑
  double _applyEMA(
    Map<JointAngleType, double> angles,
    JointAngleType joint,
    double alpha,
  ) {
    final current = angles[joint];
    if (current == null) return _smoothedValues[joint] ?? 180.0;
    
    final prev = _smoothedValues[joint] ?? current;
    final smoothed = alpha * current + (1 - alpha) * prev;
    
    _smoothedValues[joint] = smoothed;
    return smoothed;
  }
  
  /// 执行聚合逻辑
  double _executeAggregation(
    double primaryValue,
    String aggregation,
    Map<JointAngleType, double> angles,
  ) {
    switch (aggregation) {
      case 'left':
        return primaryValue; // 已是左侧关节
      case 'right':
        return primaryValue; // 已是右侧关节
      case 'avg':
        // 计算对称关节的平均值
        final symmetricJoint = _getSymmetricJoint(primaryValue == angles[JointAngleType.leftKnee]
            ? JointAngleType.leftKnee
            : JointAngleType.rightKnee);
        final leftValue = angles[symmetricJoint];
        final rightValue = primaryValue;
        
        if (leftValue == null || rightValue == null) return primaryValue;
        return (leftValue + rightValue) / 2;
      default:
        return primaryValue;
    }
  }
  
  /// 阈值判断
  bool _checkThreshold(
    double angle,
    String operator,
    double? min,
    double? max,
  ) {
    switch (operator) {
      case '<':
        return max != null && angle < max;
      case '<=':
        return max != null && angle <= max;
      case '>':
        return min != null && angle > min;
      case '>=':
        return min != null && angle >= min;
      case 'between':
        return min != null && max != null && angle >= min && angle <= max;
      default:
        return false;
    }
  }
  
  /// 获取对称关节
  JointAngleType _getSymmetricJoint(JointAngleType joint) {
    switch (joint) {
      case JointAngleType.leftKnee:
        return JointAngleType.rightKnee;
      case JointAngleType.rightKnee:
        return JointAngleType.leftKnee;
      case JointAngleType.leftHip:
        return JointAngleType.rightHip;
      case JointAngleType.rightHip:
        return JointAngleType.leftHip;
      case JointAngleType.leftElbow:
        return JointAngleType.rightElbow;
      case JointAngleType.rightElbow:
        return JointAngleType.leftElbow;
      case JointAngleType.leftShoulder:
        return JointAngleType.rightShoulder;
      case JointAngleType.rightShoulder:
        return JointAngleType.leftShoulder;
      default:
        return joint;
    }
  }
  
  /// 重置平滑状态
  void reset() {
    _smoothedValues.clear();
  }
}
