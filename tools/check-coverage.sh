#!/bin/bash
# Coverage threshold checker for whisker-core
# Ensures different modules meet minimum coverage requirements

set -e

COVERAGE_REPORT="luacov.report.out"

if [ ! -f "$COVERAGE_REPORT" ]; then
    echo "Error: Coverage report not found: $COVERAGE_REPORT"
    echo "Run 'busted --coverage && luacov' first"
    exit 1
fi

echo "Checking coverage thresholds..."

# Function to check coverage for a specific path
check_coverage() {
    local path=$1
    local threshold=$2
    local name=$3

    # Extract coverage for the specific path
    local coverage=$(grep "^lib/whisker/$path" "$COVERAGE_REPORT" | awk '{
        hits += $2;
        total += $3
    } END {
        if (total > 0) {
            printf "%.1f", (hits/total)*100
        } else {
            print "0"
        }
    }')

    if [ -z "$coverage" ] || [ "$coverage" = "0" ]; then
        echo "Warning: No coverage data for $name (lib/whisker/$path)"
        return 0
    fi

    echo "$name coverage: ${coverage}%"

    # Compare coverage with threshold
    result=$(awk -v cov="$coverage" -v thresh="$threshold" 'BEGIN {
        if (cov >= thresh) print "pass"; else print "fail"
    }')

    if [ "$result" = "fail" ]; then
        echo "FAIL: $name coverage (${coverage}%) is below threshold (${threshold}%)"
        return 1
    fi

    return 0
}

# Track overall status
FAILED=0

# Check kernel modules (>= 95%)
check_coverage "kernel/" 95 "Kernel" || FAILED=1

# Check core modules (>= 90%)
check_coverage "core/" 90 "Core" || FAILED=1

# Check services modules (>= 85%)
check_coverage "services/" 85 "Services" || FAILED=1

# Check formats modules (>= 80%)
check_coverage "formats/" 80 "Formats" || FAILED=1

if [ $FAILED -eq 1 ]; then
    echo ""
    echo "Coverage check FAILED: One or more modules below threshold"
    exit 1
fi

echo ""
echo "Coverage check PASSED: All modules meet thresholds"
exit 0
