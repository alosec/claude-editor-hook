# Next Up: Prioritized Tasks

**Updated**: 2025-10-31

## Current State Summary

The project is **feature-complete for current use cases**. All planned features are working:
- ✅ FZF command palette
- ✅ Session persistence
- ✅ Recent Files (JSONL-based)
- ✅ Subagent context packages
- ✅ Terminal workspace
- ✅ Enhancement agents

**Next steps depend on actual usage patterns and pain points.**

## Top Priorities

### 1. Usage Validation (Priority 0) 🔥

**Before building more features, validate current functionality.**

**Tasks:**
- Use command palette in real Claude Code sessions for 1-2 weeks
- Identify actual pain points vs theoretical improvements
- Note which menu options get used vs ignored
- Measure if Recent Files provides real value
- Test if enhancement agents save time vs manual prompting

**Decision point:** Build what's needed, not what's interesting.

### 2. Validate What's Actually Useful (Priority 1)

**Tasks:**
- Use Recent Files - Does it actually save time vs manual file opening?
- Use Enhancement Agents - Do they improve prompt quality or just add friction?
- Use Terminal workspace - Is `$PROMPT` env var useful in practice?
- Note which menu options get ignored

**Goal:** Build what's needed, remove what's not.

### 3. Menu Extensions Based on Real Needs (Priority 2)

**Potential additions if usage shows demand:**

**Git Integration:**
- `git log | fzf` - Fuzzy search commit history
- `git diff | batcat` - Syntax-highlighted diffs
- Branch switcher with FZF

**Log Streaming:**
- `tail -f /var/log/app.log` in tmux pane
- Browser console log capture
- Filter logs by pattern

**Test Runner:**
- `npm test -- --watch` in persistent window
- Test file navigator
- Failure-focused test runs

**Database Queries:**
- SQL query interface
- Schema browser
- Query history

**Beads Integration:**
- `bd ready | fzf` - Pick issue to work on
- Quick issue creation from menu
- Status updates

**Rule:** Only add if real usage demands it, not for completeness.

### 4. Documentation Polish (Priority 3)

**Tasks:**
- Add GIFs/screenshots to README showing features
- Write usage guide (when to use each menu option)
- Document common workflows
- Create troubleshooting section

**Blocked by:** Need real usage patterns to document accurately.

## Deferred / Low Priority

### Template Abstraction (editor-hook-15)

**Original question:** Should templates be informational or directive?

**Current reality:** The one template works fine. Premature to abstract.

**Decision:** Defer until we have 3+ distinct use cases that need different templates.

### YAML Context File System

**Original vision:** Claude writes YAML files → Launcher opens multiple files at line numbers

**Current reality:** Command palette proved more flexible.

**Decision:** Deferred indefinitely. May revisit if multi-file opening use cases emerge from real usage.

### MCP Integration

**Vision:** MCP tool for Claude to write context files directly (no file I/O).

**Blocker:** No clear use case given current command palette approach.

**Decision:** Deferred until we identify need for programmatic context file creation.

### Browser Integration

**Vision:** Capture browser console logs, network requests, DOM state.

**Complexity:** Requires browser extension or CDP integration.

**Decision:** Interesting but speculative. Defer until clear need emerges.

## Recently Completed (Archive Reference)

These were in nextUp.md but are now complete:

- ✅ **editor-hook-16** - Recent Files integration (completed via JSONL)
- ✅ **editor-hook-2** - Session persistence (simple "Claude" session)
- ✅ **editor-hook-15** - Template abstraction (deferred - not needed yet)
- ✅ **Unified menu system** - lib/menu-core.sh (Oct 30)
- ✅ **Subagent context packages** - Parent context awareness (Oct 30)
- ✅ **JSONL migration** - Replaced mem-sqlite (Oct 30)

## Key Principle

**Build for real needs, not theoretical completeness.**

The project is feature-complete for the command palette paradigm. Further development should be driven by:
1. Actual usage pain points
2. Measurable time savings
3. Clear workflow improvements

Avoid building features "because we can" or "for completeness."

## Next Session Actions

1. **Use the tool** - Work with Claude Code using the command palette
2. **Take notes** - What's useful? What's missing? What's awkward?
3. **Measure impact** - Does Recent Files save time? Do enhancement agents help?
4. **Decide** - Build what's needed, defer what's not

---

**Note:** This is a working tool, not a research project. Let real usage guide development.
