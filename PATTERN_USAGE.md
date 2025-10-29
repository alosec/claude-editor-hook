# Editor Hook Pattern Usage

The `claude-editor-hook` script now supports 8 different patterns for launching editors. You can select which pattern to use by setting the `EDITOR_HOOK_PATTERN` environment variable.

## Setting the Pattern

### For Claude Code settings.json:
```json
{
  "editor_hook": {
    "path": "/home/alex/code/claude-editor-hook/bin/claude-editor-hook",
    "env": {
      "EDITOR_HOOK_PATTERN": "1"
    }
  }
}
```

### For current session only:
```bash
export EDITOR_HOOK_PATTERN=1
```

## Available Patterns

### Pattern 1: Simple Emacs (DEFAULT)
**Best for:** Quick, reliable editing
```bash
export EDITOR_HOOK_PATTERN=1
```
- Launches emacs directly in tmux session
- Just like the working nano pattern
- Clean and simple, no menu

### Pattern 2: FZF Popup Menu
**Best for:** Fuzzy search enthusiasts (requires fzf)
```bash
export EDITOR_HOOK_PATTERN=2
```
- Shows fuzzy-searchable menu
- Choose: Emacs, Vi, Nano, or Batcat
- VSCode-like command palette UX

### Pattern 3: Persistent Session
**Best for:** Workspace-style editing
```bash
export EDITOR_HOOK_PATTERN=3
```
- Session persists across invocations
- Reattaches to same editor session
- Good for long editing sessions

### Pattern 4: Default + Menu Hotkey
**Best for:** Power users who want options
```bash
export EDITOR_HOOK_PATTERN=4
```
- Launches emacs by default
- Press Ctrl-A m to show menu and switch tools
- Can switch between Emacs, Vi, Nano, Batcat mid-session

### Pattern 5: Interactive Menu
**Best for:** Simple, visual choice
```bash
export EDITOR_HOOK_PATTERN=5
```
- Shows text menu on launch
- Press e/v/n/b to choose editor
- No external dependencies

### Pattern 6: Pre-launch Bash Select
**Best for:** Reliability, no tmux dependencies for menu
```bash
export EDITOR_HOOK_PATTERN=6
```
- Shows numbered menu before tmux launches
- Most reliable pattern
- Easy to debug

### Pattern 7: Run-shell Menu
**Best for:** Debugging tmux display-menu issues
```bash
export EDITOR_HOOK_PATTERN=7
```
- Uses run-shell for command execution
- Creates wrapper scripts
- Advanced debugging pattern

### Pattern 8: Hybrid Respawn
**Best for:** Creative workflows
```bash
export EDITOR_HOOK_PATTERN=8
```
- Shows menu, respawns pane with selection
- Complex but flexible
- Experimental pattern

## Testing Patterns

To test a pattern:
1. Set the environment variable
2. Press Ctrl-G in Claude Code
3. Check `/tmp/claude-editor-hook.log` to see which pattern was used

```bash
# Test Pattern 1
export EDITOR_HOOK_PATTERN=1
# Now press Ctrl-G in Claude Code

# Check the log
tail -20 /tmp/claude-editor-hook.log
```

## Logging

All patterns log to `/tmp/claude-editor-hook.log`:
- Timestamp
- Arguments (temp file path)
- TMUX variable state
- **Which pattern is being used**

Example log output:
```
=== Wed Oct 29 04:31:31 UTC 2025 ===
Args: /tmp/claude-prompt-88d831d3-2666-471f-b730-e565d7edd480.md
TMUX: /tmp/tmux-1000/default,2047504,0
Using pattern: 1
Pattern 1: Simple emacs exec
```

## Recommended Patterns

- **Start with Pattern 1** (Simple Emacs) - Most reliable, works like nano
- **Try Pattern 2** (FZF) - Best UX if you have fzf installed
- **Use Pattern 6** (Bash Select) - Most reliable if Pattern 2 doesn't work
- **Advanced users:** Pattern 4 (Hotkey menu) for maximum flexibility

## Default Behavior

If `EDITOR_HOOK_PATTERN` is not set, or is set to an invalid value, the script defaults to **Pattern 1** (Simple Emacs).
