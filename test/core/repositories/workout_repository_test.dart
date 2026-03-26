import 'package:flutter_test/flutter_test.dart';
import 'package:pose_app/core/models/workout_session.dart';
import 'package:pose_app/core/repositories/workout_repository.dart';
import 'package:hive/hive.dart';
import 'dart:io';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late WorkoutRepository repository;
  late HiveTestHelper testHelper;

  setUp(() async {
    testHelper = HiveTestHelper();
    await testHelper.setup();
    
    repository = WorkoutRepository();
    await repository.init();
  });

  tearDown(() async {
    await repository.dispose();
    await testHelper.teardown();
  });

  group('WorkoutRepository', () {
    test('初始化后应该能够获取所有会话（空列表）', () async {
      final sessions = repository.getAllSessions();
      expect(sessions, isEmpty);
    });

    test('保存会话后应该能够获取到', () async {
      final now = DateTime.now();
      final session = WorkoutSession(
        id: 'test-1',
        exerciseType: 'squat',
        startTime: now.subtract(const Duration(minutes: 5)),
        endTime: now,
        totalReps: 10,
        goodFormReps: 8,
        avgKneeAngle: 95.0,
      );

      await repository.saveSession(session);
      
      final sessions = repository.getAllSessions();
      expect(sessions.length, 1);
      expect(sessions.first.id, 'test-1');
    });

    test('getAllSessions应该按时间倒序排列', () async {
      final now = DateTime.now();
      final session1 = WorkoutSession(
        id: 'test-1',
        exerciseType: 'squat',
        startTime: now.subtract(const Duration(hours: 2)),
        endTime: now.subtract(const Duration(hours: 1, minutes: 55)),
        totalReps: 10,
        goodFormReps: 8,
        avgKneeAngle: 95.0,
      );
      final session2 = WorkoutSession(
        id: 'test-2',
        exerciseType: 'squat',
        startTime: now.subtract(const Duration(hours: 1)),
        endTime: now.subtract(const Duration(minutes: 55)),
        totalReps: 15,
        goodFormReps: 12,
        avgKneeAngle: 90.0,
      );

      await repository.saveSession(session1);
      await repository.saveSession(session2);
      
      final sessions = repository.getAllSessions();
      expect(sessions.length, 2);
      expect(sessions.first.id, 'test-2'); // 较新的应该在前
      expect(sessions[1].id, 'test-1');
    });

    test('删除会话后应该从列表中移除', () async {
      final now = DateTime.now();
      final session = WorkoutSession(
        id: 'test-1',
        exerciseType: 'squat',
        startTime: now.subtract(const Duration(minutes: 5)),
        endTime: now,
        totalReps: 10,
        goodFormReps: 8,
        avgKneeAngle: 95.0,
      );

      await repository.saveSession(session);
      expect(repository.getAllSessions().length, 1);
      
      await repository.deleteSession('test-1');
      expect(repository.getAllSessions().length, 0);
    });
  });
}

class HiveTestHelper {
  String? _tempDir;
  
  Future<void> setup() async {
    _tempDir = Directory.systemTemp.createTempSync().path;
    Hive.init(_tempDir);
    
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(SquatRepAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(WorkoutSessionAdapter());
    }
  }
  
  Future<void> teardown() async {
    await Hive.close();
    if (_tempDir != null) {
      await Directory(_tempDir!).delete(recursive: true);
    }
  }
}
