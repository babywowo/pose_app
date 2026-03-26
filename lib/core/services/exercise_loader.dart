import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';
import 'package:pose_app/core/models/exercise_definition.dart';

/// 动作配置加载器
class ExerciseLoader {
  static final Map<String, ExerciseDefinition> _cache = {};

  /// 从YAML文件加载配置
  static Future<ExerciseDefinition> fromYaml(String assetPath) async {
    if (_cache.containsKey(assetPath)) {
      return _cache[assetPath]!;
    }

    final yamlString = await rootBundle.loadString(assetPath);
    final yaml = loadYaml(yamlString) as Map<dynamic, dynamic>;

    // 使用 ExerciseDefinition.fromYaml 工厂方法
    final definition = ExerciseDefinition.fromYaml(
      yaml.map((key, value) => MapEntry(key.toString(), value)),
    );

    _cache[assetPath] = definition;
    return definition;
  }
}
