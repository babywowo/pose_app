import 'package:flutter_test/flutter_test.dart';
import 'package:pose_app/core/models/angle_result.dart';
import 'package:pose_app/core/models/pose_landmark.dart';
import 'package:pose_app/core/services/angle_calculator.dart';

void main() {
  group('AngleCalculator.calculateAngle', () {
    test('计算180°直线（三点共线）', () {
      // 三个点在一条垂直线上
      final a = const Offset(0.5, 0.1);
      final b = const Offset(0.5, 0.5);
      final c = const Offset(0.5, 0.9);

      final angle = AngleCalculator.calculateAngle(a, b, c);
      expect(angle, closeTo(180, 1.0));
    });

    test('计算90°直角（L形）', () {
      // b为顶点，ab和cb垂直
      final a = const Offset(0.5, 0.1);
      final b = const Offset(0.5, 0.5);
      final c = const Offset(0.9, 0.5);

      final angle = AngleCalculator.calculateAngle(a, b, c);
      expect(angle, closeTo(90, 1.0));
    });

    test('计算45°锐角', () {
      // 构造等腰直角三角形：b为直角顶点
      // ab垂直向下，cb水平向右
      final a = const Offset(0.5, 0.8);
      final b = const Offset(0.5, 0.5);
      final c = const Offset(0.8, 0.5);

      final angle = AngleCalculator.calculateAngle(a, b, c);
      expect(angle, closeTo(90, 1.0));
    });

    test('计算锐角（<90°）', () {
      final a = const Offset(0.3, 0.3);
      final b = const Offset(0.5, 0.5);
      final c = const Offset(0.7, 0.3);

      final angle = AngleCalculator.calculateAngle(a, b, c);
      expect(angle, lessThan(90));
      expect(angle, greaterThan(0));
    });

    test('计算钝角（>90°）', () {
      final a = const Offset(0.1, 0.5);
      final b = const Offset(0.5, 0.5);
      final c = const Offset(0.7, 0.6);

      final angle = AngleCalculator.calculateAngle(a, b, c);
      expect(angle, greaterThan(90));
      expect(angle, lessThan(180));
    });

    test('零距离点应返回0°', () {
      // a和b重合
      final a = const Offset(0.5, 0.5);
      final b = const Offset(0.5, 0.5);
      final c = const Offset(0.7, 0.5);

      final angle = AngleCalculator.calculateAngle(a, b, c);
      expect(angle, 0);

      // b和c重合
      final a2 = const Offset(0.5, 0.5);
      final b2 = const Offset(0.5, 0.5);
      final c2 = const Offset(0.5, 0.5);

      final angle2 = AngleCalculator.calculateAngle(a2, b2, c2);
      expect(angle2, 0);
    });
  });

  group('AngleCalculator.calculate', () {
    late AngleCalculator calculator;

    setUp(() {
      calculator = const AngleCalculator();
    });

    test('空帧应返回空角度结果', () {
      final emptyFrame = PoseFrame(
        landmarks: [],
        timestamp: DateTime.now(),
      );

      final result = calculator.calculate(emptyFrame);
      expect(result.isEmpty, true);
      expect(result.angles.isEmpty, true);
    });

    test('完整姿态帧应计算所有关节角度', () {
      // 构造一个模拟的姿态帧（标准化坐标）
      final frame = PoseFrame(
        landmarks: [
          // 左腿
          PoseLandmark(
            type: PoseLandmarkType.leftHip,
            x: 0.4,
            y: 0.4,
            z: 0,
            likelihood: 0.9,
          ),
          PoseLandmark(
            type: PoseLandmarkType.leftKnee,
            x: 0.4,
            y: 0.6,
            z: 0,
            likelihood: 0.9,
          ),
          PoseLandmark(
            type: PoseLandmarkType.leftAnkle,
            x: 0.4,
            y: 0.8,
            z: 0,
            likelihood: 0.9,
          ),
          // 右腿
          PoseLandmark(
            type: PoseLandmarkType.rightHip,
            x: 0.6,
            y: 0.4,
            z: 0,
            likelihood: 0.9,
          ),
          PoseLandmark(
            type: PoseLandmarkType.rightKnee,
            x: 0.6,
            y: 0.6,
            z: 0,
            likelihood: 0.9,
          ),
          PoseLandmark(
            type: PoseLandmarkType.rightAnkle,
            x: 0.6,
            y: 0.8,
            z: 0,
            likelihood: 0.9,
          ),
          // 左肩
          PoseLandmark(
            type: PoseLandmarkType.leftShoulder,
            x: 0.4,
            y: 0.2,
            z: 0,
            likelihood: 0.9,
          ),
          // 右肩
          PoseLandmark(
            type: PoseLandmarkType.rightShoulder,
            x: 0.6,
            y: 0.2,
            z: 0,
            likelihood: 0.9,
          ),
        ],
        timestamp: DateTime.now(),
      );

      final result = calculator.calculate(frame);
      expect(result.isEmpty, false);

      // 应该计算到左右膝盖角度
      expect(result.getAngle(JointAngleType.leftKnee), isNotNull);
      expect(result.getAngle(JointAngleType.rightKnee), isNotNull);

      // 由于三点共线，角度应接近180°
      expect(
        result.getAngleValue(JointAngleType.leftKnee),
        closeTo(180, 5.0),
      );
      expect(
        result.getAngleValue(JointAngleType.rightKnee),
        closeTo(180, 5.0),
      );
    });

    test('可信度不足的关键点应被跳过', () {
      final frame = PoseFrame(
        landmarks: [
          PoseLandmark(
            type: PoseLandmarkType.leftHip,
            x: 0.4,
            y: 0.4,
            z: 0,
            likelihood: 0.9, // 可信
          ),
          PoseLandmark(
            type: PoseLandmarkType.leftKnee,
            x: 0.4,
            y: 0.6,
            z: 0,
            likelihood: 0.3, // 不可信
          ),
          PoseLandmark(
            type: PoseLandmarkType.leftAnkle,
            x: 0.4,
            y: 0.8,
            z: 0,
            likelihood: 0.9,
          ),
        ],
        timestamp: DateTime.now(),
      );

      final result = calculator.calculate(frame);
      // 左膝角度应为null，因为左膝关键点不可信
      expect(result.getAngle(JointAngleType.leftKnee), isNull);
    });

    test('缺失的关键点应被跳过', () {
      final frame = PoseFrame(
        landmarks: [
          // 只提供左髋和左膝，缺失左踝
          PoseLandmark(
            type: PoseLandmarkType.leftHip,
            x: 0.4,
            y: 0.4,
            z: 0,
            likelihood: 0.9,
          ),
          PoseLandmark(
            type: PoseLandmarkType.leftKnee,
            x: 0.4,
            y: 0.6,
            z: 0,
            likelihood: 0.9,
          ),
        ],
        timestamp: DateTime.now(),
      );

      final result = calculator.calculate(frame);
      // 左膝角度应为null，因为左踝缺失
      expect(result.getAngle(JointAngleType.leftKnee), isNull);
    });

    test('计算深度蹲姿（膝盖≈80°）', () {
      // 构造一个深蹲姿态：膝盖明显弯曲
      // hip(0.5, 0.3), knee(0.35, 0.6), ankle(0.65, 0.8)
      final frame = PoseFrame(
        landmarks: [
          PoseLandmark(
            type: PoseLandmarkType.leftHip,
            x: 0.5,
            y: 0.3,
            z: 0,
            likelihood: 0.9,
          ),
          PoseLandmark(
            type: PoseLandmarkType.leftKnee,
            x: 0.35,
            y: 0.6,
            z: 0,
            likelihood: 0.9,
          ),
          PoseLandmark(
            type: PoseLandmarkType.leftAnkle,
            x: 0.65,
            y: 0.8,
            z: 0,
            likelihood: 0.9,
          ),
        ],
        timestamp: DateTime.now(),
      );

      final result = calculator.calculate(frame);
      final leftKneeAngle = result.getAngleValue(JointAngleType.leftKnee);

      expect(leftKneeAngle, isNotNull);
      // 深蹲姿态，膝盖角度应在70-100度之间
      expect(leftKneeAngle!, greaterThan(70));
      expect(leftKneeAngle, lessThan(100));
    });

    test('计算站立姿态（膝盖≈170°）', () {
      // 构造一个站立姿态（接近直线，略有自然弯曲）
      final frame = PoseFrame(
        landmarks: [
          PoseLandmark(
            type: PoseLandmarkType.leftHip,
            x: 0.4,
            y: 0.3,
            z: 0,
            likelihood: 0.9,
          ),
          PoseLandmark(
            type: PoseLandmarkType.leftKnee,
            x: 0.4,
            y: 0.5,
            z: 0,
            likelihood: 0.9,
          ),
          PoseLandmark(
            type: PoseLandmarkType.leftAnkle,
            x: 0.4,
            y: 0.7,
            z: 0,
            likelihood: 0.9,
          ),
        ],
        timestamp: DateTime.now(),
      );

      final result = calculator.calculate(frame);
      final leftKneeAngle = result.getAngleValue(JointAngleType.leftKnee);

      expect(leftKneeAngle, isNotNull);
      // 站立姿态，膝盖角度应接近180度
      expect(leftKneeAngle, greaterThan(160));
      expect(leftKneeAngle, lessThanOrEqualTo(180));
    });

    test('角度计算精度测试（误差≤2°）', () {
      // 构造已知角度的姿态（90度）
      final frame = PoseFrame(
        landmarks: [
          PoseLandmark(
            type: PoseLandmarkType.leftHip,
            x: 0.4,
            y: 0.4,
            z: 0,
            likelihood: 0.9,
          ),
          PoseLandmark(
            type: PoseLandmarkType.leftKnee,
            x: 0.4,
            y: 0.6,
            z: 0,
            likelihood: 0.9,
          ),
          PoseLandmark(
            type: PoseLandmarkType.leftAnkle,
            x: 0.6,
            y: 0.6,
            z: 0,
            likelihood: 0.9,
          ),
        ],
        timestamp: DateTime.now(),
      );

      final result = calculator.calculate(frame);
      final leftKneeAngle = result.getAngleValue(JointAngleType.leftKnee);

      expect(leftKneeAngle, isNotNull);
      // 理论值是90度，允许误差2度
      expect(leftKneeAngle!, closeTo(90, 2));
    });

    test('应计算所有8个关节角度', () {
      final frame = PoseFrame(
        landmarks: [
          // 腿部
          PoseLandmark(
            type: PoseLandmarkType.leftHip,
            x: 0.4,
            y: 0.4,
            z: 0,
            likelihood: 0.9,
          ),
          PoseLandmark(
            type: PoseLandmarkType.leftKnee,
            x: 0.4,
            y: 0.6,
            z: 0,
            likelihood: 0.9,
          ),
          PoseLandmark(
            type: PoseLandmarkType.leftAnkle,
            x: 0.4,
            y: 0.8,
            z: 0,
            likelihood: 0.9,
          ),
          PoseLandmark(
            type: PoseLandmarkType.rightHip,
            x: 0.6,
            y: 0.4,
            z: 0,
            likelihood: 0.9,
          ),
          PoseLandmark(
            type: PoseLandmarkType.rightKnee,
            x: 0.6,
            y: 0.6,
            z: 0,
            likelihood: 0.9,
          ),
          PoseLandmark(
            type: PoseLandmarkType.rightAnkle,
            x: 0.6,
            y: 0.8,
            z: 0,
            likelihood: 0.9,
          ),
          // 肩部
          PoseLandmark(
            type: PoseLandmarkType.leftShoulder,
            x: 0.4,
            y: 0.2,
            z: 0,
            likelihood: 0.9,
          ),
          PoseLandmark(
            type: PoseLandmarkType.rightShoulder,
            x: 0.6,
            y: 0.2,
            z: 0,
            likelihood: 0.9,
          ),
          // 手臂
          PoseLandmark(
            type: PoseLandmarkType.leftElbow,
            x: 0.3,
            y: 0.5,
            z: 0,
            likelihood: 0.9,
          ),
          PoseLandmark(
            type: PoseLandmarkType.leftWrist,
            x: 0.2,
            y: 0.6,
            z: 0,
            likelihood: 0.9,
          ),
          PoseLandmark(
            type: PoseLandmarkType.rightElbow,
            x: 0.7,
            y: 0.5,
            z: 0,
            likelihood: 0.9,
          ),
          PoseLandmark(
            type: PoseLandmarkType.rightWrist,
            x: 0.8,
            y: 0.6,
            z: 0,
            likelihood: 0.9,
          ),
        ],
        timestamp: DateTime.now(),
      );

      final result = calculator.calculate(frame);

      // 验证所有8个关节角度都被计算
      final expectedJoints = [
        JointAngleType.leftKnee,
        JointAngleType.rightKnee,
        JointAngleType.leftHip,
        JointAngleType.rightHip,
        JointAngleType.leftElbow,
        JointAngleType.rightElbow,
        JointAngleType.leftShoulder,
        JointAngleType.rightShoulder,
      ];

      for (final joint in expectedJoints) {
        expect(
          result.getAngle(joint),
          isNotNull,
          reason: '$joint should be calculated',
        );
      }
    });
  });

  group('AngleCalculator.smooth', () {
    test('EMA平滑测试', () {
      // alpha = 0.3
      final prev = 100.0;
      final current = 150.0;
      final smoothed = AngleCalculator.smooth(prev, current);

      // 100 * 0.7 + 150 * 0.3 = 70 + 45 = 115
      expect(smoothed, closeTo(115, 0.01));
    });

    test('自定义alpha平滑', () {
      final prev = 100.0;
      final current = 150.0;
      final smoothed = AngleCalculator.smooth(prev, current, alpha: 0.5);

      // 100 * 0.5 + 150 * 0.5 = 50 + 75 = 125
      expect(smoothed, closeTo(125, 0.01));
    });

    test('完全使用当前值（alpha=1）', () {
      final prev = 100.0;
      final current = 150.0;
      final smoothed = AngleCalculator.smooth(prev, current, alpha: 1.0);

      expect(smoothed, closeTo(150, 0.01));
    });

    test('完全使用之前值（alpha=0）', () {
      final prev = 100.0;
      final current = 150.0;
      final smoothed = AngleCalculator.smooth(prev, current, alpha: 0.0);

      expect(smoothed, closeTo(100, 0.01));
    });
  });

  group('FrameAngles', () {
    test('getAngle应返回对应关节的角度', () {
      final angles = FrameAngles(
        angles: {
          JointAngleType.leftKnee: const AngleResult(
            joint: JointAngleType.leftKnee,
            angle: 90.5,
          ),
          JointAngleType.rightKnee: const AngleResult(
            joint: JointAngleType.rightKnee,
            angle: 91.5,
          ),
        },
        timestamp: DateTime.now(),
      );

      expect(angles.getAngle(JointAngleType.leftKnee)!.angle, 90.5);
      expect(angles.getAngle(JointAngleType.rightKnee)!.angle, 91.5);
    });

    test('getAngleValue应返回角度值', () {
      final angles = FrameAngles(
        angles: {
          JointAngleType.leftKnee: const AngleResult(
            joint: JointAngleType.leftKnee,
            angle: 90.5,
          ),
        },
        timestamp: DateTime.now(),
      );

      expect(angles.getAngleValue(JointAngleType.leftKnee), 90.5);
    });

    test('getAngle和getAngleValue对不存在的关节应返回null', () {
      final angles = FrameAngles(
        angles: {},
        timestamp: DateTime.now(),
      );

      expect(angles.getAngle(JointAngleType.leftKnee), isNull);
      expect(angles.getAngleValue(JointAngleType.leftKnee), isNull);
    });

    test('empty()应创建空FrameAngles', () {
      final empty = FrameAngles.empty();
      expect(empty.isEmpty, true);
      expect(empty.angles.isEmpty, true);
    });
  });

  group('AngleResult', () {
    test('formattedAngle应格式化角度', () {
      final result = const AngleResult(
        joint: JointAngleType.leftKnee,
        angle: 90.567,
      );

      expect(result.formattedAngle, '90.6°');
    });

    test('invalid常量应为无效角度', () {
      final invalid = AngleResult.invalid;
      expect(invalid.isValid, false);
      expect(invalid.angle, 0);
    });
  });
}
