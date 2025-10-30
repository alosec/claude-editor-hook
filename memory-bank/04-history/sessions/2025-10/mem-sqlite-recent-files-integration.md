# Session: mem-sqlite Recent Files Integration (Oct 30, 2025)

**Status:** ✅ COMPLETE (with follow-up issue for daemon management)

**Branch:** `feature/mem-sqlite-recent-files`

**Duration:** ~2.5 hours (planning + implementation + bug fix + testing)

## What We Shipped

Successfully integrated mem-sqlite database querying into the FZF command palette, adding a "Recent Files" option that shows the last 25 files Claude touched across all sessions with real-time updates.

### Core Feature

- **New menu option**: "Recent Files" in Pattern 2 FZF palette
- **Live database query**: Uses mem-sqlite to track Read/Edit/Write tool invocations
- **FZF integration**: Full-height picker with batcat syntax-highlighted preview
- **Smart timestamps**: Uses actual tool invocation time, not database insertion time
- **Graceful errors**: Clear messages when database is missing or stale

## Files Changed

### Created
- `lib/scripts/query-recent-files.sh` (64 lines) - SQL query wrapper with project filtering
- `lib/prompts/enhancement-agent.txt` (captured during session)
- `memory-bank/04-history/sessions/2025-10/mem-sqlite-recent-files-integration.md` (this file)

### Modified
- `bin/claude-editor-hook` - Symlink resolution fix + Recent Files handler
- `memory-bank/01-architecture/systemPatterns.md` - Architecture documentation
- `memory-bank/02-active/currentWork.md` - Session tracking
- `README.md` - Feature documentation + daemon setup instructions

## Commits

```
0068b89 docs: Add mem-sqlite daemon requirement for Recent Files
c4a0724 fix: Use messages.timestamp instead of tool_uses.created for accurate recency
c76197a feat: Add mem-sqlite Recent Files integration to FZF menu
```

## Beads Issues (9 closed)

### Planning & Implementation
- ✅ **editor-hook-17** (P0): Setup mem-sqlite dependencies and run initial sync
- ✅ **editor-hook-18** (P1): Design and test SQL query for recent files
- ✅ **editor-hook-19** (P1): Create query wrapper script
- ✅ **editor-hook-20** (P1): Add Recent Files option to Pattern 2 FZF menu
- ✅ **editor-hook-22** (P2): Error handling for missing database
- ✅ **editor-hook-23** (P2): Testing with real data

### Deferred/Closed
- ✅ **editor-hook-21** (P2): File action submenu (deferred - direct open works well)

### Parent
- ✅ **editor-hook-16** (P2): Integrate mem-sqlite for recent files tracking in FZF menu

### Bug Fixed
- ✅ **editor-hook-25** (P0): Fix timestamp bug - wrong field used for sorting

### Follow-up Created
- 🔄 **editor-hook-26** (P1): Ensure mem-sqlite sync daemon is robust and reliable

## Technical Deep Dive

### The Timestamp Bug Discovery

**Initial Implementation:**
```sql
SELECT json_extract(tu.parameters, '$.file_path') AS file_path,
       MAX(tu.created) AS last_touched
FROM tool_uses tu
```

**Problem:** `tool_uses.created` is the **database insertion timestamp** (when mem-sqlite synced), not when Claude actually invoked the tool.

**Fix:**
```sql
SELECT json_extract(tu.parameters, '$.file_path') AS file_path,
       MAX(m.timestamp) AS last_touched
FROM tool_uses tu
JOIN messages m ON tu.messageId = m.id
```

**Result:** Files now sorted by actual tool invocation time from Claude Code's JSONL logs.

### Database Schema Understanding

```
messages.timestamp    → ISO8601 string from Claude Code JSONL (actual event time)
tool_uses.created     → SQLite DATETIME DEFAULT CURRENT_TIMESTAMP (insertion time)
```

The fix required joining with the `messages` table to access the original event timestamp.

### Symlink Resolution Fix

When installed via `~/.local/bin/claude-editor-hook` → actual script location, the `$0` variable points to the symlink, not the real file. This broke relative paths to `lib/scripts/`.

**Solution:**
```bash
SCRIPT_SOURCE="${BASH_SOURCE[0]:-$0}"
while [ -L "$SCRIPT_SOURCE" ]; do
    SCRIPT_DIR="$(cd -P "$(dirname "$SCRIPT_SOURCE")" && pwd)"
    SCRIPT_SOURCE="$(readlink "$SCRIPT_SOURCE")"
    [[ $SCRIPT_SOURCE != /* ]] && SCRIPT_SOURCE="$SCRIPT_DIR/$SCRIPT_SOURCE"
done
SCRIPT_DIR="$(cd -P "$(dirname "$SCRIPT_SOURCE")" && pwd)"
```

Iteratively follows symlinks until reaching the actual file.

