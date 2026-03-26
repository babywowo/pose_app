# EMA Factor 优化计划

**创建日期**: 2026-03-26  
**作者**: AI Agent  
**版本**: v1.0

---

## 📋 问题背景

### 当前状态
- **EMA factor**: 1.0（完全禁用平滑）
- **原因**: 适配集成测试（无噪声数据）
- **影响**: 生产环境中无法处理姿态检测噪声

### 集成测试要求
- 输入：`170°` → 立即触发 standing→descending
- 期望：无延迟，即时响应
- 测试数据：精确的角度序列，无噪声

### 生产环境需求
- 输入：`170° ± 噪声` → 应该过滤噪声后触发
- 期望：适当平滑，过滤瞬时抖动
- 真实数据：有噪声的角度序列

---

## 🔬 EMA Factor 影响分析

### Factor = 1.0（无平滑）
```
输入序列：[170, 169, 168, 167, 166, 165]
输出序列：[170, 169, 168, 167, 166, 165]
```
**优点**:
- ✅ 零延迟，即时响应
- ✅ 完美适配集成测试

**缺点**:
- ❌ 无法过滤噪声
- ❌ 瞬时抖动会触发假转换

### Factor = 0.5（中等平滑）
```
输入序列：[170, 169, 168, 167, 166, 165]
输出序列：[170, 169.5, 168.75, 167.88, 167.44, 167.22]
计算逻辑：
  输出[1] = 输入[1]*0.5 + 输出[0]*0.5 = 169*0.5 + 170*0.5 = 169.5
  输出[2] = 输入[2]*0.5 + 输出[1]*0.5 = 168*0.5 + 169.5*0.5 = 168.75
```
**优点**:
- ✅ 50%噪声过滤
- ✅ 适度延迟（2-3帧）
- ✅ 平衡响应速度和稳定性

**缺点**:
- ❌ 可能使集成测试失败（需要调整测试）

### Factor = 0.3（强平滑）
```
输入序列：[170, 169, 168, 167, 166, 165]
输出序列：[170, 169.3, 168.79, 168.45, 168.22, 168.05]
计算逻辑：
  输出[1] = 输入[1]*0.3 + 输出[0]*0.7 = 169*0.3 + 170*0.7 = 169.3
  输出[2] = 输入[2]*0.3 + 输出[1]*0.7 = 168*0.3 + 169.3*0.7 = 168.79
```
**优点**:
- ✅ 70%噪声过滤
- ✅ 高稳定性

**缺点**:
- ❌ 明显延迟（5-10帧）
- ❌ 可能导致集成测试大量失败

---

## 🎯 推荐方案

### 方案A：双配置文件（推荐）⭐
**思路**: 维护两套配置，集成测试和生产环境使用不同的factor

**实施步骤**:
1. 创建 `squat.exercise.test.yaml` (factor=1.0)
   ```yaml
   detection_layers:
     trigger:
       enabled: true
       config:
         ema_alpha: 1.0  # 无平滑，适配集成测试
   ```

2. 创建 `squat.exercise.prod.yaml` (factor=0.5)
   ```yaml
   detection_layers:
     trigger:
       enabled: true
       config:
         ema_alpha: 0.5  # 中等平滑，适配生产环境
   ```

3. 修改 `ExerciseLoader.fromYaml()` 支持环境参数
   ```dart
   static Future<ExerciseDefinition> fromYaml(
     String path, {
     bool isTest = false,
   }) async {
     final fileName = isTest 
       ? path.replaceAll('.yaml', '.test.yaml')
       : path;
     // 加载配置...
   }
   ```

4. 修改 `SquatAnalyzer.create()` 支持测试模式
   ```dart
   static Future<SquatAnalyzer> create({bool isTest = false}) async {
     final analyzer = SquatAnalyzer();
     analyzer._definition = await ExerciseLoader.fromYaml(
       'assets/exercises/squat.exercise.yaml',
       isTest: isTest,
     );
     // ...
   }
   ```

