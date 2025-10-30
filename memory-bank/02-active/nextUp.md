# Next Up: Prioritized Tasks

**Updated**: 2025-10-30

## Top 10 Tasks

### 1. Explore template abstraction (Priority 1) - editor-hook-15 🔥 CURRENT FOCUS
**The core architectural question:** What should the template tell parallel instances?

Options:
1. Minimal informational - explain mechanism, maximize flexibility
2. Task-based templates - multiple specialized templates
3. Template with parameters - {{TASK}} and {{CONTEXT}} variables
4. Hybrid - minimal base + task overlay

**Current lean:** Option 1 (minimal informational)

**Next steps:**
- Draft minimal informational template
- Test with different use cases (enhance, execute-command, investigate)
- Document decision and rationale

### 2. Design flexible template system (Priority 1) - editor-hook-12
**Follows from editor-hook-15**. Once we know the right abstraction, implement the system:
- lib/prompts/ directory structure
- Variable substitution mechanism
- How to pass additional context beyond {{FILE}}

### 3. Implement simple persistent "Claude" session (Priority 1) - editor-hook-2
**NEW SIMPLE APPROACH**:
- Always use session named "Claude"
- Check if exists → attach, else create → attach
- Keep menu alias functionality
- No project-based hashing complexity

### 4. Update enhancement-agent.txt to reflect parallel instance reality (Priority 2) - editor-hook-10
**Blocked by editor-hook-15**. Once abstraction is decided, update current template to match.

### 5. Add "Execute Command & Pipe" menu option (Priority 2) - editor-hook-13
**Test case for template flexibility**. User describes command → parallel instance executes → pipes to {{FILE}}. Proves the pattern works beyond prompt enhancement.

### 6. Generalize Claude prompt enhancement pattern (Priority 2) - editor-hook-4
Create reusable pattern for spawning enhancement agents. Interactive and non-interactive modes both working, need to document pattern for future extensions.

### 7. Fix session numbering (Priority 2) - editor-hook-3
**Will be resolved by #3**: Currently sessions increment on each Ctrl-G. Persistence will solve this.

### 8. Context file reading (Priority 2)
Parse `~/.claude/editor-context.yaml` to open multiple files at specific line numbers. Foundation for multi-file workflows.

### 9. MCP Tool for Context Writing (Priority 2)
Create an MCP server that gives Claude a tool to write context files directly (no file I/O). Makes Claude's job easier and faster.

### 10. Smart Fallback Mode (Priority 2)
When no context file exists, inspect `git diff` and automatically open changed files. Useful default behavior.

## Additional High-Priority Tasks

### Log Streaming Integration (Priority 3)
Add ability to tail server logs, browser console, or any command output directly in the launcher.

### Git Diff Launcher (Priority 3)
Show diffs side-by-side in ediff or similar. Claude can specify which commits/branches to compare.

### Browser DevTools Integration (Priority 3)
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
