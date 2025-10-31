# Project Brief: Claude Editor Hook

## What This Is

A command palette for Claude Code that intercepts `Ctrl-G` to provide an extensible FZF menu with editors, tools, and specialized enhancement agents - plus a persistent tmux workspace for long-running tasks.

## The Core Idea

When you press `Ctrl-G` in Claude Code to edit a prompt, the `$EDITOR` environment variable determines what launches. By pointing `$EDITOR` to our wrapper script, we intercept that hook and provide an interactive menu that can:

- **Launch editors** - Emacs, Vi, Nano for quick edits
- **Open workspace** - Full bash shell with `$PROMPT` env var
- **Recent Files** - Query last 25 files Claude touched (via JSONL parsing)
- **Enhance prompts** - Spawn Claude subagents with rich parent context
- **Detach/return** - Flexible workflow control

## How It Works

```
User hits Ctrl-G in Claude Code
    ↓
Claude Code launches $EDITOR
    ↓
$EDITOR = ~/.local/bin/claude-editor-hook
    ↓
Hook creates/attaches to persistent "Claude" tmux session
    ↓
FZF menu appears with 8 options:
  • Edit with Emacs/Vi/Nano
  • Open Terminal
  • Recent Files (JSONL-based)
  • Detach
  • Enhance (Interactive/Non-interactive)
    ↓
User selection executes → Returns to Claude Code when done
```

## Current Features (Working Now)

### FZF Command Palette
- **Session Persistence** - Always uses tmux session named "Claude"
- **Unified Menu System** - Shared `lib/menu-core.sh` for consistency
- **Extensible** - Add new options by editing menu definition

### Recent Files Integration
- **Direct JSONL Parsing** - Reads `~/.claude/projects/` session logs
- **Intelligent Caching** - First run ~1s, subsequent runs <100ms
- **Zero Dependencies** - No external daemons required
- **Preview with batcat** - Syntax-highlighted file preview in FZF

### Subagent Context Packages
- **Parent Context Awareness** - Subagents see last 15 conversation turns
- **Tool Usage Tracking** - Know what files were read/edited/written
- **File-based IPC** - Clean interface, no shell escaping issues
- **Auto-generated** - Context package created automatically on spawn

### Workspace Features
- **Terminal Access** - `$PROMPT` env var points to prompt file
- **Menu Alias** - Type `menu` to reopen command palette
- **Persistent Windows** - Create additional tmux windows for parallel work

## Architecture

**Entry Point:** `bin/claude-editor-hook` (Pattern 2 - FZF menu)

**Shared Logic:** `lib/menu-core.sh` - Single source of truth for menu

**Helper Scripts:**
- `lib/scripts/query-recent-files-jsonl.sh` - Parse JSONL logs with caching
- `lib/scripts/create-subagent-context.sh` - Build context packages
- `lib/scripts/extract-parent-context.sh` - Extract conversation history

**Config:** Project or global `.claude-editor-hook.conf` (sets PATTERN)

## Use Cases (Working Now)

**Prompt Enhancement:**
- Hit Ctrl-G → "Enhance (Interactive)"
- Claude subagent opens with full conversation context
- Investigates codebase, rewrites prompt with specifics
- Exit returns enhanced prompt to parent session

**Recent Files Access:**
- Hit Ctrl-G → "Recent Files"
- See last 25 files touched across all sessions
- FZF picker with batcat preview
- Select → View or Edit

**Terminal Workspace:**
- Hit Ctrl-G → "Open Terminal"
- Full bash shell with `$PROMPT` env var
- Type `menu` to reopen palette
- Run commands, edit files, explore codebase

**Quick Edits:**
- Hit Ctrl-G → "Edit with Emacs/Vi/Nano"
- Traditional editor workflow

## Future Exploration

**Multi-Agent Orchestration** (research phase):
- Persistent specialized agents (Planning, Coding, Testing)
- Chief of Staff pattern for workflow delegation
- See `memory-bank/01-architecture/multi-agent-orchestration-exploration.md`

**Context File System** (deferred):
- Original vision of YAML-driven multi-file opening
- May revisit if use cases emerge
- Command palette proved more flexible in practice

## Project Status

**Current:** ✅ Feature-complete command palette with 8 working options

**Recent:** JSONL migration, menu unification, context packages (Oct 2025)

**Exploring:** Multi-agent orchestration patterns (speculative)
