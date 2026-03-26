# 三层架构整改总体规划

**制定时间**: 2026-03-26 16:05  
**版本**: v1.0  
**目标**: 完成从单层架构到三层姿态检测架构的全面重构

---

## 📋 涉及范围总览

### 一、代码实现（8个文件）

#### ✅ 已完成（4个文件）
1. **lib/core/services/detection_layers/base_layer.dart**
   - 状态：✅ 已完成
   - 内容：基础接口定义
   - 无需修改

2. **lib/core/services/detection_layers/trigger_layer.dart**
   - 状态：✅ 已完成
   - 内容：第一层触发机制实现
   - 无需修改

3. **lib/core/services/detection_layers/stability_layer.dart**
   - 状态：✅ 已完成
   - 内容：第二层稳定性检测（预留接口）
   - 无需修改

4. **lib/core/services/detection_layers/transition_layer.dart**
   - 状态：✅ 已完成
   - 内容：第三层过渡平滑（预留接口）
   - 无需修改

#### 🔄 需要修改（4个文件）
5. **lib/core/services/state_machine.dart**
   - 状态：🔄 需要集成TriggerLayer
   - 修改内容：
     - 导入TriggerLayer
     - 替换_checkConditions方法为使用TriggerLayer.check()
     - 添加层次配置支持

6. **lib/core/services/squat_analyzer.dart**
   - 状态：🔄 需要从YAML加载层次配置
   - 修改内容：
     - 移除硬编码的_emaFactor = 1.0
     - 从definition读取trigger层配置
     - 将配置传递给TriggerLayer

7. **lib/core/services/angle_calculator.dart**
   - 状态：🔄 需要支持可配置的EMA
   - 修改内容：
     - 当前：EMA factor = 1.0（硬编码）
     - 修改：接受外部传入的alpha参数
     - 或：保持当前状态（因为配置已转移到detection_layers/trigger_layer.dart）

8. **lib/core/models/exercise_definition.dart**
   - 状态：🔄 需要添加层次配置支持
   - 修改内容：
     - 添加detectionLayers配置字段
     - 解析YAML中的detection_layers节点
     - 提供getter方法供分析器使用

---

### 二、配置文件（1个文件）

#### 🔄 需要修改
9. **assets/exercises/squat.exercise.yaml**
   - 状态：✅ 已添加detection_layers配置（之前已完成）
   - 当前内容：
   ```yaml
   detection_layers:
     trigger:
       enabled: true
       config:
         ema_alpha: 1.0
     stability:
       enabled: false
       config:
         min_duration_ms: 500
         tolerance: 5
         window_size: 30
     transition:
       enabled: false
       config:
         smoothness_threshold: 10
         evaluation_window: 20
   ```
   - 无需进一步修改

---

### 三、测试文件（4类测试）

#### 1. 单元测试（新增1个）
10. **test/core/services/detection_layers/trigger_layer_test.dart**
    - 状态：✅ 已完成
    - 内容：第一层触发机制的单元测试
    - 无需修改

#### 🔄 需要更新（现有单元测试）
11. **test/core/services/squat_counter_test.dart**
    - 状态：🔄 需要更新以适配新架构
    - 修改内容：
      - 如果使用SquatCounter，需要更新测试用例
      - 或：保持不变（SquatCounter已废弃）

12. **test/core/services/angle_calculator_test.dart**
    - 状态：⚠️ 可能需要更新
    - 修改内容：
      - 验证EMA平滑的可配置性
      - 测试不同的alpha值

#### 🔄 需要验证（集成测试）
13. **test/integration/squat_analysis_integration_test.dart**
    - 状态：🔄 需要运行验证
    - 修改内容：
      - 运行测试验证通过率提升（预期：25% → 81%）
      - 如果测试仍然失败，需要调整角度序列或阈值
    - 无需修改代码，只需运行和报告

14. **test/integration/debug_*.dart**（调试测试文件）
    - 状态：⚠️ 可选：更新或删除
    - 建议：保留作为历史记录

#### 3. Widget测试（保持不变）
15. **test/features/analysis/presentation/analysis_screen_test.dart**
16. **test/features/history/presentation/history_screen_test.dart**
17. 其他Widget测试（53个）
    - 状态：✅ 无需修改
    - 原因：Widget测试不涉及底层逻辑，只测试UI

---

### 四、文档（5个文件）

#### ✅ 已完成（设计文档）
18. **ai/docs/three-layer-detection-architecture.md**
    - 状态：✅ 已完成
    - 内容：三层架构设计文档
    - 无需修改

19. **ai/docs/three-layer-architecture-implementation.md**
    - 状态：✅ 已完成
    - 内容：实现总结文档
    - 无需修改

20. **ai/docs/integration-test-diagnosis-report.md**
    - 状态：✅ 已完成
    - 内容：集成测试诊断报告
    - 无需修改

#### 🔄 需要更新（实施文档）
21. **ai/docs/complete-refactoring-master-plan.md**（本文件）
    - 状态：✅ 正在创建
    - 内容：总体规划文档
    - 后续：更新为"已完成"

