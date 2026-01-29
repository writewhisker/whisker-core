#!/usr/bin/env bash
#
# Run busted tests under multiple Lua interpreters.
# Mirrors the CI test matrix (5.1, 5.2, 5.3, 5.4, luajit) plus Lua 5.5.
#
# Skips a version if:
#   - The interpreter alias is not found on PATH
#   - busted cannot load under that interpreter (e.g. missing luarocks install)
#
# The script extracts package paths from the installed busted wrapper and
# injects them when invoking each Lua interpreter directly. This works for
# interpreters ABI-compatible with the busted install (same major.minor).
# For other versions, install busted via per-version luarocks.
#

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
RESET='\033[0m'

LUA_VERSIONS=(lua5.1 lua5.2 lua5.3 lua5.4 lua5.5 luajit)

BUSTED_BIN=$(command -v busted 2>/dev/null || echo "")
if [ -z "$BUSTED_BIN" ]; then
    echo -e "${RED}busted not found on PATH${RESET}"
    exit 1
fi

# Extract package paths and entry point from the busted wrapper script.
BUSTED_LUA_PATH=$(sed -n 's/.*package\.path="\([^"]*\)".*/\1/p' "$BUSTED_BIN")
BUSTED_LUA_CPATH=$(sed -n 's/.*package\.cpath="\([^"]*\)".*/\1/p' "$BUSTED_BIN")
BUSTED_ENTRY=$(sed -n "s/.*' '\([^']*busted[^']*\)' .*/\1/p" "$BUSTED_BIN")

if [ -z "$BUSTED_LUA_PATH" ] || [ -z "$BUSTED_ENTRY" ]; then
    echo -e "${YELLOW}Could not parse busted wrapper; falling back to busted --lua${RESET}"
    USE_DIRECT=true
else
    USE_DIRECT=false
fi

passed=()
failed=()
skipped=()
skipped_no_busted=()

run_with_direct() {
    local luaver="$1"
    "$luaver" \
        -e "package.path='${BUSTED_LUA_PATH}'..package.path; package.cpath='${BUSTED_LUA_CPATH}'..package.cpath" \
        "$BUSTED_ENTRY" --verbose 2>&1
}

run_with_flag() {
    local luaver="$1"
    "$BUSTED_BIN" --lua="$luaver" --verbose 2>&1
}

for luaver in "${LUA_VERSIONS[@]}"; do
    if ! command -v "$luaver" >/dev/null 2>&1; then
        skipped+=("$luaver")
        continue
    fi

    version_str=$("$luaver" -v 2>&1)
    echo ""
    echo -e "${BLUE}Testing with ${luaver} (${version_str})...${RESET}"

    if [ "$USE_DIRECT" = true ]; then
        output=$(run_with_flag "$luaver") && rc=0 || rc=$?
    else
        output=$(run_with_direct "$luaver") && rc=0 || rc=$?
    fi

    if [ $rc -ne 0 ]; then
        if echo "$output" | grep -q "module '.*' not found\|requires LuaFileSystem\|cannot open\|no file"; then
            echo -e "${YELLOW}  ⊘ busted not available for ${luaver} (incompatible or missing luarocks install)${RESET}"
            skipped_no_busted+=("$luaver")
        else
            echo "$output"
            failed+=("$luaver")
        fi
    else
        echo "$output"
        passed+=("$luaver")
    fi
done

echo ""
echo -e "${BLUE}=== Summary ===${RESET}"
if [ ${#passed[@]} -gt 0 ]; then
    echo -e "${GREEN}✓ Passed: ${passed[*]}${RESET}"
fi
if [ ${#skipped[@]} -gt 0 ]; then
    echo -e "${YELLOW}⊘ Skipped (not installed): ${skipped[*]}${RESET}"
fi
if [ ${#skipped_no_busted[@]} -gt 0 ]; then
    echo -e "${YELLOW}⊘ Skipped (no busted for version): ${skipped_no_busted[*]}${RESET}"
fi
if [ ${#failed[@]} -gt 0 ]; then
    echo -e "${RED}✗ Failed: ${failed[*]}${RESET}"
    exit 1
fi
echo -e "${GREEN}✓ All available versions passed!${RESET}"
