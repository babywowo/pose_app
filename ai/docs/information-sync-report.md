# PoseApp 信息同步梳理报告

## 完成时间
2026-03-26 19:15

## 问题发现

### 用户反馈
> 面板上的REPS有刷新，"深蹲"按钮上的数值没有刷新，多半是相关信息没有同步

### 根本原因
`_StartAnalysisButton`（摄像头页面的"开始深蹲分析"按钮）仍在使用旧的`squatStateProvider`，而`squatStateProvider`在新架构下已经不再更新。

---

## 修复记录

### 1. 修复摄像头页面的开始分析按钮

**文件**: `lib/features/camera/presentation/camera_screen.dart`

**修改前**（第313行）:
```dart
final squatState = ref.watch(squatStateProvider);

label: Text(
  isAnalyzing
      ? '停止分析  ·  ${squatState.repCount} 次'
      : '开始深蹲分析',
),
```

**修改后**:
```dart
final exerciseState = ref.watch(exerciseStateProvider);

label: Text(
  isAnalyzing
      ? '停止分析  ·  ${exerciseState.repCount} 次'
      : '开始深蹲分析',
),
```

**效果**: 摄像头页面的"开始分析/停止分析"按钮现在正确显示实时计数。

---

## 全面信息同步梳理

### 数据流图

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ 摄像头输入                                                              │
│  CameraImage → PoseDetectorService → PoseFrame                            │
└───────────────────────────┬───────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────────────────┐
│ 角度计算                                                                │
│  AngleCalculator.calculate() → FrameAngles                                │
└───────────────────────────┬───────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────────────────┐
│ 动作分析（核心）                                                        │
│  SquatAnalyzer.update(angles) → ExerciseState                            │
│  ├─ EMA平滑（factor=1.0，无平滑）                                       │
│  ├─ 状态机转换（StateMachine.transition）                                  │
│  ├─ 计数判断（shouldCountRep）                                           │
│  └─ 质量评估（goodThreshold ≤ 90°）                                      │
└───────────────────────────┬───────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────────────────┐
│ 状态存储（Provider层）                                                   │
│  exerciseStateProvider ← ExerciseState                                   │
│  ├─ exerciseType: 'squat'                                              │
│  ├─ currentPhase: 'standing' | 'descending' | 'bottom' | 'ascending'    │
│  ├─ repCount: 0, 1, 2, ...                                           │
│  ├─ phaseLabel: '站立' | '下蹲中' | '最低点' | '起身中'               │
│  ├─ keyAngles: {leftKnee: 170, rightKnee: 170}                         │
│  ├─ isGoodForm: true | false                                           │
│  ├─ feedback: '站立准备，开始下蹲'                                        │
│  └─ timestamp: DateTime                                                │
└───────────────────────────┬───────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────────────────┐
│ UI显示层（多个Widget消费同一个数据源）                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│ 1. CameraScreen（摄像头页面）                                           │
│     ├─ _StartAnalysisButton.watch(exerciseStateProvider)                  │
│     │   └─ 显示: "停止分析 · ${repCount} 次"                             │
│     └─ DebugOverlay.watch(debugStatsProvider)                             │
│         ├─ EXERCISE: 'squat'                                           │
│         ├─ PHASE: currentPhase                                          │
│         ├─ REPS: repCount                                               │
│         ├─ L-KNEE: keyAngles['leftKnee']                                 │
│         └─ R-KNEE: keyAngles['rightKnee']                                │
├─────────────────────────────────────────────────────────────────────────────┤
│ 2. AnalysisScreen（分析页面）                                            │
│     ├─ watch(exerciseStateProvider)                                       │
│     ├─ _CounterCard                                                     │
│     │   ├─ 大数字: $repCount                                            │
│     │   └─ 阶段指示器: currentPhase + phaseLabel                         │
│     └─ _FeedbackCard                                                     │
│         └─ 反馈消息: feedback                                           │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 关键Provider同步关系

### 核心Provider（新架构）

