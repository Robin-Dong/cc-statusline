# cc-statusline

A statusline script for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) that displays real-time session info, cost tracking, and tool usage.

## Preview

```
json-render(main) | Opus | Ctx:42% ▓▓▓▓░░░░░░
30d:$118.07(29.8M/38.8k) | 7d:$19.94(4.7M/36.7k) | Today:$17.12(4.0M/36.7k) | Session:$0.42(500.0k/15.0k)
Repo:63msg/5sess | Tools:Glob(x3), Write(x2), Bash(x1)
```

**Line 1** - Project directory, git branch, model name, context window usage with color-coded progress bar (green < 50%, yellow 50-80%, red > 80%)

**Line 2** - Estimated cost with input/output token breakdown for 30-day, 7-day, today, and current session

**Line 3** - Current repo's total messages/sessions, tools called in this session with invocation counts

## Requirements

- `jq` (JSON processor)
- `bc` (calculator, pre-installed on macOS/most Linux)

## Install

```bash
git clone https://github.com/Robin-Dong/cc-statusline.git
cd cc-statusline
./install.sh
```

This will:
1. Symlink `statusline.sh` to `~/.claude/statusline.sh`
2. Add `statusLine` config to `~/.claude/settings.json`

Restart Claude Code to activate.

## Uninstall

```bash
./uninstall.sh
```

## Customization

The script is a single `statusline.sh` file. Claude Code pipes a JSON object to stdin on each update. Edit the script directly to customize.

### Available JSON fields from stdin

| Field | Description |
|---|---|
| `model.display_name` | Model name (e.g. "Opus") |
| `model.id` | Full model ID (e.g. "claude-opus-4-6") |
| `cwd` | Current working directory |
| `workspace.project_dir` | Directory where Claude Code was launched |
| `session_id` | Current session ID |
| `cost.total_cost_usd` | Session cost in USD |
| `context_window.used_percentage` | Context window usage (0-100) |
| `context_window.total_input_tokens` | Cumulative input tokens |
| `context_window.total_output_tokens` | Cumulative output tokens |
| `context_window.context_window_size` | Max context size |
| `cost.total_duration_ms` | Session wall-clock time |
| `cost.total_lines_added` | Lines of code added |
| `cost.total_lines_removed` | Lines of code removed |
| `version` | Claude Code version |

### Common customizations

**Change colors** - Edit the color variables at the top of the script:

```bash
# ANSI color codes
DIM='\033[2m'
CYAN='\033[36m'
GREEN='\033[32m'
YELLOW='\033[33m'
MAGENTA='\033[35m'
# Add your own:
RED='\033[31m'
```

**Change progress bar style** - Modify `BAR_W` for width, or change the fill characters:

```bash
BAR_W=20                          # wider bar
tr ' ' '█'   # instead of ▓
tr ' ' '·'   # instead of ░
```

**Change cost pricing** - The cost calculation uses Anthropic standard pricing. Edit the jq query in the `agg` function (around line 109):

```
# Default pricing (per million tokens):
#   input: $15, output: $75, cache_read: $1.875, cache_write: $18.75
(.i*15 + .o*75 + .cr*1.875 + .cw*18.75) / 1e6
```

**Change cache TTL** - Cost data is cached to avoid re-parsing JSONL files on every update:

```bash
CACHE_TTL=300   # seconds (default: 5 minutes)
```

To force a refresh, delete the cache:

```bash
rm ~/.claude/statusline-cost-cache.tsv
```

**Add/remove lines** - Each `echo -e` outputs one statusline row. Comment out or add new lines as needed. For example, to add session duration:

```bash
DURATION_MS=$(echo "$input" | jq -r '.cost.total_duration_ms // 0')
MINS=$((DURATION_MS / 60000))
echo -e "${DIM}Duration:${RESET} ${MINS}min"
```

**Show only 2 lines** - Comment out the Line 3 block (Repo + Tools section) if you prefer a compact view.

### settings.json reference

The `statusLine` config in `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline.sh",
    "padding": 1
  }
}
```

- `padding` - Horizontal spacing in characters (default: 0)

### Testing

Test the script locally by piping sample JSON:

```bash
echo '{"model":{"display_name":"Opus"},"cwd":"/your/project","workspace":{"project_dir":"/your/project"},"cost":{"total_cost_usd":0.5},"session_id":"test","context_window":{"used_percentage":42,"total_input_tokens":500000,"total_output_tokens":15000}}' | ./statusline.sh
```

## License

MIT
