#!/bin/sh

source .env

ARTICLES_FILE="bin/pocket_articles.json"
RESOLVED_ITEM_JSON="${RESOLVED_ITEM_JSON_PATH}"

ARTICLE_COUNT=$(jq 'length' "${ARTICLES_FILE}")
RESOLVED_ITEM_COUNT=$(jq '.resolved_item_ids | length' "${RESOLVED_ITEM_JSON}")
UNRESOLVED_ITEM_COUNT=$((ARTICLE_COUNT - RESOLVED_ITEM_COUNT))

UNRESOLVED_IDS=$(jq -r --slurpfile resolved "$RESOLVED_ITEM_JSON" '
  map(select(.item_id as $id | $resolved[0].resolved_item_ids | index($id) | not).item_id) | .[]
' "$ARTICLES_FILE")

echo "[INFO] unresolved articles ${UNRESOLVED_ITEM_COUNT} found (total articles: ${ARTICLE_COUNT})"
echo "[INFO] unresolved ids are"
echo "$UNRESOLVED_IDS"

for ITEM_ID in $UNRESOLVED_IDS; do
  ITEM=$(jq -r --arg id "$ITEM_ID" '
    map(select(.item_id == $id)) | .[0] |
    if .resolved_title | test("^https?://") then
      {title: "title-unresolved", url: .resolved_url}
    else
      {title: .resolved_title, url: .resolved_url}
    end
  ' "$ARTICLES_FILE")

  # convert `/` to `-` since it is not allowed in filename
  TITLE=$(echo "$ITEM" | jq -r '.title' | sed 's/\//-/g')
  URL=$(echo "$ITEM" | jq -r '.url')

  CONTENT=$(trafilatura --markdown --formatting --with-metadata -u "$URL")
  FILENAME="${OUTPUT_FAVORITE_ITEM_ARCHIVE_DIR}/$(echo "${TITLE}-${ITEM_ID}").md"

  echo "$CONTENT" > "$FILENAME"

  echo "[INFO] file created: $FILENAME"
done

# update the resolved_item_ids in the JSON file
ITEM_IDS=$(jq '[.[] | .item_id]' "${ARTICLES_FILE}")
UPDATED_RESOLVED_JSON=$(jq --argjson ids "$ITEM_IDS" '.resolved_item_ids = $ids' "$RESOLVED_ITEM_JSON")
echo "$UPDATED_RESOLVED_JSON" > "$RESOLVED_ITEM_JSON"

echo "[INFO] updated ${RESOLVED_ITEM_JSON}"

