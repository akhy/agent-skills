#!/bin/bash
# memos.sh - Memos API client for /api/v1/memos endpoints
# Usage: memos.sh <command> [options]
#
# Required env vars:
#   MEMOS_URL           Base URL of your Memos instance (e.g. https://memos.example.com)
#   MEMOS_ACCESS_TOKEN  Bearer token from account settings
#
# Commands:
#   list                            List memos
#     --filter EXPR                 AIP-160 filter (e.g. 'state == "NORMAL"')
#     --page-size N
#     --page-token TOKEN
#     --state STATE                 NORMAL | ARCHIVED
#     --order-by FIELD
#     --show-deleted
#
#   create                          Create a memo
#     --content TEXT                Memo content (required)
#     --visibility VALUE            PUBLIC | PROTECTED | PRIVATE (default: PRIVATE)
#     --pinned                      Pin the memo
#
#   get MEMO                        Get a memo (e.g. memos/123)
#
#   update MEMO                     Update a memo
#     --content TEXT
#     --visibility VALUE
#     --pinned true|false
#     --state STATE
#
#   delete MEMO                     Delete a memo
#     --force                       Hard delete
#
#   comments MEMO                   List comments on a memo
#     --page-size N
#     --page-token TOKEN
#     --order-by FIELD
#
#   comment MEMO                    Post a comment
#     --content TEXT                Comment content (required)
#
#   attachments MEMO                List attachments of a memo
#     --page-size N
#     --page-token TOKEN
#
#   set-attachments MEMO            Set attachments on a memo
#     --names NAME,...              Comma-separated attachment resource names
#
#   reactions MEMO                  List reactions on a memo
#
#   react MEMO                      Add a reaction
#     --reaction EMOJI              Reaction emoji (required)
#
#   delete-reaction MEMO REACTION   Remove a reaction
#
#   relations MEMO                  List relations of a memo
#
#   set-relations MEMO              Set relations on a memo
#     --relations JSON              JSON array of MemoRelation objects (required)

set -euo pipefail

: "${MEMOS_URL:?MEMOS_URL env var is required}"
: "${MEMOS_ACCESS_TOKEN:?MEMOS_ACCESS_TOKEN env var is required}"

BASE="${MEMOS_URL%/}/api/v1"
AUTH="Authorization: Bearer $MEMOS_ACCESS_TOKEN"

_curl() {
  curl -sSf -H "$AUTH" -H "Content-Type: application/json" "$@"
}

_qs() {
  # Append query params to URL; args: url key=val ...
  local url="$1"; shift
  local sep="?"
  [[ "$url" == *"?"* ]] && sep="&"
  for kv in "$@"; do
    url="${url}${sep}${kv}"
    sep="&"
  done
  echo "$url"
}

cmd="${1:-}"
shift || true

