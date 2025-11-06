#!/usr/bin/env bash

# Query Claude Code JSONL logs directly for recently touched files
# Uses intelligent caching to avoid re-parsing on every invocation
# Returns one file path per line, ordered by recency (most recent first)
# Exit codes: 0 (success), 1 (no JSONL files), 2 (parse error)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CACHE_DIR="$(cd "$SCRIPT_DIR/../cache" && pwd)"
PROJECTS_DIR="$HOME/.claude/projects"
PROJECT_FILTER="${1:-}"

# Limit to parse (last N lines from each JSONL file)
PARSE_LIMIT=5000

# Generate cache key from current working directory
CACHE_KEY=$(echo "$PWD" | md5sum | cut -d' ' -f1)
CACHE_FILE="$CACHE_DIR/recent-files-${CACHE_KEY}.json"

# Detect project directory name in ~/.claude/projects
# Converts /home/alex/code/g-menu -> -home-alex-code-g-menu
detect_project_dir() {
    local cwd="${1:-$PWD}"
    # Replace slashes with dashes, which creates leading dash from root /
    echo "$cwd" | tr '/' '-'
}

PROJECT_DIR="$PROJECTS_DIR/$(detect_project_dir)"

# Check if project JSONL directory exists
if [ ! -d "$PROJECT_DIR" ]; then
    echo "Error: No JSONL logs found for current project at $PROJECT_DIR" >&2
    exit 1
fi

# Find all JSONL files, sorted by modification time (newest first)
mapfile -t JSONL_FILES < <(find "$PROJECT_DIR" -name "*.jsonl" -type f -printf "%T@ %p\n" | sort -rn | cut -d' ' -f2-)

if [ ${#JSONL_FILES[@]} -eq 0 ]; then
    echo "Error: No JSONL files found in $PROJECT_DIR" >&2
    exit 1
fi

# Get most recent JSONL modification time
LATEST_MTIME=$(stat -c %Y "${JSONL_FILES[0]}" 2>/dev/null || echo 0)

# Check cache validity
if [ -f "$CACHE_FILE" ]; then
    CACHE_MTIME=$(jq -r '.last_jsonl_mtime // 0' "$CACHE_FILE" 2>/dev/null || echo 0)

    if [ "$LATEST_MTIME" -le "$CACHE_MTIME" ]; then
        # Cache is fresh, return cached results
        jq -r '.files[].path' "$CACHE_FILE" 2>/dev/null && exit 0
    fi
fi

# Cache is stale or missing, parse JSONL files with jq
# Process all files in one jq invocation for speed
{
    for jsonl_file in "${JSONL_FILES[@]}"; do
        tail -n "$PARSE_LIMIT" "$jsonl_file" 2>/dev/null
    done
} | jq -r '
    # Only process assistant messages with tool uses
    select(.type == "assistant") |
    select(.message.content != null) |
    # Capture timestamp at message level, then process content
    {timestamp: .timestamp, tools: .message.content} |
    .timestamp as $ts |
    .tools[] |
    select(.type == "tool_use") |
    select(.name == "Read" or .name == "Edit" or .name == "Write") |
    select(.input.file_path != null) |
    # Exclude temporary Claude prompt files
    select(.input.file_path | test("/tmp/claude-prompt-.*\\.md$") | not) |
    {
        file_path: .input.file_path,
        timestamp: $ts
    }
' | jq -s '
    # Group by file_path and keep most recent timestamp
    group_by(.file_path) |
    map({
        file_path: .[0].file_path,
        timestamp: (map(.timestamp) | max)
    }) |
    # Sort by timestamp descending
    sort_by(.timestamp) | reverse |
    # Limit to 25
    .[0:25]
' > /tmp/recent-files-with-timestamps-$$

# Extract just file paths for output
jq -r '.[] | .file_path' /tmp/recent-files-with-timestamps-$$ > /tmp/recent-files-output-$$

# Build and save cache with timestamps
jq -n \
    --arg project "$PWD" \
    --argjson mtime "$LATEST_MTIME" \
    --arg cached_at "$(date -Iseconds)" \
    --argjson files "$(cat /tmp/recent-files-with-timestamps-$$ | jq 'map({path: .file_path, timestamp: .timestamp})')" \
    '{project_dir: $project, last_jsonl_mtime: $mtime, cached_at: $cached_at, files: $files}' \
    > "$CACHE_FILE"

# Output results
cat /tmp/recent-files-output-$$
rm -f /tmp/recent-files-output-$$ /tmp/recent-files-with-timestamps-$$

exit 0
