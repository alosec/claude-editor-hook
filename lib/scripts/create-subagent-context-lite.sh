#!/usr/bin/env bash
# Create lightweight subagent context package for non-interactive enhancement
# Usage: create-subagent-context-lite.sh <prompt-file> <output-dir>
#
# This is a lighter version optimized for Haiku's non-interactive enhancement.
# Includes only what's needed: prompt file path, recent files, metadata.
# Skips parent conversation context since this is automated enhancement.

set -euo pipefail

PROMPT_FILE="$1"
OUTPUT_DIR="$2"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Create context directory
mkdir -p "$OUTPUT_DIR"

# Create system prompt focused on enhancement task
cat > "$OUTPUT_DIR/system-prompt.txt" <<EOF
You are a Claude subagent performing automated prompt enhancement.

Available context in \$CONTEXT_DIR ($OUTPUT_DIR):
- recent-files.txt: Files recently edited in this session
- meta.json: Working directory and metadata

Your workflow:
1. Read the prompt file to identify sections marked with *** text *** or <<< text >>>
2. Use Read, Grep, Glob, Bash tools to investigate each marked area
3. Gather concrete details (file paths, line numbers, code snippets, patterns)
4. Replace marked sections with your findings
5. Write the enhanced prompt back to the prompt file
6. Output only 'Done' when complete

Focus on gathering factual context, not speculation. Include file paths with line numbers when relevant.
EOF

# Create user prompt that triggers the enhancement
cat > "$OUTPUT_DIR/user-prompt.txt" <<EOF
Read the prompt file at $PROMPT_FILE and enhance sections marked with *** text *** or <<< text >>>.

Marked sections indicate areas needing investigation or context:
- File references that need paths/line numbers
- Feature descriptions needing architecture context
- Bug reports needing related code patterns
- Questions needing answers from the codebase

Investigate each marked section, gather concrete details, then write the enhanced prompt back to $PROMPT_FILE.
EOF

# Query recent files (useful for context about what user is working on)
bash "$SCRIPT_DIR/query-recent-files-jsonl.sh" > "$OUTPUT_DIR/recent-files.txt" 2>/dev/null || echo "No recent files available" > "$OUTPUT_DIR/recent-files.txt"

# Create metadata
cat > "$OUTPUT_DIR/meta.json" <<METAEOF
{
  "created_at": "$(date -Iseconds)",
  "working_dir": "$PWD",
  "prompt_file": "$PROMPT_FILE",
  "parent_pid": $$,
  "type": "non-interactive-enhancement"
}
METAEOF

chmod -R u+rw "$OUTPUT_DIR"
