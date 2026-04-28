#!/usr/bin/env bash
# =============================================================================
# wedit.sh — Web File Editor (HTML / JS / CSS)
# Usage: wedit.sh <command> [options] <file>
# =============================================================================

set -euo pipefail

# ── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'; RESET='\033[0m'

# ── Helpers ───────────────────────────────────────────────────────────────────
die()  { echo -e "${RED}ERROR: $*${RESET}" >&2; exit 1; }
info() { echo -e "${CYAN}$*${RESET}"; }
ok()   { echo -e "${GREEN}✔  $*${RESET}"; }
warn() { echo -e "${YELLOW}⚠  $*${RESET}"; }

usage() {
cat <<EOF
${BOLD}wedit.sh${RESET} — Surgical editor for HTML / JS / CSS files

${BOLD}USAGE${RESET}
  wedit.sh <command> [options] <file>

${BOLD}COMMANDS${RESET}
  show      <pattern>                    Show lines matching pattern (with line numbers)
  find      <pattern>                    Find files in tree containing pattern
  before    <pattern> <insert_text>      Insert text BEFORE each matching line
  after     <pattern> <insert_text>      Insert text AFTER each matching line
  replace   <old_pattern> <new_text>     Replace matching text with new text
  remove    <pattern>                    Remove lines matching pattern
  between   <start_pat> <end_pat>        Show/operate on a block between two patterns
  wrap      <pattern> <before> <after>   Wrap matching line with before/after text

${BOLD}OPTIONS${RESET}
  -n, --dry-run      Preview changes without writing to file
  -b, --backup       Create .bak backup before editing (default: on)
  -N, --no-backup    Skip backup
  -i, --ignore-case  Case-insensitive matching
  -g, --glob <pat>   Run on all matching files (e.g. "*.js" or "src/**/*.css")
  -h, --help         Show this help

${BOLD}EXAMPLES${RESET}
  # Show all lines containing "TODO"
  wedit.sh show "TODO" app.js

  # Preview inserting a console.log before every "return" statement
  wedit.sh --dry-run before "return" "  console.log('reaching return');" app.js

  # Replace a CSS colour value
  wedit.sh replace "#ff0000" "#e74c3c" styles.css

  # Remove all console.log lines (with backup)
  wedit.sh remove "console\.log" app.js

  # Insert a meta tag after <head> in all HTML files
  wedit.sh --glob "*.html" after "<head>" '  <meta name="robots" content="noindex">'

  # Wrap every <img> tag with a <figure>
  wedit.sh wrap "<img " "<figure>" "</figure>" index.html

  # Show a block between two markers
  wedit.sh between "<!-- START NAV -->" "<!-- END NAV -->" index.html
EOF
}

# ── Argument parsing ──────────────────────────────────────────────────────────
DRY_RUN=false
BACKUP=true
IGNORE_CASE=false
GLOB=""
COMMAND=""
ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--dry-run)     DRY_RUN=true;      shift ;;
    -b|--backup)      BACKUP=true;       shift ;;
    -N|--no-backup)   BACKUP=false;      shift ;;
    -i|--ignore-case) IGNORE_CASE=true;  shift ;;
    -g|--glob)        GLOB="$2";         shift 2 ;;
    -h|--help)        usage; exit 0 ;;
    -*)               die "Unknown option: $1" ;;
    *)
      if [[ -z "$COMMAND" ]]; then COMMAND="$1"
      else ARGS+=("$1"); fi
      shift ;;
  esac
done

[[ -z "$COMMAND" ]] && { usage; exit 1; }

# ── SED flags ─────────────────────────────────────────────────────────────────
sed_i_flag() {
  # BSD sed (macOS) needs -i '' ; GNU sed (Linux/Termux) uses -i
  if sed --version 2>/dev/null | grep -q GNU; then echo "-i"
  else echo "-i ''"; fi
}

SED_I=$(sed_i_flag)
SED_CASE_FLAG=""
GREP_CASE_FLAG=""
$IGNORE_CASE && { SED_CASE_FLAG="I"; GREP_CASE_FLAG="-i"; }

