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

## Future Enhancements

**MCP Integration**: Create MCP tool for Claude to write context files directly (no file I/O)

**Session History**: Track context files over time, allow replay

**Smart Defaults**: If no context file, inspect git diff and open changed files

**Browser Integration**: Capture browser console logs, show in launcher

**Multi-project**: Context files per project in `.claude/editor-context.yaml`
