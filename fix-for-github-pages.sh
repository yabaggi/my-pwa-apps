#!/bin/bash
# ============================================================
# fix-for-github-pages.sh
# Fixes all PWA paths for GitHub Pages deployment
# Safe to run multiple times — skips already correct values
#
# Usage: Run from your repo root (e.g. ~/githubreps/my-pwa-apps/)
#   bash fix-for-github-pages.sh
# ============================================================

REPO="my-pwa-apps"
TOTAL_CHANGED=0
TOTAL_SKIPPED=0

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

ok()   { echo -e "  ${GREEN}[✓]${NC} $1"; }
skip() { echo -e "  ${CYAN}[—]${NC} $1"; }
warn() { echo -e "  ${YELLOW}[!]${NC} $1"; }

# ============================================================
fix_app() {
  local folder="$1"
  local changed=0

  echo ""
  echo -e "${BOLD}--- Processing: $folder ---${NC}"

  # ============================================================
  # 1. FIX sw.js
  # ============================================================
  local swfile="$folder/sw.js"
  if [ ! -f "$swfile" ]; then
    warn "sw.js not found — skipping"
  else
    local sw_changed=0

    # Fix urlsToCache — all relative/wrong path variations
    # Relative: "/foldername/" already correct for local, needs /my-pwa-apps/ prefix
    if grep -q "\"/$folder/\"" "$swfile" && ! grep -q "\"/my-pwa-apps/$folder/\"" "$swfile"; then
      sed -i "s|\"/$folder/|\"/my-pwa-apps/$folder/|g" "$swfile"
      sw_changed=1
    fi
    if grep -q "'/$folder/'" "$swfile" && ! grep -q "'/my-pwa-apps/$folder/'" "$swfile"; then
      sed -i "s|'/$folder/|'/my-pwa-apps/$folder/|g" "$swfile"
      sw_changed=1
    fi

    # Fix OFFLINE_URL variations
    if grep -q "OFFLINE_URL" "$swfile" && ! grep -q "/my-pwa-apps/" "$swfile"; then
      sed -i "s|OFFLINE_URL = '/$folder/|OFFLINE_URL = '/my-pwa-apps/$folder/|g" "$swfile"
      sed -i "s|OFFLINE_URL = \"/$folder/|OFFLINE_URL = \"/my-pwa-apps/$folder/|g" "$swfile"
      sed -i "s|OFFLINE_URL = './|OFFLINE_URL = '/my-pwa-apps/$folder/|g" "$swfile"
      sed -i "s|OFFLINE_URL = \"./|OFFLINE_URL = \"/my-pwa-apps/$folder/|g" "$swfile"
      sw_changed=1
    fi

    # Bump cache version only if not already using -gh suffix
    if ! grep -q "\-gh[0-9]*'" "$swfile" && ! grep -q "\-gh[0-9]*\"" "$swfile"; then
      sed -i "s|-v[0-9]*';|-gh1';|g" "$swfile"
      sed -i "s|-v[0-9]*\";|-gh1\";|g" "$swfile"
      sw_changed=1
    fi

    # Remove duplicate urlsToCache entries
    local dupes
    dupes=$(awk '/urlsToCache = \[/,/\];/' "$swfile" | grep -o '"[^"]*"' | sort | uniq -d)
    if [ -n "$dupes" ]; then
      awk '
        BEGIN { in_cache=0 }
        /urlsToCache = \[/ { in_cache=1; print; next }
        /\];/ && in_cache { in_cache=0; print; next }
        in_cache {
          if (!seen[$0]++) print
          next
        }
        { print }
      ' "$swfile" > "$swfile.tmp" && mv "$swfile.tmp" "$swfile"
      sw_changed=1
    fi

    if [ $sw_changed -eq 1 ]; then
      ok "sw.js fixed"
      ((changed++))
    else
      skip "sw.js already correct"
    fi
  fi

  # ============================================================
  # 2. FIX manifest.json
  # ============================================================
  local manifest="$folder/manifest.json"
  if [ ! -f "$manifest" ]; then
    warn "manifest.json not found — skipping"
  else
    local manifest_changed=0

    # Fix start_url — all variations
    # Already correct
    if grep -q "\"start_url\": \"/my-pwa-apps/$folder/\"" "$manifest"; then
      skip "start_url already correct"
    else
      # Absolute without /my-pwa-apps/
      if grep -q "\"start_url\": \"/$folder/\"" "$manifest"; then
        sed -i "s|\"start_url\": \"/$folder/\"|\"start_url\": \"/my-pwa-apps/$folder/\"|g" "$manifest"
        manifest_changed=1
      fi
      # Relative ./
      if grep -q "\"start_url\": \"./\"" "$manifest"; then
        sed -i "s|\"start_url\": \"./\"|\"start_url\": \"/my-pwa-apps/$folder/\"|g" "$manifest"
        manifest_changed=1
      fi
      # Relative ./index.html
      if grep -q "\"start_url\": \"./index.html\"" "$manifest"; then
        sed -i "s|\"start_url\": \"./index.html\"|\"start_url\": \"/my-pwa-apps/$folder/\"|g" "$manifest"
        manifest_changed=1
      fi
      # Bare index.html
      if grep -q "\"start_url\": \"index.html\"" "$manifest"; then
        sed -i "s|\"start_url\": \"index.html\"|\"start_url\": \"/my-pwa-apps/$folder/\"|g" "$manifest"
        manifest_changed=1
      fi
      # Bare /
      if grep -q "\"start_url\": \"/\"" "$manifest"; then
        sed -i "s|\"start_url\": \"/\"|\"start_url\": \"/my-pwa-apps/$folder/\"|g" "$manifest"
        manifest_changed=1
      fi
    fi

    # Fix scope — all variations
    if grep -q "\"scope\": \"/my-pwa-apps/$folder/\"" "$manifest"; then
      skip "scope already correct"
    else
      if grep -q "\"scope\": \"/$folder/\"" "$manifest"; then
        sed -i "s|\"scope\": \"/$folder/\"|\"scope\": \"/my-pwa-apps/$folder/\"|g" "$manifest"
        manifest_changed=1
      fi
      if grep -q "\"scope\": \"./\"" "$manifest"; then
        sed -i "s|\"scope\": \"./\"|\"scope\": \"/my-pwa-apps/$folder/\"|g" "$manifest"
        manifest_changed=1
      fi
      if grep -q "\"scope\": \"/\"" "$manifest"; then
        sed -i "s|\"scope\": \"/\"|\"scope\": \"/my-pwa-apps/$folder/\"|g" "$manifest"
        manifest_changed=1
      fi
    fi

    # Fix icon src paths — all variations
    if grep -q "\"src\": \"/my-pwa-apps/$folder/icons/" "$manifest"; then
      skip "icon paths already correct"
    else
      # Relative: icons/
      sed -i "s|\"src\": \"icons/|\"src\": \"/my-pwa-apps/$folder/icons/|g" "$manifest"
      # Relative: ./icons/
      sed -i "s|\"src\": \"./icons/|\"src\": \"/my-pwa-apps/$folder/icons/|g" "$manifest"
      # Absolute without /my-pwa-apps/
      sed -i "s|\"src\": \"/$folder/icons/|\"src\": \"/my-pwa-apps/$folder/icons/|g" "$manifest"
      manifest_changed=1
    fi

    if [ $manifest_changed -eq 1 ]; then
      ok "manifest.json fixed"
      ((changed++))
    else
      skip "manifest.json already correct"
    fi
  fi

  # ============================================================
  # 3. FIX index.html
  # ============================================================
  local index="$folder/index.html"
  if [ ! -f "$index" ]; then
    warn "index.html not found — skipping"
  else
    local index_changed=0

    # Fix SW registration path — all variations
    if grep -q "register('/my-pwa-apps/$folder/sw.js')" "$index" || \
       grep -q "register(\"/my-pwa-apps/$folder/sw.js\")" "$index"; then
      skip "SW registration path already correct"
    else
      # Bare relative: 'sw.js'
      if grep -q "register('sw.js')" "$index"; then
        sed -i "s|register('sw.js')|register('/my-pwa-apps/$folder/sw.js')|g" "$index"
        index_changed=1
      fi
      if grep -q "register(\"sw.js\")" "$index"; then
        sed -i "s|register(\"sw.js\")|register(\"/my-pwa-apps/$folder/sw.js\")|g" "$index"
        index_changed=1
      fi
      # Relative: './sw.js'
      if grep -q "register('./sw.js')" "$index"; then
        sed -i "s|register('./sw.js')|register('/my-pwa-apps/$folder/sw.js')|g" "$index"
        index_changed=1
      fi
      if grep -q "register(\"./sw.js\")" "$index"; then
        sed -i "s|register(\"./sw.js\")|register(\"/my-pwa-apps/$folder/sw.js\")|g" "$index"
        index_changed=1
      fi
      # Absolute without /my-pwa-apps/
      if grep -q "register('/$folder/sw.js')" "$index"; then
        sed -i "s|register('/$folder/sw.js')|register('/my-pwa-apps/$folder/sw.js')|g" "$index"
        index_changed=1
      fi
      if grep -q "register(\"/$folder/sw.js\")" "$index"; then
        sed -i "s|register(\"/$folder/sw.js\")|register(\"/my-pwa-apps/$folder/sw.js\")|g" "$index"
        index_changed=1
      fi
    fi

    # Fix manifest link — all variations
    if grep -q "href=\"/my-pwa-apps/$folder/manifest.json\"" "$index" || \
       grep -q "href='/my-pwa-apps/$folder/manifest.json'" "$index"; then
      skip "manifest link already correct"
    else
      sed -i "s|href=\"manifest.json\"|href=\"/my-pwa-apps/$folder/manifest.json\"|g" "$index"
      sed -i "s|href='manifest.json'|href='/my-pwa-apps/$folder/manifest.json'|g" "$index"
      sed -i "s|href=\"./manifest.json\"|href=\"/my-pwa-apps/$folder/manifest.json\"|g" "$index"
      sed -i "s|href='./manifest.json'|href='/my-pwa-apps/$folder/manifest.json'|g" "$index"
      sed -i "s|href=\"/$folder/manifest.json\"|href=\"/my-pwa-apps/$folder/manifest.json\"|g" "$index"
      sed -i "s|href='/$folder/manifest.json'|href='/my-pwa-apps/$folder/manifest.json'|g" "$index"
      index_changed=1
    fi

    # Special case: fix Firebase SW paths in prom only
    if [ "$folder" = "prom" ]; then
      local firebase_changed=0
      if grep -q "getRegistration('/prom/firebase" "$index" && \
         ! grep -q "getRegistration('/my-pwa-apps/prom/firebase" "$index"; then
        sed -i "s|getRegistration('/prom/firebase-messaging-sw.js')|getRegistration('/my-pwa-apps/prom/firebase-messaging-sw.js')|g" "$index"
        firebase_changed=1
      fi
      if grep -q "register('/prom/firebase" "$index" && \
         ! grep -q "register('/my-pwa-apps/prom/firebase" "$index"; then
        sed -i "s|register('/prom/firebase-messaging-sw.js')|register('/my-pwa-apps/prom/firebase-messaging-sw.js')|g" "$index"
        firebase_changed=1
      fi
      if grep -q "register('firebase-messaging-sw.js')" "$index"; then
        sed -i "s|register('firebase-messaging-sw.js')|register('/my-pwa-apps/prom/firebase-messaging-sw.js')|g" "$index"
        firebase_changed=1
      fi
      [ $firebase_changed -eq 1 ] && ok "prom Firebase SW path fixed"
      index_changed=$((index_changed + firebase_changed))
    fi

    if [ $index_changed -gt 0 ]; then
      ok "index.html fixed"
      ((changed++))
    else
      skip "index.html already correct"
    fi
  fi

  # Per-app summary
  if [ $changed -gt 0 ]; then
    echo -e "  ${GREEN}→ $changed file(s) updated${NC}"
    ((TOTAL_CHANGED++))
  else
    echo -e "  ${CYAN}→ already correct, nothing changed${NC}"
    ((TOTAL_SKIPPED++))
  fi
}

# ============================================================
# Main — loop all app folders
# ============================================================
echo -e "${BOLD}"
echo "=============================="
echo "  GitHub Pages Path Fixer"
echo "  Repo: $REPO"
echo "=============================="
echo -e "${NC}"

for dir in */; do
  folder="${dir%/}"
  # Skip root-level non-app folders
  [ ! -f "$folder/index.html" ] && continue
  fix_app "$folder"
done

# Final summary
echo ""
echo -e "${BOLD}=============================="
echo "  DONE"
echo "=============================="
echo -e "${NC}"
echo "  Apps updated : $TOTAL_CHANGED"
echo "  Apps skipped : $TOTAL_SKIPPED (already correct)"
echo ""
echo "  Next steps:"
echo "    git add ."
echo "    git commit -m 'fix: update all paths for GitHub Pages'"
echo "    git push"

