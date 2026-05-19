#!/bin/bash

# xadd.sh — Standalone script to add, download, and snap video(s)
# Usage: ./xadd.sh <URL> or ./xadd.sh <file-with-urls>

INPUT="$1"
FILE="videos.json"
SNAPS_DIR="snaps"

if [ -z "$INPUT" ]; then
    echo "Usage: $0 <URL> or $0 <filename>"
    exit 1
fi

# --- Load Environment Variables ---
if [ -f ".env" ]; then
    # Load .env while ignoring comments and empty lines
    export $(grep -v '^#' .env | xargs)
fi

# Configuration Defaults
INTERVAL="${INTERVAL:-3}"
REMOVE_AFTER_SNAP=true

# --- Helper: Confirmation Prompt ---
confirm() {
    local message="$1"
    read -p "$message [y/N]: " choice < /dev/tty
    case "$choice" in
        y|Y ) return 0 ;;
        * ) return 1 ;;
    esac
}

# --- Function: Add Video (Metadata) ---
fn_add() {
    local URL="$1"
    
    if [[ ! "$URL" =~ ^https?:// ]]; then
        echo "Skipping invalid URL: $URL"
        return 1
    fi

    echo "Fetching details for: $URL ..."

    # Fetch metadata using yt-dlp
    local METADATA=$(yt-dlp --quiet --no-warnings --print "%(extractor)s|%(id)s|%(title)s|%(duration_string)s|%(resolution)s|%(ext)s|%(filesize_approx)s" "$URL")

    if [ -z "$METADATA" ]; then
        echo "Error: Could not fetch metadata for $URL"
        return 1
    fi

    IFS='|' read -r EXTRACTOR ID TITLE DURATION RESOLUTION EXT SIZE <<< "$METADATA"

    if [[ "$SIZE" =~ ^[0-9]+$ ]]; then
        HUMAN_SIZE=$(numfmt --to=iec-i --suffix=B "$SIZE" 2>/dev/null || echo "$SIZE")
    else
        HUMAN_SIZE="Unknown"
    fi

    if [ -z "$ID" ] || [ "$ID" == "NA" ]; then
        ID="manual-$(date +%s)"
    fi

    # Check if already exists in JSON
    if [ -f "$FILE" ]; then
        if jq -e ".[] | select(.id == \"$ID\")" "$FILE" > /dev/null 2>&1; then
            echo "Error: Video with ID $ID already exists in $FILE"
            return 1
        fi
    fi

    [[ -z "$EXTRACTOR" || "$EXTRACTOR" == "-" ]] && EXTRACTOR="manual"
    local PREFIXED_TITLE="${EXTRACTOR^^}-${TITLE}"

    # Create JSON entry
    local ROW=$(jq -n \
        --arg id "$ID" \
        --arg url "$URL" \
        --arg title "$PREFIXED_TITLE" \
        --arg dur "$DURATION" \
        --arg res "$RESOLUTION" \
        --arg fmt "$EXT" \
        --arg size "$HUMAN_SIZE" \
        '{id: $id, url: $url, title: $title, duration: $dur, resolution: $res, format: $fmt, size: $size, downloaded: false, snapped: false, snap_count: 0}')

    # Append to file
    if [ ! -f "$FILE" ] || [ ! -s "$FILE" ]; then
        echo "[$ROW]" > "$FILE"
    else
        jq ". += [$ROW]" "$FILE" > temp.json && mv temp.json "$FILE"
    fi

    echo "Added: $TITLE ($DURATION, $HUMAN_SIZE) [ID: $ID]"
    return 0
}

# --- Function: Download Video ---
fn_download() {
    local URL="$1"
    
    # ── Parse MAXSIZE → bytes ──
    local MAXSIZE_BYTES=0
    if [ -n "${MAXSIZE:-}" ]; then
        local MS="${MAXSIZE//\"/}"
        MS="${MS//\'/}"
        local NUM=$(echo "$MS" | sed 's/[^0-9.]//g')
        local UNIT=$(echo "$MS" | sed 's/[0-9.]//g' | tr '[:lower:]' '[:upper:]')

        case "$UNIT" in
            K|KB) FACTOR=1024 ;;
            M|MB) FACTOR=1048576 ;;
            G|GB) FACTOR=1073741824 ;;
            *)    FACTOR=1 ;;
        esac
        MAXSIZE_BYTES=$(awk "BEGIN {printf \"%.0f\", $NUM * $FACTOR}")
    fi

    local row=$(jq -c ".[] | select(.url == \"$URL\")" "$FILE")
    if [ -z "$row" ]; then
        echo "Error: URL not found in $FILE"
        return 1
    fi

    local ID=$(echo "$row" | jq -r '.id')
    local TITLE=$(echo "$row" | jq -r '.title // "Unknown"')
    local OUT_FILE="dl-$ID.mp4"

    # Size check before download
    if [ "$MAXSIZE_BYTES" -gt 0 ]; then
        echo "Checking filesize for $TITLE..."
        local REMOTE_SIZE=$(yt-dlp --quiet --no-warnings --print "%(filesize_approx)s" -f "bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best" "$URL" 2>/dev/null || echo "")
        
        if [ -n "$REMOTE_SIZE" ] && [ "$REMOTE_SIZE" != "NA" ] && [ "$REMOTE_SIZE" != "None" ]; then
            REMOTE_SIZE=$(echo "$REMOTE_SIZE" | cut -d. -f1 | tr -d ' ')
            if [ "$REMOTE_SIZE" -gt "$MAXSIZE_BYTES" ]; then
                local HUMAN=$(numfmt --to=iec-i --suffix=B "$REMOTE_SIZE" 2>/dev/null || echo "${REMOTE_SIZE} bytes")
                local LIMIT=$(numfmt --to=iec-i --suffix=B "$MAXSIZE_BYTES" 2>/dev/null || echo "$MAXSIZE")
                echo "✗ SKIPPED: $TITLE (Size $HUMAN exceeds limit $LIMIT)"
                jq "map(if .id == \"$ID\" then .skip_reason = \"size:$HUMAN>$LIMIT\" else . end)" "$FILE" > temp.json && mv temp.json "$FILE"
                return 1
            fi
        fi
    fi

    echo "Downloading: $URL ..."
    local DL_OPTS=(-f "bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best" -o "$OUT_FILE" --no-part)
    [ -n "${MAXSIZE:-}" ] && DL_OPTS+=(--max-filesize "$MAXSIZE")

    if yt-dlp "${DL_OPTS[@]}" "$URL" && [ -f "$OUT_FILE" ]; then
        echo "✓ Downloaded: $OUT_FILE"
        jq "map(if .id == \"$ID\" then .downloaded = true | del(.skip_reason) else . end)" "$FILE" > temp.json && mv temp.json "$FILE"
        return 0
    else
        echo "✗ Download failed for $URL"
        rm -f "$OUT_FILE" "dl-$ID"* 2>/dev/null
        return 1
    fi
}

