# Multi-Agent Orchestration Pattern (Exploratory)

**Status**: 🔬 Research / Speculative Design
**Date**: 2025-10-31
**Related Issues**: editor-hook-32 (tmux integration patterns)

## Vision

Transform the persistent Claude workspace from a "command palette with parallel instances" into a **multi-agent orchestration runtime** where the top-level Claude instance (Chief of Staff) can spawn, manage, and communicate with persistent interactive sub-agents.

## The Core Insight

The Ctrl-G hook creates a **bidirectional communication channel** via files:
1. Top-level Claude hits Ctrl-G → writes task to prompt file → waits for PID termination
2. Nested session receives prompt file → routes to agent → agent processes → writes response
3. Coordinator process exits → Claude Code captures file contents → top-level Claude receives response

**Key innovation**: Decouple agent lifecycle from process termination. Agents persist across tasks while a lightweight coordinator manages the IPC.

## Current State vs. Proposed State

### Current Pattern (Working)

```
User ← → Claude Code (top-level)
              ↓
         [Hits Ctrl-G]
              ↓
    Nested "Claude" Session
    ┌──────────────────┐
    │ FZF Menu         │
    │ • Spawn parallel │
    │   Claude         │
    │ • Terminal       │
    │ • Recent files   │
    └──────────────────┘
         ↓
    New Claude window
    (one-shot, fresh context)
```

**Characteristics:**
- ✅ Persistent workspace exists
- ✅ Can spawn parallel instances
- ❌ No orchestration or state management
- ❌ Fresh context each time (no agent memory)
- ❌ User must manually coordinate agents

### Proposed Pattern (Orchestrated)

```
User ← → Top-Level Claude (Chief of Staff)
              ↓
         [Hits Ctrl-G to delegate]
              ↓
         [Prompt file created]
              ↓
    Coordinator in Nested Session
         (routes & manages)
              ↓
    ┌─────────┬──────────┬─────────┬─────────┐
    │Planning │ Coding   │ Testing │ Review  │
    │Agent    │ Agent    │ Agent   │ Agent   │
    │(window1)│(window2) │(window3)│(window4)│
    └─────────┴──────────┴─────────┴─────────┘
         ↑
         │
    [User can intercept/observe any agent]
```

**Characteristics:**
- ✅ Persistent agents maintain context across tasks
- ✅ Chief orchestrates multi-step workflows
- ✅ User can intercept/override at any point
- ✅ Agents visible and inspectable (not black boxes)
- ✅ Parallel work (multiple agents active simultaneously)

## Architecture

### Components

**1. Top-Level Claude (Chief of Staff)**
- Lives in main Claude Code session
- Receives high-level requests from user
- Orchestrates multi-step workflows
- Uses Ctrl-G to delegate to sub-agents
- Reviews sub-agent outputs and decides next steps

**2. Nested Session Coordinator**
- Lightweight process that manages IPC
- Owns the PID that Claude Code waits on
- Routes incoming prompts to appropriate agents
- Tracks agent status (idle/working/blocked)
- Signals completion (exits to wake up Chief)

**3. Persistent Sub-Agents**
- Long-running interactive Claude instances
- Each lives in its own tmux window
- Maintains context across multiple tasks
- Reads from agent-specific inbox file
- Writes results to shared output file
- Can be inspected/controlled by user at any time

### Communication Protocol

**Prompt File Lifecycle:**

```bash
# 1. Chief initiates delegation
Top-Level Claude: [Hits Ctrl-G]
Claude Code: Creates /tmp/prompt-PID.txt, waits for process exit

# 2. Coordinator receives
Nested Session: claude-editor-hook attaches to "Claude" session
Coordinator: Reads /tmp/prompt-PID.txt

# 3. Routing decision
Coordinator: Checks agent status files
  /tmp/claude-agents/planning.status → "idle"
  /tmp/claude-agents/coding.status → "working"
  /tmp/claude-agents/testing.status → "idle"

# 4. Delivery to agent
Coordinator: Writes to /tmp/claude-agents/planning.prompt
Coordinator: Sends signal to Planning Agent window
Planning Agent: Picks up prompt, begins work

# 5. Agent completion
Planning Agent: Writes result to /tmp/prompt-PID.txt
Planning Agent: Updates status → "idle"
Planning Agent: Signals coordinator

# 6. Return to Chief
Coordinator: Exits (PID terminates)
Claude Code: Captures /tmp/prompt-PID.txt contents
Top-Level Claude: Receives result in prompt input
```