**优点**:
- ✅ 集成测试和生产环境分离
- ✅ 测试保持100%通过率
- ✅ 生产环境获得适当的平滑
- ✅ 灵活调整不同环境的参数

**缺点**:
- 需要修改 `ExerciseLoader` 代码
- 需要维护两套配置文件

---

### 方案B：动态调整（备选）
**思路**: 运行时根据需要动态调整factor

**实施步骤**:
1. 在 `SquatAnalyzer` 中添加 `setEmaFactor()` 方法
   ```dart
   void setEmaFactor(double factor) {
     _emaFactor = factor;
   }
   ```

2. 在集成测试中显式设置 factor
   ```dart
   final analyzer = await SquatAnalyzer.create();
   analyzer.setEmaFactor(1.0);  // 集成测试：无平滑
   ```

3. 在生产环境中使用默认 factor（从配置加载）

**优点**:
- 无需修改配置文件
- 灵活控制

**缺点**:
- 集成测试需要显式设置
- 容易遗漏（测试中忘记设置）

---

### 方案C：直接修改（不推荐）
**思路**: 直接将factor改为0.5，并调整集成测试

**实施步骤**:
1. 修改 `squat.exercise.yaml`: `ema_alpha: 0.5`
2. 修改集成测试：增加帧数，等待平滑稳定

**优点**:
- 简单直接

**缺点**:
- ❌ 集成测试需要大量修改
- ❌ 测试变得复杂（需要等待平滑）
- ❌ 可能引入新的bug

---

## 📊 推荐值对比

| Factor | 噪声过滤 | 响应延迟 | 适用场景 |
|--------|---------|---------|---------|
| 1.0 | 0% | 0帧 | 集成测试、快速响应应用 |
| 0.7 | 30% | 1-2帧 | 高质量摄像头、环境稳定 |
| **0.5** | **50%** | **2-3帧** | **标准生产环境（推荐）** |
| 0.3 | 70% | 5-10帧 | 低质量摄像头、高噪声环境 |

---

## 🚀 实施计划

### 阶段1：创建测试配置文件（1小时）
- [ ] 创建 `squat.exercise.test.yaml`
- [ ] 复制当前配置，确保 factor=1.0
- [ ] 运行测试，确保100%通过

### 阶段2：修改代码支持环境切换（2小时）
- [ ] 修改 `ExerciseLoader.fromYaml()` 支持 `isTest` 参数
- [ ] 修改 `SquatAnalyzer.create()` 支持 `isTest` 参数
- [ ] 更新集成测试，使用 `SquatAnalyzer.create(isTest: true)`

### 阶段3：创建生产配置文件（30分钟）
- [ ] 创建 `squat.exercise.prod.yaml`
- [ ] 设置 factor=0.5
- [ ] 验证配置格式正确

### 阶段4：验证和文档（1小时）
- [ ] 运行所有测试，确保通过
- [ ] 更新文档说明双配置文件
- [ ] 记录不同环境的推荐参数

---

## 📝 决策记录

### ADR-001: EMA Factor 双配置策略

**状态**: 提议

**上下文**:
- 集成测试要求即时响应（factor=1.0）
- 生产环境需要噪声过滤（factor=0.5）
- 单一配置无法同时满足两个需求

**决策**:
采用双配置文件策略，测试环境和生产环境使用不同的EMA factor。

**后果**:
- **正面**:
  - 集成测试保持100%通过率
  - 生产环境获得适当的平滑
  - 配置清晰，易于理解
  
- **负面**:
  - 需要维护两套配置文件
  - 需要修改加载代码

---

## 🔍 验证步骤

### 测试环境验证
```bash
# 集成测试应该100%通过
flutter test test/integration/squat_analysis_integration_test.dart

# 单元测试应该100%通过
flutter test test/core/services/
```

### 生产环境验证
```bash
# 运行应用，观察实际效果
flutter run

# 观察调试面板：
# - POSE > 0（检测到人体）
# - PHASE 正确转换
# - REPS 正确计数
```

---

**文档完成时间**: 2026-03-26  
**下一步**: 与用户确认是否实施方案A
