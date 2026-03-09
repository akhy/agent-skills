#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = [
#   "requests-oauthlib==1.3.1",
# ]
# ///
"""Plurk API client — timeline and responses.

Env vars required:
  PLURK_APP_KEY        OAuth consumer key
  PLURK_APP_SECRET     OAuth consumer secret
  PLURK_AUTH_TOKEN     OAuth user access token
  PLURK_AUTH_SECRET    OAuth user access secret

Usage:
  plurk.py timeline [--limit N] [--filter FILTER] [--offset TIMESTAMP]
  plurk.py get-plurk <plurk_id>
  plurk.py public-timeline <user_id> [--limit N] [--offset TIMESTAMP]
  plurk.py responses <plurk_id> [--from N] [--count N]
  plurk.py respond <plurk_id> <qualifier> <content>
  plurk.py --help
"""

import json
import os
import sys

from requests_oauthlib import OAuth1Session

BASE_URL = "https://www.plurk.com"

QUALIFIERS = [
    "says", "thinks", "feels", "hopes", "wishes", "needs", "will", "is",
    "wants", "has", "was", "wonders", "adores", "hates", "loves", "likes",
    "dislikes", "asks", "shares", "knows", "fears", "replies",
]


def get_session() -> OAuth1Session:
    app_key = os.environ.get("PLURK_APP_KEY")
    app_secret = os.environ.get("PLURK_APP_SECRET")
    auth_token = os.environ.get("PLURK_AUTH_TOKEN")
    auth_secret = os.environ.get("PLURK_AUTH_SECRET")

    missing = [k for k, v in {
        "PLURK_APP_KEY": app_key,
        "PLURK_APP_SECRET": app_secret,
        "PLURK_AUTH_TOKEN": auth_token,
        "PLURK_AUTH_SECRET": auth_secret,
    }.items() if not v]

    if missing:
        print(f"Error: missing env vars: {', '.join(missing)}", file=sys.stderr)
        sys.exit(1)

    return OAuth1Session(app_key, app_secret, auth_token, auth_secret)


def api_get(session: OAuth1Session, path: str, params: dict) -> dict:
    url = f"{BASE_URL}{path}"
    resp = session.get(url, params={k: v for k, v in params.items() if v is not None})
    if not resp.ok:
        print(f"HTTP {resp.status_code}: {resp.text}", file=sys.stderr)
        sys.exit(1)
    return resp.json()


def api_post(session: OAuth1Session, path: str, data: dict) -> dict:
    url = f"{BASE_URL}{path}"
    resp = session.post(url, data={k: v for k, v in data.items() if v is not None})
    if not resp.ok:
        print(f"HTTP {resp.status_code}: {resp.text}", file=sys.stderr)
        sys.exit(1)
    return resp.json()


def cmd_timeline(session: OAuth1Session, args: list[str]) -> None:
    limit = None
    filter_ = None
    offset = None
    it = iter(args)
    for arg in it:
        if arg == "--limit":
            limit = next(it)
        elif arg == "--filter":
            filter_ = next(it)
        elif arg == "--offset":
            offset = next(it)
        else:
            print(f"Unknown option: {arg}", file=sys.stderr)
            sys.exit(1)

    result = api_get(session, "/APP/Timeline/getPlurks", {
        "limit": limit,
        "filter": filter_,
        "offset": offset,
    })
    print(json.dumps(result, indent=2))


def cmd_get_plurk(session: OAuth1Session, args: list[str]) -> None:
    if not args:
        print("Usage: get-plurk <plurk_id>", file=sys.stderr)
        sys.exit(1)
    plurk_id = args[0]
    result = api_get(session, "/APP/Timeline/getPlurk", {"plurk_id": plurk_id})
    print(json.dumps(result, indent=2))


def cmd_public_timeline(session: OAuth1Session, args: list[str]) -> None:
    if not args:
        print("Usage: public-timeline <user_id> [--limit N] [--offset TIMESTAMP]", file=sys.stderr)
        sys.exit(1)
    user_id = args[0]
    limit = None
    offset = None
    it = iter(args[1:])
    for arg in it:
        if arg == "--limit":
            limit = next(it)
        elif arg == "--offset":
            offset = next(it)
        else:
            print(f"Unknown option: {arg}", file=sys.stderr)
            sys.exit(1)

    result = api_get(session, "/APP/Timeline/getPublicPlurks", {
        "user_id": user_id,
        "limit": limit,
        "offset": offset,
    })
    print(json.dumps(result, indent=2))


def cmd_responses(session: OAuth1Session, args: list[str]) -> None:
    if not args:
        print("Usage: responses <plurk_id> [--from N] [--count N]", file=sys.stderr)
        sys.exit(1)
    plurk_id = args[0]
    from_response = None
    count = None
    it = iter(args[1:])
    for arg in it:
        if arg == "--from":
            from_response = next(it)
        elif arg == "--count":
            count = next(it)
        else:
            print(f"Unknown option: {arg}", file=sys.stderr)
            sys.exit(1)

    result = api_get(session, "/APP/Responses/get", {
        "plurk_id": plurk_id,
        "from_response": from_response,
        "count": count,
    })
    print(json.dumps(result, indent=2))


def cmd_respond(session: OAuth1Session, args: list[str]) -> None:
    if len(args) < 3:
        print(f"Usage: respond <plurk_id> <qualifier> <content>", file=sys.stderr)
        print(f"Qualifiers: {', '.join(QUALIFIERS)}", file=sys.stderr)
        sys.exit(1)
    plurk_id, qualifier, content = args[0], args[1], " ".join(args[2:])
    result = api_post(session, "/APP/Responses/responseAdd", {
        "plurk_id": plurk_id,
        "qualifier": qualifier,
        "content": content,
    })
    print(json.dumps(result, indent=2))


COMMANDS = {
    "timeline": cmd_timeline,
    "get-plurk": cmd_get_plurk,
    "public-timeline": cmd_public_timeline,
    "responses": cmd_responses,
    "respond": cmd_respond,
}


def main() -> None:
    if len(sys.argv) < 2 or sys.argv[1] in ("--help", "-h"):
        print(__doc__)
        sys.exit(0)

    command = sys.argv[1]
    if command not in COMMANDS:
        print(f"Unknown command: {command}", file=sys.stderr)
        print(f"Commands: {', '.join(COMMANDS)}", file=sys.stderr)
        sys.exit(1)

    session = get_session()
    COMMANDS[command](session, sys.argv[2:])


if __name__ == "__main__":
    main()
