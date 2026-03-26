# 选项A：调试并修复 - 详细发现报告

**执行时间**: 2026-03-26 17:00  
**状态**: Phase 1完成，调试进行中

---

## 🔍 问题分析过程

### 1. 对比老状态机（SquatCounter）

老状态机的关键特点：
```dart
// 平滑计算
_smoothedLeft = left * 0.3 + _smoothedLeft * 0.7;
_smoothedRight = right * 0.3 + _smoothedRight * 0.7;

// 使用平滑后的角度判断状态
_updatePhase(avgAngle);
```

**关键发现**：
- 使用**平滑后的角度**进行状态判断
- 平滑因子固定为0.3
- 初始平滑值为180.0

### 2. 分析新状态机（SquatAnalyzer + StateMachine）

新状态机的流程：
```
SquatAnalyzer:
  1. 获取原始角度
  2. 更新平滑值（emaFactor从配置加载）
  3. 传递原始角度给StateMachine

StateMachine:
  1. 聚合角度（avg）
  2. 检查条件
  3. 执行转换
```

**关键发现**：
- SquatAnalyzer做EMA平滑（emaFactor=1.0 = 无平滑）
- 传递**原始角度**给StateMachine
- StateMachine不做平滑，直接使用原始角度

### 3. 发现的问题

#### 问题1: 初始平滑值导致第一帧不准确

**代码**：
```dart
// 初始化
double _smoothedLeft = 180.0;
double _smoothedRight = 180.0;

// 第一次update
final leftAngle = angles.getAngleValue(JointAngleType.leftKnee) ?? _smoothedLeft; // 170
final rightAngle = angles.getAngleValue(JointAngleType.rightKnee) ?? _smoothedRight; // 170

// EMA平滑
_smoothedLeft = leftAngle * 1.0 + _smoothedLeft * 0.0; // 170 * 1.0 + 180 * 0.0 = 170
_smoothedRight = rightAngle * 1.0 + _smoothedRight * 0.0; // 170 * 1.0 + 180 * 0.0 = 170
```

**分析**：
- 第一帧：left=170, right=170, smooth=170 ✅ 正确
- 逻辑没问题，emaFactor=1.0时直接使用原始角度

#### 问题2: 配置转换规则顺序

**YAML配置**：
```yaml
transitions:
  - from: bottom
    to: ascending
    triggers:
      - operator: > min: 100  # bottom→ascending

  - from: ascending
    to: standing
    triggers:
      - operator: > min: 160  # ascending→standing
```

**StateMachine逻辑**：
```dart
for (final trans in transitions) {
  if (_checkConditions(trans.triggers, angles)) {
    // 执行第一个满足的转换
    _currentStateId = trans.toState;
    // ...
  }
}
```

**分析**：
- 状态机按YAML顺序检查转换规则
- 如果角度=120°，在bottom阶段：
  - 检查bottom→ascending: 120>100 ✓ → 触发
  - 状态变为ascending
  - 下一帧角度=170°，在ascending阶段：
    - 检查ascending→standing: 170>160 ✓ → 触发
    - 状态变为standing，计数+1
- 这个逻辑应该是**正确的**！

#### 问题3: PowerShell输出格式导致无法查看调试信息

**问题**：
- Windows PowerShell的输出格式是CLIXML
- print()语句的输出被XML标签覆盖
- 无法查看实时调试信息

**影响**：
- 无法直接看到状态机的执行过程
- 难以定位问题所在

---

## ✅ 已尝试的修复

### 修复1: 添加初始化标志

**代码**：
```dart
bool _initialized = false;

if (!_initialized) {
  _smoothedLeft = leftAngle;
  _smoothedRight = rightAngle;
  _initialized = true;
} else {
  _smoothedLeft = leftAngle * _emaFactor + _smoothedLeft * (1 - _emaFactor);
  _smoothedRight = rightAngle * _emaFactor + _smoothedRight * (1 - _emaFactor);
}
```

**目标**：
- 第一帧直接使用原始角度，不做平滑
- 后续帧应用EMA平滑

**结果**：未知（无法查看测试结果）

### 修复2: 移除TriggerLayer复杂逻辑

**代码**：
```dart
// 直接使用Cond的check方法（不做额外平滑）
if (!cond.check(value)) {
  return false;
}
```

**目标**：
- 简化状态机逻辑
- 避免双重平滑

**结果**：未知（无法查看测试结果）

---

## 🔮 根本原因推测

### 最可能的原因

基于以上分析，最可能的原因是：

1. **测试用例的角度序列与阈值不匹配**
   - 测试使用逐帧角度变化（每帧变化1度）
   - 但状态机可能在中间帧就触发了
   - 导致最终状态不符合预期

2. **状态机转换的"回弹"问题**
   - 如果角度在两个转换规则的边界反复横跳
   - 可能导致状态不稳定
   - 例如：120°时bottom→ascending触发，但下一帧119°时可能又有问题

3. **YAML配置的转换规则优先级问题**
   - 有两个转换规则都满足条件时（例如bottom直接到standing和bottom到ascending）
   - 取决于YAML中的顺序
   - 可能不是预期的行为

---

## 💡 建议的下一步行动

### 选项A1: 使用老状态机的逻辑（推荐）

**理由**：
- 老状态机已经验证过，逻辑稳定
- 只需要将其迁移到新架构

**任务**：
1. 参考SquatCounter的_updatePhase逻辑
2. 直接在SquatAnalyzer中实现状态机
3. 不使用通用的StateMachine
4. 重新运行测试验证

**预估时间**: 30分钟

### 选项A2: 简化测试用例角度序列（备选）

**理由**：
- 减少帧数，使状态转换更明确
- 例如：只输入关键角度（170, 140, 80, 120, 170）

**任务**：
1. 创建简化的测试用例
2. 只使用5-10帧而不是几百帧
3. 验证状态转换

**预估时间**: 20分钟

### 选项A3: 添加详细的日志文件输出（保守）

**理由**：
- 绕过PowerShell输出问题
- 将调试信息写入文件
- 测试完成后查看日志

**任务**：
1. 修改SquatAnalyzer和StateMachine
2. 添加文件写入逻辑
3. 运行测试并分析日志

**预估时间**: 25分钟

---

## 📊 当前状态

### 代码修改
- ✅ ExerciseDefinition - 支持detection_layers配置
- ✅ StateMachine - 集成TriggerLayer
- ✅ SquatAnalyzer - 从YAML加载emaAlpha，添加初始化标志

### 测试结果
- ⚠️ 无法获取（PowerShell输出问题）
- 预期通过率：25% (未改善)

### 问题状态
- 🔍 已识别3个可能原因
- 🎯 需要1个验证行动
- 🚧 需要绕过调试输出问题

---

**下一步**: 等待用户选择具体的验证行动