## mem-sqlite Integration

### Architecture

```
Claude Code → ~/.claude/projects/*.jsonl
                      ↓
            mem-sqlite daemon (chokidar watcher)
                      ↓
            Parse JSONL → Transform → SQLite
                      ↓
      ~/.local/share/memory-sqlite/claude_code.db
                      ↓
            query-recent-files.sh (SQL query)
                      ↓
            FZF menu with batcat preview
```

### Database Stats
- **Size:** 310MB after initial sync
- **Tool uses:** 48,501 tracked operations
- **Sessions:** 945 conversations
- **Performance:** Query executes in <100ms even with 48K rows

### SQL Query Design

**Final optimized query:**
```sql
SELECT DISTINCT
  json_extract(tu.parameters, '$.file_path') AS file_path,
  MAX(m.timestamp) AS last_touched
FROM tool_uses tu
JOIN messages m ON tu.messageId = m.id
WHERE
  tu.toolName IN ('Read', 'Edit', 'Write')
  AND json_extract(tu.parameters, '$.file_path') IS NOT NULL
  AND json_extract(tu.parameters, '$.file_path') != ''
GROUP BY file_path
ORDER BY last_touched DESC
LIMIT 25;
```

**Key design choices:**
1. **json_extract()** - SQLite built-in for parsing JSON `parameters` field
2. **toolName filter** - Only Read/Edit/Write have `file_path` parameter
3. **DISTINCT + GROUP BY** - Deduplicates multiple touches of same file
4. **MAX(m.timestamp)** - Gets most recent touch per file
5. **LIMIT 25** - Keeps menu manageable

## FZF Layout Improvements

### Initial Design
- Height: 70%
- Preview: side-by-side (right:60%)

### Final Design (user request)
- Height: 100% (full screen)
- Preview: stacked (up:70%)

```bash
fzf --height=100% \
    --prompt='Recent Files: ' \
    --border --reverse \
    --preview='batcat --color=always --style=numbers {}' \
    --preview-window=up:70%:wrap
```

**Rationale:** Vertical stacking provides more space for file paths and better preview visibility.

## Learnings

### 1. Database Timestamp Semantics Matter
Don't assume all timestamp fields are equivalent. In ETL pipelines:
- **Event time** (when it happened) ≠ **Ingestion time** (when it was recorded)

Always use event time for user-facing features.

### 2. mem-sqlite Expected Usage
One-time sync (`npm run cli sync`) is insufficient. The tool is designed to run as a **continuous daemon**:
- `npm run cli start` - Watcher daemon with sub-second latency
- `docker compose up -d` - Recommended production deployment

### 3. Symlink-Aware Path Resolution
When distributing scripts via `~/.local/bin/` symlinks:
- Use `BASH_SOURCE[0]` instead of `$0`
- Iteratively resolve symlinks with `readlink`
- Test both direct execution and symlink execution

### 4. Orchestrated Subagent Workflow
The planning-agent → granular Beads issues → execution pattern was highly effective:
- Planning agent created 8 well-defined issues
- Each issue independently testable
- Clear dependency chain
- Average lead time: 0.5 hours

### 5. User Testing Revealed Edge Cases
Initial implementation worked but user testing revealed:
- Wrong timestamp field used
- Need for daemon (not one-shot sync)
- Layout preferences (100% height, stacked preview)

Ship early, iterate with real usage.

## Open Questions & Future Work

### Daemon Management (editor-hook-26)
How to ensure mem-sqlite daemon stays running?
- Systemd service?
- pm2 process manager?
- tmux persistent session?
- Status checks in menu?

### Project Filtering
Should Recent Files filter by current project automatically?
- Query already supports `PROJECT_FILTER` parameter
- Could detect current working directory
- Show "All files" vs "This project" toggle?

### Time-Based Filtering
Add options for:
- Last hour
- Today
- This week
- Custom time range

### Tool-Specific Views
Separate menus for:
- "Recently Read" (Read tool only)
- "Recently Edited" (Edit tool only)
- "Recently Written" (Write tool only)

## Success Metrics

- ✅ Feature complete and working with daemon
- ✅ Query performance <100ms with 48K rows
- ✅ Timestamps accurate (uses actual tool invocation time)
- ✅ Graceful error handling
- ✅ Well-documented in README and architecture docs
- ✅ 9 Beads issues closed
- ✅ User tested and approved

## Related Documentation

- **Architecture:** `memory-bank/01-architecture/systemPatterns.md` (Recent Files Integration section)
- **Setup:** `README.md` (Recent Files Setup section)
- **Query Script:** `lib/scripts/query-recent-files.sh`
- **Beads Issues:** editor-hook-16 through editor-hook-26

---

**Next Session:** Focus on editor-hook-26 (daemon robustness) or editor-hook-15 (template abstraction).
