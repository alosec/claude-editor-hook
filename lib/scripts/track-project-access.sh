#!/usr/bin/env bash

# Track project access for recent projects feature
# Logs project directory access to JSONL format
# Usage: track-project-access.sh <project-path>

set -euo pipefail

PROJECT_PATH="${1:-}"

if [ -z "$PROJECT_PATH" ]; then
    echo "Error: Project path required" >&2
    exit 1
fi

# Resolve to absolute path
PROJECT_PATH=$(cd "$PROJECT_PATH" && pwd)

# Determine JSONL log location
# Use the current working directory to find the project-specific log
PROJECTS_DIR="$HOME/.claude/projects"

# Convert current working directory to project directory format
# /home/alex/code/g-menu -> -home-alex-code-g-menu
detect_project_dir() {
    local cwd="${1:-$PWD}"
    echo "$cwd" | tr '/' '-'
}

# Get the project directory for the CURRENT location (where command is run from)
PROJECT_DIR="$PROJECTS_DIR/$(detect_project_dir)"

# Find most recent JSONL file in current project directory
if [ -d "$PROJECT_DIR" ]; then
    JSONL_FILE=$(find "$PROJECT_DIR" -name "*.jsonl" -type f -printf "%T@ %p\n" | sort -rn | head -1 | cut -d' ' -f2-)

    if [ -n "$JSONL_FILE" ]; then
        # Append project access event to JSONL
        # Format matches Claude Code's internal structure for compatibility
        TIMESTAMP=$(date -Iseconds)

        # Create a custom event that can be parsed later
        cat >> "$JSONL_FILE" <<EOF
{"type":"project_access","timestamp":"$TIMESTAMP","project_path":"$PROJECT_PATH"}
EOF
    fi
fi

exit 0
