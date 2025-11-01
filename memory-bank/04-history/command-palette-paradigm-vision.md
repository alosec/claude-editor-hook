# The Command Palette Paradigm

**Date:** 2025-10-29
**Status:** Core architectural insight

## The Realization

The Ctrl-G hook isn't just an "editor launcher" - it's a **universal command palette and delegation mechanism** for arbitrary code execution that cleanly returns to Claude Code.

### The Pattern

```
Ctrl-G → fzf menu → [ANY SCRIPT/TOOL] → tmux session → exits cleanly back to Claude Code
```

**Key insight:** Using fzf as a command palette launcher, combined with tmux session management, means we can execute **literally anything** and cleanly return control to Claude Code when done.

## What This Enables

### 1. **Parallel Claude Instances**
Spawn a second Claude CLI instance for specialized work:
- Prompt enhancement (current implementation)
- Code analysis
- Test generation
- Documentation writing
- Refactoring suggestions

**Flow:**
```
User writes rough prompt → Ctrl-G → "Enhance with Claude" →
Enhancement agent investigates codebase → Rewrites prompt with context →
Returns to original Claude with enhanced prompt
```

### 2. **Development Tools**
Any CLI tool becomes instantly accessible:
- `git log --oneline | fzf` → Select commit, open files changed
- `docker ps` → Select container, tail logs
- `npm run test:watch` → Run tests in split pane
- Database query interfaces
- API testing tools (curl, httpie)
- File diff viewers (ediff, delta)

### 3. **Log Streaming & Monitoring**
Stream any data source into the session:
- Server logs (`tail -f /var/log/app.log`)
- Browser console output
- Test runner output
- Database query logs
- Network request monitoring

**Layout:**
```
┌─────────────────────┬─────────────────────┐
│ Prompt Editor       │ Server Logs         │
│ (nano/emacs)        │ (tail -f)           │
├─────────────────────┼─────────────────────┤
│ Test Output         │ Browser Console     │
│ (npm test --watch)  │ (websocket stream)  │
└─────────────────────┴─────────────────────┘
```

### 4. **Interactive Workflows**
Multi-step processes with user input:
- Select files from `git diff` → Choose action (view/edit/stage)
- Browse Beads issues → Select one → Show related files
- Pick test to run → Show output → Jump to failing line

### 5. **Context Assembly**
Build composite views from multiple sources:
- Multi-select files to review
- Toggle multiple log sources on/off
- Show code + docs + tests side-by-side
- Combine git history + current changes + related issues

### 6. **Smart Defaults**
Contextual automation without explicit setup:
- No context file? → Auto-show `git diff` files
- Build failed? → Open errors + relevant source files
- Test failed? → Show test + implementation + logs
- Merge conflict? → Launch conflict resolution UI

## The Meta-Pattern: Delegation Mechanism

The Ctrl-G hook has become a **universal delegation system**:

```
┌─────────────────────────────────────────────┐
│ Claude Code (Main Session)                  │
│ • Maintains conversation context            │
│ • Recognizes when external work is needed   │
│ • Writes context file describing task       │
│ • Tells user to hit Ctrl-G                  │
└─────────────────────────────────────────────┘
                    ↓ (User hits Ctrl-G)
┌─────────────────────────────────────────────┐
│ Command Palette (fzf menu)                  │
│ • View code                                 │
│ • Enhance prompt with Claude                │
│ • Check logs                                │
│ • Run tests                                 │
│ • Git operations                            │
│ • [Anything else scriptable]                │
└─────────────────────────────────────────────┘
                    ↓ (User selects action)
┌─────────────────────────────────────────────┐
│ Isolated Execution Context (tmux)          │
│ • Spawns specialized tool/agent             │
│ • Has own context window                    │
│ • Can investigate, analyze, execute         │
│ • Writes results back                       │
└─────────────────────────────────────────────┘
                    ↓ (Exit/completion)
┌─────────────────────────────────────────────┐
│ Return to Claude Code                       │
│ • Results available to main session         │
│ • Context stays clean                       │
│ • Ready for next action                     │
└─────────────────────────────────────────────┘
```

## Why This Is Powerful

### Context Efficiency
- Main Claude session stays focused on conversation
- Investigation/analysis happens in separate contexts
- No pollution of main conversation with exploratory work

### Separation of Concerns
- Prompt enhancement agent ≠ Implementation agent
- Each specialized task gets its own context
- Natural mapping to different workflows

### Composability
- Each menu option is independent
- Can chain operations (enhance prompt → view files → run tests)
- Mix and match tools as needed

### Clean Handoffs
- Main Claude delegates work
- Specialized tool/agent completes task
- Results return cleanly
- Main Claude acts on results

### Infinite Extensibility
**Because it's just scripts**, you can add:
- Any CLI tool
- Custom TUI applications
- Parallel LLM instances (Claude, GPT, local models)
- Integration with external services
- Database queries
- API calls
- File system operations
- Literally anything executable

## Current Implementation Status

**Working:**
- ✅ Pattern 2: FZF popup menu with configurable options
- ✅ Prompt enhancement with parallel Claude CLI (`cndsp`)
- ✅ Clean return to Claude Code after enhancement
- ✅ Non-interactive mode: `claude -p` for direct prompt submission

**In Progress:**
- Log streaming integration
- Multi-pane layouts
- Smart default behaviors
- Dynamic menu generation

**Planned:**
- Session history and replay
- Browser DevTools integration
- Git workflow integrations
- Persistent workspace sessions

## Related Files

- `memory-bank/01-architecture/systemPatterns.md` - Original architecture doc
- `MENU_PATTERNS.md` - 8 menu pattern experiments
- `PATTERN_USAGE.md` - How to select patterns via env var
- `memory-bank/02-active/nextUp.md` - Prioritized features

## Key Design Principle

**"It's not an editor hook anymore - it's a command palette."**

The fact that it's triggered by Ctrl-G (the editor hook) is an implementation detail. What matters is:
1. Clean entry point from Claude Code
2. Arbitrary code execution capability
3. Clean return path to Claude Code

This opens up entirely new ways of working with Claude in the terminal.
