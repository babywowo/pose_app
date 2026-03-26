# 三层姿态检测架构设计文档

**设计日期**: 2026-03-26  
**设计者**: AI Agent  
**版本**: v1.0

---

## 1️⃣ 架构总览

```
┌─────────────────────────────────────────────────────────────┐
│                  三层姿态检测架构                         │
└─────────────────────────────────────────────────────────────┘
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
    ┌───▼────┐       ┌───▼────┐       ┌───▼────┐
    │ Layer 1 │       │ Layer 2 │       │ Layer 3 │
    │  触发   │  ───▶ │  稳定   │  ───▶ │  过渡   │
    │  机制   │       │  检测   │       │  平滑   │
    └───┬────┘       └───┬────┘       └───┬────┘
        │               │               │
        │               │               │
        ▼               ▼               ▼
   [瞬时阈值]      [时间窗口]      [连续性验证]
   [当前实现]      [预留接口]      [预留接口]
```

---

## 2️⃣ 第一层：阈值触发机制 (当前实现)

### 核心目标
- **即时响应**: 角度达到阈值立即触发状态转换
- **零延迟**: 不考虑时间因素，纯角度驱动
- **适用场景**: 集成测试、快速响应的应用

### 技术实现
```dart
// 当前代码已实现
class TriggerLayer {
  // 瞬时阈值判断
  static bool checkTrigger({
    required double angle,
    required String operator,
    required double threshold,
  }) {
    switch (operator) {
      case '<': return angle < threshold;
      case '<=': return angle <= threshold;
      case '>': return angle > threshold;
      case '>=': return angle >= threshold;
      default: return false;
    }
  }
}
```

### 配置示例 (YAML)
```yaml
phases:
  - id: standing
    label: 站立
    
transitions:
  - from: standing
    to: descending
    should_count_rep: false
    triggers:
      - joint: leftKnee
        aggregation: avg
        operator: <     # 第一层：瞬时触发
        max: 150        # 膝角 < 150° 立即触发
```

### 集成测试适配
- ✅ 无需修改
- ✅ 测试数据本身无噪声，不需要稳定性检测
- ✅ 期望即时响应，第一层完美匹配

---

## 3️⃣ 第二层：稳定性检测 (预留接口)

### 核心目标
- **防误触**: 确保姿态持续一定时间才认为稳定
- **噪声过滤**: 过滤瞬时抖动
- **适用场景**: 生产环境、需要高质量判断的场景

### 技术实现 (预留接口)
```dart
class StabilityLayer {
  // 时间窗口内的稳定性验证
  static bool checkStability({
    required List<double> angleHistory,  // 过去N帧的角度
    required double threshold,
    required Duration minDuration,       // 最小持续时间
    required double tolerance,           // 允许的波动范围
  }) {
    if (angleHistory.isEmpty) return false;
    
    // 1. 检查是否所有角度都在阈值范围内
    final allInThreshold = angleHistory.every(
      (angle) => angle <= threshold + tolerance
    );
    
    // 2. 检查是否持续足够时间
    final timeWindow = angleHistory.length * frameInterval;
    final enoughDuration = timeWindow >= minDuration;
    
    return allInThreshold && enoughDuration;
  }
}
```

### 配置示例 (YAML - 预留)
```yaml
phases:
  - id: bottom
    label: 最低点
    stability_config:              # 第二层配置 (预留)
      enabled: true
      min_duration_ms: 500         # 需要保持至少500ms
      tolerance: 5                # 允许±5°的波动
      window_size: 30             # 检查过去30帧
      
transitions:
  - from: descending
    to: bottom
    stability_required: true        # 需要稳定性验证
```

### 使用场景
1. **深蹲最低点**: 确保用户真正蹲到底，而不是经过
2. **站立完成**: 确保用户完全站立稳定
3. **防止假触发**: 快速抖动不应触发状态转换

---

## 4️⃣ 第三层：过渡平滑 (预留接口)

### 核心目标
- **连续性验证**: 确保姿态转换是平滑的，不是跳跃的
- **质量评估**: 根据过渡速度和稳定性评分
- **适用场景**: 高质量训练、教练级应用

