# Next Up: Prioritized Tasks

## Top 10 Tasks

### 1. Complete MVP Implementation (Priority 0)
Build emacs and batcat launchers to prove the concept works end-to-end.

### 2. Menu Launcher (Priority 1)
Interactive menu using `fzf` or `dialog` that presents numbered options. Claude can define the menu structure in context file.

### 3. Tmux Launcher (Priority 1)
Orchestrate tmux sessions with multiple panes: editor, logs, tests, etc. Most powerful for complex debugging scenarios.

### 4. Log Streaming Integration (Priority 2)
Add ability to tail server logs, browser console, or any command output directly in the launcher.

### 5. MCP Tool for Context Writing (Priority 2)
Create an MCP server that gives Claude a tool to write context files directly (no file I/O). Makes Claude's job easier and faster.

### 6. Smart Fallback Mode (Priority 2)
When no context file exists, inspect `git diff` and automatically open changed files. Useful default behavior.

### 7. Git Diff Launcher (Priority 3)
Show diffs side-by-side in ediff or similar. Claude can specify which commits/branches to compare.

### 8. Browser DevTools Integration (Priority 3)
Capture and display browser console logs, network requests, or DOM state. Requires browser extension or CDP integration.

### 9. Session History & Replay (Priority 3)
Track all context files written during a day/week, allow user to replay previous views. Useful for "what was I looking at earlier?"

### 10. Per-Project Context Files (Priority 4)
Support `.claude/editor-context.yaml` in project directories, not just global `~/.claude/`. Allows per-project customization.

## Future Ideas (Not Prioritized)

- **AI-Generated Context**: Claude analyzes error messages and automatically prepares context with relevant files
- **Diff Highlighting**: When opening files, show only the lines that changed since last commit
- **Multi-User Coordination**: Share context files with team, "open what Alice was looking at"
- **Recording Mode**: Record all context changes during a debugging session, create timeline
- **Integration with Other Tools**: VS Code, Jupyter notebooks, database query tools, etc.

## Dependencies

- **MCP tool** requires understanding MCP SDK (probably Node.js or Python)
- **Browser integration** needs browser extension architecture
- **Tmux launcher** needs tmux installed and basic scripting knowledge

## Notes

Focus on MVP first. The real value comes from seeing it work in a real Claude Code session, then iterating based on actual usage patterns.
