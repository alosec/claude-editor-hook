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

## Parallel Instance Pattern (Ctrl+G Hijacking)

**The Meta-Pattern**: Hijacking Claude Code's Ctrl+G editor hook to spawn parallel Claude instances that communicate via shared files.

### How It Works (The Weird Part)

**Normal Claude Code Ctrl+G flow:**
1. User hits Ctrl+G → Opens `$EDITOR` on prompt file
2. User edits in editor → Saves and closes
3. Editor process terminates → Claude Code recaptures control
4. Edited prompt appears in chat input

**What we're doing (Ctrl+G hijacking):**
1. Set `$EDITOR` to our wrapper script (`claude-editor-hook`)
2. User hits Ctrl+G → Claude Code spawns wrapper with temp prompt file
3. Wrapper launches tmux session with command palette
4. User can choose various actions, including "Enhance (Interactive)"
5. This spawns a **parallel Claude instance** (not child/subagent - full interactive instance)
6. Parallel instance has access to the prompt file ({{FILE}})
7. Parallel instance investigates, modifies the file, then exits
8. When parallel instance exits → tmux closes → wrapper terminates
9. **Claude Code captures file contents** on editor process termination
10. File contents appear as next prompt in TUI input

**Key insight:** The prompt file is a **write-only communication channel** from parallel instance to Claude Code's TUI. The parent Claude instance never reads the file - Claude Code itself captures it when the editor process ends.

### What Makes This Different from Subagents

- **Not a subagent**: This is a full interactive Claude instance (you could hit Ctrl+G again from it)
- **File-based communication**: Parallel instance writes to file → Claude Code TUI reads on process exit
- **Process lifecycle**: Control flow managed by process termination, not API calls
- **Parallel not hierarchical**: More like spawning a coworker than delegating to a child
- **One-way channel**: Parallel instance → File → Claude Code TUI (parent instance never sees the file)

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

- **Reduces cognitive load**: User types minimal prompt, parallel instance enhances it
- **Better first-time execution**: Next Claude session has all needed context upfront
- **Investigative separation**: Enhancement work happens in separate context window
- **Iterative refinement**: Can hit Ctrl+G multiple times to refine prompt before submitting
- **Context efficiency**: Parent session stays clean, investigation happens elsewhere

### Pattern 2: FZF Command Palette

Pattern 2 provides an extensible FZF-based menu with multiple capabilities:

**Menu Options:**
- **Edit with Emacs/Vi/Nano** - Open prompt file in chosen editor
- **Open Terminal** - Drop into bash with `$PROMPT` env var set
- **Recent Files** - Query mem-sqlite for last 25 files touched by Claude
- **Detach** - Exit cleanly back to Claude Code
- **Enhance (Interactive/Non-interactive)** - Spawn parallel Claude instance

### Recent Files Integration (mem-sqlite)

**Overview:**
The "Recent Files" menu option queries the mem-sqlite database to show the last 25 files Claude touched in recent sessions, enabling quick access to recently read/edited files without searching.

**Architecture:**
```
User selects "Recent Files"
  ↓
Query mem-sqlite database (~/. local/share/memory-sqlite/claude_code.db)
  ↓
Extract file_path from tool_uses where toolName IN ('Read', 'Edit', 'Write')
  ↓
Show FZF picker with batcat preview
  ↓
User selects file → Open with emacs
```

**SQL Query Design:**
```sql
SELECT DISTINCT
  json_extract(tu.parameters, '$.file_path') AS file_path,
  MAX(tu.created) AS last_touched
FROM tool_uses tu
WHERE
  tu.toolName IN ('Read', 'Edit', 'Write')
  AND json_extract(tu.parameters, '$.file_path') IS NOT NULL
  AND json_extract(tu.parameters, '$.file_path') != ''
GROUP BY file_path
ORDER BY last_touched DESC
LIMIT 25;
```

**Implementation Files:**
- `lib/scripts/query-recent-files.sh` - Bash wrapper for SQLite query
- `bin/claude-editor-hook` lines 78-110 - FZF menu handler
- Database: `~/.local/share/memory-sqlite/claude_code.db`

**Requirements:**
- mem-sqlite must be installed and synced: `cd ~/code/mem-sqlite && npm run cli sync`
- batcat for file previews (falls back gracefully if missing)

**Features:**
- FZF fuzzy search across file paths
- Live preview with syntax highlighting (batcat)
- Graceful error handling for missing database
- Handles non-existent files (historical paths)

### Implementation (Pattern 2)

When user selects "Enhance (Interactive)" from the fzf menu:

```bash
# Load prompt template and substitute file path
PROMPT_TEMPLATE="$SCRIPT_DIR/../lib/prompts/enhancement-agent.txt"
PROMPT=$(sed "s|{{FILE}}|$FILE|g" "$PROMPT_TEMPLATE")

tmux new-window
tmux send-keys "cndsp '$PROMPT'" Enter
```

