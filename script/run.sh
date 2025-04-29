#!/bin/sh

source .env

echo "[INFO] running scripts ..."

echo "[INFO] getting pocket articles ..."
sh get-favorite-pocket-articles.sh

echo "[INFO] generating pocket item list summary ..."
sh generate-pocket-item-list-summary.sh

echo "[INFO] generating archive markdown file (only unresolved items) from pocket item list ..."
sh generate-unresolved-pocket-item-archive.sh

echo "[INFO] scripts completed."