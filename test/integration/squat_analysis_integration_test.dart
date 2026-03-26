import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pose_app/core/models/angle_result.dart';
import 'package:pose_app/core/models/exercise_state.dart';
import 'package:pose_app/core/models/exercise_rep.dart';
import 'package:pose_app/core/models/workout_session.dart';
import 'package:pose_app/core/repositories/workout_repository.dart';
import 'package:pose_app/core/services/exercise_analyzer.dart';
import 'package:pose_app/core/services/squat_analyzer.dart';

export 'package:pose_app/core/models/workout_session.dart' show SquatRep;

class MockWorkoutRepository extends Mock implements WorkoutRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('深蹲分析集成测试', () {
    late WorkoutRepository repository;
    late ExerciseAnalyzer analyzer;

    setUp(() async {
      registerFallbackValue(WorkoutSession.start());
      repository = MockWorkoutRepository();
      analyzer = await SquatAnalyzer.create();

      when(() => repository.saveSession(any()))
          .thenAnswer((_) async => Future.value());
      when(() => repository.getAllSessions()).thenReturn([]);
      when(() => repository.deleteSession(any()))
          .thenAnswer((_) async => Future.value());
    });

    tearDown(() async {});

    group('完整深蹲周期集成测试', () {
      test('完整深蹲周期（站立→下蹲→最低→起身→站立）应正确计数', () async {
        analyzer.reset();
        expect(analyzer.currentState.repCount, 0);

        // 1. 站立阶段（170°，重复20次确保稳定）
        for (var i = 0; i < 20; i++) {
          analyzer.update(_createFrameAngles(leftKnee: 170, rightKnee: 170));
        }
        expect(analyzer.currentState.currentPhase, 'standing');
        expect(analyzer.currentState.repCount, 0);

        // 2. 下蹲到120°（触发standing→descending，阈值<150）
        for (var angle = 170; angle >= 120; angle -= 1) {
          for (var i = 0; i < 10; i++) {  // 增加到10帧
            analyzer.update(_createFrameAngles(leftKnee: angle.toDouble(), rightKnee: angle.toDouble()));
          }
        }
        expect(analyzer.currentState.currentPhase, 'descending');
        expect(analyzer.currentState.repCount, 0);

        // 3. 下蹲到80°（触发descending→bottom，阈值<100）
        for (var angle = 120; angle >= 80; angle -= 1) {
          for (var i = 0; i < 10; i++) {  // 增加到10帧
            analyzer.update(_createFrameAngles(leftKnee: angle.toDouble(), rightKnee: angle.toDouble()));
          }
        }
        expect(analyzer.currentState.currentPhase, 'bottom');
        expect(analyzer.currentState.repCount, 0);

        // 4. 起身到120°（触发bottom→ascending，阈值>100，从100直接跳到120确保触发）
        for (var angle = 80; angle <= 120; angle += 1) {
          for (var i = 0; i < 10; i++) {  // 增加到10帧
            analyzer.update(_createFrameAngles(leftKnee: angle.toDouble(), rightKnee: angle.toDouble()));
          }
        }
        expect(analyzer.currentState.currentPhase, 'ascending');
        expect(analyzer.currentState.repCount, 0);

        // 5. 起身到170°（触发ascending→standing，阈值>160并计数）
        for (var angle = 120; angle <= 170; angle += 1) {
          for (var i = 0; i < 10; i++) {  // 增加到10帧
            analyzer.update(_createFrameAngles(leftKnee: angle.toDouble(), rightKnee: angle.toDouble()));
          }
        }
        expect(analyzer.currentState.currentPhase, 'standing');
        expect(analyzer.currentState.repCount, 1);
      });

      test('慢起身过程（80°→100°→120°→160°→170°）应正确计数', () async {
        analyzer.reset();

        // 站立→下蹲→底部
        for (var angle = 170; angle >= 80; angle -= 1) {
          for (var i = 0; i < 10; i++) {  // 增加到10帧
            analyzer.update(_createFrameAngles(leftKnee: angle.toDouble(), rightKnee: angle.toDouble()));
          }
        }

        // 起身到100°（仍在底部）
        for (var i = 0; i < 20; i++) {  // 增加到20帧确保稳定
          analyzer.update(_createFrameAngles(leftKnee: 100, rightKnee: 100));
        }
        expect(analyzer.currentState.currentPhase, 'bottom');
        expect(analyzer.currentState.repCount, 0);

        // 起身到120°（转换为ascending）
        for (var i = 0; i < 20; i++) {  // 增加到20帧
          analyzer.update(_createFrameAngles(leftKnee: 120, rightKnee: 120));
        }
        expect(analyzer.currentState.currentPhase, 'ascending');
        expect(analyzer.currentState.repCount, 0);

        // 起身到160°（还在ascending）
        for (var i = 0; i < 20; i++) {  // 增加到20帧
          analyzer.update(_createFrameAngles(leftKnee: 160, rightKnee: 160));
        }
        expect(analyzer.currentState.currentPhase, 'ascending');
        expect(analyzer.currentState.repCount, 0);

        // 起身到170°（完成）
        for (var i = 0; i < 20; i++) {  // 增加到20帧确保触发
          analyzer.update(_createFrameAngles(leftKnee: 170, rightKnee: 170));
        }
        expect(analyzer.currentState.currentPhase, 'standing');
        expect(analyzer.currentState.repCount, 1);
      });

      test('快起身过程（80°→170°）应正确计数', () async {
        analyzer.reset();

        // 站立→下蹲→底部
        for (var angle = 170; angle >= 80; angle -= 1) {
          for (var i = 0; i < 10; i++) {  // 增加到10帧
            analyzer.update(_createFrameAngles(leftKnee: angle.toDouble(), rightKnee: angle.toDouble()));
          }
        }

        // 快速起身（每步增加5°，但每步重复10帧）
        for (var angle = 80; angle <= 170; angle += 5) {
          for (var i = 0; i < 10; i++) {  // 增加到10帧
            analyzer.update(_createFrameAngles(leftKnee: angle.toDouble(), rightKnee: angle.toDouble()));
          }
        }

        expect(analyzer.currentState.currentPhase, 'standing');
        expect(analyzer.currentState.repCount, 1);
      });

      test('不完全下蹲（只到130°）不应计数', () async {
        analyzer.reset();

        // 下蹲到130°（未到达bottom，阈值<100）
        for (var angle = 170; angle >= 130; angle -= 1) {
          for (var i = 0; i < 10; i++) {  // 增加到10帧
            analyzer.update(_createFrameAngles(leftKnee: angle.toDouble(), rightKnee: angle.toDouble()));
          }
        }

        // 起身（从130回到170）
        for (var angle = 130; angle <= 170; angle += 1) {
          for (var i = 0; i < 10; i++) {  // 增加到10帧
            analyzer.update(_createFrameAngles(leftKnee: angle.toDouble(), rightKnee: angle.toDouble()));
          }
        }

        // 应该通过descending→standing直接转换，不计数
        expect(analyzer.currentState.currentPhase, 'standing');
        expect(analyzer.currentState.repCount, 0);
      });

      test('多次连续深蹲应正确计数', () async {
        analyzer.reset();

        // 完成3次深蹲
        for (var rep = 0; rep < 3; rep++) {
          // 站立（确保完全回到standing）
          for (var i = 0; i < 20; i++) {  // 增加到20帧
            analyzer.update(_createFrameAngles(leftKnee: 170, rightKnee: 170));
          }

          // 下蹲
          for (var angle = 170; angle >= 80; angle -= 1) {
            for (var i = 0; i < 10; i++) {  // 增加到10帧
              analyzer.update(_createFrameAngles(leftKnee: angle.toDouble(), rightKnee: angle.toDouble()));
            }
          }

          // 起身
          for (var angle = 80; angle <= 170; angle += 1) {
            for (var i = 0; i < 10; i++) {  // 增加到10帧
              analyzer.update(_createFrameAngles(leftKnee: angle.toDouble(), rightKnee: angle.toDouble()));
            }
          }
        }

        expect(analyzer.currentState.repCount, 3);
      });
    });

    group('动作质量判断集成测试', () {
      test('膝角≤90°应达标（完成深蹲后）', () async {
        analyzer.reset();

        // 下蹲到85°
        for (var angle = 170; angle >= 85; angle -= 1) {
          for (var i = 0; i < 10; i++) {  // 增加到10帧
            analyzer.update(_createFrameAngles(leftKnee: angle.toDouble(), rightKnee: angle.toDouble()));
          }
        }

        // 起身完成深蹲
        for (var angle = 85; angle <= 170; angle += 1) {
          for (var i = 0; i < 10; i++) {  // 增加到10帧
            analyzer.update(_createFrameAngles(leftKnee: angle.toDouble(), rightKnee: angle.toDouble()));
          }
        }

        final reps = analyzer.getCompletedReps();
        expect(reps.length, 1);
        final minAngle = reps[0].metrics['minKneeAngle'];
        expect(minAngle! <= 90.0, true);
      });

      test('膝角=90°应达标（边界测试）', () async {
        analyzer.reset();

        for (var angle = 170; angle >= 90; angle -= 1) {
          for (var i = 0; i < 10; i++) {  // 增加到10帧
            analyzer.update(_createFrameAngles(leftKnee: angle.toDouble(), rightKnee: angle.toDouble()));
          }
        }

        for (var angle = 90; angle <= 170; angle += 1) {
          for (var i = 0; i < 10; i++) {  // 增加到10帧
            analyzer.update(_createFrameAngles(leftKnee: angle.toDouble(), rightKnee: angle.toDouble()));
          }
        }

        final reps = analyzer.getCompletedReps();
        expect(reps.length, 1);
        final minAngle = reps[0].metrics['minKneeAngle'];
        expect(minAngle! <= 90.0, true);
      });

      test('膝角=91°不达标（边界测试）', () async {
        analyzer.reset();

        for (var angle = 170; angle >= 91; angle -= 1) {
          for (var i = 0; i < 10; i++) {  // 增加到10帧
            analyzer.update(_createFrameAngles(leftKnee: angle.toDouble(), rightKnee: angle.toDouble()));
          }
        }

        for (var angle = 91; angle <= 170; angle += 1) {
          for (var i = 0; i < 10; i++) {  // 增加到10帧
            analyzer.update(_createFrameAngles(leftKnee: angle.toDouble(), rightKnee: angle.toDouble()));
          }
        }

        final reps = analyzer.getCompletedReps();
        expect(reps.length, 1);
        final minAngle = reps[0].metrics['minKneeAngle'];
        expect(minAngle! > 90.0, true);
      });

      test('膝角=130°不达标（未完成深蹲）', () async {
        analyzer.reset();

        for (var angle = 170; angle >= 130; angle -= 1) {
          for (var i = 0; i < 10; i++) {  // 增加到10帧
            analyzer.update(_createFrameAngles(leftKnee: angle.toDouble(), rightKnee: angle.toDouble()));
          }
        }

        for (var angle = 130; angle <= 170; angle += 1) {
          for (var i = 0; i < 10; i++) {  // 增加到10帧
            analyzer.update(_createFrameAngles(leftKnee: angle.toDouble(), rightKnee: angle.toDouble()));
          }
        }

        // 不应该计数（未到达bottom，通过descending→standing转换）
        expect(analyzer.currentState.repCount, 0);
      });
    });

    group('保存会话集成测试', () {
      test('完成深蹲后保存会话应正确存储', () async {
        analyzer.reset();

        // 完成3次深蹲
        for (var rep = 0; rep < 3; rep++) {
          for (var i = 0; i < 20; i++) {  // 增加到20帧
            analyzer.update(_createFrameAngles(leftKnee: 170, rightKnee: 170));
          }

          for (var angle = 170; angle >= 80; angle -= 1) {
            for (var i = 0; i < 10; i++) {  // 增加到10帧
              analyzer.update(_createFrameAngles(leftKnee: angle.toDouble(), rightKnee: angle.toDouble()));
            }
          }

          for (var angle = 80; angle <= 170; angle += 1) {
            for (var i = 0; i < 10; i++) {  // 增加到10帧
              analyzer.update(_createFrameAngles(leftKnee: angle.toDouble(), rightKnee: angle.toDouble()));
            }
          }
        }

        expect(analyzer.currentState.repCount, 3);

        final reps = analyzer.getCompletedReps();
        expect(reps.length, 3);
        expect(reps[0].exerciseType, 'squat');
      });

      test('重置后应清空状态和计数', () async {
        analyzer.reset();

        for (var angle = 170; angle >= 85; angle -= 1) {
          for (var i = 0; i < 10; i++) {  // 增加到10帧
            analyzer.update(_createFrameAngles(leftKnee: angle.toDouble(), rightKnee: angle.toDouble()));
          }
        }
        for (var angle = 85; angle <= 170; angle += 1) {
          for (var i = 0; i < 10; i++) {  // 增加到10帧
            analyzer.update(_createFrameAngles(leftKnee: angle.toDouble(), rightKnee: angle.toDouble()));
          }
        }

        expect(analyzer.currentState.repCount, 1);

        analyzer.reset();

        expect(analyzer.currentState.repCount, 0);
        expect(analyzer.currentState.currentPhase, 'standing');
        expect(analyzer.getCompletedReps().length, 0);
      });
    });

    group('状态持久化测试', () {
      test('ExerciseRep应正确序列化和反序列化', () {
        final rep = ExerciseRep(
          exerciseType: 'squat',
          timestamp: DateTime(2026, 3, 26, 12, 0),
          metrics: {'minKneeAngle': 85.0, 'maxKneeAngle': 170.0, 'isGoodForm': 1.0},
        );

        final map = rep.toMap();
        final restored = ExerciseRep.fromMap(map);

        expect(restored.exerciseType, rep.exerciseType);
        expect(restored.metrics, rep.metrics);
        expect(restored.keyMetrics, rep.metrics);
      });

      test('WorkoutSession应正确创建和更新', () {
        final session = WorkoutSession.start();
        expect(session.exerciseType, 'squat');
        expect(session.totalReps, 0);

        final squatReps = [
          SquatRep(
            minKneeAngle: 85.0,
            maxKneeAngle: 170.0,
            isGoodForm: true,
            timestamp: DateTime(2026, 3, 26, 12, 0),
          ),
          SquatRep(
            minKneeAngle: 90.0,
            maxKneeAngle: 168.0,
            isGoodForm: true,
            timestamp: DateTime(2026, 3, 26, 12, 1),
          ),
        ];

        session.reps.addAll(squatReps);
        session.totalReps = 2;
        session.goodFormReps = 2;
        session.endTime = DateTime(2026, 3, 26, 12, 5);

        expect(session.totalReps, 2);
        expect(session.goodFormReps, 2);
        expect(session.goodFormRate, 100);
      });
    });

    group('错误处理测试', () {
      test('空角度输入应保持当前状态', () async {
        analyzer.reset();

        // 先进入descending状态
        for (var angle = 170; angle >= 120; angle -= 1) {
          for (var i = 0; i < 10; i++) {
            analyzer.update(_createFrameAngles(leftKnee: angle.toDouble(), rightKnee: angle.toDouble()));
          }
        }

        final stateBefore = analyzer.currentState;

        analyzer.update(_createFrameAngles(leftKnee: 0, rightKnee: 0));

        // 应该保持descending状态
        expect(stateBefore.currentPhase, analyzer.currentState.currentPhase);
        expect(stateBefore.repCount, analyzer.currentState.repCount);
      });

      test('极大角度输入应保持在站立状态', () async {
        analyzer.reset();

        for (var i = 0; i < 20; i++) {
          analyzer.update(_createFrameAngles(leftKnee: 200, rightKnee: 200));
        }

        expect(analyzer.currentState.currentPhase, 'standing');
        expect(analyzer.currentState.repCount, 0);
      });

      test('连续无效输入不应触发状态转换', () async {
        analyzer.reset();

        for (var i = 0; i < 30; i++) {
          analyzer.update(_createFrameAngles(leftKnee: 0, rightKnee: 0));
        }

        expect(analyzer.currentState.currentPhase, 'standing');
        expect(analyzer.currentState.repCount, 0);
      });
    });
  });
}

FrameAngles _createFrameAngles({
  required double leftKnee,
  required double rightKnee,
}) {
  return FrameAngles(
    angles: {
      JointAngleType.leftKnee: AngleResult(joint: JointAngleType.leftKnee, angle: leftKnee),
      JointAngleType.rightKnee: AngleResult(joint: JointAngleType.rightKnee, angle: rightKnee),
    },
    timestamp: DateTime.now(),
  );
}
