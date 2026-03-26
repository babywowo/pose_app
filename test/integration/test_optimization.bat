#!/bin/bash

# 集成测试优化验证脚本
# 目标: 验证EMA factor优化后的集成测试通过率

echo "========================================="
echo "集成测试优化验证 (EMA factor = 0.9)"
echo "========================================="
echo ""

# 运行集成测试
flutter test test/integration/squat_analysis_integration_test.dart --no-coverage

# 检查测试结果
if [ $? -eq 0 ]; then
    echo ""
    echo "✅ 所有集成测试通过!"
else
    echo ""
    echo "❌ 部分测试失败,需要进一步调整"
fi

echo ""
echo "测试执行完成"
