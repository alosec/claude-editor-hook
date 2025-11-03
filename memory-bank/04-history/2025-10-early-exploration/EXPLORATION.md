# UX Pattern Exploration

## Testing Flow
1. Edit `bin/claude-editor-hook`
2. Hit Ctrl-G in Claude Code
3. Check `/tmp/claude-editor-hook.log`
4. Observe behavior
5. Iterate!

## Patterns to Explore

### Pattern A: Menu-First
- Open tmux session
- Show display-menu immediately
- User picks editor
- Launch that editor

### Pattern B: Session-as-Workspace
- Open tmux session with default view (nano? batcat?)
- Bind tmux key (like Ctrl-e) to show menu
- User can switch editors/viewers on the fly
- Session persists as the "editor workspace"

### Pattern C: Split Panes
- Open tmux with split layout
- Top pane: context viewer (batcat)
- Bottom pane: prompt editor (nano)
- Menu to swap modes

### Pattern D: Simple Default + Menu Escape Hatch
- Default to nano (working pattern)
- Special escape sequence (like Ctrl-A m) shows menu
- Can switch to different tools without exiting

## Current Status
Testing with logs enabled...
