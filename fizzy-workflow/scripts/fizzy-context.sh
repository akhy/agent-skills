#!/bin/bash
# fizzy-context.sh - Get board context needed for card workflows
# Usage: fizzy-context.sh <board_id>

BOARD_ID="${1:?Usage: fizzy-context.sh <board_id>}"

# Use fizzy's built-in --jq flag (unreleased); fall back to external jq
fizzy_jq() {
    local filter="$1"; shift
    local out rc
    out=$(fizzy "$@" --jq "$filter" 2>&1)
    rc=$?
    if [ $rc -eq 0 ]; then
        echo "$out"
    elif echo "$out" | grep -qi "unknown flag\|flag provided but not defined"; then
        fizzy "$@" --json | jq "$filter"
    else
        echo "$out" >&2
        return $rc
    fi
}

echo "=== Fizzy Context for board: $BOARD_ID ==="
echo

echo "Columns:"
fizzy_jq '[.data[] | {id, name}]' column list --board "$BOARD_ID"
echo

echo "Git remote:"
git remote get-url origin 2>/dev/null || echo "  (not in a git repository)"
