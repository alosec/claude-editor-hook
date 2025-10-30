#!/usr/bin/env bash
# Create subagent context package
# Usage: create-subagent-context.sh <prompt-file> <output-dir>

set -euo pipefail

PROMPT_FILE="$1"
OUTPUT_DIR="$2"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Create context directory
mkdir -p "$OUTPUT_DIR"

# Create system prompt with ACTUAL prompt file path
cat > "$OUTPUT_DIR/system-prompt.txt" <<EOF
You are a Claude subagent spawned from a parent Claude Code session.

Output file: $PROMPT_FILE
Write your response to this file when done.

Context files in \$CONTEXT_DIR ($OUTPUT_DIR):
- parent-context.md: Recent conversation between user and parent Claude
- recent-files.txt: Recently edited files (one per line)
- meta.json: Metadata (working directory, timestamps)

Workflow:
1. Read parent-context.md to understand what user wants
2. Read $PROMPT_FILE to see any draft/notes from parent
3. Investigate codebase as needed (Grep, Read, bd commands, etc.)
4. Write your enhanced/final output to $PROMPT_FILE
5. Exit when done
EOF

# Extract parent context
bash "$SCRIPT_DIR/extract-parent-context.sh" > "$OUTPUT_DIR/parent-context.md" 2>/dev/null || echo "No parent context available" > "$OUTPUT_DIR/parent-context.md"

# Query recent files
bash "$SCRIPT_DIR/query-recent-files-jsonl.sh" > "$OUTPUT_DIR/recent-files.txt" 2>/dev/null || echo "No recent files available" > "$OUTPUT_DIR/recent-files.txt"

# Create metadata with actual prompt file path
cat > "$OUTPUT_DIR/meta.json" <<METAEOF
{
  "created_at": "$(date -Iseconds)",
  "working_dir": "$PWD",
  "prompt_file": "$PROMPT_FILE",
  "parent_pid": $$
}
METAEOF

chmod -R u+rw "$OUTPUT_DIR"
