# Session: Subagent Context Package System (2025-10-30)

**Status:** ✅ COMPLETE

## What We Shipped

Built a context package system that gives spawned Claude subagents (via "Enhance Interactive") rich awareness of the parent conversation, including recent messages, tool usage, and files touched.

## The Problem

When spawning interactive Claude instances for prompt enhancement:
- Subagents had no awareness of parent conversation
- Couldn't see what files were recently read/edited
- Didn't know what commands were run
- Had to guess at context

This limited their ability to enhance prompts intelligently.

## The Solution

**Context Package Structure:**
```
/tmp/claude-subagent-{PID}/
├── system-prompt.txt     # Instructions + output file path
├── parent-context.md     # Last 15 conversation turns with tool usage
├── recent-files.txt      # 25 most recently edited files
└── meta.json            # Metadata (working dir, timestamps)
```

**Parent Context Format:**
```markdown
## USER
[user message]

## ASSISTANT
[assistant response]

**Tools Used:**
- `Read` → /path/to/file.js
- `Edit` → /path/to/modified.ts
- `Bash` → Command description
- `Grep` → Pattern: search_term
```

## Files Changed

**Created:**
- `lib/scripts/create-subagent-context.sh` - Context package creation
- `lib/scripts/extract-parent-context.sh` - JSONL conversation parser

**Modified:**
- `lib/menu-core.sh` - Updated "Enhance (Interactive)" to create context package
- `README.md` - Documented context package feature

## Implementation Details

**JSONL Parsing for Context:**
```bash
# Extract last 15 conversation turns from JSONL logs
jq -r 'select(.type == "message") |
       {role: .role, content: .content, tool_uses: .tool_uses}' \
    ~/.claude/projects/-project-name/calls/*.jsonl
```

**Tool Usage Extraction:**
- Parses tool_use blocks from assistant messages
- Formats with clear markers: `Read →`, `Edit →`, `Bash →`
- Includes file paths and command descriptions

**Subagent Launch:**
```bash
CONTEXT_DIR=$(create-subagent-context.sh "$PROMPT_FILE")
claude --dangerously-skip-permissions \
    --system-prompt "$CONTEXT_DIR/system-prompt.txt" \
    < "$CONTEXT_DIR/parent-context.md"
```

## Key Learnings

**Benefits:**
1. **Context awareness** - Subagents understand what's happening
2. **Better enhancements** - Can reference recent work
3. **File-based injection** - No shell escaping issues
4. **Clean separation** - Context in temp directory

**Design Decision - Why Files?**
- Passing context via stdin avoids shell escaping complexity
- Temp directory keeps all context organized
- System prompt points to output file location
- Clean, debuggable interface

## Example Usage

**Before (blind subagent):**
```
User: Update authentication
Subagent: Which auth file? Where is it? What auth system?
```

**After (context-aware subagent):**
```
User: Update authentication
Subagent: I see you recently edited src/auth/middleware.ts and
read config/auth.config.js. Based on the conversation, you're
working on JWT token validation. I'll enhance the prompt to
reference the middleware bug at line 42...
```

## Commits

```
6dead6b feat: Add subagent context package system with rich parent context
```

## Related Features

- Works with "Enhance (Interactive)" menu option
- Complements Recent Files feature
- Uses same JSONL parsing infrastructure

## Impact

Interactive enhancement agents are now genuinely useful - they understand the broader context and can make intelligent suggestions based on recent work, not just the immediate prompt.
