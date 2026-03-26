import 'package:pose_app/core/models/angle_result.dart';
import 'package:pose_app/core/services/detection_layers/base_layer.dart';

/// 第三层：过渡平滑 (预留接口)
/// 
/// 核心目标：姿态转换的连续性处理，评估动作质量
/// 
/// 适用场景：
/// - 高质量训练应用
/// - 教练级反馈系统
/// - 需要动作质量评分的场景
/// 
/// 注意：当前为预留接口，暂不集成到主流程
class TransitionLayer implements DetectionLayer {
  @override
  final String layerName = 'TransitionLayer';
  
  /// 转换前的历史数据
  final Map<String, List<double>> _fromPhaseHistory = {};
  
  /// 转换后的历史数据
  final Map<String, List<double>> _toPhaseHistory = {};
  
  /// 最大历史窗口大小
  final int maxHistorySize;
  
  /// 构造函数
  const TransitionLayer({
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
    final smoothnessThreshold = config['smoothness_threshold'] as double? ?? 10.0;
    final evaluationWindow = config['evaluation_window'] as int? ?? 20;
    final jointType = config['joint'] as JointAngleType?;
    
    if (jointType == null) {
      return DetectionResult.fail(
        layerName: layerName,
        metadata: {'reason': 'Missing joint type in config'},
      );
    }
    
    // 更新转换后数据
    _updateToPhaseHistory(jointType, angles[jointType] ?? 180.0);
    
    // 获取转换前后的数据
    final fromData = _fromPhaseHistory[jointType] ?? [];
    final toData = _toPhaseHistory[jointType] ?? [];
    
    // 需要足够的历史数据
    if (fromData.length < evaluationWindow || toData.length < evaluationWindow) {
      return DetectionResult.fail(
        layerName: layerName,
        metadata: {
          'reason': 'Insufficient data for evaluation',
          'from_size': fromData.length,
          'to_size': toData.length,
          'required': evaluationWindow,
        },
      );
    }
    
    // 1. 计算转换过程中的最大变化率
    final transitionAngles = [
      ...fromData.sublist(fromData.length - evaluationWindow),
      ...toData.sublist(0, evaluationWindow),
    ];
    final maxDelta = _calculateMaxDelta(transitionAngles);
    
    // 2. 检查是否平滑
    final isSmooth = maxDelta <= smoothnessThreshold;
    
    // 3. 计算过渡时间
    final transitionTime = toData.length * frameInterval;
    
    // 4. 质量评分
    final qualityScore = _calculateQualityScore(
      maxDelta: maxDelta,
      time: transitionTime,
      isSmooth: isSmooth,
      threshold: smoothnessThreshold,
    );
    
    // 保存结果到元数据
    final result = DetectionResult(
      passed: true, // 过渡层不阻止转换，只评估质量
      layerName: layerName,
      metadata: {
        'is_smooth': isSmooth,
        'quality_score': qualityScore,
        'max_delta': maxDelta,
        'transition_time_ms': transitionTime.inMilliseconds,
        'evaluation_window': evaluationWindow,
        'smoothness_threshold': smoothnessThreshold,
        'from_phase_size': fromData.length,
        'to_phase_size': toData.length,
      },
    );
    
    return result;
  }
  
  /// 记录转换前的数据
  void recordFromPhase(JointAngleType joint, double angle) {
    if (!_fromPhaseHistory.containsKey(joint)) {
      _fromPhaseHistory[joint] = [];
    }
    
    final history = _fromPhaseHistory[joint]!;
    history.add(angle);
    
    // 限制历史大小
    if (history.length > maxHistorySize) {
      history.removeAt(0);
    }
  }
  
  /// 更新转换后的历史数据
  void _updateToPhaseHistory(JointAngleType joint, double angle) {
    if (!_toPhaseHistory.containsKey(joint)) {
      _toPhaseHistory[joint] = [];
    }
    
    final history = _toPhaseHistory[joint]!;
    history.add(angle);
    
    // 限制历史大小
    if (history.length > maxHistorySize) {
      history.removeAt(0);
    }
  }
  
  /// 计算最大变化率
  double _calculateMaxDelta(List<double> angles) {
    if (angles.length < 2) return 0.0;
    
    double maxDelta = 0.0;
    for (var i = 1; i < angles.length; i++) {
      final delta = (angles[i] - angles[i - 1]).abs();
      if (delta > maxDelta) {
        maxDelta = delta;
      }
    }
    return maxDelta;
  }
  
  /// 计算质量评分 (0.0 - 1.0)
  double _calculateQualityScore({
    required double maxDelta,
    required Duration time,
    required bool isSmooth,
    required double threshold,
  }) {
    // 1. 平滑度得分 (0.0 - 0.7)
    final smoothnessScore = isSmooth
        ? 0.7
        : 0.7 * (1 - (maxDelta - threshold) / threshold).clamp(0.0, 1.0);
    
    // 2. 速度适度性得分 (0.0 - 0.3)
    // 假设理想的转换时间在500ms-1000ms之间
    const idealMinMs = 500;
    const idealMaxMs = 1000;
    final timeMs = time.inMilliseconds;
    double speedScore;
    
    if (timeMs < idealMinMs) {
      // 太快，线性降分
      speedScore = 0.3 * (timeMs / idealMinMs);
    } else if (timeMs > idealMaxMs) {
      // 太慢，线性降分
      speedScore = 0.3 * (idealMaxMs / timeMs);
    } else {
      // 刚好，满分
      speedScore = 0.3;
    }
    
    // 3. 综合得分
    return (smoothnessScore + speedScore).clamp(0.0, 1.0);
  }
  
  /// 标记阶段转换开始
  void markTransitionStart(JointAngleType joint) {
    // 清空转换后的数据，准备新的转换
    _toPhaseHistory.remove(joint);
  }
  
  /// 帧间隔时间（假设16fps）
  static const Duration frameInterval = Duration(milliseconds: 62);
  
  /// 重置历史数据
  void reset() {
    _fromPhaseHistory.clear();
    _toPhaseHistory.clear();
  }
}