# --- Function: Take Snaps ---
fn_snap() {
    local VIDEO_FILE="$1"
    
    if [[ ! "$VIDEO_FILE" =~ ^dl-(.*)\.mp4$ ]]; then
        echo "Error: Invalid video filename format for snapping: $VIDEO_FILE"
        return 1
    fi
    
    local ID="${BASH_REMATCH[1]}"
    local TITLE=$(jq -r ".[] | select(.id == \"$ID\") | .title" "$FILE")
    local OUT_DIR="$SNAPS_DIR/$ID"
    mkdir -p "$OUT_DIR"

    echo "Snapping: $TITLE (Interval: ${INTERVAL}s) ..."

    # First frame
    ffmpeg -y -ss 0 -i "$VIDEO_FILE" -frames:v 1 -q:v 2 "$OUT_DIR/img000.jpg" -hide_banner -loglevel error

    # Interval frames
    ffmpeg -y -i "$VIDEO_FILE" -vf "fps=1/$INTERVAL" -q:v 2 -start_number 1 "$OUT_DIR/img%03d.jpg" -hide_banner -loglevel error

    # Last frame
    local DURATION=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$VIDEO_FILE")
    if [ -n "$DURATION" ]; then
        local LAST_TS=$(echo "$DURATION - 0.1" | bc)
        ffmpeg -y -ss "$LAST_TS" -i "$VIDEO_FILE" -frames:v 1 -q:v 2 "$OUT_DIR/img_last_tmp.jpg" -hide_banner -loglevel error
        
        local LAST_NUM=$(ls "$OUT_DIR"/img[0-9]*.jpg 2>/dev/null | wc -l)
        LAST_NUM=$((LAST_NUM + 1))
        local LAST_FILENAME=$(printf "$OUT_DIR/img%03d.jpg" "$LAST_NUM")
        mv "$OUT_DIR/img_last_tmp.jpg" "$LAST_FILENAME"
    fi

    local SNAP_COUNT=$(ls "$OUT_DIR" | grep -c "img.*.jpg")
    if [ "$SNAP_COUNT" -gt 0 ]; then
        echo "Successfully captured $SNAP_COUNT snaps in $OUT_DIR"
        jq "map(if .id == \"$ID\" then .snapped = true | .snap_count = $SNAP_COUNT else . end)" "$FILE" > temp.json && mv temp.json "$FILE"
        return 0
    else
        echo "Failed to capture snaps for $ID"
        return 1
    fi
}

