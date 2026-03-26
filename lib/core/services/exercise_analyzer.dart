import 'package:pose_app/core/models/angle_result.dart';
import 'package:pose_app/core/models/exercise_definition.dart';
import 'package:pose_app/core/models/exercise_rep.dart';
import 'package:pose_app/core/models/exercise_state.dart';

/// 动作分析器接口
abstract class ExerciseAnalyzer {
  /// 动作类型标识
  String get exerciseType;

  /// 动作定义（从配置加载）
  ExerciseDefinition get definition;

  /// 当前状态
  ExerciseState get currentState;

  /// 完成的重复次数
  int get repCount;

  /// 本次动作的关键指标（如最小角度）
  Map<String, double> get keyMetrics;

  /// 所有重复记录
  List<ExerciseRep> get reps;

  /// 输入一帧角度，更新状态
  ExerciseState update(FrameAngles angles);

  /// 重置分析器
  void reset();

  /// 获取当前阶段的关键角度值（用于UI显示）
  Map<String, double> getKeyAngles(FrameAngles angles);

  /// 获取完成的记录列表
  List<ExerciseRep> getCompletedReps();
}

/// 动作分析器工厂类型
typedef ExerciseAnalyzerFactory = Future<ExerciseAnalyzer> Function();
