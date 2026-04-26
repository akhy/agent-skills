#!/bin/bash
# fizzy-context.sh - Get board context needed for card workflows
# Usage: fizzy-context.sh <board_id>

BOARD_ID="${1:?Usage: fizzy-context.sh <board_id>}"

echo "=== Fizzy Context for board: $BOARD_ID ==="
echo

echo "Columns:"
fizzy column list --board "$BOARD_ID" --jq '[.data[] | {id, name}]'
echo

echo "Git remote:"
git remote get-url origin 2>/dev/null || echo "  (not in a git repository)"