# --- Function: Update JSON (Final Pass) ---
fn_update() {
    echo "Updating $FILE with snap listings..."
    node << 'EOF'
const fs = require('fs');
const path = require('path');
const JSON_FILE = 'videos.json';
const SNAPS_DIR = 'snaps';

try {
  if (!fs.existsSync(JSON_FILE) || fs.readFileSync(JSON_FILE, 'utf8').trim() === '') {
    fs.writeFileSync(JSON_FILE, '[]');
  }
  const rawData = fs.readFileSync(JSON_FILE, 'utf8');
  let videos = JSON.parse(rawData);

  if (fs.existsSync(SNAPS_DIR)) {
    const mainDirs = fs.readdirSync(SNAPS_DIR);
    videos.forEach(v => {
      if (v && v.id && mainDirs.includes(v.id)) {
        const targetPath = path.join(SNAPS_DIR, v.id);
        const files = fs.readdirSync(targetPath)
          .filter(f => f.toLowerCase().endsWith('.jpg'))
          .sort();
        
        v.snaps = files;
        v.snapped = files.length > 0;
        v.snap_count = files.length;
      } else {
        v.snaps = [];
        v.snapped = false;
        v.snap_count = 0;
      }
    });
    fs.writeFileSync(JSON_FILE, JSON.stringify(videos, null, 2));
    console.log(`✅ Successfully validated metrics and updated ${JSON_FILE}`);
  }
} catch (err) {
  console.error(`❌ Update script failure: ${err.message}`);
}
EOF
}

# --- Main URL Processing Logic ---
process_url() {
    local URL="$1"
    echo ">>> Processing: $URL"

    # 1. Check if URL already exists
    if [ -f "$FILE" ]; then
        if jq -e ".[] | select(.url == \"$URL\")" "$FILE" > /dev/null; then
            echo "Video skipped - $URL already exists in $FILE"
            echo "-------------------"
            return 0
        fi
    fi

    # 2. Add video metadata
    if ! fn_add "$URL"; then
        # Check if it was added anyway (might fail if ID existed but URL was new)
        if ! jq -e ".[] | select(.url == \"$URL\")" "$FILE" > /dev/null; then
            echo "Error: Failed to add video $URL"
            echo "-------------------"
            return 1
        fi
    fi

    # Get ID for filename
    local ID=$(jq -r ".[] | select(.url == \"$URL\") | .id" "$FILE" | tail -n 1)
    local VIDEO_FILE="dl-$ID.mp4"

    # 3. Handle Download
    if [ -f "$VIDEO_FILE" ]; then
        echo "Video already downloaded: $VIDEO_FILE"
        if confirm "Do you want to re-download?"; then
            fn_download "$URL"
        else
            echo "Using existing file for snapping."
        fi
    else
        fn_download "$URL"
    fi

    # 4. Handle Snapping
    if [ -f "$VIDEO_FILE" ]; then
        if fn_snap "$VIDEO_FILE"; then
            if [ "$REMOVE_AFTER_SNAP" = true ]; then
                rm -v "$VIDEO_FILE"
                jq "map(if .id == \"$ID\" then .downloaded = false else . end)" "$FILE" > temp.json && mv temp.json "$FILE"
                echo "Removed $VIDEO_FILE and reset downloaded flag."
            else
                echo "Keeping $VIDEO_FILE"
            fi
        fi
    else
        echo "Video file $VIDEO_FILE not found. Cannot run snapping."
    fi
    echo "-------------------"
}

# --- Execution Entry Point ---
echo "-------------------"

if [ -f "$INPUT" ]; then
    echo "Processing URLs from file: $INPUT"
    # Use FD 3 to avoid stdin conflicts with 'confirm' (read -p) inside the loop
    while IFS= read -r line <&3 || [ -n "$line" ]; do
        line=$(echo "$line" | xargs)
        [[ -z "$line" || "$line" =~ ^# ]] && continue
        process_url "$line"
    done 3< "$INPUT"
else
    process_url "$INPUT"
fi

echo "Batch process complete."
fn_update
