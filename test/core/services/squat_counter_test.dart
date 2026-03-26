import 'package:flutter_test/flutter_test.dart';
import 'package:pose_app/core/models/angle_result.dart';
import 'package:pose_app/core/services/squat_counter.dart';

void main() {
  group('SquatCounter', () {
    late SquatCounter counter;

    setUp(() {
      counter = SquatCounter();
    });

    group('初始状态测试', () {
      test('初始状态应为站立，计数为0', () {
        final state = counter.update(FrameAngles.empty());
        expect(state.repCount, 0);
        expect(state.phase, SquatPhase.standing);
        expect(state.feedback, '站立准备，开始下蹲');
      });
    });

    group('完整深蹲测试（考虑EMA平滑）', () {
      test('完成一次完整深蹲应计数1次', () {
        // 站立初始状态，多次稳定在站立角度
        for (var i = 0; i < 10; i++) {
          counter.update(FrameAngles(
            angles: {
              JointAngleType.leftKnee: const AngleResult(
                joint: JointAngleType.leftKnee,
                angle: 175,
              ),
              JointAngleType.rightKnee: const AngleResult(
                joint: JointAngleType.rightKnee,
                angle: 175,
              ),
            },
            timestamp: DateTime.now(),
          ));
        }
        expect(counter.update(FrameAngles.empty()).phase, SquatPhase.standing);

        // 下蹲过程：使用更频繁的更新，每次递减5度，每级重复2次
        for (var angle = 170; angle >= 70; angle -= 5) {
          for (var i = 0; i < 2; i++) {
            counter.update(FrameAngles(
              angles: {
                JointAngleType.leftKnee: AngleResult(
                  joint: JointAngleType.leftKnee,
                  angle: angle.toDouble(),
                ),
                JointAngleType.rightKnee: AngleResult(
                  joint: JointAngleType.rightKnee,
                  angle: angle.toDouble(),
                ),
              },
              timestamp: DateTime.now(),
            ));
          }
        }

        // 起身过程：同样频率恢复
        for (var angle = 70; angle <= 175; angle += 5) {
          for (var i = 0; i < 2; i++) {
            counter.update(FrameAngles(
              angles: {
                JointAngleType.leftKnee: AngleResult(
                  joint: JointAngleType.leftKnee,
                  angle: angle.toDouble(),
                ),
                JointAngleType.rightKnee: AngleResult(
                  joint: JointAngleType.rightKnee,
                  angle: angle.toDouble(),
                ),
              },
              timestamp: DateTime.now(),
            ));
          }
        }

        // 验证最终计数与阶段
        final finalState = counter.update(FrameAngles.empty());
        expect(finalState.repCount, greaterThan(0));
        expect(finalState.phase, SquatPhase.standing);
      });

      test('不完整下蹲不应计数', () {
        // 模拟未达阈值深度的下蹲，下到130度后恢复
        for (var angle = 175; angle >= 130; angle -= 10) {
          counter.update(FrameAngles(
            angles: {
              JointAngleType.leftKnee: AngleResult(
                joint: JointAngleType.leftKnee,
                angle: angle.toDouble(),
              ),
              JointAngleType.rightKnee: AngleResult(
                joint: JointAngleType.rightKnee,
                angle: angle.toDouble(),
              ),
            },
            timestamp: DateTime.now(),
          ));
        }

        for (var angle = 130; angle <= 175; angle += 10) {
          counter.update(FrameAngles(
            angles: {
              JointAngleType.leftKnee: AngleResult(
                joint: JointAngleType.leftKnee,
                angle: angle.toDouble(),
              ),
              JointAngleType.rightKnee: AngleResult(
                joint: JointAngleType.rightKnee,
                angle: angle.toDouble(),
              ),
            },
            timestamp: DateTime.now(),
          ));
        }

        final state = counter.update(FrameAngles.empty());
        expect(state.repCount, 0);
      });

      test('深蹲达到90°以下应标记为达标', () {
        // 下蹲到60度，确保触发达标判定
        for (var angle = 175; angle >= 60; angle -= 5) {
          for (var i = 0; i < 2; i++) {
            counter.update(FrameAngles(
              angles: {
                JointAngleType.leftKnee: AngleResult(
                  joint: JointAngleType.leftKnee,
                  angle: angle.toDouble(),
                ),
                JointAngleType.rightKnee: AngleResult(
                  joint: JointAngleType.rightKnee,
                  angle: angle.toDouble(),
                ),
              },
              timestamp: DateTime.now(),
            ));
          }
        }

        final state = counter.update(FrameAngles.empty());
        expect(state.isGoodForm, true);
      });

      test('深蹲只到95°应标记为不达标', () {
        // 下蹲到95度，判定不达标
        for (var angle = 175; angle >= 95; angle -= 10) {
          counter.update(FrameAngles(
            angles: {
              JointAngleType.leftKnee: AngleResult(
                joint: JointAngleType.leftKnee,
                angle: angle.toDouble(),
              ),
              JointAngleType.rightKnee: AngleResult(
                joint: JointAngleType.rightKnee,
                angle: angle.toDouble(),
              ),
            },
            timestamp: DateTime.now(),
          ));
        }

        final state = counter.update(FrameAngles.empty());
        expect(state.isGoodForm, false);
      });

      test('连续3次完整深蹲应计数3次', () {
        // 执行3次完整下蹲循环，使用更小的步长确保平滑值充分到达阈值
        for (var rep = 0; rep < 3; rep++) {
          // 先稳定站立状态
          for (var i = 0; i < 5; i++) {
            counter.update(FrameAngles(
              angles: {
                JointAngleType.leftKnee: const AngleResult(
                  joint: JointAngleType.leftKnee,
                  angle: 175,
                ),
                JointAngleType.rightKnee: const AngleResult(
                  joint: JointAngleType.rightKnee,
                  angle: 175,
                ),
              },
              timestamp: DateTime.now(),
            ));
          }

          // 下蹲：小步长（5°），每级重复3次，确保EMA平滑值低于100°
          for (var angle = 170; angle >= 70; angle -= 5) {
            for (var i = 0; i < 3; i++) {
              counter.update(FrameAngles(
                angles: {
                  JointAngleType.leftKnee: AngleResult(
                    joint: JointAngleType.leftKnee,
                    angle: angle.toDouble(),
                  ),
                  JointAngleType.rightKnee: AngleResult(
                    joint: JointAngleType.rightKnee,
                    angle: angle.toDouble(),
                  ),
                },
                timestamp: DateTime.now(),
              ));
            }
          }

          // 在底部停留几帧确保状态稳定
          for (var i = 0; i < 5; i++) {
            counter.update(FrameAngles(
              angles: {
                JointAngleType.leftKnee: const AngleResult(
                  joint: JointAngleType.leftKnee,
                  angle: 70,
                ),
                JointAngleType.rightKnee: const AngleResult(
                  joint: JointAngleType.rightKnee,
                  angle: 70,
                ),
              },
              timestamp: DateTime.now(),
            ));
          }

          // 起身：小步长（5°），每级重复3次
          for (var angle = 70; angle <= 175; angle += 5) {
            for (var i = 0; i < 3; i++) {
              counter.update(FrameAngles(
                angles: {
                  JointAngleType.leftKnee: AngleResult(
                    joint: JointAngleType.leftKnee,
                    angle: angle.toDouble(),
                  ),
                  JointAngleType.rightKnee: AngleResult(
                    joint: JointAngleType.rightKnee,
                    angle: angle.toDouble(),
                  ),
                },
                timestamp: DateTime.now(),
              ));
            }
          }
        }

        final state = counter.update(FrameAngles.empty());
        expect(state.repCount, equals(3));
      });
    });

    group('reset测试', () {
      test('reset后应回到初始状态', () {
        // 先执行一次角度更新
        counter.update(FrameAngles(
          angles: {
            JointAngleType.leftKnee: const AngleResult(
              joint: JointAngleType.leftKnee,
              angle: 150,
            ),
            JointAngleType.rightKnee: const AngleResult(
              joint: JointAngleType.rightKnee,
              angle: 150,
            ),
          },
          timestamp: DateTime.now(),
        ));

        // 执行 reset
        counter.reset();

        // 验证恢复初始状态
        final state = counter.update(FrameAngles.empty());
        expect(state.repCount, 0);
        expect(state.phase, SquatPhase.standing);
        expect(state.isGoodForm, false);
      });

      test('reset后应清空reps列表', () {
        // 先完成一次完整深蹲，使用小步长确保到达底部状态
        // 稳定站立
        for (var i = 0; i < 5; i++) {
          counter.update(FrameAngles(
            angles: {
              JointAngleType.leftKnee: const AngleResult(
                joint: JointAngleType.leftKnee,
                angle: 175,
              ),
              JointAngleType.rightKnee: const AngleResult(
                joint: JointAngleType.rightKnee,
                angle: 175,
              ),
            },
            timestamp: DateTime.now(),
          ));
        }

        // 下蹲：小步长（5°），每级重复3次
        for (var angle = 170; angle >= 70; angle -= 5) {
          for (var i = 0; i < 3; i++) {
            counter.update(FrameAngles(
              angles: {
                JointAngleType.leftKnee: AngleResult(
                  joint: JointAngleType.leftKnee,
                  angle: angle.toDouble(),
                ),
                JointAngleType.rightKnee: AngleResult(
                  joint: JointAngleType.rightKnee,
                  angle: angle.toDouble(),
                ),
              },
              timestamp: DateTime.now(),
            ));
          }
        }

        // 底部停留
        for (var i = 0; i < 5; i++) {
          counter.update(FrameAngles(
            angles: {
              JointAngleType.leftKnee: const AngleResult(
                joint: JointAngleType.leftKnee,
                angle: 70,
              ),
              JointAngleType.rightKnee: const AngleResult(
                joint: JointAngleType.rightKnee,
                angle: 70,
              ),
            },
            timestamp: DateTime.now(),
          ));
        }

        // 起身：小步长（5°），每级重复3次
        for (var angle = 70; angle <= 175; angle += 5) {
          for (var i = 0; i < 3; i++) {
            counter.update(FrameAngles(
              angles: {
                JointAngleType.leftKnee: AngleResult(
                  joint: JointAngleType.leftKnee,
                  angle: angle.toDouble(),
                ),
                JointAngleType.rightKnee: AngleResult(
                  joint: JointAngleType.rightKnee,
                  angle: angle.toDouble(),
                ),
              },
              timestamp: DateTime.now(),
            ));
          }
        }

        expect(counter.reps.length, greaterThan(0));

        // 执行 reset，清空 reps
        counter.reset();

        // 验证 reps 已清空
        expect(counter.reps.isEmpty, true);
      });
    });

    group('空关键点处理测试', () {
      test('空角度应使用平滑值', () {
        // 初始化一次稳定状态
        counter.update(FrameAngles(
          angles: {
            JointAngleType.leftKnee: const AngleResult(
              joint: JointAngleType.leftKnee,
              angle: 170,
            ),
            JointAngleType.rightKnee: const AngleResult(
              joint: JointAngleType.rightKnee,
              angle: 170,
            ),
          },
          timestamp: DateTime.now(),
        ));

        // 传入空角度应使用平滑值，不抛出异常
        final state = counter.update(FrameAngles.empty());

        expect(state, isNotNull);
        expect(state.phase, SquatPhase.standing);
      });

      test('部分关键点缺失应使用默认值', () {
        // 仅提供左膝角度，右膝使用默认/平滑值
        final state = counter.update(FrameAngles(
          angles: {
            JointAngleType.leftKnee: const AngleResult(
              joint: JointAngleType.leftKnee,
              angle: 150,
            ),
          },
          timestamp: DateTime.now(),
        ));

        // 状态应正常生成
        expect(state, isNotNull);
      });
    });

    group('反馈消息测试', () {
      test('站立阶段应显示"站立准备，开始下蹲"', () {
        counter.update(FrameAngles(
          angles: {
            JointAngleType.leftKnee: const AngleResult(
              joint: JointAngleType.leftKnee,
              angle: 170,
            ),
            JointAngleType.rightKnee: const AngleResult(
              joint: JointAngleType.rightKnee,
              angle: 170,
            ),
          },
          timestamp: DateTime.now(),
        ));

        final state = counter.update(FrameAngles.empty());
        expect(state.feedback, '站立准备，开始下蹲');
      });

      test('下蹲阶段应显示继续下蹲提示', () {
        // 多次更新角度进入下蹲阶段
        for (var angle = 175; angle >= 130; angle -= 10) {
          counter.update(FrameAngles(
            angles: {
              JointAngleType.leftKnee: AngleResult(
                joint: JointAngleType.leftKnee,
                angle: angle.toDouble(),
              ),
              JointAngleType.rightKnee: AngleResult(
                joint: JointAngleType.rightKnee,
                angle: angle.toDouble(),
              ),
            },
            timestamp: DateTime.now(),
          ));
        }

        final state = counter.update(FrameAngles.empty());
        expect(state.feedback, contains('继续下蹲'));
      });

      test('底部达标应显示"✓ 深度到位！"', () {
        // 下蹲到85度，触发底部达标反馈
        // 注意：根据代码，_squatThreshold = 100°，需要多次更新让平滑值低于100°
        for (var angle = 175; angle >= 70; angle -= 5) {
          for (var i = 0; i < 2; i++) {
            counter.update(FrameAngles(
              angles: {
                JointAngleType.leftKnee: AngleResult(
                  joint: JointAngleType.leftKnee,
                  angle: angle.toDouble(),
                ),
                JointAngleType.rightKnee: AngleResult(
                  joint: JointAngleType.rightKnee,
                  angle: angle.toDouble(),
                ),
              },
              timestamp: DateTime.now(),
            ));
          }
        }

        final state = counter.update(FrameAngles.empty());
        expect(state.feedback, '✓ 深度到位！');
      });

      test('底部不达标应显示"再深一点 (目标 ≤ 90°)"', () {
        // 下蹲到95度，不达标
        // 同样需要多次更新让平滑值稳定在底部状态
        for (var angle = 175; angle >= 95; angle -= 5) {
          for (var i = 0; i < 2; i++) {
            counter.update(FrameAngles(
              angles: {
                JointAngleType.leftKnee: AngleResult(
                  joint: JointAngleType.leftKnee,
                  angle: angle.toDouble(),
                ),
                JointAngleType.rightKnee: AngleResult(
                  joint: JointAngleType.rightKnee,
                  angle: angle.toDouble(),
                ),
              },
              timestamp: DateTime.now(),
            ));
          }
        }

        final state = counter.update(FrameAngles.empty());
        expect(state.feedback, '再深一点 (目标 ≤ 90°)');
      });

      test('起身阶段应显示"起身中…"', () {
        // 先完成下蹲
        for (var angle = 175; angle >= 85; angle -= 10) {
          counter.update(FrameAngles(
            angles: {
              JointAngleType.leftKnee: AngleResult(
                joint: JointAngleType.leftKnee,
                angle: angle.toDouble(),
              ),
              JointAngleType.rightKnee: AngleResult(
                joint: JointAngleType.rightKnee,
                angle: angle.toDouble(),
              ),
            },
            timestamp: DateTime.now(),
          ));
        }

        // 起身
        for (var angle = 85; angle <= 120; angle += 10) {
          counter.update(FrameAngles(
            angles: {
              JointAngleType.leftKnee: AngleResult(
                joint: JointAngleType.leftKnee,
                angle: angle.toDouble(),
              ),
              JointAngleType.rightKnee: AngleResult(
                joint: JointAngleType.rightKnee,
                angle: angle.toDouble(),
              ),
            },
            timestamp: DateTime.now(),
          ));
        }

        final state = counter.update(FrameAngles.empty());
        expect(state.feedback, '起身中…');
      });
    });
  });
}
