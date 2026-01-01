#!/usr/bin/env bash
set -euo pipefail

WEBHOOK_URL="${MEMES_DISCORD}"
USER_AGENT="dev0root-reddit-bot/2.1 (github.com/dev0root)"

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

# ---------- FETCH ----------
JSON=$(curl -s \
  -H "User-Agent: $USER_AGENT" \
  -H "Accept: application/json" \
  "$URL")

# ---------- VALIDATE JSON ----------
if ! echo "$JSON" | jq empty >/dev/null 2>&1; then
  echo "Reddit returned non-JSON response (rate-limit / HTML)"
  exit 0
fi

# ---------- EXTRACT MEDIA ----------
MEDIA=$(echo "$JSON" | jq -c '
  .data.children[]
  | .data
  | select(.over_18 == false)
  | {
      id: .id,
      title: .title,
      subreddit: .subreddit,
      permalink: ("https://reddit.com" + .permalink),

      type:
        (if .is_video == true then "video" else "image" end),

      media:
        (
          if .is_video == true and .media.reddit_video.fallback_url then
            .media.reddit_video.fallback_url
          elif .is_gallery == true and .media_metadata then
            .media_metadata | to_entries[0].value.s.u
          else
            (.url_overridden_by_dest
             // .preview.images[0].source.url
             // .url)
          end
        )
    }
  | select(.media != null)
')

COUNT=$(echo "$MEDIA" | wc -l)

if [ "$COUNT" -eq 0 ]; then
  echo "No media found in r/$SUB"
  exit 0
fi

# ---------- RANDOM PICK ----------
INDEX=$((RANDOM % COUNT))
SELECTED=$(echo "$MEDIA" | sed -n "$((INDEX + 1))p")

TITLE=$(echo "$SELECTED" | jq -r '.title')
TYPE=$(echo "$SELECTED" | jq -r '.type')
MEDIA_URL=$(echo "$SELECTED" | jq -r '.media' | sed 's/&amp;/\&/g')
LINK=$(echo "$SELECTED" | jq -r '.permalink')
SRC=$(echo "$SELECTED" | jq -r '.subreddit')

# ---------- DISCORD PAYLOAD ----------
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