# ── File list builder ─────────────────────────────────────────────────────────
build_file_list() {
  local file="${ARGS[-1]:-}"
  if [[ -n "$GLOB" ]]; then
    mapfile -t FILES < <(find . -type f -name "$GLOB" 2>/dev/null | sort)
    [[ ${#FILES[@]} -eq 0 ]] && die "No files matched glob: $GLOB"
  elif [[ -n "$file" ]] && [[ -f "$file" ]]; then
    FILES=("$file")
  else
    die "No file specified or file not found: '$file'"
  fi
}

# ── Preview: show matching lines with context ─────────────────────────────────
preview_match() {
  local pattern="$1" file="$2"
  local count
  count=$(grep -c $GREP_CASE_FLAG "$pattern" "$file" 2>/dev/null || true)

  if [[ "$count" -eq 0 ]]; then
    warn "No matches for pattern: $pattern  in $file"
    return 1
  fi

  echo -e "\n${BOLD}${DIM}── $file ──────────────────────────────────────────${RESET}"
  echo -e "${YELLOW}  $count match(es) for: ${BOLD}$pattern${RESET}"
  echo ""

  # Show matched lines with line numbers and 2-line context
  grep -n $GREP_CASE_FLAG --color=always -A2 -B2 "$pattern" "$file" \
    | awk '
        /^[0-9]+-/ { print "  \033[2m" $0 "\033[0m"; next }   # context line
        /^[0-9]+:/ { print "  \033[1;33m" $0 "\033[0m"; next } # matched line
        /^--$/     { print "  \033[2m···\033[0m"; next }
        { print "  " $0 }
      '
  echo ""
  return 0
}

# ── Backup ────────────────────────────────────────────────────────────────────
make_backup() {
  local file="$1"
  if $BACKUP; then
    cp "$file" "${file}.bak"
    info "  Backup → ${file}.bak"
  fi
}

# ── Apply sed in-place or dry-run ─────────────────────────────────────────────
apply_sed() {
  local sed_script="$1" file="$2"
  if $DRY_RUN; then
    echo -e "${YELLOW}  [dry-run] Result preview:${RESET}"
    sed "$sed_script" "$file" | head -60
  else
    make_backup "$file"
    eval sed $SED_I "'$sed_script'" "'$file'"
    ok "  Written → $file"
  fi
}

# ── COMMANDS ──────────────────────────────────────────────────────────────────

cmd_show() {
  # wedit.sh show <pattern> <file>
  [[ ${#ARGS[@]} -lt 2 ]] && die "Usage: wedit.sh show <pattern> <file>"
  local pattern="${ARGS[0]}" file="${ARGS[1]}"
  [[ -f "$file" ]] || die "File not found: $file"
  preview_match "$pattern" "$file" || true
}

cmd_find() {
  # wedit.sh find <pattern>  — searches current tree
  [[ ${#ARGS[@]} -lt 1 ]] && die "Usage: wedit.sh find <pattern>"
  local pattern="${ARGS[0]}"
  info "Searching for: $pattern"
  grep -rn $GREP_CASE_FLAG --include="*.html" --include="*.js" \
           --include="*.css" --color=always "$pattern" . || warn "No matches found."
}

cmd_before() {
  # wedit.sh before <pattern> <insert_text> <file>
  [[ ${#ARGS[@]} -lt 3 ]] && die "Usage: wedit.sh before <pattern> <insert_text> <file>"
  local pattern="${ARGS[0]}" insert="${ARGS[1]}" file="${ARGS[2]}"
  [[ -f "$file" ]] || die "File not found: $file"

  preview_match "$pattern" "$file" || die "Aborting — no matches."

  # Escape insert text for sed
  local escaped_insert
  escaped_insert=$(printf '%s\n' "$insert" | sed 's/[[\.*^$()+?{|]/\\&/g')

  info "  → Inserting BEFORE each match..."
  apply_sed "\\|$pattern|${SED_CASE_FLAG}i\\
${escaped_insert}" "$file"
}

cmd_after() {
  # wedit.sh after <pattern> <insert_text> <file>
  [[ ${#ARGS[@]} -lt 3 ]] && die "Usage: wedit.sh after <pattern> <insert_text> <file>"
  local pattern="${ARGS[0]}" insert="${ARGS[1]}" file="${ARGS[2]}"
  [[ -f "$file" ]] || die "File not found: $file"

  preview_match "$pattern" "$file" || die "Aborting — no matches."

  local escaped_insert
  escaped_insert=$(printf '%s\n' "$insert" | sed 's/[[\.*^$()+?{|]/\\&/g')

  info "  → Inserting AFTER each match..."
  apply_sed "\\|$pattern|${SED_CASE_FLAG}a\\
${escaped_insert}" "$file"
}

cmd_replace() {
  # wedit.sh replace <old_pattern> <new_text> <file>
  [[ ${#ARGS[@]} -lt 3 ]] && die "Usage: wedit.sh replace <old_pattern> <new_text> <file>"
  local pattern="${ARGS[0]}" new_text="${ARGS[1]}" file="${ARGS[2]}"
  [[ -f "$file" ]] || die "File not found: $file"

  preview_match "$pattern" "$file" || die "Aborting — no matches."

  # Escape | and & in replacement (| is our delimiter; & is sed back-reference)
  local escaped_new
  escaped_new=$(printf '%s' "$new_text" | sed 's/[|&]/\\&/g')

  info "  → Replacing matches..."
  # Use | as delimiter so / in pattern or replacement never breaks the expression
  apply_sed "s|$pattern|$escaped_new|g${SED_CASE_FLAG}" "$file"
}

cmd_remove() {
  # wedit.sh remove <pattern> <file>
  [[ ${#ARGS[@]} -lt 2 ]] && die "Usage: wedit.sh remove <pattern> <file>"
  local pattern="${ARGS[0]}" file="${ARGS[1]}"
  [[ -f "$file" ]] || die "File not found: $file"

  preview_match "$pattern" "$file" || die "Aborting — no matches."

  warn "  → REMOVING all matching lines..."
  apply_sed "\\|$pattern|${SED_CASE_FLAG}d" "$file"
}

cmd_between() {
  # wedit.sh between <start_pat> <end_pat> <file>  — show only
  [[ ${#ARGS[@]} -lt 3 ]] && die "Usage: wedit.sh between <start_pat> <end_pat> <file>"
  local start="${ARGS[0]}" end="${ARGS[1]}" file="${ARGS[2]}"
  [[ -f "$file" ]] || die "File not found: $file"

  echo -e "\n${BOLD}${DIM}── $file ──────────────────────────────────────────${RESET}"
  info "  Block from: $start → $end"
  echo ""
  awk "/$start/,/$end/" "$file" | nl -ba | \
    awk '{ printf "  \033[2m%4s\033[0m  %s\n", $1, substr($0, index($0,$2)) }'
  echo ""
}

cmd_wrap() {
  # wedit.sh wrap <pattern> <before_text> <after_text> <file>
  [[ ${#ARGS[@]} -lt 4 ]] && die "Usage: wedit.sh wrap <pattern> <before_text> <after_text> <file>"
  local pattern="${ARGS[0]}" before="${ARGS[1]}" after="${ARGS[2]}" file="${ARGS[3]}"
  [[ -f "$file" ]] || die "File not found: $file"

  preview_match "$pattern" "$file" || die "Aborting — no matches."

  local esc_before esc_after
  esc_before=$(printf '%s\n' "$before" | sed 's/[[\.*^$()+?{|]/\\&/g')
  esc_after=$(printf '%s\n' "$after"  | sed 's/[[\.*^$()+?{|]/\\&/g')

  info "  → Wrapping matches with before/after text..."
  apply_sed "\\|$pattern|${SED_CASE_FLAG}{
i\\
${esc_before}
a\\
${esc_after}
}" "$file"
}

# ── Multi-file glob wrapper ───────────────────────────────────────────────────
run_command() {
  case "$COMMAND" in
    show)    cmd_show ;;
    find)    cmd_find ;;
    before)  cmd_before ;;
    after)   cmd_after ;;
    replace) cmd_replace ;;
    remove)  cmd_remove ;;
    between) cmd_between ;;
    wrap)    cmd_wrap ;;
    *)       die "Unknown command: $COMMAND. Run wedit.sh --help" ;;
  esac
}

# If --glob is set, loop over matched files injecting each as the last ARG
if [[ -n "$GLOB" ]]; then
  build_file_list
  # Remove any trailing file arg from ARGS (glob replaces it)
  [[ ${#ARGS[@]} -gt 0 ]] && unset 'ARGS[-1]'
  for f in "${FILES[@]}"; do
    ARGS+=("$f")
    run_command
    unset 'ARGS[-1]'
  done
else
  run_command
fi