**Agent Status Tracking:**

Each agent maintains a status file:
```json
{
  "agent_id": "planning",
  "status": "idle|working|blocked",
  "current_task": "Analyzing auth middleware bug",
  "context_summary": "Working on editor-hook-42, auth flow",
  "last_active": "2025-10-31T14:32:00Z",
  "window_id": "Claude:1"
}
```

Coordinator uses these to make routing decisions.

### Key Technical Challenges

**1. Process ID Decoupling**
- Agent runs as `claude` process in tmux window
- Coordinator runs as wrapper process (owns PID that Claude Code waits on)
- Agent completion must signal coordinator, not exit itself

**Possible solution:**
```bash
# In coordinator
AGENT_WINDOW="Claude:1"
PROMPT_FILE="/tmp/prompt-$$.txt"

# Deliver prompt to agent window
tmux send-keys -t "$AGENT_WINDOW" "process_task '$PROMPT_FILE'" Enter

# Wait for completion signal
while [ ! -f "$PROMPT_FILE.done" ]; do
  sleep 0.1
done

# Exit to notify Chief
exit 0
```

**2. Attention State Management**
- Interactive Claude instances have "attention" - they're either idle or actively processing
- Can't deliver new prompt while agent is thinking
- Need reliable way to detect "agent is ready for input"

**Possible solution:**
- Agent maintains status file
- Agent wrapper script updates status: idle → working → idle
- Coordinator only routes to idle agents
- If no agents idle, spawn new one or queue request

**3. User Interception**
- User might switch to nested session and interact directly with agent
- This breaks the "agent status" assumptions
- Need to handle gracefully

**Possible solution:**
- Accept that user control overrides orchestration
- Agent can detect manual intervention (status not updated by wrapper)
- Chief can poll agent status, realize it's blocked, ask user what happened

**4. Multi-Step Workflows**
- Chief wants to do: Plan → Review Plan → Code → Test → Deploy
- Each step depends on previous
- Need orchestration logic in Chief

**Possible solution:**
- Chief maintains workflow state in its own context
- After each Ctrl-G round-trip, Chief decides next step
- Could also: Chief writes workflow script, coordinator executes it

## Use Cases

### 1. Feature Implementation Flow

**User:** "Implement dark mode for settings page"

**Chief:** "I'll orchestrate this. First, planning."
[Hits Ctrl-G, writes: "Plan dark mode implementation for settings page"]

**Planning Agent:** [Analyzes codebase, creates plan, writes to file]

**Chief:** [Receives plan] "Plan looks good. Let me delegate to coding."
[Hits Ctrl-G, writes: "Implement this plan: [plan details]"]

**Coding Agent:** [Implements feature, writes summary]

**Chief:** [Receives summary] "Code complete. Now testing."
[Hits Ctrl-G, writes: "Deploy feature branch and run E2E tests"]

**Testing Agent:** [Deploys, runs tests, sends screenshots via email]

**Chief:** "Tests passing. Merging to main."
[Executes merge directly or delegates to another agent]

**User:** [Reviews only at the end, or intercepts at any point]

### 2. Parallel Investigation

**User:** "Debug the auth middleware failure"

**Chief:** "I'll investigate from multiple angles."
[Hits Ctrl-G three times, spawning three agents:]

**Agent 1:** "Check server logs for auth errors"
**Agent 2:** "Review middleware code and recent changes"
**Agent 3:** "Search issue tracker for similar problems"

[All three work simultaneously]
[Each writes findings to shared location]

