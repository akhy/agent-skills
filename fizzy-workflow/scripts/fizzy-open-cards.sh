#!/bin/bash
# fizzy-open-cards.sh - List open cards on a board
# Usage: fizzy-open-cards.sh <board_id>

BOARD_ID="${1:?Usage: fizzy-open-cards.sh <board_id>}"

fizzy card list --board "$BOARD_ID" --all --jq '[.data[] | {number, title, assignees: [.assignees[].name]}]'
