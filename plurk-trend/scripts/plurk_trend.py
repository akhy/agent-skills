#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = [
#   "requests-oauthlib==1.3.1",
# ]
# ///
"""Plurk trending — top plurks by response count within a time window.

Env vars required:
  PLURK_APP_KEY        OAuth consumer key
  PLURK_APP_SECRET     OAuth consumer secret
  PLURK_AUTH_TOKEN     OAuth user access token
  PLURK_AUTH_SECRET    OAuth user access secret

Usage:
  plurk_trend.py [--top N] [--since DURATION] [--min-responses N]
  plurk_trend.py --help

Options:
  --top N              Number of trending plurks to return (default: 10)
  --since DURATION     Time window in Go-style duration (default: 24h)
                       Units: h (hours), m (minutes), s (seconds)
                       Examples: 24h, 6h, 1h30m, 90m, 30s
  --min-responses N    Minimum response count to include (default: 1)
"""

import json
import os
import re
import sys
from datetime import datetime, timezone, timedelta
from email.utils import parsedate_to_datetime

from requests_oauthlib import OAuth1Session

BASE_URL = "https://www.plurk.com"
TIMELINE_API = "/APP/Timeline/getPlurks"


def parse_go_duration(s: str) -> timedelta:
    """Parse a Go-style duration string into a timedelta.

    Supported units: h, m, s. Examples: "24h", "1h30m", "90m", "30s".
    """
    pattern = re.compile(r"(\d+(?:\.\d+)?)(h|m|s)")
    matches = pattern.findall(s)
    if not matches or pattern.sub("", s).strip():
        raise ValueError(
            f"Invalid duration '{s}'. Use Go-style format, e.g. 24h, 1h30m, 90m, 30s"
        )
    total_seconds = 0.0
    unit_seconds = {"h": 3600, "m": 60, "s": 1}
    for value, unit in matches:
        total_seconds += float(value) * unit_seconds[unit]
    return timedelta(seconds=total_seconds)


def to_base36(n: int) -> str:
    digits = "0123456789abcdefghijklmnopqrstuvwxyz"
    if n == 0:
        return "0"
    result = ""
    while n:
        result = digits[n % 36] + result
        n //= 36
    return result


def permalink(plurk_id: int) -> str:
    return f"https://www.plurk.com/p/{to_base36(plurk_id)}"


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


def fetch_timeline_page(session: OAuth1Session, offset: str | None) -> dict:
    params = {"limit": 30}
    if offset:
        params["offset"] = offset
    resp = session.get(f"{BASE_URL}{TIMELINE_API}", params=params)
    if not resp.ok:
        print(f"HTTP {resp.status_code}: {resp.text}", file=sys.stderr)
        sys.exit(1)
    return resp.json()


def parse_posted(posted: str) -> datetime:
    """Parse RFC 2822 UTC timestamp from plurk API into an aware datetime."""
    return parsedate_to_datetime(posted)


def fetch_since(session: OAuth1Session, since: timedelta) -> tuple[list[dict], dict]:
    """Fetch all plurks within the given time window, paginating as needed."""
    cutoff = datetime.now(timezone.utc) - since
    all_plurks: list[dict] = []
    all_users: dict = {}
    offset = None

    while True:
        data = fetch_timeline_page(session, offset)
        plurks = data.get("plurks", [])
        users = data.get("plurk_users", {})
        all_users.update(users)

        if not plurks:
            break

        oldest_in_page = None
        for p in plurks:
            posted = parse_posted(p["posted"])
            if posted >= cutoff:
                all_plurks.append(p)
            if oldest_in_page is None or posted < oldest_in_page:
                oldest_in_page = posted

        # Stop paginating if the oldest plurk on this page is before the cutoff
        if oldest_in_page and oldest_in_page < cutoff:
            break

        # Prepare offset for next page: use the oldest posted time in this batch
        oldest_plurk = min(plurks, key=lambda p: parse_posted(p["posted"]))
        offset = oldest_plurk["posted"]

        # Safety: stop if we got fewer results than requested
        if len(plurks) < 30:
            break

    return all_plurks, all_users


def relative_time(dt: datetime) -> str:
    """Return a human-readable relative time string, e.g. '2 hours ago'."""
    delta = datetime.now(timezone.utc) - dt
    seconds = int(delta.total_seconds())
    if seconds < 60:
        return f"{seconds} second{'s' if seconds != 1 else ''} ago"
    minutes = seconds // 60
    if minutes < 60:
        return f"{minutes} minute{'s' if minutes != 1 else ''} ago"
    hours = minutes // 60
    if hours < 24:
        return f"{hours} hour{'s' if hours != 1 else ''} ago"
    days = hours // 24
    return f"{days} day{'s' if days != 1 else ''} ago"


def format_trending(plurks: list[dict], users: dict, top: int, min_responses: int) -> list[dict]:
    """Filter, sort, and return the top trending plurks."""
    with_responses = [p for p in plurks if p.get("response_count", 0) >= min_responses]
    sorted_plurks = sorted(with_responses, key=lambda p: p["response_count"], reverse=True)
    top_plurks = sorted_plurks[:top]

    result = []
    for p in top_plurks:
        uid = str(p.get("owner_id") or p.get("user_id", ""))
        user = users.get(uid, {})
        display_name = user.get("display_name") or user.get("full_name") or user.get("nick_name", "")
        nick_name = user.get("nick_name", "")

        posted_dt = parse_posted(p["posted"])
        posted_local = posted_dt.astimezone().strftime("%Y-%m-%d %H:%M:%S %Z")
        result.append({
            "plurk_id": p["plurk_id"],
            "permalink": permalink(p["plurk_id"]),
            "posted": f"{posted_local} ({relative_time(posted_dt)})",
            "plurker": f"{display_name} (@{nick_name})" if nick_name else display_name,
            "qualifier": p.get("qualifier", ""),
            "content_raw": p.get("content_raw", ""),
            "content": p.get("content", ""),
            "response_count": p["response_count"],
        })

    return result


def main() -> None:
    top = 10
    since = timedelta(hours=24)
    min_responses = 1
    args = sys.argv[1:]

    if "--help" in args or "-h" in args:
        print(__doc__)
        sys.exit(0)

    it = iter(args)
    for arg in it:
        if arg == "--top":
            try:
                top = int(next(it))
            except (StopIteration, ValueError):
                print("--top requires an integer argument", file=sys.stderr)
                sys.exit(1)
        elif arg == "--since":
            try:
                since = parse_go_duration(next(it))
            except (StopIteration, ValueError) as e:
                print(str(e), file=sys.stderr)
                sys.exit(1)
        elif arg == "--min-responses":
            try:
                min_responses = int(next(it))
                if min_responses < 1:
                    raise ValueError
            except (StopIteration, ValueError):
                print("--min-responses requires a positive integer", file=sys.stderr)
                sys.exit(1)
        else:
            print(f"Unknown option: {arg}", file=sys.stderr)
            sys.exit(1)

    since_hours = since.total_seconds() / 3600
    session = get_session()
    print(f"Fetching timeline for the last {since_hours:g}h...", file=sys.stderr)
    plurks, users = fetch_since(session, since)
    print(f"Found {len(plurks)} plurks in window, filtering...", file=sys.stderr)

    trending = format_trending(plurks, users, top, min_responses)
    print(json.dumps(trending, indent=2))


if __name__ == "__main__":
    main()
