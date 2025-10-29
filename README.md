# Claude Editor Hook

> A context-aware editor launcher that lets Claude orchestrate what opens when you hit `Ctrl-G` in Claude Code.

## What Is This?

When you press `Ctrl-G` in Claude Code to edit a prompt, it launches whatever is in your `$EDITOR` environment variable. This project intercepts that hook, allowing Claude to dynamically control what you see:

- **Multiple files** at specific line numbers in emacs
- **File previews** with syntax highlighting via batcat
- **Interactive menus** with numbered options
- **Tmux sessions** with editor, logs, and test panes
- **Log streams** from servers or browsers
- **Anything else** you can script

## How It Works

```
┌───────────────────────────────────────────────┐
│  You hit Ctrl-G in Claude Code                │
└───────────────────────────────────────────────┘
                    ↓
┌───────────────────────────────────────────────┐
│  Claude Code launches $EDITOR                 │
│  $EDITOR = claude-editor-hook                 │
└───────────────────────────────────────────────┘
                    ↓
┌───────────────────────────────────────────────┐
│  Wrapper reads ~/.claude/editor-context.yaml  │
│  Claude wrote: mode=emacs, files=[...]        │
└───────────────────────────────────────────────┘
                    ↓
┌───────────────────────────────────────────────┐
│  Launcher opens exactly what you need         │
└───────────────────────────────────────────────┘
```

## Example Use Cases

**Code Review**: Claude identifies 5 files needing changes, opens them in split-pane emacs at the right line numbers.

**Debugging**: Claude detects an error, opens the file at the error line alongside relevant logs in batcat.

**Testing**: Claude triggers tests, opens tmux with code editor, test output, and server logs.

**Exploration**: Claude presents a menu of 10 relevant files, you select which to view.

## Installation

```bash
# Clone the repo
cd ~/code
git clone [your-repo-url] claude-editor-hook
cd claude-editor-hook

# Symlink the wrapper to your PATH
mkdir -p ~/.local/bin
ln -s ~/code/claude-editor-hook/bin/claude-editor-hook ~/.local/bin/

# Update your shell config (~/.bashrc or ~/.zshrc)
export EDITOR="claude-editor-hook"

# Reload your shell
source ~/.bashrc
```

## Usage

### Manual Testing

Create a context file:

```yaml
# ~/.claude/editor-context.yaml
mode: emacs
files:
  - path: /home/alex/code/myproject/src/main.js
    line: 42
    description: "Bug location"
  - path: /home/alex/code/myproject/src/utils.js
    line: 108
    description: "Related function"
```

Then trigger it:

```bash
# Simulates Ctrl-G in Claude Code
claude-editor-hook /tmp/some-temp-file
```

### With Claude Code

Once installed, Claude can write context files during your conversation:

```
You: "Show me where the authentication bug is"

Claude: "I found the issue in auth.js line 42. Let me set up the view..."
        [writes ~/.claude/editor-context.yaml]
        "Now hit Ctrl-G to open the files"

You: [hits Ctrl-G]
     [emacs opens with auth.js:42 and related files]
```

## Architecture

See [memory-bank/01-architecture/systemPatterns.md](memory-bank/01-architecture/systemPatterns.md) for details.

**Key components**:
- `bin/claude-editor-hook` - Main wrapper script
- `lib/config-reader.sh` - Parse YAML context files
- `lib/launcher-*.sh` - Plugin launchers (emacs, batcat, menu, tmux)
- `templates/context-schema.yaml` - Example context file

## Launchers

### Emacs Launcher
Opens multiple files at specific line numbers, supports split panes.

### Batcat Launcher
Displays file previews with syntax highlighting, highlights specific lines.

### Menu Launcher
Interactive menu using fzf or dialog, user selects from options.

### Tmux Launcher
Orchestrates tmux sessions with editor, logs, tests in separate panes.

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
