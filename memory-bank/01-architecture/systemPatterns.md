# System Architecture

## Hook Flow

```
┌─────────────────────────────────────────────────────────────┐
│  Claude Code Session                                        │
│  • User hits Ctrl-G to edit prompt                          │
│  • Claude Code looks up $EDITOR                             │
│  • Launches: claude-editor-hook [temp-file]                 │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│  Main Wrapper (bin/claude-editor-hook)                      │
│  • Reads ~/.claude/editor-context.yaml                      │
│  • Parses mode, files, options                              │
│  • Dispatches to appropriate launcher                       │
└─────────────────────────────────────────────────────────────┘
                          ↓
       ┌─────────────────┼─────────────────┐
       ↓                 ↓                  ↓
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│ launcher-    │  │ launcher-    │  │ launcher-    │
│ emacs.sh     │  │ batcat.sh    │  │ menu.sh      │
├──────────────┤  ├──────────────┤  ├──────────────┤
│ Open files   │  │ Display      │  │ Show menu    │
│ at line #s   │  │ previews     │  │ with options │
└──────────────┘  └──────────────┘  └──────────────┘
```

## Context File Schema

The context file (`~/.claude/editor-context.yaml`) defines what happens on Ctrl-G:

```yaml
# Mode determines which launcher to use
mode: emacs | batcat | menu | tmux | custom

# Files to open/display with optional line numbers
files:
  - path: /path/to/file.js
    line: 42
    description: "Function to review"
  - path: /path/to/other.py
    line: 108

# Commands to run (for tmux mode)
commands:
  - name: "Server logs"
    cmd: "tail -f /var/log/server.log"
  - name: "Tests"
    cmd: "npm test -- --watch"

# Menu options (for menu mode)
menu:
  - label: "Edit in emacs"
    action: emacs
    files: [...]
  - label: "View with batcat"
    action: batcat
    files: [...]
  - label: "Show logs"
    action: tmux
    commands: [...]

# Custom launcher script (for custom mode)
custom_launcher: /path/to/custom-script.sh

# Metadata
created_by: claude
timestamp: 2025-10-29T14:30:00Z
session_id: abc123
```

## Launcher Interface

All launchers follow the same interface:

**Input**:
- Context file path as argument: `launcher-emacs.sh ~/.claude/editor-context.yaml`
- Or parsed values from wrapper

**Output**:
- Launch appropriate tool (emacs, batcat, fzf, tmux)
- Block until user exits
- Exit code 0 on success

**Responsibilities**:
- Parse context file (or receive parsed data)
- Validate required fields
- Launch tool with correct arguments
- Handle errors gracefully

## Directory Structure

```
claude-editor-hook/
├── bin/
│   └── claude-editor-hook       # Main entry point (symlinked to ~/.local/bin)
├── lib/
│   ├── config-reader.sh         # Parse YAML/JSON with yq/jq
│   ├── launcher-emacs.sh        # Emacs launcher
│   ├── launcher-batcat.sh       # Batcat launcher
│   ├── launcher-menu.sh         # fzf/dialog menu
│   ├── launcher-tmux.sh         # tmux orchestration
│   └── utils.sh                 # Shared utilities
├── templates/
│   └── context-schema.yaml      # Example for Claude to reference
└── memory-bank/
    └── ...                       # Documentation
```

## Key Design Decisions

**YAML over JSON**: More human-readable, easier for Claude to write, supports comments

**Bash for MVP**: Fast to iterate, no dependencies beyond standard tools (yq, jq)

**Launcher Plugins**: Each launcher is independent script, easy to add new ones

**Context File Location**: `~/.claude/editor-context.yaml` is well-known location Claude can write to

**Graceful Fallback**: If context file doesn't exist or is invalid, fall back to plain emacs

## Prompt Enhancement Agent Pattern (Pattern 2 + "Open in Claude")

**The Meta-Pattern**: Using Ctrl-G to spawn a parallel Claude instance that enhances your prompt.

### How It Works

1. **User writes rough prompt** in Claude Code (e.g., "Fix auth")
2. **User hits Ctrl-G** → Pattern 2 menu appears
3. **User selects "Open in Claude"** from fzf menu
4. **New Claude instance spawns** with specialized prompt enhancement instructions
5. **Enhancement agent investigates**:
   - Reads the rough prompt from the temp file
   - Searches codebase for relevant files
   - Checks Beads issues for related tasks
   - Reviews recent commits
   - Identifies patterns and dependencies
6. **Agent rewrites prompt** with:
   - Specific file paths and line numbers
   - Context from relevant code sections
   - Links to related Beads issues
   - Actionable implementation details
7. **Agent saves enhanced prompt** back to the temp file and exits
8. **Control returns to original Claude** with the enhanced prompt ready to execute

### Example Flow

**User's rough input:**
```
Fix auth
```

**After enhancement agent:**
```markdown
Fix authentication bug in website/src/middleware/auth.ts:42

Context:
- Issue: editor-hook-85 (Auth middleware failing on token refresh)
- Related files:
  - website/src/middleware/auth.ts:42 (token validation logic)
  - website/src/lib/supabase.ts:108 (client initialization)
- Recent commit 29a4906 touched auth flow
- Pattern: Use supabase.auth.getSession() not getUser() for middleware

Implementation:
1. Update auth.ts:42 to use getSession() instead of getUser()
2. Add null check for session.user
3. Update error handling to return 401 with proper message
```

### Benefits

- **Reduces cognitive load**: User types minimal prompt, gets fully contextualized task
- **Better first-time execution**: Original Claude has all needed context upfront
- **Investigative separation**: Enhancement work happens in separate context window
- **Iterative refinement**: Can reopen in Claude multiple times to refine prompt

### Implementation (Pattern 2)

When user selects "Open in Claude" from the fzf menu:

```bash
tmux new-window
tmux send-keys "cndsp 'You are a prompt enhancement agent. The file $FILE contains a rough prompt from a user working with Claude Code. Your job: 1) Read the prompt, 2) Investigate the codebase to find relevant context (files, Beads issues, patterns, recent commits), 3) Rewrite the prompt with specific file paths, line numbers, and actionable context, 4) Save the enhanced prompt back to $FILE. Make it detailed enough that the original Claude instance can act on it immediately without further investigation.'" Enter
```

### Related Issues

- editor-hook-19: Prompt enhancement agent implementation
- editor-hook-14: Use Claude CLI for dynamic menu options
- editor-hook-16: Drawer-style popup with Claude CLI

## Future Enhancements

**MCP Integration**: Create MCP tool for Claude to write context files directly (no file I/O)

**Session History**: Track context files over time, allow replay

**Smart Defaults**: If no context file, inspect git diff and open changed files

**Browser Integration**: Capture browser console logs, show in launcher

**Multi-project**: Context files per project in `.claude/editor-context.yaml`
