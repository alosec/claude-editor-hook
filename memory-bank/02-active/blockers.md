# Blockers

**Updated**: 2025-10-31

## Active Blockers

None currently.

## Resolved Blockers

### editor-hook-2: Implement simple persistent session ✅ RESOLVED (Oct 29)

**Goal**: Simple session persistence pattern for ctrl-g

**Resolution**: Implemented in Pattern 2 with simple "Claude" session name.

**Implementation:**
- Always use tmux session named "Claude"
- Check if exists → attach, else create → attach
- Preserves `menu` alias functionality
- No project-based hashing complexity

**Outcome:** Working as designed. Session persists across Ctrl-G invocations, windows survive between menu launches.

### editor-hook-25: Stale database issue ✅ RESOLVED (Oct 30)

**Problem**: Recent Files showing stale results from mem-sqlite database when daemon not running.

**Resolution**: Migrated from mem-sqlite to direct JSONL parsing with caching.

**Implementation:**
- `lib/scripts/query-recent-files-jsonl.sh` - Parses JSONL logs directly
- Intelligent caching (first run ~1s, subsequent <100ms)
- Zero external dependencies
- Always current (reads actual session logs)

**Outcome:** Recent Files now works reliably without daemon setup or configuration.

## Watching

None currently.

---

**Note:** No active blockers. Project is feature-complete for current use cases.