### 技术实现 (预留接口)
```dart
class TransitionLayer {
  // 平滑过渡算法
  static TransitionResult evaluateTransition({
    required List<double> fromPhaseAngles,   // 原阶段的最后N帧
    required List<double> toPhaseAngles,     // 新阶段的前N帧
    required double smoothnessThreshold,     // 平滑度阈值
  }) {
    // 1. 计算变化率（避免突变）
    final transitionAngles = [...fromPhaseAngles, ...toPhaseAngles];
    final maxDelta = _calculateMaxDelta(transitionAngles);
    
    // 2. 检查是否平滑
    final isSmooth = maxDelta <= smoothnessThreshold;
    
    // 3. 计算过渡时间
    final transitionTime = toPhaseAngles.length * frameInterval;
    
    // 4. 质量评分
    final qualityScore = _calculateQualityScore(
      maxDelta: maxDelta,
      time: transitionTime,
      isSmooth: isSmooth,
    );
    
    return TransitionResult(
      isSmooth: isSmooth,
      qualityScore: qualityScore,
      transitionTime: transitionTime,
      maxDelta: maxDelta,
    );
  }
  
  // 计算最大变化率
  static double _calculateMaxDelta(List<double> angles) {
    double maxDelta = 0;
    for (var i = 1; i < angles.length; i++) {
      final delta = (angles[i] - angles[i-1]).abs();
      if (delta > maxDelta) maxDelta = delta;
    }
    return maxDelta;
  }
}
```

### 配置示例 (YAML - 预留)
```yaml
phases:
  - id: ascending
    label: 起身中
    transition_config:           # 第三层配置 (预留)
      enabled: true
      smoothness_threshold: 10   # 每帧变化不超过10°
      evaluation_window: 20      # 评估过渡前后的20帧
      
quality_metrics:
  transition_quality:
    enabled: true
    weight: 0.3                # 质量评分权重30%
```

### 使用场景
1. **动作质量评分**: 评估用户动作是否平滑
2. **训练反馈**: 提示用户"动作过快"或"动作不连贯"
3. **教练级应用**: 提供详细的动作分析报告

---

## 5️⃣ 架构对比

### 当前实现 (仅第一层)
```
角度输入 ──▶ 阈值判断 ──▶ 状态转换
  |            |
170° ────────▶ <150? ────────▶ YES → descending
```

### 完整三层架构
```
角度输入
    │
    ├─▶ Layer 1: 阈值触发 ──▶ 是否达到阈值?
    │                      │
    │                      ├─ YES ──▶ 继续
    │                      └─ NO  ──▶ 跳过
    │
    ├─▶ Layer 2: 稳定性检测 (可选)
    │                      │
    │                      ├─ YES ──▶ 继续
    │                      └─ NO  ──▶ 跳过
    │
    └─▶ Layer 3: 过渡平滑 (可选)
                           │
                           ├─ YES ──▶ 质量评分
                           └─ NO  ──▶ 警告
```

---

## 6️⃣ 实施计划

### Phase 1: 第一层完善 (当前任务)
- ✅ 保留现有的阈值触发机制
- ✅ 调整 EMA factor = 1.0 (无平滑) 适配集成测试
- ✅ 确保状态机即时响应
- 🔄 更新配置文件支持层次化配置
- 🔄 更新集成测试文档说明层次化架构

### Phase 2: 第二层预留 (未来任务)
- 📋 设计 StabilityLayer 接口
- 📋 添加 YAML 配置结构
- 📋 编写单元测试（但暂不集成到主流程）
- 📋 文档说明稳定性检测原理

### Phase 3: 第三层预留 (未来任务)
- 📋 设计 TransitionLayer 接口
- 📋 添加质量评估算法
- 📋 编写单元测试（但暂不集成到主流程）
- 📋 文档说明过渡平滑原理

---

## 7️⃣ 配置文件设计

### 当前配置 (squat.exercise.yaml)
```yaml
id: squat
name: 深蹲
description: 标准深蹲动作检测与计数

# 第一层：阈值触发 (当前实现)
detection_layers:
  trigger:
    enabled: true
    alpha: 1.0  # EMA平滑因子 (1.0 = 无平滑)
    
  # 第二层：稳定性检测 (预留接口)
  stability:
    enabled: false
    config:
      min_duration_ms: 500
      tolerance: 5
      window_size: 30
      
  # 第三层：过渡平滑 (预留接口)
  transition:
    enabled: false
    config:
      smoothness_threshold: 10
      evaluation_window: 20

phases:
  - id: standing
    label: 站立
    # ...
```

