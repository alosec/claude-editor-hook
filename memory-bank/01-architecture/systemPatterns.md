# System Architecture

## Current Architecture (Pattern 2 - FZF Command Palette)

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
│  • Creates/attaches to persistent "Claude" tmux session     │
│  • Loads lib/menu-core.sh                                   │
│  • Shows FZF menu with 8 options                            │
└─────────────────────────────────────────────────────────────┘
                          ↓
       ┌─────────────────┼─────────────────┬──────────────────┐
       ↓                 ↓                  ↓                  ↓
┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│ Editors      │  │ Terminal     │  │ Recent Files │  │ Enhancement  │
│ (Emacs/Vi)   │  │ Workspace    │  │ (JSONL)      │  │ Agents       │
├──────────────┤  ├──────────────┤  ├──────────────┤  ├──────────────┤
│ Edit prompt  │  │ Full shell   │  │ FZF picker   │  │ Context-     │
│ file         │  │ with $PROMPT │  │ + batcat     │  │ aware subs   │
└──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘
```

## Hook Flow

**Normal Ctrl-G flow:**
1. User hits Ctrl-G → Claude Code spawns `$EDITOR` with temp prompt file
2. Editor opens → User edits → Saves and closes
3. Editor process terminates → Claude Code reads file contents
4. File contents appear in Claude Code prompt input

**Our intercepted flow:**
1. `$EDITOR = ~/.local/bin/claude-editor-hook`
2. Hook creates/attaches persistent tmux session named "Claude"
3. FZF menu appears with 8 options
4. User selects action → Executes → Process terminates
5. Claude Code reads file contents (if modified)
6. User returns to Claude Code session

## Unified Menu System

**Single Source of Truth:** `lib/menu-core.sh`

Both entry points use the same menu logic:
- `bin/claude-editor-hook` - Main Ctrl-G hook (Pattern 2)
- `bin/claude-editor-menu` - Standalone menu command

**Menu Definition:**
```bash
show_menu() {
    local FILE="$1"

    local MENU="Edit with Emacs:emacs -nw \"$FILE\"
Edit with Vi:vi \"$FILE\"
Edit with Nano:nano \"$FILE\"
Open Terminal:open-terminal
Recent Files:recent-files
Detach:detach
Enhance (Interactive):claude-spawn-interactive
Enhance (Non-interactive):claude-enhance-auto"

    # FZF selection → Command execution
}
```

**Benefits:**
- Add menu option once → Available everywhere
- Consistent behavior across entry points
- Easy to maintain and extend

## Session Persistence

**Pattern:** Always use tmux session named "Claude"

**Lifecycle:**
1. First Ctrl-G: Creates session "Claude" with menu
2. User detaches or completes action → Returns to Claude Code
3. Next Ctrl-G: Reattaches to existing "Claude" session
4. Windows persist between invocations

**Implementation:**
```bash
SESSION_NAME="Claude"

if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    # Respawn window 1 with fresh menu
    tmux respawn-window -t "$SESSION_NAME:1" -k bash -c "$MENU_CMD"
    # Attach to session
    exec tmux attach -t "$SESSION_NAME"
else
    # Create new session with menu
    exec tmux new-session -s "$SESSION_NAME" bash -c "$MENU_CMD"
fi
```

**Why simple session name:**
- No project-based hashing complexity
- Easy to understand and debug
- User can create additional windows for parallel work
- Type `menu` from any window to reopen palette

## Recent Files Integration (JSONL-Based)

**Overview:**
Direct JSONL parsing replaces mem-sqlite dependency, providing zero-config Recent Files access with intelligent caching.

**Architecture:**
```
User selects "Recent Files"
  ↓
lib/scripts/query-recent-files-jsonl.sh
  ↓
