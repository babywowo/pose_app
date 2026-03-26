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

  // 初始化 WorkoutRepository（同步等待，确保后续使用时已就绪）
  final workoutRepository = WorkoutRepository();
  await workoutRepository.init();

  runApp(
    ProviderScope(
      overrides: [
        // 使用已初始化的 repository
        workoutRepositoryProvider.overrideWithValue(workoutRepository),
      ],
      child: const PoseApp(),
    ),
  );
}
