# Claude Editor Hook

> A command palette for Claude Code that intercepts `Ctrl-G` to launch editors, tools, and specialized agents.

## Current Status

✅ **Working and Simple** - Pattern 2 with FZF menu.

**✅ Working Now:**
- FZF command palette with 8 options
- Edit with Emacs/Vi/Nano (returns to Claude Code when done)
- **Open Terminal** (full shell with `$PROMPT` env var set to temp file path)
- **Recent Files** - Query JSONL logs for last 25 files Claude touched (with intelligent caching)
- **Subagent Context Package** - Spawn Claude instances with rich parent context (conversation + tools + files)
- Interactive + non-interactive prompt enhancement
- Configurable via `~/.claude-editor-hook.conf` (set `PATTERN=2`)

**📋 Future Exploration (Not Actively Planned):**
- Menu extensions based on real usage needs (git ops, log streaming, test runners)
- Enhanced history viewer - "Better Ctrl-O" parsing ~/.claude/projects
- Context file system for multi-file opening (may revisit if use cases emerge)
- Multi-pane tmux layouts with logs
- MCP tool for Claude to write context files
- Multi-agent orchestration (interesting theory, likely overkill)

## What Is This?

When you press `Ctrl-G` in Claude Code to edit a prompt, it launches whatever is in your `$EDITOR` environment variable. This project intercepts that hook to provide a command palette that can launch:

- ✅ **Interactive menus** with FZF for choosing editors and tools
- ✅ **Prompt enhancement agents** that investigate your codebase and rewrite prompts
- ✅ **Any editor** (emacs, vi, nano) or viewer (batcat)
- ✅ **Anything scriptable** - the menu accepts any command or script
- 📋 **Multiple files** at specific line numbers (requires context file system - planned)
- 📋 **Tmux layouts** with editor, logs, and test panes (planned)
- 📋 **Log streams** from servers or browsers (planned)

## How It Works

```
┌───────────────────────────────────────────────┐
│  You hit Ctrl-G in Claude Code                │
└───────────────────────────────────────────────┘
                    ↓
┌───────────────────────────────────────────────┐
│  FZF menu appears:                            │
│  • Edit with Emacs                            │
│  • Edit with Vi                               │
│  • Edit with Nano                             │
│  • Open Terminal ($PROMPT available)          │
│  • Recent Files (last 25 files touched)      │
│  • Detach                                     │
│  • Enhance (Interactive)                      │
│  • Enhance (Non-interactive)                  │
└───────────────────────────────────────────────┘
                    ↓
┌───────────────────────────────────────────────┐
│  Select action → Execute → Exit returns to    │
│  Claude Code with your edited prompt          │
└───────────────────────────────────────────────┘
```

**Key Features:**
- **Simple FZF menu** - Fuzzy searchable command palette
- **Open Terminal** - Full bash shell with `$PROMPT` env var pointing to temp file
- **Recent Files** - Access last 25 files Claude touched via JSONL parsing (no dependencies)
- **Prompt enhancement** - Interactive or auto modes for Claude to investigate and enhance prompts
- **Clean and minimal** - Just works, no complexity

**Recent Files Details:**
The Recent Files feature reads Claude Code's JSONL session logs directly from `~/.claude/projects/`. No external dependencies or daemons required.

**Performance:**
- First run: ~1s (parses last 5000 lines from each JSONL file)
- Subsequent runs: <100ms (uses cached results until JSONL files change)
- Cache location: `lib/cache/recent-files-*.json`

**How it works:**
1. Detects current project directory → maps to `~/.claude/projects/-project-name/`
2. Finds all JSONL files, sorted by modification time
3. Parses Read/Edit/Write tool invocations with `jq`
4. Groups by file path, keeps most recent timestamp
5. Returns top 25 files, most recent first

**Subagent Context Package Details:**
When spawning interactive Claude instances (Ctrl-G → "Enhance (Interactive)"), a context package is automatically created with:

