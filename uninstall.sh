#!/bin/bash
# Uninstall claude-statusline

CLAUDE_DIR="$HOME/.claude"
TARGET="$CLAUDE_DIR/statusline.sh"
SETTINGS="$CLAUDE_DIR/settings.json"
CACHE="$CLAUDE_DIR/statusline-cost-cache.tsv"

# Remove symlink
if [ -L "$TARGET" ]; then
    rm -f "$TARGET"
    echo "Removed $TARGET"
fi

# Remove cache
rm -f "$CACHE"

# Remove statusLine config from settings.json
if [ -f "$SETTINGS" ] && jq -e '.statusLine' "$SETTINGS" > /dev/null 2>&1; then
    jq 'del(.statusLine)' "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"
    echo "Removed statusLine config from $SETTINGS"
fi

echo "Done. Restart Claude Code to apply."
