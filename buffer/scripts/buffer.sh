#!/usr/bin/env bash
# Buffer GraphQL API client
# Requires: curl, jq
# Env: BUFFER_API_KEY (required), BUFFER_API_URL (optional)
set -euo pipefail

BUFFER_API_URL="${BUFFER_API_URL:-https://api.buffer.com}"
: "${BUFFER_API_KEY:?BUFFER_API_KEY environment variable is required}"

# ---------------------------------------------------------------------------
# GraphQL helper
# ---------------------------------------------------------------------------

gql() {
  local query="$1"
  local variables="${2:-{}}"

  local response
  response=$(curl -sf \
    -X POST \
    -H "Authorization: Bearer $BUFFER_API_KEY" \
    -H "Content-Type: application/json" \
    "$BUFFER_API_URL" \
    -d "$(jq -cn --arg q "$query" --argjson v "$variables" '{query: $q, variables: $v}')")

  local errors
  errors=$(echo "$response" | jq -r '.errors // empty')
  if [[ -n "$errors" ]]; then
    echo "GraphQL errors:" >&2
    echo "$errors" | jq '.' >&2
    exit 1
  fi

  echo "$response" | jq '.data'
}

# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------

cmd_account() {
  # Returns account info including organization IDs needed for other commands
  gql 'query {
    account {
      id email name avatar timezone
      organizations { id name ownerEmail }
    }
  }'
}

cmd_channels() {
  local org_id=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --org-id) org_id="$2"; shift 2 ;;
      *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
  done
  [[ -z "$org_id" ]] && { echo "--org-id is required" >&2; exit 1; }

  gql 'query GetChannels($input: ChannelsInput!) {
    channels(input: $input) {
      id name service type avatar displayName
      isDisconnected isLocked timezone
    }
  }' "$(jq -cn --arg oid "$org_id" '{input: {organizationId: $oid}}')"
}

cmd_channel() {
  local id=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --id) id="$2"; shift 2 ;;
      *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
  done
  [[ -z "$id" ]] && { echo "--id is required" >&2; exit 1; }

  gql 'query GetChannel($input: ChannelInput!) {
    channel(input: $input) {
      id name service type avatar displayName
      isDisconnected isLocked timezone
      postingSchedule { day times paused }
    }
  }' "$(jq -cn --arg cid "$id" '{input: {id: $cid}}')"
}

cmd_get_post() {
  local id=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --id) id="$2"; shift 2 ;;
      *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
  done
  [[ -z "$id" ]] && { echo "--id is required" >&2; exit 1; }

  gql 'query GetPost($input: PostInput!) {
    post(input: $input) {
      id status text dueAt sentAt createdAt updatedAt
      shareMode schedulingType isCustomScheduled
      channelId channelService
      tags { id name color }
      author { id email name }
      error { message }
    }
  }' "$(jq -cn --arg pid "$id" '{input: {id: $pid}}')"
}

cmd_list_posts() {
  local org_id="" status="" channel_id="" limit=20 after=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --org-id)     org_id="$2";     shift 2 ;;
      --status)     status="$2";     shift 2 ;;
      --channel-id) channel_id="$2"; shift 2 ;;
      --limit)      limit="$2";      shift 2 ;;
      --after)      after="$2";      shift 2 ;;
      *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
  done
  [[ -z "$org_id" ]] && { echo "--org-id is required" >&2; exit 1; }

  local vars
  vars=$(jq -cn \
    --arg oid "$org_id" \
    --arg cid "$channel_id" \
    --arg st "$status" \
    --argjson limit "$limit" \
    --arg after "$after" \
    '{
      input: {
        organizationId: $oid,
        filter: {
          channelIds: (if $cid == "" then null else [$cid] end),
          status:     (if $st  == "" then null else [$st]  end)
        }
      },
      first: $limit,
      after: (if $after == "" then null else $after end)
    }')

  gql 'query ListPosts($input: PostsInput!, $first: Int, $after: String) {
    posts(input: $input, first: $first, after: $after) {
      edges {
        cursor
        node {
          id status text dueAt sentAt createdAt
          channelId channelService shareMode
          tags { id name color }
        }
      }
      pageInfo { hasNextPage endCursor }
    }
  }' "$vars"
}