**Context Package Structure:**
```
/tmp/claude-subagent-{PID}/
├── system-prompt.txt     # Instructions + output file path
├── parent-context.md     # Last 15 conversation turns with tool usage
├── recent-files.txt      # 25 most recently edited files
└── meta.json            # Metadata (working dir, timestamps)
```

**Parent Context Format:**
```markdown
## USER
[user message]

## ASSISTANT
[assistant response]

**Tools Used:**
- `Read` → /path/to/file.js
- `Edit` → /path/to/modified.ts
- `Bash` → Command description
- `Grep` → Pattern: search_term
```

**Benefits:**
- Subagents understand parent conversation context
- See what files were recently read/edited
- Know what commands were run
- Clear output channel (write to specified file)
- No shell escaping issues (file-based prompt injection)

## Example Use Cases

**✅ Prompt Enhancement (Working Now)**:
- You write: `#enhance\nAdd dark mode support`
- Hit Ctrl-G → Choose "Enhance (Non-interactive)"
- Haiku investigates codebase, finds theme system patterns
- Rewrites prompt with file paths (src/styles/theme.ts:42), architectural context
- Returns to main Claude session with enhanced prompt

**Available directives**: #enhance, #spellcheck, #suggest, #investigate, #fix, #please <custom>

**✅ Interactive Enhancement with Context Package (Working Now)**:
- Hit Ctrl-G → Choose "Enhance (Interactive)"
- New Claude subagent window opens with rich context:
  - Recent conversation history (last 15 turns)
  - Tool usage (Read/Edit/Write/Bash/Grep actions)
  - Recently edited files (last 25 files)
  - Clear instructions on output file location
- Subagent investigates, enhances prompt, writes back
- Exit returns enhanced prompt to parent Claude session

**✅ Editor Selection (Working Now)**:
- Hit Ctrl-G → FZF menu shows Emacs/Vi/Nano options
- Select preferred editor for the prompt file

**📋 Code Review (Planned)**:
- Claude identifies 5 files needing changes
- Writes context file with file paths and line numbers
- Hit Ctrl-G → Opens split-pane emacs at right locations
- *Requires: Context file system (issue editor-hook-3)*

**📋 Debugging (Planned)**:
- Claude detects an error
- Hit Ctrl-G → Multi-pane tmux with code + logs
- *Requires: Multi-pane layouts (issue editor-hook-13)*

## Installation

### Quick Install

```bash
# Clone the repo
cd ~/code
git clone [your-repo-url] claude-editor-hook
cd claude-editor-hook

# Run the install script (experimental)
./install.sh install

# Update your shell config (~/.bashrc or ~/.zshrc)
export EDITOR="claude-editor-hook"

# Reload your shell
source ~/.bashrc
```

The install script attempts to:
- Create a symlink from `~/.local/bin/claude-editor-hook` to the project
- Track installation metadata with git commit hash, branch, and date
- Store deployment info in `~/.local/bin/.claude-editor-hook-install.json`

### Installation Management

**Check installation details:**
```bash
./install.sh info
```

This shows which git commit, branch, and date you deployed. Perfect for knowing exactly what version is running.

**Uninstall:**
```bash
./install.sh uninstall
```

### Manual Installation (without install script)

```bash
# Symlink directly
mkdir -p ~/.local/bin
ln -s ~/code/claude-editor-hook/bin/claude-editor-hook ~/.local/bin/
```

## Usage

### Configuration

**Pattern Selection:** Choose which menu pattern to use:

```bash
# Set pattern via environment variable (default: 1)
export EDITOR_HOOK_PATTERN=2  # Use FZF menu (recommended)

# Or create project-level config
echo 'PATTERN=2' > .claude-editor-hook.conf

# Or create global config
echo 'PATTERN=2' > ~/.claude-editor-hook.conf
```

