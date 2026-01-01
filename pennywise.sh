#!/usr/bin/env bash
set -euo pipefail

WEBHOOK_URL="${MEMES_DISCORD}"
USER_AGENT="dev0root-classic-meme/1.0 (github.com/dev0root)"

SUBREDDITS=(
  techmemes
  ProgrammerHumor
  ITMemes
  codingmemes
  linuxmemes
  aimemes
)

SUB="${SUBREDDITS[$RANDOM % ${#SUBREDDITS[@]}]}"

URL="https://old.reddit.com/r/${SUB}/hot.json?limit=50&raw_json=1"

# -------- FETCH --------
JSON=$(curl -s \
  -H "User-Agent: $USER_AGENT" \
  -H "Accept: application/json" \
  "$URL")

# -------- VALIDATE JSON --------
if ! echo "$JSON" | jq empty >/dev/null 2>&1; then
  echo "Reddit returned non-JSON, skipping"
  exit 0
fi

# -------- EXTRACT IMAGE MEMES ONLY --------
MEMES=$(echo "$JSON" | jq -c '
  .data.children[]
  | .data
  | select(.over_18 == false)
  | select(.post_hint == "image")
  | select(.url | test("\\.(jpg|jpeg|png|webp)$"))
  | {
      title: .title,
      image: .url,
      permalink: ("https://reddit.com" + .permalink),
      subreddit: .subreddit
    }
')

COUNT=$(echo "$MEMES" | wc -l)

if [ "$COUNT" -eq 0 ]; then
  echo "No image memes found in r/$SUB"
  exit 0
fi

# -------- RANDOM PICK --------
INDEX=$((RANDOM % COUNT))
SELECTED=$(echo "$MEMES" | sed -n "$((INDEX + 1))p")

TITLE=$(echo "$SELECTED" | jq -r '.title')
IMAGE=$(echo "$SELECTED" | jq -r '.image')
LINK=$(echo "$SELECTED" | jq -r '.permalink')
SRC=$(echo "$SELECTED" | jq -r '.subreddit')

# -------- DISCORD PAYLOAD --------
PAYLOAD=$(jq -n \
  --arg title "$TITLE" \
  --arg image "$IMAGE" \
  --arg link "$LINK" \
  --arg sub "$SRC" \
  '{
    content: "🤡 **Pennywise — Classic Tech Meme**",
    embeds: [
      {
        title: $title,
        url: $link,
        image: { url: $image },
        footer: { text: ("Source: r/" + $sub) }
      }
    ]
  }')

# -------- SEND --------
curl -s -X POST \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" \
  "$WEBHOOK_URL"
