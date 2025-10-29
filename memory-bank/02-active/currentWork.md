# Current Work: MVP Implementation

**Status**: Initial setup complete, ready for code implementation

**Branch**: `mvp` (code), `main` (docs)

## This Week's Focus

Build the minimal viable product with two launchers:
1. **Emacs launcher** - Open multiple files at specific line numbers
2. **Batcat launcher** - Display file previews with syntax highlighting

This proves the concept and establishes the plugin pattern for future launchers.

## What We've Done

- ✅ Created project repository at `~/code/claude-editor-hook`
- ✅ Initialized git
- ✅ Set up Beads issue tracker with prefix `editor-hook`
- ✅ Written memory bank foundation (projectbrief, systemPatterns)

## What's Next

**Immediate** (on `mvp` branch):
1. Main wrapper script that reads context file and dispatches
2. Config reader using `yq` for YAML parsing
3. Emacs launcher that accepts files with line numbers
4. Batcat launcher for quick previews
5. Example context file template
6. Test end-to-end: Claude writes context → Ctrl-G → launcher activates

**Then**:
1. Update `~/.bashrc` to use wrapper: `export EDITOR="claude-editor-hook"`
2. Test in real Claude Code session
3. Document usage in main README

## Key Implementation Details

**Main Wrapper** (`bin/claude-editor-hook`):
- Check if `~/.claude/editor-context.yaml` exists
- If yes: parse mode and dispatch to launcher
- If no: fallback to `emacs -nw $@`
- Pass context file path to launcher

**Config Reader** (`lib/config-reader.sh`):
- Use `yq` to parse YAML (install with `pip install yq` or use `jq` for JSON)
- Extract mode field
- Validate structure
- Export variables for launcher scripts

**Emacs Launcher** (`lib/launcher-emacs.sh`):
- Parse files array from context
- Build emacs command: `emacs -nw +line1 file1 +line2 file2`
- Support split-pane with multiple files

**Batcat Launcher** (`lib/launcher-batcat.sh`):
- Display each file in sequence with batcat
- Highlight specific line numbers with `-H line:line` flag
- Paginate through multiple files

## Testing Approach

1. Create test context files in `test/fixtures/`
2. Run wrapper directly: `./bin/claude-editor-hook`
3. Verify each launcher works independently
4. Integration test: Set `$EDITOR` and trigger from Claude Code

## Blockers

None currently. All dependencies (emacs, batcat, yq) available.

## Notes

- Keep it simple for MVP - no error handling overkill
- Document as we go for future maintainers
- Real win is when Claude starts writing context files during session
