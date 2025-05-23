#!/bin/sh

set -e

source .env

# Authz
## response is in format like `code=xxxx`
POCKET_AUTH_CODE=$(curl -s "https://getpocket.com/v3/oauth/request?consumer_key=${POCKET_CONSUMER_KEY}&redirect_uri=https://example.com" | awk -F'[=]' '{print $2}')
if [ -z "$POCKET_AUTH_CODE" ]; then
  echo "[ERROR] Failed to retrieve auth code" >&2
  exit 1
fi
echo "[INFO] your auth code: $POCKET_AUTH_CODE"

open "https://getpocket.com/auth/authorize?request_token=${POCKET_AUTH_CODE}&redirect_uri=https://example.com"

## You can issue an access token if you authorize it with the above url within a certain time. If you exceed the time, you will get 403 with "Get access key".
sleep 5

## getting access key
## response is in format like `access_token=xxxx&username=xxxx`
POCKET_ACCESS_KEY=$(curl "https://getpocket.com/v3/oauth/authorize?consumer_key=${POCKET_CONSUMER_KEY}&code=${POCKET_AUTH_CODE}" | awk -F'[=&]' '{print $2}')
if [ -z "$POCKET_ACCESS_KEY" ]; then
  echo "[ERROR] Failed to retrieve access key" >&2
  exit 1
fi
echo "[INFO] your access key: $POCKET_ACCESS_KEY"

# Display a monthly count of the number of articles read
## 5000 article seems to be the limit for 1 API call (cannot find in document)
## when reached to 5000, use count and offset to retrieve more data.
## see also https://getpocket.com/developer/docs/v3/retrieve
OFFSET=0
COUNT=30
HAS_MORE_ITEM=true
ALL_ITEMS="[]"

while [ "$HAS_MORE_ITEM" = true ]; do
  echo "[INFO] retrieving... (COUNT, OFFSET)=(${COUNT}, ${OFFSET})"

  RESPONSE=$(curl -s -X POST 'https://getpocket.com/v3/get' \
    -d consumer_key="${POCKET_CONSUMER_KEY}" \
    -d access_token="${POCKET_ACCESS_KEY}" \
    -d favorite='1' \
    -d total='1' \
    -d count="${COUNT}" \
    -d offset="${OFFSET}" \
    -d state='archive' \
    -d detailType='simple')

    if [ $? -ne 0 ] || [ -z "$RESPONSE" ]; then
      echo "[ERROR] Failed to retrieve articles" >&2
      exit 1
    fi

  CLEAN_RESPONSE=$(echo "$RESPONSE" | tr -d '[:cntrl:]')
  ITEMS=$(echo "$CLEAN_RESPONSE" |
    jq '.list |
      to_entries |
      map({
        "item_id": .value.item_id,
        "resolved_url": .value.resolved_url,
        "resolved_title": .value.resolved_title,
        "time_read": (.value.time_read | tonumber | strftime("%Y-%m-%d"))
      })')
  ALL_ITEMS=$(echo "$ALL_ITEMS" "$ITEMS" | jq -s 'add')

  # `total` is in the response, but it is not always accessible.
  # for some reason, it turns out be null in some conditions.
  ITEMS_COUNT=$(echo "$CLEAN_RESPONSE" | jq '.list | length')
  if [ "$ITEMS_COUNT" -lt "$COUNT" ]; then
    HAS_MORE_ITEM=false
  else
    OFFSET=$((OFFSET + COUNT))
  fi
done

echo "$ALL_ITEMS" | jq 'sort_by(.time_read) | reverse' > bin/pocket_articles.json