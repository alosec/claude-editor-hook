# Next Up: Prioritized Tasks

**Updated**: 2025-10-30

## Top 10 Tasks

### 1. Implement simple persistent "Claude" session (Priority 1) - editor-hook-2
**NEW SIMPLE APPROACH**:
- Always use session named "Claude"
- Check if exists → attach, else create → attach
- Keep menu alias functionality
- No project-based hashing complexity

### 3. Fix session numbering (Priority 2) - editor-hook-3
**Will be resolved by #2**: Currently sessions increment on each Ctrl-G. Persistence will solve this.

### 4. Generalize Claude prompt enhancement pattern (Priority 2) - editor-hook-4
Create reusable pattern for spawning enhancement agents. Interactive and non-interactive modes both working, need to document pattern for future extensions.

### 5. Context file reading (Priority 2)
Parse `~/.claude/editor-context.yaml` to open multiple files at specific line numbers. Foundation for multi-file workflows.

### 6. MCP Tool for Context Writing (Priority 2)
Create an MCP server that gives Claude a tool to write context files directly (no file I/O). Makes Claude's job easier and faster.

### 7. Smart Fallback Mode (Priority 2)
When no context file exists, inspect `git diff` and automatically open changed files. Useful default behavior.

### 8. Log Streaming Integration (Priority 3)
Add ability to tail server logs, browser console, or any command output directly in the launcher.

### 9. Git Diff Launcher (Priority 3)
Show diffs side-by-side in ediff or similar. Claude can specify which commits/branches to compare.

### 10. Browser DevTools Integration (Priority 3)
Capture and display browser console logs, network requests, or DOM state. Requires browser extension or CDP integration.

## Additional Tasks (Lower Priority)

- **Session History & Replay** (P3): Track context files over time, allow replay
- **Per-Project Context Files** (P4): Support `.claude/editor-context.yaml` in project roots

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
