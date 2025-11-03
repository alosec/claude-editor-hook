#!/usr/bin/env bash

# Query recently accessed projects from JSONL logs
# Uses intelligent caching similar to query-recent-files-jsonl.sh
# Returns one project path per line, ordered by recency (most recent first)
# Exit codes: 0 (success), 1 (no JSONL files), 2 (parse error)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CACHE_DIR="$(cd "$SCRIPT_DIR/../cache" && pwd)"
PROJECTS_DIR="$HOME/.claude/projects"

# Limit to parse (last N lines from each JSONL file)
PARSE_LIMIT=2000

# Generate cache key from current working directory
CACHE_KEY=$(echo "$PWD" | md5sum | cut -d' ' -f1)
CACHE_FILE="$CACHE_DIR/recent-projects-${CACHE_KEY}.json"

# Detect project directory name in ~/.claude/projects
detect_project_dir() {
    local cwd="${1:-$PWD}"
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
        jq -r '.projects[].path' "$CACHE_FILE" 2>/dev/null && exit 0
    fi
fi

# Cache is stale or missing, parse JSONL files with jq
# Process all files in one jq invocation for speed
{
    for jsonl_file in "${JSONL_FILES[@]}"; do
        tail -n "$PARSE_LIMIT" "$jsonl_file" 2>/dev/null
    done
} | jq -r '
    # Look for custom project_access events
    select(.type == "project_access") |
    select(.project_path != null) |
    {
        project_path: .project_path,
        timestamp: .timestamp
    }
' | jq -s '
    # Group by project_path and keep most recent timestamp
    group_by(.project_path) |
    map({
        project_path: .[0].project_path,
        timestamp: (map(.timestamp) | max)
    }) |
    # Sort by timestamp descending
    sort_by(.timestamp) | reverse |
    # Limit to 10 recent projects
    .[0:10]
' > /tmp/recent-projects-with-timestamps-$$

# Extract just project paths for output
jq -r '.[] | .project_path' /tmp/recent-projects-with-timestamps-$$ > /tmp/recent-projects-output-$$

# Build and save cache with timestamps
jq -n \
    --arg cwd "$PWD" \
    --argjson mtime "$LATEST_MTIME" \
    --arg cached_at "$(date -Iseconds)" \
    --argjson projects "$(cat /tmp/recent-projects-with-timestamps-$$ | jq 'map({path: .project_path, timestamp: .timestamp})')" \
    '{current_dir: $cwd, last_jsonl_mtime: $mtime, cached_at: $cached_at, projects: $projects}' \
    > "$CACHE_FILE"

# Output results
cat /tmp/recent-projects-output-$$
rm -f /tmp/recent-projects-output-$$ /tmp/recent-projects-with-timestamps-$$

exit 0
