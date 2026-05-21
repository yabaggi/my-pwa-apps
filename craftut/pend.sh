#!/bin/bash

echo ".....found in urls.txt not processed yet...."
# diff_urls.sh — List URLs in urls.txt that are not in videos.json

URLS_FILE="urls.txt"
JSON_FILE="videos.json"

if [ ! -f "$URLS_FILE" ]; then
    echo "Error: $URLS_FILE not found."
    exit 1
fi

if [ ! -f "$JSON_FILE" ] || [ ! -s "$JSON_FILE" ]; then
    # If JSON doesn't exist or is empty, print all URLs from urls.txt
    awk '{print $NF}' "$URLS_FILE" | grep "^http"
    exit 0
fi

# Get all existing URLs from videos.json
EXISTING_URLS=$(jq -r '.[].url' "$JSON_FILE")

while IFS= read -r line || [ -n "$line" ]; do
    # Trim line
    line=$(echo "$line" | xargs)
    [[ -z "$line" || "$line" =~ ^# ]] && continue

    # Extract URL (it's the last word on the line)
    URL=$(echo "$line" | awk '{print $NF}')

    # Validate it's a URL
    if [[ "$URL" =~ ^https?:// ]]; then
        # Check if URL exists in the list
        if ! echo "$EXISTING_URLS" | grep -qFx "$URL"; then
            echo "$URL"
        fi
    fi
done < "$URLS_FILE"
echo
echo ".....Pending downloads......"
jq -c '.[] | select(
        .downloaded == false and 
        (.skip_reason == null or .skip_reason == "") and
        .available != false and
        .snapped == false
    )| .id' videos.json
echo
echo ".....Pendin snaps......."
jq -r '.[] | select(
      .downloaded == true and
      .snapped == false) | "\(.id): \(.title)"' videos.json
echo
echo ".....sync with GITHUB status....."
./vsync.sh |grep "✗"
echo
echo ".....videos.json diff...."
diff videos.json ~/githubreps/my-pwa-apps/craftut/videos.json |grep '"id":'
echo
echo ".....diff of ./snaps and GITHUB /snaps ...."
diff -qr ./snaps/ ~/githubreps/my-pwa-apps/craftut/snaps/
