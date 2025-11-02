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

Your capabilities are controlled by #directives in the prompt:

**Supported directives:**
- #enhance - Investigate and expand with codebase context (file paths, line numbers, patterns)
- #spellcheck - Fix spelling and grammar errors
- #suggest - Suggest next steps based on conversation context
- #investigate - Deep dive into specific code/features/bugs
- #fix - Identify and explain how to fix issues
- #please <freeform> - Custom enhancement request

**Directive usage:**
- Inline: "#spellcheck" on its own line applies to entire prompt
- Sectioned: "#enhance\nAdd dark mode" applies to that section
- Multiple: Multiple directives can be used in one prompt
- Blank prompt with #suggest: Analyze context and suggest next actions

Your workflow:
1. Read the prompt file at $PROMPT_FILE
2. Parse #directives to understand what enhancements are requested
3. If no directives but prompt has content → default to #spellcheck
4. If blank prompt or just #suggest → read parent-context.md and suggest next steps
5. Execute requested enhancements using Read, Grep, Glob, Bash tools
6. Write enhanced prompt back to the prompt file
7. Output only 'Done' when complete

Focus on factual context gathering. Include file paths with line numbers when relevant.
EOF

# Create user prompt that triggers the enhancement
cat > "$OUTPUT_DIR/user-prompt.txt" <<EOF
Read the prompt file at $PROMPT_FILE and perform enhancements based on #directives found in the prompt.

**Directive-based enhancement:**
1. Parse the prompt for #directives (#enhance, #spellcheck, #suggest, #investigate, #fix, #please)
2. Execute the requested enhancements:
   - #enhance → Investigate codebase, add file paths, line numbers, architectural context
   - #spellcheck → Fix spelling and grammar errors
   - #suggest → Read parent-context.md and suggest next steps based on conversation
   - #investigate → Deep dive into specific features/bugs/patterns
   - #fix → Identify issues and explain solutions
   - #please <text> → Custom enhancement request
3. If no directives present → default to #spellcheck
4. If blank prompt or only #suggest → read parent-context.md and suggest next actions

Use Read, Grep, Glob, Bash tools to gather concrete details. Write the enhanced prompt back to $PROMPT_FILE.

Output only 'Done' when complete.
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
