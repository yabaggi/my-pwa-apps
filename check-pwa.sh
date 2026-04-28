#!/bin/bash
# ============================================================
# check-pwa.sh — PWA Configuration Checker
# Usage:
#   Check one app:  bash check-pwa.sh prom
#   Check all apps: bash check-pwa.sh --all
# Run from: your pwaApps or my-pwa-apps root folder
# ============================================================

PASS=0
FAIL=0
WARN=0

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

pass() { echo -e "  ${GREEN}[✓]${NC} $1"; ((PASS++)); return 0; }
fail() { echo -e "  ${RED}[✗]${NC} $1"; ((FAIL++)); return 0; }
warn() { echo -e "  ${YELLOW}[!]${NC} $1"; ((WARN++)); return 0; }
info() { echo -e "  ${CYAN}[-]${NC} $1"; return 0; }

# ============================================================
check_app() {
  local folder="$1"
  PASS=0; FAIL=0; WARN=0

  echo ""
  echo -e "${BOLD}=============================="
  echo -e "  Checking: $folder"
  echo -e "==============================${NC}"

  # ── File existence ──────────────────────────────────────
  echo -e "\n${CYAN}[ Files ]${NC}"

  if [ -f "$folder/index.html" ];    then pass "index.html exists";    else fail "index.html MISSING"; fi
  if [ -f "$folder/manifest.json" ]; then pass "manifest.json exists"; else fail "manifest.json MISSING"; fi
  if [ -f "$folder/sw.js" ];         then pass "sw.js exists";         else fail "sw.js MISSING"; fi
  if [ -f "$folder/offline.html" ];  then pass "offline.html exists";  else warn "offline.html missing (optional)"; fi
  if [ -d "$folder/icons" ];         then pass "icons/ folder exists"; else warn "icons/ folder missing"; fi

  # ── index.html checks ───────────────────────────────────
  echo -e "\n${CYAN}[ index.html ]${NC}"

  if [ -f "$folder/index.html" ]; then

    # Manifest link
    if grep -q "manifest.json" "$folder/index.html"; then
      MANIFEST_LINK=$(grep -o "href=['\"][^'\"]*manifest.json['\"]" "$folder/index.html" | head -1)
      pass "manifest linked → $MANIFEST_LINK"
      if echo "$MANIFEST_LINK" | grep -q "^href=['\"]\/"; then
        pass "manifest link is absolute path"
      else
        fail "manifest link is relative — will break on GitHub Pages"
      fi
    else
      fail "manifest.json not linked in <head>"
    fi

    # SW registration
    if grep -q "serviceWorker.register" "$folder/index.html"; then
      SW_REG=$(grep -o "register(['\"][^'\"]*['\"])" "$folder/index.html" | head -1)
      pass "SW registration found → $SW_REG"

      if echo "$SW_REG" | grep -qE "register\(['\"]sw\.js['\"]"; then
        fail "SW registered with bare 'sw.js' — must be absolute path"
      elif echo "$SW_REG" | grep -qE "register\(['\"]\.\/sw\.js['\"]"; then
        fail "SW registered with relative './sw.js' — must be absolute path"
      else
        pass "SW path is absolute"
      fi

      if echo "$SW_REG" | grep -q "$folder"; then
        pass "SW path contains /$folder/"
      else
        fail "SW path does not contain /$folder/ — wrong scope"
      fi

    else
      fail "serviceWorker.register() not found — PWA will not work offline"
    fi

    # Viewport meta
    if grep -q "viewport" "$folder/index.html"; then
      pass "viewport meta tag present"
    else
      warn "viewport meta tag missing"
    fi

    # Theme color meta
    if grep -q "theme-color" "$folder/index.html"; then
      THEME=$(grep -o "content=['\"]#[^'\"]*['\"]" "$folder/index.html" | head -1)
      pass "theme-color meta present → $THEME"
    else
      warn "theme-color meta missing"
    fi

    # Apple PWA meta
    if grep -q "apple-mobile-web-app" "$folder/index.html"; then
      pass "Apple PWA meta present"
    else
      warn "Apple PWA meta missing (optional but recommended)"
    fi

    # Apple touch icon
    if grep -q "apple-touch-icon" "$folder/index.html"; then
      pass "Apple touch icon linked"
    else
      warn "Apple touch icon missing (optional)"
    fi

  fi

  # ── manifest.json checks ────────────────────────────────
  echo -e "\n${CYAN}[ manifest.json ]${NC}"

  if [ -f "$folder/manifest.json" ]; then

    # name
    if grep -q '"name"' "$folder/manifest.json"; then
      NAME=$(grep -o '"name"[^,]*' "$folder/manifest.json" | head -1)
      pass "name present → $NAME"
    else
      fail "name missing — required for install prompt"
    fi

    # short_name
    if grep -q '"short_name"' "$folder/manifest.json"; then
      SHORT=$(grep -o '"short_name"[^,]*' "$folder/manifest.json" | head -1)
      pass "short_name present → $SHORT"
    else
      warn "short_name missing (recommended)"
    fi

    # description
    if grep -q '"description"' "$folder/manifest.json"; then
      pass "description present"
    else
      warn "description missing (recommended)"
    fi

    # start_url
    if grep -q '"start_url"' "$folder/manifest.json"; then
      START_URL=$(grep -o '"start_url"[^,]*' "$folder/manifest.json" | head -1)
      pass "start_url found → $START_URL"
      if echo "$START_URL" | grep -qE '"start_url":\s*"\./|"start_url":\s*"index\.html|"start_url":\s*"/"'; then
        fail "start_url is relative or bare '/' — will break on GitHub Pages"
      elif echo "$START_URL" | grep -q "/$folder/"; then
        pass "start_url contains /$folder/"
      else
        fail "start_url missing /$folder/ — wrong path"
      fi
    else
      fail "start_url missing — required for install prompt"
    fi

    # scope
    if grep -q '"scope"' "$folder/manifest.json"; then
      SCOPE=$(grep -o '"scope"[^,]*' "$folder/manifest.json" | head -1)
      pass "scope found → $SCOPE"
      if echo "$SCOPE" | grep -qE '"scope":\s*"\./|"scope":\s*"/"'; then
        fail "scope is relative or bare '/' — will break on GitHub Pages"
      elif echo "$SCOPE" | grep -q "/$folder/"; then
        pass "scope contains /$folder/"
      else
        fail "scope missing /$folder/ — wrong path"
      fi
    else
      warn "scope missing (recommended)"
    fi

    # display — critical for install prompt
    echo -e "\n${CYAN}[ manifest.json — Display & Appearance ]${NC}"

    if grep -q '"display"' "$folder/manifest.json"; then
      DISPLAY=$(grep -o '"display"[^,]*' "$folder/manifest.json" | head -1)
      pass "display found → $DISPLAY"
      if echo "$DISPLAY" | grep -q "standalone"; then
        pass "display is 'standalone' — install prompt supported ✓"
      elif echo "$DISPLAY" | grep -q "fullscreen"; then
        pass "display is 'fullscreen' — install prompt supported ✓"
      elif echo "$DISPLAY" | grep -q "minimal-ui"; then
        warn "display is 'minimal-ui' — install prompt may not appear on all devices"
      elif echo "$DISPLAY" | grep -q "browser"; then
        fail "display is 'browser' — install prompt will NOT appear"
      fi
    else
      fail "display missing — install prompt requires 'standalone' or 'fullscreen'"
    fi

    # orientation
    if grep -q '"orientation"' "$folder/manifest.json"; then
      ORI=$(grep -o '"orientation"[^,]*' "$folder/manifest.json" | head -1)
      pass "orientation present → $ORI"
    else
      warn "orientation missing (optional)"
    fi

    # theme_color
    if grep -q '"theme_color"' "$folder/manifest.json"; then
      TC=$(grep -o '"theme_color"[^,]*' "$folder/manifest.json" | head -1)
      pass "theme_color present → $TC"
    else
      warn "theme_color missing (recommended)"
    fi

    # background_color
    if grep -q '"background_color"' "$folder/manifest.json"; then
      BC=$(grep -o '"background_color"[^,]*' "$folder/manifest.json" | head -1)
      pass "background_color present → $BC"
    else
      warn "background_color missing (recommended for splash screen)"
    fi

    # ── Icons ──────────────────────────────────────────────
    echo -e "\n${CYAN}[ manifest.json — Icons ]${NC}"

    if grep -q '"icons"' "$folder/manifest.json"; then
      ICON_COUNT=$(grep -c '"src"' "$folder/manifest.json")
      pass "icons array present ($ICON_COUNT icons defined)"

      # Required sizes for install prompt
      for size in "192x192" "512x512"; do
        if grep -q "\"$size\"" "$folder/manifest.json"; then
          pass "icon ${size} present — required for install prompt ✓"
        else
          fail "icon ${size} MISSING — Chrome will NOT show install prompt"
        fi
      done

      # Recommended sizes
      for size in "72x72" "96x96" "128x128" "144x144" "152x152" "384x384"; do
        if grep -q "\"$size\"" "$folder/manifest.json"; then
          pass "icon ${size} present"
        else
          warn "icon ${size} missing (optional)"
        fi
      done

      # Maskable
      if grep -q "maskable" "$folder/manifest.json"; then
        pass "maskable icon purpose defined — adaptive icons supported"
      else
        warn "no maskable icon — adaptive icons won't work on Android"
      fi

      # Icon paths absolute
      FIRST_ICON=$(grep -o '"src": "[^"]*"' "$folder/manifest.json" | head -1)
      if echo "$FIRST_ICON" | grep -q '"src": "/'; then
        pass "icon paths are absolute → $FIRST_ICON"
      else
        fail "icon paths are relative → $FIRST_ICON — will break on GitHub Pages"
      fi

      # Icon files actually exist on disk
      while IFS= read -r icon_src; do
        local_path=$(echo "$icon_src" | sed "s|.*/my-pwa-apps/$folder/||" | sed "s|.*/$folder/||" | tr -d '"')
        if [ -f "$folder/$local_path" ]; then
          pass "icon file exists: $local_path"
        else
          fail "icon file MISSING on disk: $local_path — cache.addAll() will fail"
        fi
      done < <(grep -o '"src": "[^"]*"' "$folder/manifest.json" | grep -o '"[^"]*icons[^"]*"' | tr -d '"')

    else
      fail "icons array missing — required for install prompt"
    fi

  fi

  # ── sw.js checks ────────────────────────────────────────
  echo -e "\n${CYAN}[ sw.js ]${NC}"

  if [ -f "$folder/sw.js" ]; then

    # CACHE_NAME
    if grep -q "CACHE_NAME" "$folder/sw.js"; then
      CACHE=$(grep -o "CACHE_NAME = '[^']*'" "$folder/sw.js" | head -1)
      pass "CACHE_NAME found → $CACHE"
    else
      fail "CACHE_NAME missing"
    fi

    # urlsToCache
    if grep -q "urlsToCache" "$folder/sw.js"; then
      URL_COUNT=$(grep -c "/$folder/" "$folder/sw.js")
      pass "urlsToCache found ($URL_COUNT entries with /$folder/)"

      if awk '/urlsToCache/,/\]/' "$folder/sw.js" | grep -qE '"[[:space:]]*/[[:space:]]"'; then
        fail "urlsToCache contains bare '/' — should be '/$folder/'"
      else
        pass "No bare '/' in urlsToCache"
      fi

      if awk '/urlsToCache/,/\]/' "$folder/sw.js" | grep -qE '"\./'; then
        fail "urlsToCache contains relative './' paths — use absolute paths"
      else
        pass "No relative './' paths in urlsToCache"
      fi

      DUPES=$(awk '/urlsToCache = \[/,/\];/' "$folder/sw.js" | grep -o '"[^"]*"' | sort | uniq -d)
      if [ -n "$DUPES" ]; then
        warn "Duplicate cache entries: $DUPES"
      else
        pass "No duplicate cache entries"
      fi

    else
      fail "urlsToCache missing"
    fi

    # Event handlers
    if grep -q "addEventListener('install'\|addEventListener(\"install\"" "$folder/sw.js"; then
      pass "install event handler present"
    else
      fail "install event handler missing"
    fi

    if grep -q "addEventListener('activate'\|addEventListener(\"activate\"" "$folder/sw.js"; then
      pass "activate event handler present"
    else
      fail "activate event handler missing"
    fi

    if grep -q "addEventListener('fetch'\|addEventListener(\"fetch\"" "$folder/sw.js"; then
      pass "fetch event handler present"
    else
      fail "fetch event handler MISSING — offline will NOT work"
    fi

    # respondWith — critical
    if grep -q "respondWith" "$folder/sw.js"; then
      pass "respondWith() present — requests will be intercepted"
    else
      fail "respondWith() MISSING — SW won't serve cached content offline"
    fi

    # skipWaiting
    if grep -q "skipWaiting" "$folder/sw.js"; then
      pass "skipWaiting() present — activates immediately on install"
    else
      warn "skipWaiting() missing — requires tab close/reopen to activate"
    fi

    # clients.claim
    if grep -q "clients.claim" "$folder/sw.js"; then
      pass "clients.claim() present — controls page immediately after activation"
    else
      warn "clients.claim() missing — SW won't control current tab until reload"
    fi

    # Old cache cleanup
    if grep -q "caches.delete" "$folder/sw.js"; then
      pass "old cache cleanup present in activate handler"
    else
      warn "no old cache cleanup — stale caches may accumulate over time"
    fi

    # OFFLINE_URL
    if grep -q "OFFLINE_URL" "$folder/sw.js"; then
      OFFLINE=$(grep -o "OFFLINE_URL = '[^']*'" "$folder/sw.js" | head -1)
      pass "OFFLINE_URL defined → $OFFLINE"
      if echo "$OFFLINE" | grep -q "/$folder/"; then
        pass "OFFLINE_URL contains /$folder/"
      else
        fail "OFFLINE_URL missing /$folder/ — offline fallback page won't load"
      fi
    else
      warn "OFFLINE_URL not defined (no offline fallback page)"
    fi

    # Cache strategy
    if grep -q "cachedResponse || fetchPromise\|stale-while-revalidate" "$folder/sw.js"; then
      info "Cache strategy detected: stale-while-revalidate"
    elif grep -q "fetch(event.request).catch\|network.first\|network-first" "$folder/sw.js"; then
      info "Cache strategy detected: network-first"
    elif grep -q "caches.match.*return r\|cache.first\|cache-first" "$folder/sw.js"; then
      info "Cache strategy detected: cache-first"
    else
      warn "Cache strategy: could not detect — verify fetch handler logic"
    fi

  fi

  # ── Install Prompt Readiness ─────────────────────────────
  echo -e "\n${CYAN}[ Install Prompt Readiness ]${NC}"

  local install_ready=1
  local install_issues=()

  if [ ! -f "$folder/manifest.json" ]; then
    install_issues+=("manifest.json missing")
    install_ready=0
  else
    grep -q '"name"' "$folder/manifest.json"     || { install_issues+=("name missing in manifest"); install_ready=0; }
    grep -q '"start_url"' "$folder/manifest.json" || { install_issues+=("start_url missing"); install_ready=0; }
    grep -q '"192x192"' "$folder/manifest.json"   || { install_issues+=("192x192 icon missing"); install_ready=0; }
    grep -q '"512x512"' "$folder/manifest.json"   || { install_issues+=("512x512 icon missing"); install_ready=0; }
    grep -q "standalone\|fullscreen" "$folder/manifest.json" || { install_issues+=("display must be standalone or fullscreen"); install_ready=0; }
  fi

  if [ ! -f "$folder/sw.js" ]; then
    install_issues+=("sw.js missing")
    install_ready=0
  else
    grep -q "addEventListener('fetch'\|addEventListener(\"fetch\"" "$folder/sw.js" || { install_issues+=("fetch handler missing"); install_ready=0; }
    grep -q "respondWith" "$folder/sw.js" || { install_issues+=("respondWith missing"); install_ready=0; }
  fi

  if [ -f "$folder/index.html" ]; then
    grep -q "serviceWorker.register" "$folder/index.html" || { install_issues+=("SW not registered"); install_ready=0; }
    grep -q "manifest.json" "$folder/index.html"          || { install_issues+=("manifest not linked"); install_ready=0; }
  fi

  if [ $install_ready -eq 1 ]; then
    echo -e "  ${GREEN}${BOLD}✓ Meets all Chrome install prompt criteria${NC}"
  else
    echo -e "  ${RED}${BOLD}✗ Will NOT show install prompt:${NC}"
    for issue in "${install_issues[@]}"; do
      echo -e "    ${RED}→ $issue${NC}"
    done
  fi

  # ── Overall Summary ──────────────────────────────────────
  echo ""
  echo -e "${BOLD}------------------------------"
  echo -e "  Pass: ${GREEN}$PASS${BOLD}  Fail: ${RED}$FAIL${BOLD}  Warn: ${YELLOW}$WARN${NC}"
  if [ $FAIL -eq 0 ] && [ $WARN -eq 0 ]; then
    echo -e "  ${GREEN}Perfect — no issues found!${NC}"
  elif [ $FAIL -eq 0 ]; then
    echo -e "  ${YELLOW}Good — no critical issues, $WARN warning(s) to review${NC}"
  else
    echo -e "  ${RED}$FAIL critical issue(s) need fixing${NC}"
  fi
  echo -e "${BOLD}------------------------------${NC}"
}