---

## 8️⃣ 代码结构

```
lib/core/services/
├── detection_layers/          # 新增：层次化检测
│   ├── base_layer.dart       # 基础层接口
│   ├── trigger_layer.dart    # 第一层：触发机制 (实现中)
│   ├── stability_layer.dart  # 第二层：稳定性检测 (预留)
│   └── transition_layer.dart # 第三层：过渡平滑 (预留)
├── angle_calculator.dart     # 当前：角度计算
├── state_machine.dart        # 当前：状态机
├── squat_analyzer.dart       # 当前：深蹲分析器
└── exercise_analyzer.dart    # 当前：分析器接口
```

---

## 9️⃣ 集成测试适配

### 当前集成测试 (基于第一层)
```dart
test('完整深蹲周期应正确计数', () {
  // 第一层：瞬时触发
  // 输入 149° → 立即触发 standing→descending
  analyzer.update(_createFrameAngles(leftKnee: 149, rightKnee: 149));
  expect(analyzer.currentState.currentPhase, 'descending');
  
  // 输入 99° → 立即触发 descending→bottom
  analyzer.update(_createFrameAngles(leftKnee: 99, rightKnee: 99));
  expect(analyzer.currentState.currentPhase, 'bottom');
  
  // 输入 101° → 立即触发 bottom→ascending
  analyzer.update(_createFrameAngles(leftKnee: 101, rightKnee: 101));
  expect(analyzer.currentState.currentPhase, 'ascending');
  
  // 输入 161° → 立即触发 ascending→standing
  analyzer.update(_createFrameAngles(leftKnee: 161, rightKnee: 161));
  expect(analyzer.currentState.currentPhase, 'standing');
});
```

### 未来集成测试 (包含第二层)
```dart
test('稳定性检测：需要在500ms内保持角度', () {
  // 模拟30帧 (假设16fps ≈ 1.875s)
  for (var i = 0; i < 30; i++) {
    analyzer.update(_createFrameAngles(leftKnee: 80, rightKnee: 80));
  }
  
  // 应该触发 bottom 状态（因为保持了足够时间）
  expect(analyzer.currentState.currentPhase, 'bottom');
  
  // 快速抖动不应触发
  for (var i = 0; i < 5; i++) {
    analyzer.update(_createFrameAngles(leftKnee: 75 + i*2, rightKnee: 75 + i*2));
  }
  
  // 仍在 bottom 状态
  expect(analyzer.currentState.currentPhase, 'bottom');
});
```

### 未来集成测试 (包含第三层)
```dart
test('过渡平滑：动作过快应降低质量评分', () {
  // 快速下蹲 (10帧内从170°降到80°)
  for (var angle = 170; angle >= 80; angle -= 9) {
    analyzer.update(_createFrameAngles(leftKnee: angle.toDouble(), rightKnee: angle.toDouble()));
  }
  
  // 完成深蹲
  analyzer.update(_createFrameAngles(leftKnee: 170, rightKnee: 170));
  
  final reps = analyzer.getCompletedReps();
  final quality = reps[0].metrics['transitionQuality'];
  
  // 质量评分应该较低 (因为变化太快)
  expect(quality, lessThan(0.7));
});
```

---

## 🔟 结论

### 架构优势
1. **层次清晰**: 从简单到复杂，易于理解和维护
2. **可扩展**: 预留接口，后续无侵入式扩展
3. **灵活性**: 不同场景选择不同层次的组合
4. **测试友好**: 集成测试只需要第一层，无需等待复杂功能

### 当前状态
- ✅ **第一层**: 已实现 (阈值触发机制)
- 📋 **第二层**: 预留接口 (稳定性检测)
- 📋 **第三层**: 预留接口 (过渡平滑)

### 下一步行动
1. 保留 EMA factor = 1.0 (适配第一层)
2. 设计层次化配置结构
3. 更新 YAML 配置文件
4. 更新集成测试文档
5. 为第二层和第三层预留代码结构

---

**设计完成时间**: 2026-03-26 15:54  
**架构版本**: v1.0 (三层姿态检测架构)  
**核心思想**: 从触发 → 稳定 → 过渡，逐层递进