**Available Patterns:**
- Pattern 1: Simple emacs exec
- **Pattern 2: FZF menu (recommended)** - Command palette with extensible options
- Patterns 3-8: Experimental menu approaches
- Pattern 9: Non-interactive enhancement (auto-detects markers)

### Manual Testing

```bash
# Test the menu
claude-editor-hook /tmp/test-file

# Test with a specific pattern
EDITOR_HOOK_PATTERN=2 claude-editor-hook /tmp/test-file
```

### With Claude Code

📋 **Context file system not yet implemented.** The workflow below describes planned functionality:

```
You: "Show me where the authentication bug is"

Claude: "I found the issue in auth.js line 42. Let me set up the view..."
        [writes ~/.claude/editor-context.yaml]  # Not implemented yet
        "Now hit Ctrl-G to open the files"

You: [hits Ctrl-G]
     [Currently: shows menu. Future: opens files from context]
```

**Current workflow:** Hit Ctrl-G → Choose from menu → Edit prompt or enhance it

## Architecture

See [memory-bank/01-architecture/command-palette-paradigm.md](memory-bank/01-architecture/command-palette-paradigm.md) for the architectural vision.

**Current structure:**
- `bin/claude-editor-hook` - Monolithic script with 8+ pattern implementations (276 lines)
- Pattern 2 (lines 39-74) - FZF menu, the main extensibility point
- `install.sh` - Installation script with git metadata tracking

**Planned structure** (not yet implemented):
- `lib/config-reader.sh` - Parse YAML context files (📋 planned)
- `lib/launcher-*.sh` - Plugin launchers (📋 planned)
- `templates/context-schema.yaml` - Example context file (📋 planned)

**Extensibility Model:**
Pattern 2's FZF menu is the settled architecture. Add new capabilities by editing the `MENU` variable:

```bash
MENU="Display Text:command-to-execute
Another Option:some-script.sh
Third Option:inline bash code"
```

Currently implemented menu options:
- `Edit with Emacs:emacs -nw "$FILE"`
- `Edit with Vi:vi "$FILE"`
- `Edit with Nano:nano "$FILE"`
- `Enhance (Interactive):claude-spawn-interactive` - Spawns new Claude window
- `Enhance (Non-interactive):claude-enhance-auto` - Uses `claude -p` with Haiku

**Future menu options could include:**
- **Enhanced history viewer** - Parse `~/.claude/projects` to show last 10-20 files read/edited/created/deleted in recent calls (replaces Ctrl-O with rich, filterable view)
- Git operations (`git log | fzf`)
- Log streaming (`tail -f /var/log/app.log`)
- Test runners (`npm test --watch`)
- Database queries
- API testing tools

### The "Better Ctrl-O" Vision

Ctrl-G as a leverage point to improve on Claude Code's limited Ctrl-O history:

**Problem:** Ctrl-O shows cramped recent history, forces you to "tab out" of the session
**Solution:** Menu option that analyzes `~/.claude/projects/<project>/calls/` to show:
- Last 10-20 files touched (read, edited, created, deleted) in past X minutes
- Raw message excerpts (truncated or expandable)
- Optional Haiku summary of recent activity
- Filterable, searchable interface (fzf, batcat, custom TUI)

**Why this is powerful:** "Tab out" to rich history view while keeping the interactive session alive. Return when done exploring.

## Development

```bash
# See what's being worked on
cat memory-bank/02-active/currentWork.md

# Check the roadmap
cat memory-bank/02-active/nextUp.md

# View architecture
cat memory-bank/01-architecture/systemPatterns.md
```

Issue tracking via [Beads](https://github.com/your-beads-link):

```bash
bd ready              # Show issues ready to work on
bd create "New idea"  # Create issue
bd list               # List all issues
```

## Contributing

This is a personal project but ideas welcome! See `memory-bank/02-active/nextUp.md` for planned features.

## License

MIT

## Credits

Inspired by the realization that `$EDITOR` is just a hook we can intercept, and Claude can write files.
