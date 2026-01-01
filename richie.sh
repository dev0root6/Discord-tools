#!/usr/bin/env bash
set -euo pipefail

WEBHOOK_URL="${NEWS_DISCORD}"

HN_API="https://hn.algolia.com/api/v1/search?tags=front_page&hitsPerPage=5"

NEWS=$(curl -s "$HN_API" | jq -r '
  .hits[] |
  "- **" + .title + "**\n  " + (.url // ("https://news.ycombinator.com/item?id=" + (.objectID))) + "\n"
')

PAYLOAD=$(jq -n --arg content "📰 **Richie – Your Tech News Digest**\n\n$NEWS" \
  '{ "content": $content }')

curl -s -X POST \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" \
  "$WEBHOOK_URL"

