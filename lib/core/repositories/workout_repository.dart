import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pose_app/core/models/workout_session.dart';

const _kSessionBox = 'workout_sessions';

/// 本地历史记录仓库
class WorkoutRepository {
  Box<WorkoutSession>? _box;

  Future<void> init() async {
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(SquatRepAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(WorkoutSessionAdapter());
    }
    _box = await Hive.openBox<WorkoutSession>(_kSessionBox);
  }

  Box<WorkoutSession> get _safeBox {
    if (_box == null || !_box!.isOpen) {
      throw StateError('WorkoutRepository not initialized. Call init() first.');
    }
    return _box!;
  }

  /// 保存一次会话
  Future<void> saveSession(WorkoutSession session) async {
    await _safeBox.put(session.id, session);
  }

  /// 获取所有会话（按时间倒序）
  List<WorkoutSession> getAllSessions() {
    final sessions = _safeBox.values.toList();
    sessions.sort((a, b) => b.startTime.compareTo(a.startTime));
    return sessions;
  }

  /// 删除一条记录
  Future<void> deleteSession(String id) async {
    await _safeBox.delete(id);
  }

  Future<void> dispose() async {
    await _box?.close();
  }
}

final workoutRepositoryProvider = Provider<WorkoutRepository>((ref) {
  final repo = WorkoutRepository();
  ref.onDispose(repo.dispose);
  return repo;
});

/// 历史记录列表（异步加载）
final historySessionsProvider =
    FutureProvider<List<WorkoutSession>>((ref) async {
  final repo = ref.watch(workoutRepositoryProvider);
  try {
    return repo.getAllSessions();
  } catch (e) {
    // 如果repository未初始化，返回空列表
    return [];
  }
});
