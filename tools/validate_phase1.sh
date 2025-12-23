#!/bin/bash
# Phase 1 Validation Script
# Comprehensive validation for Phase 1: Core Architecture completion

set -e

echo "========================================"
echo "  Phase 1 Validation: Core Architecture"
echo "========================================"
echo ""

FAILED=0
PASSED=0

# Helper function for check results
check_result() {
    local name=$1
    local result=$2

    if [ $result -eq 0 ]; then
        echo "[PASS] $name"
        PASSED=$((PASSED + 1))
    else
        echo "[FAIL] $name"
        FAILED=$((FAILED + 1))
    fi
}

# 1. Run Test Suite
echo "1. Running Test Suite..."
echo "------------------------"
if busted --verbose 2>&1 | tee /tmp/test_output.txt | tail -20; then
    check_result "Test suite passes" 0
else
    check_result "Test suite passes" 1
fi
echo ""

# 2. Check Coverage
echo "2. Checking Coverage..."
echo "-----------------------"
if [ -f "tools/check-coverage.sh" ]; then
    if bash tools/check-coverage.sh 2>/dev/null; then
        check_result "Coverage thresholds met" 0
    else
        check_result "Coverage thresholds met" 1
    fi
else
    echo "Warning: check-coverage.sh not found"
    check_result "Coverage thresholds met" 1
fi
echo ""

# 3. Linting
echo "3. Running Linter..."
echo "--------------------"
if command -v luacheck &> /dev/null; then
    if luacheck lib/ --config .luacheckrc 2>&1 | tail -10; then
        check_result "Linter passes" 0
    else
        check_result "Linter passes" 1
    fi
else
    echo "Warning: luacheck not installed"
    check_result "Linter passes" 1
fi
echo ""

# 4. Formatting Check
echo "4. Checking Formatting..."
echo "-------------------------"
if [ -f "tools/check-formatting.sh" ]; then
    if bash tools/check-formatting.sh 2>&1 | tail -10; then
        check_result "Formatting check passes" 0
    else
        check_result "Formatting check passes" 1
    fi
else
    echo "Warning: check-formatting.sh not found"
    check_result "Formatting check passes" 1
fi
echo ""

# 5. Modularity Validation
echo "5. Validating Modularity..."
echo "---------------------------"
if [ -f "tools/validate_modularity.lua" ]; then
    if lua tools/validate_modularity.lua lib/whisker 2>&1 | tail -10; then
        check_result "Modularity validation passes" 0
    else
        check_result "Modularity validation passes" 1
    fi
else
    echo "Warning: validate_modularity.lua not found"
    check_result "Modularity validation passes" 1
fi
echo ""

# 6. Check Required Files
echo "6. Checking Required Files..."
echo "-----------------------------"
REQUIRED_FILES=(
    "lib/whisker/kernel/container.lua"
    "lib/whisker/kernel/events.lua"
    "lib/whisker/kernel/registry.lua"
    "lib/whisker/kernel/loader.lua"
    "lib/whisker/interfaces/format.lua"
    "lib/whisker/interfaces/state.lua"
    "lib/whisker/interfaces/engine.lua"
    "lib/whisker/interfaces/plugin.lua"
    "lib/whisker/core/story.lua"
    "lib/whisker/core/passage.lua"
    "lib/whisker/core/choice.lua"
    "tests/mocks/mock_factory.lua"
    "tests/contracts/contract_runner.lua"
)

MISSING=0
for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "  [OK] $file"
    else
        echo "  [MISSING] $file"
        MISSING=$((MISSING + 1))
    fi
done

if [ $MISSING -eq 0 ]; then
    check_result "All required files exist" 0
else
    check_result "All required files exist" 1
fi
echo ""

# 7. Check Interface Implementations
echo "7. Checking Interface Count..."
echo "------------------------------"
INTERFACE_COUNT=$(find lib/whisker/interfaces -name "*.lua" 2>/dev/null | wc -l)
echo "Found $INTERFACE_COUNT interface files"
if [ $INTERFACE_COUNT -ge 6 ]; then
    check_result "Minimum 6 interfaces defined" 0
else
    check_result "Minimum 6 interfaces defined" 1
fi
echo ""

# 8. Check Kernel Size
echo "8. Checking Kernel Size..."
echo "--------------------------"
if [ -d "lib/whisker/kernel" ]; then
    KERNEL_LINES=$(find lib/whisker/kernel -name "*.lua" -exec wc -l {} + 2>/dev/null | tail -1 | awk '{print $1}')
    echo "Kernel total lines: $KERNEL_LINES"
    if [ "$KERNEL_LINES" -lt 350 ]; then
        check_result "Kernel under 350 lines" 0
    else
        check_result "Kernel under 350 lines" 1
    fi
else
    echo "Warning: kernel directory not found"
    check_result "Kernel under 350 lines" 1
fi
echo ""

# Summary
echo "========================================"
echo "                SUMMARY"
echo "========================================"
echo ""
echo "Passed: $PASSED"
echo "Failed: $FAILED"
echo ""

if [ $FAILED -eq 0 ]; then
    echo "========================================"
    echo "       PHASE 1 VALIDATION PASSED"
    echo "========================================"
    exit 0
else
    echo "========================================"
    echo "       PHASE 1 VALIDATION FAILED"
    echo "========================================"
    echo ""
    echo "Please fix the failing checks before proceeding to Phase 2."
    exit 1
fi