22. **ai/docs/refactoring-execution-log.md**（待创建）
    - 状态：📋 待创建
    - 内容：详细执行日志
    - 目的：记录每一步的实施细节

#### 🔄 需要更新（项目文档）
23. **PROJECT_PROGRESS_REPORT.md**
    - 状态：🔄 需要更新
    - 修改内容：
      - 添加"三层架构整改"章节
      - 更新当前进度

24. **README.md**
    - 状态：🔄 需要更新
    - 修改内容：
      - 添加架构说明
      - 链接到新文档

---

## 🎯 实施优先级

### Phase 1: 核心集成（最高优先级）
- 目标：让第一层触发机制真正工作
- 预期时间：30分钟
- 涉及文件：
  - lib/core/models/exercise_definition.dart
  - lib/core/services/state_machine.dart
  - lib/core/services/squat_analyzer.dart
- 成功标准：
  - 集成测试通过率提升到80%以上
  - 单元测试全部通过
  - 代码编译无错误

### Phase 2: 测试验证（高优先级）
- 目标：验证重构后的功能完整性
- 预期时间：15分钟
- 涉及文件：
  - test/integration/squat_analysis_integration_test.dart
  - test/core/services/squat_counter_test.dart（如果需要）
- 成功标准：
  - 集成测试通过率 ≥ 80%
  - 所有测试用例都有明确结果

### Phase 3: 文档更新（中优先级）
- 目标：确保文档与代码同步
- 预期时间：20分钟
- 涉及文件：
  - PROJECT_PROGRESS_REPORT.md
  - README.md
  - ai/docs/refactoring-execution-log.md
- 成功标准：
  - 所有文档反映最新架构
  - 新人能通过文档理解架构

### Phase 4: 清理优化（低优先级）
- 目标：清理遗留代码和优化
- 预期时间：15分钟
- 涉及文件：
  - test/integration/debug_*.dart（可选）
  - lib/core/services/angle_calculator.dart（可选）
- 成功标准：
  - 代码无冗余
  - 性能无明显下降

---

## 📝 详细任务清单

### 任务组1: 修改ExerciseDefinition
- [ ] 在ExerciseDefinition类中添加DetectionLayerConfig模型
- [ ] 在YAML解析中添加detection_layers节点
- [ ] 添加getTriggerConfig()方法

### 任务组2: 修改StateMachine
- [ ] 导入TriggerLayer
- [ ] 创建TriggerLayer实例（从配置加载alpha）
- [ ] 修改_checkConditions()使用TriggerLayer.check()
- [ ] 保留现有聚合逻辑（executeAggregation）

### 任务组3: 修改SquatAnalyzer
- [ ] 移除硬编码的_emaFactor = 1.0
- [ ] 从definition读取trigger配置
- [ ] 将配置传递给TriggerLayer
- [ ] 验证无平滑角度传递给状态机

### 任务组4: 运行集成测试
- [ ] 运行flutter test test/integration/squat_analysis_integration_test.dart
- [ ] 记录测试结果
- [ ] 如果通过率<80%，分析原因
- [ ] 调整并重新测试

### 任务组5: 更新文档
- [ ] 创建refactoring-execution-log.md
- [ ] 更新PROJECT_PROGRESS_REPORT.md
- [ ] 更新README.md

### 任务组6: 清理（可选）
- [ ] 评估是否需要更新angle_calculator.dart
- [ ] 决定是否保留debug测试文件
- [ ] 检查是否有其他遗留代码

---

## 🔍 风险评估

### 高风险
- **风险1**: 集成测试通过率仍然低于预期
  - 影响：需要调整状态机阈值或角度序列
  - 缓解：保留EMA=1.0配置，必要时微调阈值

### 中风险
- **风险2**: YAML配置加载失败
  - 影响：无法启动应用
  - 缓解：保留默认配置，向后兼容

### 低风险
- **风险3**: 性能下降
  - 影响：实时响应延迟
  - 缓解：第一层计算复杂度无增加

---

## 📊 成功标准

### 量化指标
- [ ] 集成测试通过率 ≥ 80%（当前25%，目标81%）
- [ ] 所有单元测试通过
- [ ] Widget测试通过率 = 100%（保持不变）
- [ ] 代码编译无警告或错误
- [ ] 静态分析flutter analyze无问题

### 质量指标
- [ ] 代码注释完整
- [ ] 架构文档清晰
- [ ] 配置文件格式正确
- [ ] 测试覆盖核心功能

---

## 🚀 执行计划

### 立即执行（Phase 1）
1. 修改ExerciseDefinition支持层次配置
2. 修改StateMachine集成TriggerLayer
3. 修改SquatAnalyzer加载并使用配置
4. 运行测试验证

### 稍后执行（Phase 2-4）
5. 更新所有文档
6. 清理遗留代码
7. 生成最终报告

---

**下一步**: 开始执行Phase 1任务组1-3，然后运行集成测试验证。
