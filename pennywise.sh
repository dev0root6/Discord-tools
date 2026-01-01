#!/usr/bin/env bash
set -euo pipefail

WEBHOOK_URL="${MEMES_DISCORD}"
USER_AGENT="dev0root-reddit-bot/3.0 (github.com/dev0root)"

SUBREDDITS=(
  aimemes
  cybersecuritymemes
  techmemes
  ProgrammerHumor
  ITMemes
  codingmemes
)

SUB="${SUBREDDITS[$RANDOM % ${#SUBREDDITS[@]}]}"
URL="https://www.reddit.com/r/${SUB}/new.json?limit=100"

TMP_JSON="$(mktemp)"
trap 'rm -f "$TMP_JSON"' EXIT

# ---------- FETCH (no jq yet) ----------
curl -s \
  -H "User-Agent: $USER_AGENT" \
  -H "Accept: application/json" \
  "$URL" > "$TMP_JSON"

# ---------- HARD VALIDATION ----------
if ! jq empty "$TMP_JSON" >/dev/null 2>&1; then
  echo "Reddit returned non-JSON (rate-limit / HTML). Skipping run."
  head -n 5 "$TMP_JSON" || true
  exit 0
fi

# ---------- EXTRACT MEDIA ----------
MEDIA=$(jq -c '
  .data.children[]
  | .data
  | select(.over_18 == false)
  | {
      id: .id,
      title: .title,
      subreddit: .subreddit,
      permalink: ("https://reddit.com" + .permalink),
      type: (if .is_video then "video" else "image" end),
      media:
        (
          if .is_video and .media.reddit_video.fallback_url then
            .media.reddit_video.fallback_url
          elif .is_gallery and .media_metadata then
            .media_metadata | to_entries[0].value.s.u
          else
            (.url_overridden_by_dest
             // .preview.images[0].source.url
             // .url)
          end
        )
    }
  | select(.media != null)
' "$TMP_JSON")

COUNT=$(printf '%s\n' "$MEDIA" | wc -l)

if [ "$COUNT" -eq 0 ]; then
  echo "No media found in r/$SUB"
  exit 0
fi

INDEX=$((RANDOM % COUNT))
SELECTED=$(printf '%s\n' "$MEDIA" | sed -n "$((INDEX + 1))p")

TITLE=$(jq -r '.title' <<<"$SELECTED")
TYPE=$(jq -r '.type' <<<"$SELECTED")
MEDIA_URL=$(jq -r '.media' <<<"$SELECTED" | sed 's/&amp;/\&/g')
LINK=$(jq -r '.permalink' <<<"$SELECTED")
SRC=$(jq -r '.subreddit' <<<"$SELECTED")

# ---------- BUILD PAYLOAD ----------
if [ "$TYPE" = "image" ]; then
  PAYLOAD=$(jq -n \
    --arg title "$TITLE" \
    --arg image "$MEDIA_URL" \
    --arg link "$LINK" \
    --arg sub "$SRC" \
    '{
      content: "🤡 **Pennywise — The Mememing Clown**",
      embeds: [
        {
          title: $title,
          url: $link,
          image: { url: $image },
          footer: { text: ("Source: r/" + $sub) }
        }
      ]
    }')
else
  PAYLOAD=$(jq -n \
    --arg title "$TITLE" \
    --arg video "$MEDIA_URL" \
    --arg link "$LINK" \
    --arg sub "$SRC" \
    '{
      content: "🎥 **Pennywise — The Mememing Clown (Video)**\n" + $video,
      embeds: [
        {
          title: $title,
          url: $link,
          footer: { text: ("Source: r/" + $sub) }
        }
      ]
    }')
fi

# ---------- SEND ----------
curl -s -X POST \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" \
  "$WEBHOOK_URL"