Read ~/.claude/projects/<project>/calls/*.jsonl
  ↓
Parse Read/Edit/Write tool invocations with jq
  ↓
Cache results in lib/cache/recent-files-*.json
  ↓
FZF picker with batcat preview
  ↓
User selects → View/Edit choice
```

**Parsing Strategy:**
```bash
# Extract file paths from JSONL tool_use blocks
jq -r 'select(.type == "tool_use") |
       select(.name == "Read" or .name == "Edit" or .name == "Write") |
       .input.file_path' calls/*.jsonl

# Group by file path, keep most recent timestamp
# Return top 25 files
```

**Caching Logic:**
- First run: ~1s (parses last 5000 lines from each JSONL)
- Subsequent runs: <100ms (cached until JSONL mtimes change)
- Cache key: Combined modification times of source JSONL files
- Cache location: `lib/cache/recent-files-<project-hash>.json`

**Benefits over mem-sqlite:**
- Zero external dependencies
- Always current (reads actual session logs)
- No daemon management required
- Better performance with caching
- Simpler architecture

**Implementation Files:**
- `lib/scripts/query-recent-files-jsonl.sh` - JSONL parser with caching
- `lib/cache/` - Per-project cache storage
- `lib/menu-core.sh` lines 49-91 - Menu integration

## Subagent Context Package System

**Overview:**
When spawning interactive Claude instances ("Enhance Interactive"), automatically create context packages with parent conversation history, tool usage, and recent files.

**Context Package Structure:**
```
/tmp/claude-subagent-{PID}/
├── system-prompt.txt     # Instructions + output file path
├── parent-context.md     # Last 15 conversation turns
├── recent-files.txt      # 25 most recently touched files
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

**Generation Process:**
1. Extract last 15 conversation turns from JSONL logs
2. Parse tool_use blocks to extract file operations
3. Query recent files list (reuses JSONL parsing)
4. Create temp directory with all context files
5. Launch Claude with system prompt pointing to output file

**Implementation Files:**
- `lib/scripts/create-subagent-context.sh` - Orchestrates package creation
- `lib/scripts/extract-parent-context.sh` - Parses JSONL conversation history
- `lib/menu-core.sh` lines 99-125 - Integration with "Enhance (Interactive)"

**Benefits:**
- Subagents understand conversation context
- Know what files were recently touched
- See what tools were used (Read/Edit/Bash/etc)
- File-based interface (no shell escaping issues)
- Clean separation of concerns

## Parallel Instance Pattern (The Core Mechanism)

**Key Insight:** The Ctrl-G hook creates a bidirectional communication channel:
- Parent → Parallel: Via prompt file contents (initial state)
- Parallel → Claude Code TUI: Via prompt file (final state when process exits)

**Critical Detail:** The parent Claude instance never reads the file. When the parallel instance exits, **Claude Code itself** captures the file contents and populates the TUI prompt input.

**Flow:**
1. Parent Claude receives user input
2. User hits Ctrl-G → Claude Code spawns `$EDITOR` with temp file
3. Our hook intercepts, shows menu
4. User chooses "Enhance (Interactive)"
5. New Claude instance spawns with:
   - System prompt explaining mechanism
   - Parent context (conversation + tools + files)
   - Access to prompt file path
6. Parallel instance investigates, enhances, writes to file
7. Parallel instance exits → Hook process terminates
8. Claude Code captures file contents
9. Enhanced prompt appears in parent's TUI input

**What This Enables:**
- Investigation in separate context window
- Parent session stays clean (context efficiency)
- Iterative refinement (can Ctrl-G multiple times)
- Rich enhancement (subagent has conversation context)

**Not a Subagent:**
- Full interactive Claude instance (could Ctrl-G from it)
- File-based IPC (not API delegation)
- Process lifecycle management (not hierarchical)
- Parallel not child-parent relationship

## Directory Structure (Current)

```
claude-editor-hook/
├── bin/
│   ├── claude-editor-hook         # Main entry point (Pattern 2)
│   ├── claude-editor-menu         # Standalone menu
│   └── claude-editor-hook.backup-patterns  # Legacy patterns
├── lib/
│   ├── menu-core.sh              # Unified menu system ← Core
│   ├── nested-tmux.conf          # Tmux config for nested sessions
│   ├── cache/                    # JSONL parsing cache
│   │   └── recent-files-*.json
│   └── scripts/
│       ├── query-recent-files-jsonl.sh       # JSONL parser
│       ├── query-recent-files.sh             # mem-sqlite (legacy)
│       ├── create-subagent-context.sh        # Context packages
│       └── extract-parent-context.sh         # JSONL conversation parser
├── memory-bank/
│   └── ...                       # Documentation
├── install.sh                    # Installation with git metadata
└── README.md                     # User documentation
```

## Key Design Decisions

**FZF Command Palette over YAML Orchestration:**
- Original vision: Claude writes YAML files → Launcher dispatches
- Reality: Interactive menu proved more flexible and user-controlled
- YAML pattern deferred, may revisit if use cases emerge

**Direct JSONL Parsing over mem-sqlite:**
- Eliminates external daemon dependency
- Always current (reads actual session logs)
- Caching provides better performance
- Simpler architecture, fewer moving parts

**Unified Menu System:**
- Single source of truth (`lib/menu-core.sh`)
- Consistent behavior across entry points
- Easy to extend with new options

**Simple Session Persistence:**
- Always use session named "Claude"
- No project-based hashing
- User can create additional windows
- Clean, understandable model

**Subagent Context Packages:**
- File-based IPC (avoids shell escaping)
- Auto-generated on spawn
- Rich context (conversation + tools + files)
- Clean separation of concerns

## Extensibility Model

**Adding Menu Options:**

Edit `lib/menu-core.sh` menu definition:
```bash
local MENU="Edit with Emacs:emacs -nw \"$FILE\"
...
New Option:new-command"
```

Add command handler in case statement:
```bash
case "$cmd" in
    new-command)
        # Implementation
        ;;
esac
```

**Examples of Future Options:**
- Git operations (`git log | fzf`)
- Log streaming (`tail -f /var/log/app.log`)
- Database queries
- Test runners (`npm test --watch`)
- Browser DevTools integration

## Related Explorations

**Multi-Agent Orchestration (Research):**
- See `memory-bank/01-architecture/multi-agent-orchestration-exploration.md`
- Persistent specialized agents (Planning, Coding, Testing)
- Chief of Staff delegation pattern
- Status: Speculative, not implemented

**YAML Context System (Deferred):**
- Original vision documented in command-palette-paradigm.md
- Archived to history - command palette proved sufficient
- May revisit if multi-file opening use cases emerge

## Performance Characteristics

**Recent Files:**
- First query: ~1s (JSONL parsing)
- Cached queries: <100ms
- Cache invalidation: On JSONL mtime change

**Context Packages:**
- Generation time: ~500ms (15 messages + recent files)
- Minimal overhead for spawning subagents

**Session Persistence:**
- Session creation: ~200ms
- Session reattach: ~50ms
- No noticeable delay in Ctrl-G flow