**Template file** (`lib/prompts/enhancement-agent.txt`):
The template now accurately describes the parallel instance reality - you're not just an "enhancement agent", you're a parallel Claude instance communicating via file-based IPC. See the template file for current instructions.

**Why use a template file:**
- Easy to edit and iterate on parallel instance instructions
- Separates instance behavior from bash script logic
- Enables customization without touching code
- Reusable pattern for different parallel instance jobs
- Template variables (currently `{{FILE}}`) can be extended as needed

### Beyond Prompt Enhancement: The Design Space

While the current template focuses on "investigate and enhance prompt", the parallel instance pattern enables much more:

**One-shot data collection:**
- "Copy the last 100 server logs into the prompt"
- "Grab browser console errors and write to prompt"
- "Get the current git diff and add to prompt"

**Command execution + piping:**
- User describes desired bash command → Parallel instance executes → Pipes output to prompt file
- Example: "Show me all TODOs in the codebase" → Instance runs grep → Writes results to file

**Multi-step investigation:**
- Gather context from multiple sources (logs, code, issues)
- Synthesize and summarize
- Write findings back to parent

**Interactive debugging:**
- Parent asks question → Parallel instance investigates → Writes answer
- Could even spawn multiple parallel instances for different investigation paths

**Context management efficiency:**
- Main instance stays clean (minimal context usage)
- Parallel instances do heavy investigation work
- Only summarized findings return to parent

See **editor-hook-12** (P1) for designing a flexible template system that supports these diverse use cases.

### The Template Abstraction Question (editor-hook-15)

**Core architectural decision:** What should the template tell the parallel instance?

**Current state:** Template is **prescriptive** - tells instance to "investigate and enhance prompt"
**Problem:** Too narrow for the diverse use cases the pattern enables

**Four design options:**

**Option 1: Minimal Informational (leading candidate)**
- Template explains the mechanism only
- "You're a parallel instance, {{FILE}} is your return channel, use it however you need"
- Parallel instance is fully interactive - user chats naturally with it
- Maximum flexibility, minimal constraints

**Option 2: Task-Based Templates**
- Multiple templates: `lib/prompts/enhance.txt`, `execute.txt`, `investigate.txt`
- Each prescribes different job type
- Menu options map to specific templates
- More structure, easier to optimize per-task

**Option 3: Template with Parameters**
- Single template with variables: `{{FILE}}`, `{{TASK}}`, `{{CONTEXT}}`
- Wrapper passes task description as parameter
- Template interpolates task into instructions
- Structured but flexible

**Option 4: Hybrid**
- Minimal base explaining mechanism
- Optional task overlay passed as additional context
- Best of both: flexibility + structure when needed

**Key insight:** The parallel instance pattern is fundamentally an **"escape hatch to fresh Claude context with write-to-TUI mechanism"**. Everything else (what the instance does) is application-specific.

**Template's true job:**
1. Explain you're in a parallel instance (not parent, not subagent)
2. Identify the communication channel ({{FILE}} → Claude Code TUI on exit)
3. Clarify the lifecycle (read input → do work → write output → exit → TUI captures)
4. NOT prescribe what "do work" means

**Critical mechanism detail:** The file is not read by the parent Claude instance. When the parallel instance exits, Claude Code itself captures the file contents and populates the TUI prompt input with that string. This is the standard editor-save-close behavior that we're hijacking.

**Design tension:**
- **Too directive** → Limits use cases, requires multiple templates or complex logic
- **Too minimal** → Parallel instance might not understand task, waste tokens exploring
- **Sweet spot** → Explain mechanism + trust instance to read task from file/context

**Current lean:** Option 1 (minimal informational) with task description written to {{FILE}} by parent or user.

**Next steps:**
- Draft minimal informational template
- Test with different use cases (enhance, execute, investigate)
- Measure if parallel instance "gets it" without directive guidance
- Document patterns that emerge

### Related Issues

- **editor-hook-15**: Explore template abstraction (P1) - This architectural decision
- **editor-hook-10**: Update enhancement-agent.txt to reflect parallel instance reality (P2)
- **editor-hook-12**: Design flexible template system (P1) - Implementation of chosen approach
- **editor-hook-13**: Add "Execute Command & Pipe" menu option (P2) - Test case for flexibility
- editor-hook-19: Prompt enhancement agent implementation
- editor-hook-14: Use Claude CLI for dynamic menu options
- editor-hook-16: Drawer-style popup with Claude CLI

## Future Enhancements

**MCP Integration**: Create MCP tool for Claude to write context files directly (no file I/O)

**Session History**: Track context files over time, allow replay

**Smart Defaults**: If no context file, inspect git diff and open changed files

**Browser Integration**: Capture browser console logs, show in launcher

**Multi-project**: Context files per project in `.claude/editor-context.yaml`