| Provider | 类型 | 用途 | 消费者 |
|----------|------|------|--------|
| `poseFrameProvider` | StateProvider<PoseFrame> | 当前姿态帧 | AngleCalculator |
| `frameAnglesProvider` | StateProvider<FrameAngles> | 当前帧角度 | SquatAnalyzer |
| `exerciseAnalyzerProvider` | StateProvider<ExerciseAnalyzer?> | 分析器实例 | PipelineController |
| `exerciseStateProvider` | StateProvider<ExerciseState> | 当前动作状态 | CameraScreen, AnalysisScreen |
| `isAnalyzingProvider` | StateProvider<bool> | 分析开关 | CameraScreen, AnalysisScreen |
| `debugStatsProvider` | StateProvider<DebugStats> | 调试统计 | DebugOverlay |

### 废弃Provider（旧架构，向后兼容）

| Provider | 类型 | 用途 | 状态 |
|----------|------|------|------|
| `squatCounterProvider` | Provider<SquatCounter> | 深蹲计数器实例 | @Deprecated |
| `squatStateProvider` | StateProvider<SquatCounterState> | 深蹲计数状态 | @Deprecated |

---

## 数据更新时机

### PipelineController（pose_providers.dart）

```dart
// 在 poseStream 的监听回调中（每帧）
_poseSub = _poseService.poseStream.listen((frame) {
  ref.read(poseFrameProvider.notifier).state = frame; // 更新姿态帧

  if (!frame.isEmpty) {
    final angles = _angleCalc.calculate(frame);
    ref.read(frameAnglesProvider.notifier).state = angles; // 更新角度

    if (analyzing && analyzer != null) {
      final state = analyzer.update(angles);
      ref.read(exerciseStateProvider.notifier).state = state; // 更新状态 ⭐
    }
  }
});
```

### 更新顺序（每帧）
1. CameraImage → PoseFrame → `poseFrameProvider`
2. PoseFrame → FrameAngles → `frameAnglesProvider`
3. **如果正在分析** → ExerciseState → `exerciseStateProvider` ⭐
4. **同时更新** → DebugStats → `debugStatsProvider`

---

## UI组件同步验证

### ✅ 已同步组件

#### 1. CameraScreen._StartAnalysisButton
- **Provider**: `exerciseStateProvider` ✅
- **显示**: `exerciseState.repCount`
- **状态**: 已修复

#### 2. CameraScreen.DebugOverlay
- **Provider**: `debugStatsProvider` ✅
- **显示字段**:
  - EXERCISE: `stats.exerciseType`
  - PHASE: `stats.currentPhase`
  - REPS: `stats.repCount`
  - L-KNEE: `stats.keyAngles['leftKnee']`
  - R-KNEE: `stats.keyAngles['rightKnee']`
- **状态**: 已修复

#### 3. AnalysisScreen
- **Provider**: `exerciseStateProvider` ✅
- **显示**:
  - _CounterCard: `exerciseState.repCount`
  - _CounterCard: `exerciseState.currentPhase`
  - _CounterCard: `exerciseState.phaseLabel`
  - _FeedbackCard: `exerciseState.isGoodForm`
  - _FeedbackCard: `exerciseState.feedback`
- **状态**: 无问题

---

## 搜索验证结果

### ✅ 新架构Provider使用情况

```bash
# 搜索 exerciseStateProvider
lib/features/camera/presentation/camera_screen.dart:1 个匹配
lib/features/analysis/presentation/analysis_screen.dart:1 个匹配

# 搜索 exerciseAnalyzerProvider
lib/core/providers/pose_providers.dart:2 个匹配（定义）

# 搜索 isAnalyzingProvider
lib/features/camera/presentation/camera_screen.dart:2 个匹配
lib/features/analysis/presentation/analysis_screen.dart:2 个匹配
```

### ✅ 旧架构Provider使用情况