# ============================================================
# Entry point
# ============================================================

if [ "$1" = "--all" ]; then
  TOTAL_PASS=0; TOTAL_FAIL=0; TOTAL_WARN=0; APP_COUNT=0
  FAILED_APPS=()
  PASSED_APPS=()

  for dir in */; do
    folder="${dir%/}"
    [ ! -f "$folder/index.html" ] && continue
    check_app "$folder"
    ((TOTAL_PASS+=PASS))
    ((TOTAL_FAIL+=FAIL))
    ((TOTAL_WARN+=WARN))
    ((APP_COUNT++))
    if [ $FAIL -gt 0 ]; then
      FAILED_APPS+=("$folder ($FAIL fails)")
    else
      PASSED_APPS+=("$folder")
    fi
  done

  echo ""
  echo -e "${BOLD}=============================="
  echo -e "  FINAL SUMMARY — $APP_COUNT Apps"
  echo -e "=============================="
  echo -e "  ${GREEN}Total Pass : $TOTAL_PASS${NC}"
  echo -e "  ${RED}Total Fail : $TOTAL_FAIL${NC}"
  echo -e "  ${YELLOW}Total Warn : $TOTAL_WARN${NC}"

  if [ ${#PASSED_APPS[@]} -gt 0 ]; then
    echo ""
    echo -e "  ${GREEN}Apps passing:${NC}"
    for app in "${PASSED_APPS[@]}"; do
      echo -e "    ${GREEN}✓ $app${NC}"
    done
  fi

  if [ ${#FAILED_APPS[@]} -gt 0 ]; then
    echo ""
    echo -e "  ${RED}Apps with failures:${NC}"
    for app in "${FAILED_APPS[@]}"; do
      echo -e "    ${RED}✗ $app${NC}"
    done
  else
    echo -e "\n  ${GREEN}${BOLD}All apps passed!${NC}"
  fi
  echo -e "${BOLD}==============================${NC}"

elif [ -n "$1" ]; then
  if [ ! -d "$1" ]; then
    echo "Error: folder '$1' not found"
    exit 1
  fi
  check_app "$1"

else
  echo "Usage:"
  echo "  bash check-pwa.sh prom     # check one app"
  echo "  bash check-pwa.sh --all    # check all apps"
fi

