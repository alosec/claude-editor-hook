# Project Brief: Claude Editor Hook

## What We're Building

A powerful context-aware editor launcher that lets Claude orchestrate what opens when you hit `Ctrl-G` in Claude Code. Instead of always opening the same editor, Claude writes configuration files that define rich, contextual views of your codebase.

## The Core Idea

When you press `Ctrl-G` in Claude Code to edit a prompt, the `$EDITOR` environment variable determines what launches. By pointing `$EDITOR` to our wrapper script instead of directly to emacs or vi, we intercept that hook and can do **anything**:

- Open multiple files at specific line numbers in emacs
- Display file previews with batcat for quick viewing
- Present an interactive menu with numbered options
- Launch a tmux session with editor, logs, and test panes
- Stream server logs or browser console output
- Even more creative possibilities...

## How It Works

```
User hits Ctrl-G
    ↓
Claude Code launches $EDITOR
    ↓
$EDITOR = ~/code/claude-editor-hook/bin/claude-editor-hook
    ↓
Wrapper reads ~/.claude/editor-context.yaml
    ↓
Claude has written: mode=emacs, files=[foo.js:42, bar.js:108]
    ↓
Wrapper dispatches to lib/launcher-emacs.sh
    ↓
Emacs opens with both files at the right line numbers
```

## Why This Is Powerful

**Bidirectional Protocol**: Claude can write the context file during conversation, setting up exactly what you need to see. When you hit `Ctrl-G`, your environment responds to Claude's orchestration.

**Extensible**: New launchers are just bash scripts in `lib/`. Want to add browser DevTools logs? Write `launcher-browser.sh`. Want to show git diffs? Write `launcher-diff.sh`.

**Context-Aware**: Claude understands what you're working on. It can prepare the perfect view: files you need to edit, logs you need to monitor, tests you need to run.

## Use Cases

- **Code Review**: Claude identifies 5 files needing changes, sets up split-pane emacs view
- **Debugging**: Claude detects an error, opens the file at the error line + relevant logs in batcat
- **Testing**: Claude triggers a test run, opens tmux with code, test output, and server logs
- **Exploration**: Claude presents a menu of 10 relevant files, you pick which to explore
- **Log Analysis**: Claude tails server logs and browser console, filtered to relevant errors

## Project Status

**Current**: Initial planning and setup

**Next**: MVP implementation with emacs and batcat launchers

**Future**: MCP integration for Claude to write context files, tmux orchestration, menu system
