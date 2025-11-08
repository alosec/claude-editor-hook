#!/usr/bin/env bash

# Query Claude Code JSONL logs for recent conversations across all projects
# Uses intelligent caching to avoid re-parsing on every invocation
# Returns conversation metadata as JSON, ordered by recency (most recent first)
# Exit codes: 0 (success), 1 (no JSONL files), 2 (parse error)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CACHE_DIR="$(cd "$SCRIPT_DIR/../cache" && pwd)"
PROJECTS_DIR="$HOME/.claude/projects"

# Cache configuration
CACHE_FILE="$CACHE_DIR/recent-conversations.json"
LIMIT=10

# Create cache directory if it doesn't exist
mkdir -p "$CACHE_DIR"

# Find all project directories
mapfile -t PROJECT_DIRS < <(find "$PROJECTS_DIR" -maxdepth 1 -type d -name "-*" 2>/dev/null)

if [ ${#PROJECT_DIRS[@]} -eq 0 ]; then
    echo "Error: No project directories found in $PROJECTS_DIR" >&2
    exit 1
fi

# Get latest modification time across all JSONL files for cache validation
LATEST_MTIME=0
for project_dir in "${PROJECT_DIRS[@]}"; do
    while IFS= read -r -d '' file; do
        FILE_MTIME=$(stat -c %Y "$file" 2>/dev/null || echo 0)
        if [ "$FILE_MTIME" -gt "$LATEST_MTIME" ]; then
            LATEST_MTIME="$FILE_MTIME"
        fi
    done < <(find "$project_dir" -name "*.jsonl" -type f -print0 2>/dev/null)
done

# Check cache validity
if [ -f "$CACHE_FILE" ]; then
    CACHE_MTIME=$(jq -r '.last_jsonl_mtime // 0' "$CACHE_FILE" 2>/dev/null || echo 0)

    if [ "$LATEST_MTIME" -le "$CACHE_MTIME" ]; then
        # Cache is fresh, return cached results
        jq -r '.conversations[] | @json' "$CACHE_FILE" 2>/dev/null && exit 0
    fi
fi

# Cache is stale or missing, parse all JSONL files
# Collect all sessions from all projects
TEMP_SESSIONS="/tmp/conversations-$$"
> "$TEMP_SESSIONS"

for project_dir in "${PROJECT_DIRS[@]}"; do
    # Extract project name from directory (e.g., -home-alex-code-pedicab512 -> pedicab512)
    PROJECT_NAME=$(basename "$project_dir" | sed 's/^-home-alex-code-//')

    # Find all JSONL files in this project
    while IFS= read -r -d '' jsonl_file; do
        # Extract session metadata using jq
        jq -n \
            --arg file "$jsonl_file" \
            --arg project "$PROJECT_NAME" \
            --slurpfile data <(cat "$jsonl_file" 2>/dev/null || echo '[]') \
            '
            # Get first message for metadata
            ($data | map(select(.type == "user" or .type == "assistant")) | .[0]) as $first |
            # Get last message for end time
            ($data | map(select(.type == "user" or .type == "assistant")) | .[-1]) as $last |
            # Get summary (prefer last summary message, fallback to first user message)
            (
                ($data | map(select(.type == "summary")) | .[-1].summary) //
                ($data | map(select(.type == "user" and .parentUuid == null)) | .[0].message.content |
                    if type == "string" then .[0:100]
                    else (try (.[0].text // "") catch "" | .[0:100])
                    end
                ) //
                "Untitled Session"
            ) as $summary |
            # Only output if we have valid data
            if $first then
                {
                    file: $file,
                    sessionId: ($first.sessionId // "unknown"),
                    project: $project,
                    cwd: ($first.cwd // "unknown"),
                    branch: ($first.gitBranch // "unknown"),
                    summary: $summary,
                    startTime: ($first.timestamp // "unknown"),
                    endTime: ($last.timestamp // $first.timestamp // "unknown"),
                    messageCount: ($data | map(select(.type == "user" or .type == "assistant")) | length)
                }
            else
                empty
            end
            ' 2>/dev/null >> "$TEMP_SESSIONS" || true
    done < <(find "$project_dir" -name "*.jsonl" -type f -print0 2>/dev/null)
done

# Sort by endTime and limit to most recent N conversations
jq -s \
    --argjson limit "$LIMIT" \
    'sort_by(.endTime) | reverse | .[:$limit]' \
    "$TEMP_SESSIONS" > /tmp/sorted-conversations-$$

# Build and save cache
jq -n \
    --argjson mtime "$LATEST_MTIME" \
    --arg cached_at "$(date -Iseconds)" \
    --argjson conversations "$(cat /tmp/sorted-conversations-$$)" \
    '{last_jsonl_mtime: $mtime, cached_at: $cached_at, conversations: $conversations}' \
    > "$CACHE_FILE"

# Output results
jq -r '.[] | @json' /tmp/sorted-conversations-$$

# Cleanup
rm -f "$TEMP_SESSIONS" /tmp/sorted-conversations-$$

exit 0
