# Blockers

**Updated**: 2025-10-30

## Active Blockers

### editor-hook-2: Implement simple persistent session (P1)

**Goal**: Simple session persistence pattern for ctrl-g

**Simple pattern**:
- Always use a session named "Claude"
- If session "Claude" exists → attach to it
- If session "Claude" doesn't exist → create it first, then attach
- User can `tmux detach` and ctrl-g will reattach to the same session

**Why simpler is better**:
- No complex project-based hashing
- No confusion about which session you're in
- Easy to understand and debug
- Single workspace across all projects (user can change directories)

**Implementation approach**:
1. Check if session "Claude" exists with `tmux has-session -t Claude`
2. If exists: `tmux attach -t Claude`
3. If not: Create session, show menu, proceed as normal

**Key consideration**: Must preserve the `menu` alias functionality (don't remove it like experimental branch did)

## Resolved Blockers

None yet.

## Watching

None currently.