cmd_create_post() {
  local channel_id="" text="" mode="addToQueue" scheduling_type="automatic"
  local due_at="" tag_ids="" save_draft=false idea_id=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --channel-id)      channel_id="$2";      shift 2 ;;
      --text)            text="$2";            shift 2 ;;
      --mode)            mode="$2";            shift 2 ;;
      --scheduling-type) scheduling_type="$2"; shift 2 ;;
      --due-at)          due_at="$2";          shift 2 ;;
      --tag-ids)         tag_ids="$2";         shift 2 ;;
      --save-draft)      save_draft=true;      shift   ;;
      --idea-id)         idea_id="$2";         shift 2 ;;
      *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
  done
  [[ -z "$channel_id" ]] && { echo "--channel-id is required" >&2; exit 1; }

  local vars
  vars=$(jq -cn \
    --arg cid  "$channel_id" \
    --arg txt  "$text" \
    --arg mode "$mode" \
    --arg st   "$scheduling_type" \
    --argjson  draft "$save_draft" \
    --arg due  "$due_at" \
    --arg tags "$tag_ids" \
    --arg idea "$idea_id" \
    '{
      input: {
        channelId:      $cid,
        text:           (if $txt  == "" then null else $txt  end),
        mode:           $mode,
        schedulingType: $st,
        saveToDraft:    $draft,
        dueAt:          (if $due  == "" then null else $due  end),
        ideaId:         (if $idea == "" then null else $idea end),
        tagIds:         (if $tags == "" then null else ($tags | split(",")) end)
      }
    }')

  gql 'mutation CreatePost($input: CreatePostInput!) {
    createPost(input: $input) {
      ... on PostActionSuccess {
        post {
          id status text dueAt channelId channelService
          shareMode schedulingType createdAt
          tags { id name color }
        }
      }
      ... on NotFoundError      { message }
      ... on UnauthorizedError  { message }
      ... on UnexpectedError    { message }
      ... on RestProxyError     { message code }
      ... on LimitReachedError  { message }
      ... on InvalidInputError  { message }
    }
  }' "$vars"
}

cmd_update_post() {
  # Buffer's GraphQL API (as documented) does not expose an updatePost mutation.
  # Re-create (replace) the post by deleting and creating, or use the Buffer web UI.
  # This command creates a new draft with the same channel so you can review before scheduling.
  echo "Note: Buffer's public GraphQL API does not expose an updatePost mutation." >&2
  echo "      Use create-post --save-draft to create a revised draft instead." >&2
  echo "      Passing all args to create-post --save-draft ..." >&2
  cmd_create_post --save-draft "$@"
}

cmd_create_idea() {
  local org_id="" title="" text="" date="" tags="[]"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --org-id) org_id="$2"; shift 2 ;;
      --title)  title="$2";  shift 2 ;;
      --text)   text="$2";   shift 2 ;;
      --date)   date="$2";   shift 2 ;;
      --tags)   tags="$2";   shift 2 ;;
      *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
  done
  [[ -z "$org_id" ]] && { echo "--org-id is required" >&2; exit 1; }

  local vars
  vars=$(jq -cn \
    --arg oid "$org_id" \
    --arg ttl "$title" \
    --arg txt "$text" \
    --arg dt  "$date" \
    --argjson tags "$tags" \
    '{
      input: {
        organizationId: $oid,
        content: {
          title: (if $ttl == "" then null else $ttl end),
          text:  (if $txt == "" then null else $txt end),
          date:  (if $dt  == "" then null else $dt  end),
          tags:  $tags
        }
      }
    }')

  gql 'mutation CreateIdea($input: CreateIdeaInput!) {
    createIdea(input: $input) {
      ... on Idea {
        id organizationId createdAt updatedAt groupId
        content { title text date services aiAssisted tags { id name color } }
      }
      ... on IdeaResponse {
        refreshIdeas
        idea {
          id organizationId createdAt updatedAt groupId
          content { title text date services aiAssisted tags { id name color } }
        }
      }
      ... on InvalidInputError { message }
      ... on UnauthorizedError { message }
      ... on UnexpectedError   { message }
      ... on LimitReachedError { message }
    }
  }' "$vars"
}

cmd_update_idea() {
  # Same situation as update-post — no updateIdea mutation in the public GraphQL API.
  # Create a new idea with revised content instead.
  echo "Note: Buffer's public GraphQL API does not expose an updateIdea mutation." >&2
  echo "      Creating a new idea with the provided content instead..." >&2
  cmd_create_idea "$@"
}

