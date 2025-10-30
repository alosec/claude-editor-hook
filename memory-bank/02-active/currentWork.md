# Current Work: Command Palette Implementation (In Progress)

**Status**: 🔄 Pattern 2 working, command palette partially functional

**Branch**: `main`

## This Week's Focus

Implementing VS Code-style command palette for Claude Code's Ctrl-G hook:
1. ✅ **FZF menu on Ctrl-G** - Working! Shows Edit/Terminal/Enhance options
2. ✅ **Nested tmux session** - Pattern 2 creates isolated workspace with custom config
3. ✅ **Welcome message** - Shows `menu` command hint and $PROMPT variable
4. ✅ **Menu from within session** - Type `menu` to reopen command palette
5. ❌ **Keybinding** - Ctrl+backtick not working (menu alias is better solution)

The command palette paradigm is fully functional! Type `menu` from within the workspace to access all commands.

## What We've Done

**Foundation:**
- ✅ Created project repository at `~/code/claude-editor-hook`
- ✅ Initialized git with Beads issue tracker (prefix: `editor-hook`)
- ✅ Written memory bank foundation (projectbrief, systemPatterns)
- ✅ Working tmux launcher (unsets $TMUX for nesting)

**Pattern 2 - FZF Command Palette:**
- ✅ FZF menu on Ctrl-G with options: Edit (Emacs/Vi/Nano), Open Terminal, Detach, Enhance
- ✅ Nested tmux session with custom config (`lib/nested-tmux.conf`)
- ✅ Welcome message showing `menu` command and $PROMPT variable
- ✅ Fixed config leaking (session-local settings, no global pollution)
- ✅ Helper script `~/.local/bin/claude-editor-menu` (context-aware menu)
- ✅ Pattern 2 loads nested config with `tmux -f` flag
- ✅ **`menu` alias** - Type `menu` from terminal to reopen command palette (clean solution)

## What's Next

**Immediate** (P1):
1. **editor-hook-2** - Implement simple persistent "Claude" session (NEW APPROACH - TOP PRIORITY)
2. **editor-hook-3** - Fix session numbering (will be resolved by persistence)

**Then** (P2):
1. **editor-hook-4** - Generalize Claude prompt enhancement pattern
2. Context file reading - Parse `~/.claude/editor-context.yaml`
3. Configuration system - `.claude/editor-hook.yaml` (project + global)

**Future** (P3):
1. Hybrid tmux layouts - Split panes: context viewer + prompt editor
2. MCP tool - Let Claude write context files during sessions

## Key Implementation Details

**Pattern 2 Architecture** (`bin/claude-editor-hook`):
```bash
# 1. Load nested tmux config with custom keybindings
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NESTED_CONF="$SCRIPT_DIR/../lib/nested-tmux.conf"

# 2. Show FZF menu and create nested session
exec tmux -f "$NESTED_CONF" new-session bash -c "
    # Show menu, execute selection
    # Set $PROMPT for 'Open Terminal' mode
"
```

**Why Nested Sessions Work**:
- Unsets `$TMUX` to bypass tmux's nesting protection
- Creates isolated workspace with custom config (no pollution to main session)
- `$PROMPT` env var preserves file path for menu access
- When user exits (Detach), control returns cleanly to Claude Code

**Key Files**:
- `bin/claude-editor-hook` - Main entry point, dispatches to patterns
- `lib/nested-tmux.conf` - Nested session config (Ctrl+backtick binding)
- `~/.local/bin/claude-editor-menu` - FZF menu helper (context-aware)
- `~/.claude-editor-hook.conf` - Pattern selection (PATTERN=2)

## Recently Completed

**editor-hook-1**: Menu accessibility ✅ SOLVED (commit 16c5fe4)
- Implemented `menu` alias in Open Terminal mode
- Sources user's bashrc + adds alias automatically
- Simpler and more discoverable than keybinding
- Closed: Menu access now fully functional

## Current Issues & Blockers

**editor-hook-2**: Implement simple persistent "Claude" session (P1 - READY TO IMPLEMENT)
- Currently creates new session on each Ctrl-G
- **New simple approach**:
  - Always use session named "Claude"
  - If exists → attach
  - If not → create and attach
  - User can detach and reattach freely
- **Keep menu alias** (don't remove like experimental branch did)
- No complex project hashing - just one simple session name

## Notes

- Command palette paradigm is fully functional with `menu` alias!
- Config leaking is fixed - no more brown status bars or wrong prefix keys
- Keep nested session benefits: isolation, flexibility, tmux power
- `menu` command is more discoverable than Ctrl+backtick (shown in welcome message)