case "$cmd" in

  list)
    url="$BASE/memos"
    params=()
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --filter)     params+=("filter=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$2")"); shift 2 ;;
        --page-size)  params+=("pageSize=$2"); shift 2 ;;
        --page-token) params+=("pageToken=$2"); shift 2 ;;
        --state)      params+=("state=$2"); shift 2 ;;
        --order-by)   params+=("orderBy=$2"); shift 2 ;;
        --show-deleted) params+=("showDeleted=true"); shift ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
      esac
    done
    [[ ${#params[@]} -gt 0 ]] && url="$(_qs "$url" "${params[@]}")"
    _curl "$url"
    ;;

  create)
    content="" visibility="PRIVATE" pinned="false"
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --content)    content="$2"; shift 2 ;;
        --visibility) visibility="$2"; shift 2 ;;
        --pinned)     pinned="true"; shift ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
      esac
    done
    [[ -z "$content" ]] && { echo "--content is required" >&2; exit 1; }
    body=$(jq -n --arg c "$content" --arg v "$visibility" --argjson p "$pinned" \
      '{content: $c, visibility: $v, pinned: $p}')
    _curl -X POST "$BASE/memos" -d "$body"
    ;;

  get)
    memo="${1:?MEMO argument required (e.g. memos/123)}"; shift
    _curl "$BASE/$memo"
    ;;

  update)
    memo="${1:?MEMO argument required}"; shift
    fields=() masks=()
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --content)    fields+=("\"content\":$(jq -n --arg v "$2" '$v')"); masks+=("content"); shift 2 ;;
        --visibility) fields+=("\"visibility\":$(jq -n --arg v "$2" '$v')"); masks+=("visibility"); shift 2 ;;
        --pinned)     fields+=("\"pinned\":$2"); masks+=("pinned"); shift 2 ;;
        --state)      fields+=("\"state\":$(jq -n --arg v "$2" '$v')"); masks+=("state"); shift 2 ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
      esac
    done
    [[ ${#fields[@]} -eq 0 ]] && { echo "At least one field to update is required" >&2; exit 1; }
    body="{$(IFS=,; echo "${fields[*]}")}"
    mask=$(IFS=,; echo "${masks[*]}")
    _curl -X PATCH "$(_qs "$BASE/$memo" "updateMask=$mask")" -d "$body"
    ;;

  delete)
    memo="${1:?MEMO argument required}"; shift
    url="$BASE/$memo"
    [[ "${1:-}" == "--force" ]] && { url="$(_qs "$url" "force=true")"; shift; }
    _curl -X DELETE "$url"
    ;;

  comments)
    memo="${1:?MEMO argument required}"; shift
    url="$BASE/$memo/comments"
    params=()
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --page-size)  params+=("pageSize=$2"); shift 2 ;;
        --page-token) params+=("pageToken=$2"); shift 2 ;;
        --order-by)   params+=("orderBy=$2"); shift 2 ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
      esac
    done
    [[ ${#params[@]} -gt 0 ]] && url="$(_qs "$url" "${params[@]}")"
    _curl "$url"
    ;;

  comment)
    memo="${1:?MEMO argument required}"; shift
    content=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --content) content="$2"; shift 2 ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
      esac
    done
    [[ -z "$content" ]] && { echo "--content is required" >&2; exit 1; }
    body=$(jq -n --arg c "$content" '{content: $c}')
    _curl -X POST "$BASE/$memo/comments" -d "$body"
    ;;

  attachments)
    memo="${1:?MEMO argument required}"; shift
    url="$BASE/$memo/attachments"
    params=()
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --page-size)  params+=("pageSize=$2"); shift 2 ;;
        --page-token) params+=("pageToken=$2"); shift 2 ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
      esac
    done
    [[ ${#params[@]} -gt 0 ]] && url="$(_qs "$url" "${params[@]}")"
    _curl "$url"
    ;;

  set-attachments)
    memo="${1:?MEMO argument required}"; shift
    names=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --names) names="$2"; shift 2 ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
      esac
    done
    [[ -z "$names" ]] && { echo "--names is required" >&2; exit 1; }
    body=$(python3 -c "
import json, sys
names = sys.argv[1].split(',')
print(json.dumps({'attachments': [{'name': n.strip()} for n in names]}))
" "$names")
    _curl -X PATCH "$BASE/$memo/attachments" -d "$body"
    ;;

  reactions)
    memo="${1:?MEMO argument required}"; shift
    _curl "$BASE/$memo/reactions"
    ;;

  react)
    memo="${1:?MEMO argument required}"; shift
    reaction=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --reaction) reaction="$2"; shift 2 ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
      esac
    done
    [[ -z "$reaction" ]] && { echo "--reaction is required" >&2; exit 1; }
    body=$(jq -n --arg r "$reaction" '{reaction: {reactionType: $r}}')
    _curl -X POST "$BASE/$memo/reactions" -d "$body"
    ;;

  delete-reaction)
    memo="${1:?MEMO argument required}"; shift
    reaction="${1:?REACTION argument required}"; shift
    _curl -X DELETE "$BASE/$memo/reactions/$reaction"
    ;;

  relations)
    memo="${1:?MEMO argument required}"; shift
    _curl "$BASE/$memo/relations"
    ;;

  set-relations)
    memo="${1:?MEMO argument required}"; shift
    relations=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --relations) relations="$2"; shift 2 ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
      esac
    done
    [[ -z "$relations" ]] && { echo "--relations JSON array is required" >&2; exit 1; }
    body=$(jq -n --argjson r "$relations" '{relations: $r}')
    _curl -X PATCH "$BASE/$memo/relations" -d "$body"
    ;;

  ""|--help|-h)
    sed -n '/^# /p;/^#   /p' "$0" | sed 's/^# //'
    exit 0
    ;;

  *)
    echo "Unknown command: $cmd" >&2
    echo "Run '$0 --help' for usage." >&2
    exit 1
    ;;
esac
