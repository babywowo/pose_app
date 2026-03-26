import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pose_app/app.dart';
import 'package:pose_app/core/repositories/workout_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 强制竖屏（姿态检测最佳体验）
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // 沉浸式状态栏
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // 初始化 Hive
  await Hive.initFlutter();

  runApp(
    ProviderScope(
      overrides: [
        // 预先初始化 WorkoutRepository
        workoutRepositoryProvider.overrideWith((ref) {
          final repo = WorkoutRepository();
          repo.init(); // 异步，不阻塞启动
          ref.onDispose(repo.dispose);
          return repo;
        }),
      ],
      child: const PoseApp(),
    ),
  );
}
