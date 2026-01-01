#!/usr/bin/env bash
set -euo pipefail

WEBHOOK_URL="https://discord.com/api/webhooks/1453306021182308395/rJOo2TNnt28H3h9u1qgWVeZgAg-ZeRUd-JNm_OV9ePg8K3BP2ARvhTzrZnOPJ8JL3ZEV"

HN_API="https://hn.algolia.com/api/v1/search?tags=front_page&hitsPerPage=5"

NEWS=$(curl -s "$HN_API" | jq -r '
  .hits[] |
  "- **" + .title + "**\n  " + (.url // ("https://news.ycombinator.com/item?id=" + (.objectID))) + "\n"
')

PAYLOAD=$(jq -n --arg content "📰 **Top Tech News – Today**\n\n$NEWS" \
  '{ "content": $content }')

curl -s -X POST \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" \
  "$WEBHOOK_URL"

