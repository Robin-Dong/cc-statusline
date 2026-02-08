#!/bin/bash
# Claude Code Statusline
# Shows: path(branch), model, context, cost stats, repo info, tools

input=$(cat)

# --- Parse all stdin JSON fields in one jq call ---
IFS=$'\t' read -r MODEL CWD PROJECT_DIR SESSION_COST SESSION_ID CTX_PCT TOTAL_IN TOTAL_OUT <<< \
  "$(echo "$input" | jq -r '[
    (.model.display_name // "?"),
    (.cwd // .workspace.current_dir // "."),
    (.workspace.project_dir // .cwd // "."),
    ((.cost.total_cost_usd // 0) | tostring),
    (.session_id // ""),
    ((.context_window.used_percentage // 0) | floor | tostring),
    ((.context_window.total_input_tokens // 0) | tostring),
    ((.context_window.total_output_tokens // 0) | tostring)
  ] | @tsv' 2>/dev/null)"

# --- Git branch ---
BRANCH=$(cd "$CWD" 2>/dev/null && git branch --show-current 2>/dev/null || echo "?")

# --- Colors ---
DIM='\033[2m'
CYAN='\033[36m'
GREEN='\033[32m'
YELLOW='\033[33m'
MAGENTA='\033[35m'
BLUE='\033[34m'
WHITE='\033[37m'
BOLD='\033[1m'
RESET='\033[0m'

# --- Context progress bar ---
BAR_W=10
FILLED=$((CTX_PCT * BAR_W / 100))
EMPTY=$((BAR_W - FILLED))
BAR=""
[ "$FILLED" -gt 0 ] && BAR=$(printf "%${FILLED}s" | tr ' ' '▓')
[ "$EMPTY" -gt 0 ] && BAR="${BAR}$(printf "%${EMPTY}s" | tr ' ' '░')"

if [ "$CTX_PCT" -ge 80 ]; then
    BAR_COLOR='\033[31m'
elif [ "$CTX_PCT" -ge 50 ]; then
    BAR_COLOR="$YELLOW"
else
    BAR_COLOR="$GREEN"
fi

# --- Format tokens ---
fmt_tok() {
    local t=$1
    if [ "$t" -ge 1000000 ] 2>/dev/null; then
        printf "%.1fM" "$(echo "$t / 1000000" | bc -l)"
    elif [ "$t" -ge 1000 ] 2>/dev/null; then
        printf "%.1fk" "$(echo "$t / 1000" | bc -l)"
    else
        echo "${t:-0}"
    fi
}

# Format: $X.XX(Xk/Xk)
fmt_cost() {
    local cost=$1 inp=$2 out=$3
    printf '$%.2f(%s/%s)' "$cost" "$(fmt_tok "$inp")" "$(fmt_tok "$out")"
}

# --- Line 1: Path(branch) | Model | Context ---
DIR_NAME=$(basename "$CWD")
echo -e "${CYAN}${DIR_NAME}${RESET}${DIM}(${BRANCH})${RESET} ${DIM}|${RESET} ${BOLD}${MODEL}${RESET} ${DIM}|${RESET} Ctx:${BAR_COLOR}${CTX_PCT}%${RESET} ${BAR_COLOR}${BAR}${RESET}"

# --- Historical costs from session JSONL files (with 5min cache) ---
CACHE_FILE="$HOME/.claude/statusline-cost-cache.tsv"
CACHE_TTL=300
TODAY=$(date +%Y-%m-%d)
SEVEN_AGO=$(date -v-7d +%Y-%m-%d 2>/dev/null || date -d '7 days ago' +%Y-%m-%d 2>/dev/null)
THIRTY_AGO=$(date -v-30d +%Y-%m-%d 2>/dev/null || date -d '30 days ago' +%Y-%m-%d 2>/dev/null)

THIRTY_COST=0; THIRTY_IN=0; THIRTY_OUT=0
SEVEN_COST=0; SEVEN_IN=0; SEVEN_OUT=0
TODAY_COST=0; TODAY_IN=0; TODAY_OUT=0

USE_CACHE=false
if [ -f "$CACHE_FILE" ]; then
    CACHE_MTIME=$(stat -f %m "$CACHE_FILE" 2>/dev/null || stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0)
    NOW=$(date +%s)
    if [ $((NOW - CACHE_MTIME)) -lt $CACHE_TTL ]; then
        USE_CACHE=true
    fi
fi

if $USE_CACHE; then
    IFS=$'\t' read -r THIRTY_COST THIRTY_IN THIRTY_OUT SEVEN_COST SEVEN_IN SEVEN_OUT TODAY_COST TODAY_IN TODAY_OUT < "$CACHE_FILE"
else
    COST_LINE=$(find "$HOME/.claude/projects" -name '*.jsonl' -print0 2>/dev/null \
        | xargs -0 cat 2>/dev/null \
        | jq -r -s --arg today "$TODAY" --arg seven "$SEVEN_AGO" --arg thirty "$THIRTY_AGO" '
            [.[] | select(.type == "assistant" and .timestamp != null and .message.usage != null) |
                { d: .timestamp[:10],
                  i: (.message.usage.input_tokens // 0),
                  o: (.message.usage.output_tokens // 0),
                  cr: (.message.usage.cache_read_input_tokens // 0),
                  cw: (.message.usage.cache_creation_input_tokens // 0) }
            ] |
            def agg(fd; td):
                [.[] | select(.d >= fd and .d <= td)] |
                { i: (map(.i) | add // 0), o: (map(.o) | add // 0),
                  cr: (map(.cr) | add // 0), cw: (map(.cw) | add // 0) } |
                [ ((.i*15 + .o*75 + .cr*1.875 + .cw*18.75) / 1e6 * 100 | round / 100),
                  (.i + .cr + .cw), .o ];
            (agg($thirty; $today)) as $m |
            (agg($seven; $today)) as $s |
            (agg($today; $today)) as $t |
            ($m + $s + $t) | @tsv
        ' 2>/dev/null)
    if [ -n "$COST_LINE" ]; then
        echo "$COST_LINE" > "$CACHE_FILE"
        IFS=$'\t' read -r THIRTY_COST THIRTY_IN THIRTY_OUT SEVEN_COST SEVEN_IN SEVEN_OUT TODAY_COST TODAY_IN TODAY_OUT <<< "$COST_LINE"
    fi
fi

# --- Line 2: Cost stats ---
SESSION_COST_STR=$(fmt_cost "$SESSION_COST" "$TOTAL_IN" "$TOTAL_OUT")
echo -e "${DIM}30d:${RESET}${YELLOW}$(fmt_cost "$THIRTY_COST" "$THIRTY_IN" "$THIRTY_OUT")${RESET} ${DIM}|${RESET} ${DIM}7d:${RESET}${GREEN}$(fmt_cost "$SEVEN_COST" "$SEVEN_IN" "$SEVEN_OUT")${RESET} ${DIM}|${RESET} ${DIM}Today:${RESET}${CYAN}$(fmt_cost "$TODAY_COST" "$TODAY_IN" "$TODAY_OUT")${RESET} ${DIM}|${RESET} ${DIM}Session:${RESET}${MAGENTA}${SESSION_COST_STR}${RESET}"

# --- Repo stats ---
PROJ_ENCODED=$(echo "$PROJECT_DIR" | tr '/_.' '---')
SESSIONS_INDEX="$HOME/.claude/projects/${PROJ_ENCODED}/sessions-index.json"
REPO_SESS=0; REPO_MSG=0
if [ -f "$SESSIONS_INDEX" ]; then
    IFS=$'\t' read -r REPO_SESS REPO_MSG <<< "$(jq -r \
        '(.entries | length | tostring) + "\t" + ([.entries[].messageCount] | add // 0 | tostring)' \
        "$SESSIONS_INDEX" 2>/dev/null)"
fi

# --- Tools in current session (with call counts) ---
TOOLS_STR=""
if [ -n "$SESSION_ID" ] && [ -n "$PROJ_ENCODED" ]; then
    SESSION_FILE="$HOME/.claude/projects/${PROJ_ENCODED}/${SESSION_ID}.jsonl"
    if [ -f "$SESSION_FILE" ]; then
        TOOLS_STR=$(grep 'tool_use' "$SESSION_FILE" 2>/dev/null \
            | grep -o '"name": *"[^"]*"' \
            | sed 's/"name": *"//; s/"//' \
            | sort | uniq -c | sort -rn \
            | awk '{printf "%s(x%d), ", $2, $1}' \
            | sed 's/, $//')
    fi
fi

# --- Line 3: Repo + Tools ---
REPO_PART="${DIM}Repo:${RESET}${BLUE}${REPO_MSG}msg/${REPO_SESS}sess${RESET}"
if [ -n "$TOOLS_STR" ]; then
    echo -e "${REPO_PART} ${DIM}|${RESET} ${DIM}Tools:${RESET}${WHITE}${TOOLS_STR}${RESET}"
else
    echo -e "${REPO_PART}"
fi
