# Current Work: Hello World POC Complete! 🎉

**Status**: ✅ Foundation working - tmux launcher successfully opens and saves

**Branch**: `mvp`

## This Week's Focus

Build interactive launcher system on top of working tmux foundation:
1. **Menu system** - Let user choose batcat/emacs/vim/nano for each invocation
2. **Config system** - Project-level and global configuration files
3. **Context dispatching** - Read context files and auto-select launcher mode

The tmux foundation is proven - now we build the smart layer on top.

## What We've Done

- ✅ Created project repository at `~/code/claude-editor-hook`
- ✅ Initialized git with Beads issue tracker (prefix: `editor-hook`)
- ✅ Written memory bank foundation (projectbrief, systemPatterns)
- ✅ **BREAKTHROUGH**: Working tmux launcher (unsets $TMUX for nesting)
- ✅ Verified temp file editing: Ctrl-G → nano → edit → save → returns to Claude Code
- ✅ Simplified script to 3 lines (bin/claude-editor-hook)

## What's Next

**Immediate** (P1 - on `mvp` branch):
1. Interactive menu launcher (editor-hook-9) - fzf/select menu to choose viewer/editor
2. Context file reading (editor-hook-3) - Parse `~/.claude/editor-context.yaml`
3. Sequential flow design (editor-hook-4) - Show context, then edit prompt

**Then** (P2):
1. Configuration system (editor-hook-10) - `.claude/editor-hook.yaml` (project) + `~/.claude/editor-hook.yaml` (global)
2. Hybrid tmux layouts (editor-hook-5) - Split panes: context viewer + prompt editor

**Future** (P3):
1. MCP tool (editor-hook-7) - Let Claude write context files during sessions

## Key Implementation Details

**Current Working Script** (`bin/claude-editor-hook`):
```bash
#!/usr/bin/env bash
unset TMUX  # Allow nesting tmux sessions
exec tmux new-session nano "$@"
```

**Why This Works**:
- Unsets `$TMUX` to bypass tmux's nesting protection
- Creates new tmux session running nano with the temp file
- When user exits nano (Ctrl-X), tmux session ends
- Control returns cleanly to Claude Code with saved changes

**Next: Menu System** (editor-hook-9):
- Add interactive menu before launching editor
- Options: batcat (view), nano (edit), vim (edit), emacs (edit)
- Use bash `select` (simple) or `fzf` (fancy) for menu

**Next: Context Reading** (editor-hook-3):
- Check for `~/.claude/editor-context.yaml`
- If exists: parse mode and auto-select launcher
- If not: show menu or use default

## Testing Approach

✅ **Proven**: Ctrl-G → nano opens → edit → save → returns to Claude Code
**Next**: Test with batcat viewer, vim, emacs

## Blockers

None! Foundation is solid.

## Notes

- **Keep it stupid simple** - The 3-line script works perfectly
- Don't overcomplicate unless there's a real need
- Each new feature should be additive, not rewriting what works
