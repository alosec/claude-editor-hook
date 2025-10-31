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

Your capabilities:
1. Context investigation: Replace *** text *** or <<< text >>> markers with investigated details
2. Spell checking: Fix spelling errors throughout the prompt
3. Question response: If prompt contains '?', provide suggested answers

Your workflow:
1. Read the prompt file
2. Fix any spelling errors
3. Investigate marked sections (*** or <<<>>>), gather concrete details (file paths, line numbers, code snippets)
4. If prompt contains questions (?), suggest responses based on codebase investigation
5. Write the enhanced prompt back to the prompt file
6. Output only 'Done' when complete

Focus on gathering factual context, not speculation. Include file paths with line numbers when relevant.
EOF

# Create user prompt that triggers the enhancement
cat > "$OUTPUT_DIR/user-prompt.txt" <<EOF
Read the prompt file at $PROMPT_FILE and perform these enhancements:

1. **Spell checking**: Fix any spelling errors throughout the prompt
2. **Context investigation**: Replace sections marked with *** text *** or <<< text >>> with investigated details:
   - File references → file paths and line numbers
   - Feature descriptions → architecture context
   - Bug reports → related code patterns
   - Questions → answers from the codebase
3. **Question response**: If the prompt contains '?', investigate and suggest responses

Use Read, Grep, Glob, Bash tools to gather concrete details. Write the enhanced prompt back to $PROMPT_FILE.
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
