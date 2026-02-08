#!/bin/bash
# Install claude-statusline
# Creates symlink in ~/.claude/ and configures settings.json

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
TARGET="$CLAUDE_DIR/statusline.sh"
SETTINGS="$CLAUDE_DIR/settings.json"

# Ensure ~/.claude exists
mkdir -p "$CLAUDE_DIR"

# Remove old file / symlink
if [ -e "$TARGET" ] || [ -L "$TARGET" ]; then
    rm -f "$TARGET"
    echo "Removed old $TARGET"
fi

# Create symlink
ln -s "$SCRIPT_DIR/statusline.sh" "$TARGET"
echo "Linked $TARGET -> $SCRIPT_DIR/statusline.sh"

# Add statusLine config to settings.json if not present
if [ -f "$SETTINGS" ]; then
    if ! jq -e '.statusLine' "$SETTINGS" > /dev/null 2>&1; then
        jq '.statusLine = {"type":"command","command":"~/.claude/statusline.sh","padding":1}' \
            "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"
        echo "Added statusLine config to $SETTINGS"
    else
        echo "statusLine config already exists in $SETTINGS"
    fi
else
    echo '{"statusLine":{"type":"command","command":"~/.claude/statusline.sh","padding":1}}' \
        | jq . > "$SETTINGS"
    echo "Created $SETTINGS with statusLine config"
fi

echo "Done. Restart Claude Code to see the statusline."
