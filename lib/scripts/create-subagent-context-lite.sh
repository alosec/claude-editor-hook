#!/usr/bin/env bash
# Create lightweight subagent context package for non-interactive enhancement
# Usage: create-subagent-context-lite.sh <prompt-file> <output-dir>
#
# This version includes conversation context so Haiku can make intelligent
# suggestions based on what the user has been discussing, not just file edits.

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
- parent-context.md: Recent conversation between user and parent Claude
- recent-files.txt: Files recently edited in this session
- meta.json: Working directory and metadata

Your capabilities:
1. Context investigation: Replace *** text *** or <<< text >>> markers with investigated details
2. Spell checking: Fix spelling errors throughout the prompt
3. Suggestion mode: If prompt is blank/empty, suggest what to do next based on conversation context

Your workflow:
1. Read the prompt file
2. If prompt is blank/empty → Read parent-context.md to understand what user has been working on, then suggest next steps or responses
3. If prompt has content → fix spelling errors and investigate marked sections (*** or <<<>>>)
4. Write the enhanced prompt back to the prompt file
5. Output only 'Done' when complete

Focus on gathering factual context, not speculation. Include file paths with line numbers when relevant.
EOF

# Create user prompt that triggers the enhancement
cat > "$OUTPUT_DIR/user-prompt.txt" <<EOF
Read the prompt file at $PROMPT_FILE and perform these enhancements:

1. **Check if blank**: If the prompt is empty or blank, read parent-context.md to understand the conversation, then suggest what the user might want to do next (continue a task, respond to Claude's question, etc.)
2. **Spell checking**: Fix any spelling errors throughout the prompt
3. **Context investigation**: Replace sections marked with *** text *** or <<< text >>> with investigated details:
   - File references → file paths and line numbers
   - Feature descriptions → architecture context
   - Bug reports → related code patterns
   - Questions → answers from the codebase

Use Read, Grep, Glob, Bash tools to gather concrete details. Write the enhanced prompt back to $PROMPT_FILE.
EOF

# Extract parent context (conversation history)
bash "$SCRIPT_DIR/extract-parent-context.sh" > "$OUTPUT_DIR/parent-context.md" 2>/dev/null || echo "No parent context available" > "$OUTPUT_DIR/parent-context.md"

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