```bash
# 搜索 squatStateProvider
lib/core/providers/pose_providers.dart:1 个匹配（定义）
lib/features/**/*.dart: 0 个匹配 ✅

# 搜索 squatCounterProvider
lib/core/providers/pose_providers.dart:1 个匹配（定义）
lib/features/**/*.dart: 0 个匹配 ✅

# 搜索 SquatCounterState
lib/features/**/*.dart: 0 个匹配 ✅
```

**结论**: UI层已完全迁移到新架构，旧架构Provider仅保留用于向后兼容。

---

## 废弃代码标记

### pose_providers.dart

```dart
/// 深蹲计数器实例（保持状态）
/// @deprecated 使用 exerciseAnalyzerProvider 替代
/// 迁移指南：使用 exerciseAnalyzerProvider 获取通用分析器实例
@Deprecated('使用 exerciseAnalyzerProvider 替代')
final squatCounterProvider = Provider<SquatCounter>((ref) {
  return SquatCounter();
});

/// 深蹲计数状态
/// @deprecated 使用 exerciseStateProvider 替代
/// 迁移指南：使用 exerciseStateProvider 获取通用动作状态
@Deprecated('使用 exerciseStateProvider 替代')
final squatStateProvider = StateProvider<SquatCounterState>((ref) {
  return SquatCounterState.initial;
});
```

---

## 测试验证

### 验证步骤

1. **启动应用** → 热重启（确保代码更新）
2. **切换到摄像头页面** → 观察调试面板
3. **等待检测到人体** → POSE > 0, LMK ≥ 20
4. **点击"开始深蹲分析"** → 按钮变为"停止分析 · 0 次"
5. **做一次深蹲** → 观察以下变化：
   - ✅ 按钮文本: "停止分析 · 1 次"
   - ✅ 调试面板 REPS: 1
   - ✅ 调试面板 PHASE: standing → descending → bottom → ascending → standing
   - ✅ 调试面板 L-KNEE/R-KNEE: 实时角度值
6. **切换到Analysis页面** → 观察以下变化：
   - ✅ 大数字: 1
   - ✅ 阶段指示器: 站立
   - ✅ 反馈消息: "✓ 达标深蹲" 或 "再深一点"

### 预期结果

所有显示组件都应该实时同步`exerciseStateProvider`的数据，包括：
- 摄像头页面的按钮计数
- 调试面板的所有指标
- Analysis页面的计数和阶段

---

## 总结

### 已修复问题
1. ✅ 摄像头页面按钮使用`squatStateProvider` → 改为`exerciseStateProvider`
2. ✅ 调试面板使用旧字段 → 改为新架构字段（currentPhase, keyAngles, repCount）
3. ✅ 标记旧架构Provider为@Deprecated

### 信息同步验证
- ✅ 所有UI组件统一使用`exerciseStateProvider`
- ✅ 没有遗漏的旧架构引用
- ✅ 数据流清晰可追踪
- ✅ 更新时机明确（每帧）

### 架构一致性
- ✅ UI层（CameraScreen, AnalysisScreen）完全使用新架构
- ✅ Provider层统一管理新旧架构（新架构为主，旧架构标记废弃）
- ✅ 服务层（SquatAnalyzer）完全基于新架构

---

## 下一步建议

### 短期（验证修复）
1. 热重启应用
2. 按照测试验证步骤测试深蹲功能
3. 确认所有显示组件同步更新

### 中期（清理代码）
如果验证通过，可以考虑：
1. 删除`squatCounterProvider`和`squatStateProvider`的定义
2. 删除`squat_counter.dart`的@Deprecated标记，直接删除文件
3. 删除所有`@Deprecated`相关代码

### 长期（架构优化）
1. 继续集成测试优化（目标100%通过率）
2. 实现第二层（StabilityLayer）
3. 实现第三层（TransitionLayer）
4. 添加更多动作类型（俯卧撑、硬拉等）

---

**修复完成时间**: 2026-03-26 19:15
**修复人员**: AI Agent
**架构版本**: v1.0（三层架构Phase 1）
