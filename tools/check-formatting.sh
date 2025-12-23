#!/bin/bash
# Code formatting checker for whisker-core
# Ensures consistent code style across the codebase

set -e

echo "Checking code formatting..."

ERRORS=0

# Check for trailing whitespace
echo "Checking for trailing whitespace..."
if grep -rn --include="*.lua" '[[:space:]]$' lib/ tests/ 2>/dev/null; then
    echo "FAIL: Found trailing whitespace (see above)"
    ERRORS=$((ERRORS + 1))
else
    echo "PASS: No trailing whitespace"
fi

# Check for tabs (should use spaces)
echo "Checking for tabs (should use spaces)..."
if grep -rn --include="*.lua" $'\t' lib/ tests/ 2>/dev/null; then
    echo "FAIL: Found tabs, please use spaces (see above)"
    ERRORS=$((ERRORS + 1))
else
    echo "PASS: No tabs found"
fi

# Check for CRLF line endings (should be LF)
echo "Checking for CRLF line endings..."
if find lib/ tests/ -name "*.lua" -exec file {} \; 2>/dev/null | grep -i crlf; then
    echo "FAIL: Found CRLF line endings, please use LF"
    ERRORS=$((ERRORS + 1))
else
    echo "PASS: All files use LF line endings"
fi

# Check for lines exceeding 100 characters
echo "Checking for long lines (>100 chars)..."
LONG_LINES=$(find lib/ -name "*.lua" -exec awk 'length > 100 { print FILENAME ":" NR ": " length " chars" }' {} \; 2>/dev/null | head -10)
if [ -n "$LONG_LINES" ]; then
    echo "Warning: Found lines exceeding 100 characters:"
    echo "$LONG_LINES"
    # Not a failure, just a warning
else
    echo "PASS: No lines exceed 100 characters"
fi

if [ $ERRORS -gt 0 ]; then
    echo ""
    echo "Formatting check FAILED: $ERRORS error(s) found"
    exit 1
fi

echo ""
echo "Formatting check PASSED"
exit 0