**Chief:** [Receives three reports, synthesizes, presents to user]

### 3. Long-Running Monitoring

**User:** "Monitor the build and let me know if it fails"

**Chief:** "I'll delegate to a monitoring agent."
[Spawns agent in background]

**Monitor Agent:** [Watches build, maintains context]
[Build fails 20 minutes later]
[Agent writes failure report, signals Chief]

**Chief:** [Receives alert] "Build failed. Here's the error..."
[User wasn't even in Claude Code - Chief queued the message]

### 4. Specialized Agent Pool

**Chief maintains:**
- **Planning Agent** (knows system architecture, creates implementation plans)
- **Coding Agent** (knows coding patterns, implements features)
- **Testing Agent** (knows CI/CD, runs tests, interprets results)
- **Review Agent** (knows quality standards, reviews code)
- **Database Agent** (knows schema, writes SQL, analyzes queries)

**Chief routes tasks** based on type, maintaining agent context specialization.

## Benefits

### For the User

1. **Less micromanagement**: Describe goal once, Chief orchestrates
2. **Visibility**: Can observe/intercept any agent at any time
3. **Context efficiency**: Chief stays clean, agents do heavy lifting
4. **Parallel work**: Multiple agents work simultaneously
5. **Persistent state**: Agents remember previous interactions

### For the Chief (Top-Level Claude)

1. **Clean context**: Delegates investigation to sub-agents
2. **Orchestration capability**: Can execute multi-step workflows
3. **Error recovery**: Can retry or reroute if agent fails
4. **Specialization**: Can build agent expertise over time

### Compared to Built-in Subagents

| Feature | Built-in Subagents | This Pattern |
|---------|-------------------|--------------|
| User visibility | ❌ Black box | ✅ Full visibility |
| User control | ❌ No interaction | ✅ Can intercept anytime |
| Persistence | ❌ One-shot | ✅ Long-running |
| Parallelism | ❌ Sequential | ✅ Simultaneous |
| Context retention | ❌ Fresh each time | ✅ Maintains history |
| Orchestration | ✅ Automatic | ⚠️ Requires protocol |

## Open Questions

### 1. Is orchestration worth the complexity?

**Trade-off:** Build coordination logic vs. just manually stepping through agents

**Validation:** Prototype one-step delegation, see if it feels better than manual

### 2. How much intelligence in the coordinator?

**Option A:** Dumb router (Chief explicitly names agent)
**Option B:** Smart router (Coordinator analyzes task, picks agent)
**Option C:** Chief decides everything (Coordinator just delivers)

**Lean:** Option C (keep coordinator simple, Chief stays smart)

### 3. What happens when things break?

- Agent crashes mid-task
- User manually kills agent window
- Coordinator loses track of agent status
- Prompt file gets corrupted

**Need:** Error handling, recovery strategies, graceful degradation

### 4. External interface (email/API)?

**Future possibility:** Chief could receive requests via email or API, not just from user in Claude Code

**Example:**
```
Email: "Chief, check if the deployment succeeded"
Chief: [Delegates to testing agent, emails back results]
```

This turns Chief into a **personal AI employee** accessible outside Claude Code.

### 5. Is this actually better than just using Claude Code normally?

**The fundamental question:** Would you actually use this, or is it just intellectually interesting?

**Test:** If you find yourself typing "continue" repeatedly in long workflows, there's signal that orchestration would help.

**Counter-signal:** If setting up the orchestration takes longer than just doing the work, it's premature optimization.

## Minimal Viable Prototype

To validate this pattern without over-building:

### MVP Scope

1. ✅ Persistent "Claude" session (already works)
2. ✅ Prompt file as IPC (already works)
3. **NEW:** Simple coordinator script
4. **NEW:** One persistent agent (Planning Agent)
5. **NEW:** One-step delegation flow

### MVP Flow

```
User: "Chief, plan the dark mode feature"
Chief: [Hits Ctrl-G]
       [Writes: "Plan dark mode feature for settings page"]

Coordinator: [Sees prompt file]
            [Checks if Planning Agent window exists]
            [If not, spawns it]
            [Delivers prompt to Planning Agent]
            [Waits for completion]

Planning Agent: [Processes in its own window]
               [Maintains context from previous tasks]
               [Writes plan to prompt file]
               [Signals done]

Coordinator: [Sees done signal]
            [Exits]

Chief: [Receives plan]
      [Reviews, decides next step manually]
```

**What this validates:**
- Does one-step delegation feel better than manual?
- Is agent persistence valuable?
- Is visibility/control useful?
- Do we run into technical blockers?

**What this defers:**
- Multi-step orchestration
- Multiple agent types
- Smart routing logic
- External interfaces

### Implementation Sketch

**1. Coordinator script** (`lib/coordinator.sh`)
```bash
#!/usr/bin/env bash
PROMPT_FILE="$1"
AGENT_WINDOW="Claude:1"  # Planning Agent lives here

# Check if Planning Agent exists
if ! tmux list-windows -t Claude | grep -q "^1:"; then
    # Spawn Planning Agent
    tmux new-window -t Claude:1 -n "Planning" \
        "claude --dangerously-skip-permissions"
fi

# Deliver prompt (somehow - details TBD)
# Wait for completion (somehow - details TBD)
# Exit to notify Chief
```

**2. Agent wrapper** (wraps Claude instance)
```bash
#!/usr/bin/env bash
# Run inside agent window
# Provides protocol for receiving tasks and signaling completion

# Watch for prompts
# Load into Claude somehow
# Detect completion somehow
# Signal coordinator
```

**3. Pattern 2 modification** (`bin/claude-editor-hook`)
```bash
case "$PATTERN" in
    2)
        # Check if this is a delegation (from Chief)
        if [ -f "$FILE.delegate" ]; then
            # Route via coordinator
            exec bash lib/coordinator.sh "$FILE"
        else
            # Normal menu flow
            exec tmux attach -t Claude || tmux new-session -s Claude ...
        fi
        ;;
esac
```

## Timeline to Prototype

**Conservative estimate:** 1-2 days of focused work
- 4 hours: Build coordinator + agent wrapper
- 2 hours: Integrate with existing Pattern 2
- 2 hours: Test, debug, iterate
- 2 hours: Documentation

**Realistic estimate:** 4-6 hours spread over a week
- Assuming exploration, dead ends, distractions

**Risk:** Could be a dead end if technical challenges are harder than expected

## Decision Point

**Build this if:**
- You frequently run multi-step workflows (plan → code → test)
- You find yourself typing "continue" repeatedly
- You want sub-agents to maintain context across tasks
- You want visibility into what sub-agents are doing

**Skip this if:**
- Current manual coordination feels fine
- The complexity isn't justified by time savings
- You'd rather spend time shipping features
- It's just a "cool demo" without real utility

## Related Exploration

This pattern is related to but distinct from:
- **editor-hook-32**: Tmux integration patterns (non-nested session exploration)
- **Orchestrated Subagent Workflow**: Planning → Coding → Testing agent delegation (manual)
- **Parallel Instance Pattern**: Current Ctrl-G enhancement agent (one-shot, fresh context)

The multi-agent orchestration pattern combines elements of all three:
- Uses nested session (from current pattern)
- Orchestrates multiple agents (from workflow pattern)
- But adds: persistence, statefulness, user control

## Conclusion

This is a **high-risk, high-reward** exploration. If it works, it could dramatically change how you interact with Claude Code - moving from "active supervision" to "high-level direction." If it doesn't work, it's a fun learning experience and possibly a viral demo.

The MVP is small enough to validate quickly. The key question is: **will you actually use it, or is it just intellectually satisfying to think about?**

---

**Next Steps (if pursuing):**
1. Create `feature/multi-agent-orchestration` branch
2. Build minimal coordinator script
3. Test one-step delegation with Planning Agent
4. Evaluate: does this feel better than manual coordination?
5. Decide: expand or abandon based on real usage