# ---------------------------------------------------------------------------
# Usage / dispatch
# ---------------------------------------------------------------------------

usage() {
  cat <<'EOF'
Buffer GraphQL API client
Usage: buffer.sh <command> [options]

ACCOUNT
  account
      Get authenticated account info (includes org IDs needed elsewhere)

CHANNELS
  channels --org-id <id>
      List all channels for an organization

  channel --id <id>
      Get details and posting schedule for a specific channel

POSTS
  create-post --channel-id <id> [options]
      Create or schedule a post
        --text <text>               Post text content
        --mode <mode>               addToQueue* | shareNow | shareNext |
                                    customScheduled | recommendedTime
        --scheduling-type <type>    automatic* | notification
        --due-at <ISO8601>          Scheduled datetime (required for customScheduled)
        --tag-ids <id1,id2,...>     Comma-separated tag IDs
        --save-draft                Save as draft instead of scheduling
        --idea-id <id>              Link post to an existing idea

  update-post --channel-id <id> [same options as create-post]
      Create a revised draft (the public API has no updatePost mutation)

  get-post --id <id>
      Get a post by ID

  list-posts --org-id <id> [options]
      List posts for an organization
        --status <status>           draft | scheduled | sent | error | needs_approval
        --channel-id <id>           Filter by channel
        --limit <n>                 Results per page (default: 20)
        --after <cursor>            Pagination cursor from previous response

IDEAS
  create-idea --org-id <id> [options]
      Create a new idea in the Buffer Create space
        --title <title>             Idea headline
        --text <text>               Idea body text
        --date <ISO8601>            Target publish date for planning
        --tags <json>               JSON array: '[{"id":"...","name":"...","color":"#..."}]'

  update-idea --org-id <id> [same options as create-idea]
      Create a revised idea (the public API has no updateIdea mutation)

ENVIRONMENT
  BUFFER_API_KEY    (required) Your Buffer API key
  BUFFER_API_URL    (optional) Override API base URL (default: https://api.buffer.com)

EXAMPLES
  # Step 1: get your org ID
  bash buffer/scripts/buffer.sh account | jq '.account.organizations[].id'

  # Step 2: list channels to find channel IDs
  bash buffer/scripts/buffer.sh channels --org-id <org-id>

  # Add a post to the queue
  bash buffer/scripts/buffer.sh create-post \
    --channel-id <channel-id> \
    --text "Hello from the Buffer API!"

  # Schedule a post at a specific time
  bash buffer/scripts/buffer.sh create-post \
    --channel-id <channel-id> \
    --text "Scheduled content" \
    --mode customScheduled \
    --due-at "2026-04-01T09:00:00Z"

  # Share immediately
  bash buffer/scripts/buffer.sh create-post \
    --channel-id <channel-id> \
    --text "Live now!" \
    --mode shareNow

  # Save a draft
  bash buffer/scripts/buffer.sh create-post \
    --channel-id <channel-id> \
    --text "Draft content" \
    --save-draft

  # Create an idea
  bash buffer/scripts/buffer.sh create-idea \
    --org-id <org-id> \
    --title "Spring campaign" \
    --text "Content ideas for Q2..." \
    --date "2026-04-01T00:00:00Z"

  # Paginate through posts
  result=$(bash buffer/scripts/buffer.sh list-posts --org-id <org-id> --limit 10)
  echo "$result" | jq '.posts.edges[].node | {id, status, text}'
  cursor=$(echo "$result" | jq -r '.posts.pageInfo.endCursor')
  bash buffer/scripts/buffer.sh list-posts --org-id <org-id> --limit 10 --after "$cursor"
EOF
}

main() {
  local cmd="${1:-}"
  [[ -z "$cmd" || "$cmd" == "--help" || "$cmd" == "-h" ]] && { usage; exit 0; }
  shift

  case "$cmd" in
    account)      cmd_account      "$@" ;;
    channels)     cmd_channels     "$@" ;;
    channel)      cmd_channel      "$@" ;;
    create-post)  cmd_create_post  "$@" ;;
    update-post)  cmd_update_post  "$@" ;;
    get-post)     cmd_get_post     "$@" ;;
    list-posts)   cmd_list_posts   "$@" ;;
    create-idea)  cmd_create_idea  "$@" ;;
    update-idea)  cmd_update_idea  "$@" ;;
    *) echo "Unknown command: $cmd" >&2; usage >&2; exit 1 ;;
  esac
}

main "$@"
