# Claude Code JSONL Session Log Structure Analysis

## Overview

Claude Code maintains conversation logs in JSONL (JSON Lines) format. Each line is a complete JSON object representing a message or event in a conversation session.

**Key Finding:** One `.jsonl` file = One complete session. Sessions are identified by unique UUIDs in the `sessionId` field.

---

## File Organization

### Directory Structure

```
~/.claude/projects/
├── -home-alex-code/                           # Project 1
│   ├── 0205f437-f816-4704-b6f3-9cf7b060888c.jsonl  # Session UUID
│   ├── 0507b4e4-48a1-4ec4-a682-51b1dca9d613.jsonl  # Another session
│   ├── agent-32335b9b.jsonl                        # Agent subprocess session
│   └── ...
├── -home-alex-code-pedicab512/               # Project 2
│   ├── 02a992ed-fb8a-4d0b-8a81-7998432eab11.jsonl
│   ├── 03674ec6-6a21-4d99-8835-f491aa302b6e.jsonl
│   └── ...
└── -home-alex-code-[other-projects]/
```

### File Naming Patterns

1. **UUID Format** (main sessions):
   - `550e8400-e29b-41d4-a716-446655440000.jsonl`
   - These are the primary session files
   - Timestamp is stored inside the JSON, not in filename
   - Files contain all messages from one conversation start to end

2. **Agent Format** (subagent sessions):
   - `agent-32335b9b.jsonl`
   - Spawned by main Claude instance via subagent mechanism
   - Still one session per file
   - Parent-child relationship tracked via `parentUuid` field

3. **Directory Naming**:
   - Project paths use full absolute path with slashes replaced by hyphens
   - Example: `/home/alex/code/pedicab512` → `-home-alex-code-pedicab512`
   - Allows multiple projects to have independent JSONL logs

---

## Message Structure

### Common Fields (All Messages)

Every JSONL line contains:

```json
{
  "parentUuid": "uuid-of-previous-message-or-null",
  "isSidechain": false,                    // true for background execution
  "userType": "external",
  "cwd": "/absolute/working/directory",   // Project directory
  "sessionId": "550e8400-e29b-41d4-a716-446655440000",
  "version": "2.0.28",                    // Claude Code version
  "gitBranch": "main",                    // Current git branch
  "type": "user" | "assistant" | "file-history-snapshot" | "summary",
  "message": {...},                       // Content (varies by type)
  "uuid": "unique-message-id",
  "timestamp": "2025-10-29T07:35:14.293Z" // ISO 8601 timestamp
}
```

### Message Types

#### 1. User Message (`type: "user"`)

```json
{
  "type": "user",
  "message": {
    "role": "user",
    "content": "Run /prepare to orient yourself. Read memory-bank/02-active/currentWork.md..."
  }
}
```

**Content Types in `message.content`:**
- **Text**: `string` - Direct user input
- **Array**: `[{type: "tool_result", ...}, {...}]` - Response to tool calls
- **Tool Results**: Results from bash, read, edit, etc.

#### 2. Assistant Message (`type: "assistant"`)

```json
{
  "type": "assistant",
  "message": {
    "model": "claude-sonnet-4-5-20250929",
    "id": "msg_01Gh7HTdRUmmDxFmcnDipCjS",
    "type": "message",
    "role": "assistant",
    "content": [
      {
        "type": "text",
        "text": "I'll help you enhance this prompt. Let me start by reading..."
      },
      {
        "type": "tool_use",
        "id": "toolu_015CDuzCunTQqCr1DSkBPwVk",
        "name": "Bash",
        "input": {"command": "pwd", "description": "Verify working directory"}
      }
    ],
    "stop_reason": null,
    "usage": {
      "input_tokens": 3,
      "output_tokens": 1,
      "cache_creation_input_tokens": 19481,
      "cache_read_input_tokens": 12434
    }
  }
}
```

**Content can contain multiple types:**
- `text` - Regular text response
- `tool_use` - Tool invocation (Bash, Read, Edit, etc.)
- `tool_result` - Result of a tool execution

#### 3. File History Snapshot (`type: "file-history-snapshot"`)

```json
{
  "type": "file-history-snapshot",
  "messageId": "36348984-04a9-4e00-9158-4f36061ed5e4",
  "snapshot": {
    "messageId": "36348984-04a9-4e00-9158-4f36061ed5e4",
    "trackedFileBackups": {
      "src/components/booking/BookingForm.tsx": {
        "backupFileName": "9880cfe2c7908a6c@v3",
        "version": 3,
        "backupTime": "2025-10-15T10:13:14.923Z"
      }
    },
    "timestamp": "2025-10-15T10:13:14.920Z"
  },
  "isSnapshotUpdate": false
}
```

**Purpose**: Tracks file changes within the session for recovery/auditing

#### 4. Summary (`type: "summary"`)

```json
{
  "type": "summary",
  "summary": "Dispatcher workflow analysis: offer ride tool design",
  "leafUuid": "a525a351-167a-472c-8521-607a7f30cbae"
}
```

**Purpose**: High-level summary of session content (used for quick scanning)

---

## Identifying Session Boundaries

### Session Start

A session begins with a message where `parentUuid: null`:

```json
{
  "parentUuid": null,           // ← Session starter
  "sessionId": "550e8400...",
  "type": "user",
  "message": {"role": "user", "content": "..."}
}
```

### Session End

Sessions end when:
1. No more messages are appended to the JSONL file
2. User closes the Claude Code window
3. Natural conversation conclusion

There's no explicit "end" marker - just the last line in the file.

### Multiple Sessions in Same Project

The same project directory will have multiple `.jsonl` files:

```
-home-alex-code-pedicab512/
├── 02a992ed-fb8a-4d0b-8a81-7998432eab11.jsonl  # Session 1
├── 03674ec6-6a21-4d99-8835-f491aa302b6e.jsonl  # Session 2 (different date)
└── 0875f25c-ea34-42c1-974f-3de5e50e4b52.jsonl  # Session 3
```

**To identify unique sessions:**
- Extract `sessionId` from any message in the file
- All messages in one `.jsonl` file share the same `sessionId`
- Filename UUID usually matches the `sessionId` (for main sessions, not agents)

---

## Practical Examples

### Example 1: Simple Session (3 messages)

```json
# Message 1: User starts session
{"parentUuid":null,"isSidechain":false,"sessionId":"130bc834-285a-4160-9b5d-bc2cf004fec9","type":"user","message":{"role":"user","content":"What is 5+5?"},"uuid":"d1403c8b-bd7d-4806-8ffd-99ab07dc1360","timestamp":"2025-10-31T05:27:48.460Z"}

# Message 2: Claude responds
{"parentUuid":"d1403c8b-bd7d-4806-8ffd-99ab07dc1360","sessionId":"130bc834-285a-4160-9b5d-bc2cf004fec9","type":"assistant","message":{"model":"claude-3-5-haiku-20241022","role":"assistant","content":[{"type":"text","text":"10"}]},"uuid":"434a8768-b8cb-4ca7-bb84-7009a8125ccf","timestamp":"2025-10-31T05:27:50.203Z"}

# No further messages = session ends
```

### Example 2: Session with Tool Use

```json
# User request
{"parentUuid":null,"sessionId":"0507b4e4-48a1-4ec4-a682-51b1dca9d613","type":"user","message":{"role":"user","content":"Run /prepare..."},...}

# Claude calls tool
{"parentUuid":"...","sessionId":"0507b4e4-...","type":"assistant","message":{"content":[{"type":"tool_use","name":"Bash","input":{"command":"pwd"}}]},...}

# User receives tool result
{"parentUuid":"...","sessionId":"0507b4e4-...","type":"user","message":{"content":[{"tool_use_id":"...","type":"tool_result","content":"/home/alex/code/claude-editor-hook"}]},...}

# Claude processes result and continues
{"parentUuid":"...","sessionId":"0507b4e4-...","type":"assistant","message":{"content":[{"type":"text","text":"...analysis..."}]},...}
```

### Example 3: Session with Summary

```json
# Appears near end or as meta-information
{"type":"summary","summary":"Dispatcher workflow analysis: offer ride tool design","leafUuid":"a525a351-..."}
```

---

## Key Fields for Building a Session Viewer

### For Session List (Quick Summary)

Extract these from first user message:

```
sessionId          # Unique identifier
timestamp          # Start time (from first message)
cwd                # Project directory
gitBranch          # Git branch at session start
message.content    # First user message (truncated) = Title/Topic
version            # Claude Code version
```

### For Session Details

```
# Count messages
All lines where type IN ("user", "assistant")

# Get last interaction timestamp
Latest timestamp value

# Identify all tools used
Collect all message[].content[].type == "tool_use" with name field

# Get model used
message.model values (can vary across messages if using different models)

# Track file changes
All file-history-snapshot entries

# Get summary
type == "summary" entries
```

### Useful Derived Fields

```
duration           = max(timestamp) - min(timestamp)
message_count      = count(type IN ("user", "assistant"))
tool_count         = count(type == "tool_use")
models_used        = unique(message.model)
topics             = First 100 chars of first user message
files_changed      = count(snapshot[].trackedFileBackups entries)
```

---

## Gotchas and Edge Cases

### 1. Empty Files

Some JSONL files are empty or contain only file-history-snapshots:

```json
{"type":"file-history-snapshot","messageId":"...","snapshot":{...}}
{"type":"file-history-snapshot","messageId":"...","snapshot":{...}}
```

**These are not real conversations.** Treat as no-op.

### 2. Sidechain Sessions

Messages with `isSidechain: true` are background tasks:

```json
{"isSidechain":true,"type":"user","message":{"content":"Warmup"},...}
```

These are often brief warmup messages or background work. Can include or exclude depending on viewer goals.

### 3. Multiple Models in One Session

A single session can use different models:

```json
# Message 1: Uses haiku
{"message":{"model":"claude-3-5-haiku-20241022",...}}

# Message 2: Uses sonnet
{"message":{"model":"claude-sonnet-4-5-20250929",...}}
```

Track separately if modeling token usage.

### 4. Tool Results Can Be Inline

Tool results appear as user messages with tool_result arrays:

```json
{"type":"user","message":{"content":[{"tool_use_id":"...","type":"tool_result","content":"output"}]}}
```

This is **not a new user input** - it's Claude receiving tool output.

### 5. Truncated Content

Some fields truncate very long content. Full content is available in file-history-snapshot for edited files.

### 6. Timestamp Precision

Timestamps are ISO 8601 with milliseconds:
- `2025-10-29T07:35:14.293Z`
- Ideal for sorting and deduplication

### 7. CWD Can Change

Working directory is recorded per-message:

```json
# Message 1
{"cwd":"/home/alex/code/pedicab512",...}

# Message 2 (could be different project!)
{"cwd":"/home/alex/code/claude-editor-hook",...}
```

This happens with `/prepare` commands across projects.

---

## Recommended Parsing Approach

### For Building a Cache

1. **Index by sessionId**:
   - Use as primary key
   - One entry per `.jsonl` file (usually)

2. **Store Session Metadata**:
   ```typescript
   interface SessionMetadata {
     sessionId: string;
     filePath: string;
     projectPath: string;
     startTime: string;      // First message timestamp
     endTime: string;        // Last message timestamp
     topic: string;          // First 100 chars of first user message
     messageCount: number;
     toolsUsed: string[];    // ["Bash", "Read", "Edit"]
     modelsUsed: string[];   // ["haiku", "sonnet"]
     gitBranch: string;
     lastUpdated: string;    // Cache generation time
   }
   ```

3. **Incremental Updates**:
   - Store file modification time
   - Only re-parse if file changed
   - Compare line counts to detect new messages

### For Session Content Extraction

```bash
# Parse JSONL efficiently
jq -c 'select(.type | IN("user", "assistant"))' session.jsonl

# Extract first message (title)
jq -c 'select(.parentUuid==null)' session.jsonl | head -1 | \
  jq '.message.content[0].text // .message.content' | head -c 100

# Count message types
jq -c '.type' session.jsonl | sort | uniq -c

# Get all tools used
jq -r '.message.content[]? | select(.type=="tool_use") | .name' session.jsonl | sort | uniq
```

---

## What Makes a Good Summary

### Recommended Display

For each session in a viewer:

```
📅 Oct 29, 2025 | 07:35 - 07:40 (5 min) | 12 messages
Branch: mvp | Path: ~/code/claude-editor-hook

"Run /prepare to orient yourself. Read memory-bank/02-active/currentWork.md..."

Tools: Bash, Read, Edit (6 invocations)
Models: claude-sonnet-4-5-20250929
Status: ✓ Complete (no errors)
```

### Quick Scanning (List View)

- **Time Range**: Start and end timestamps
- **Duration**: Human-readable (5 min, 2 hours, etc.)
- **Topic**: First ~80 characters of first user message
- **Tools Used**: Count or icon bar
- **Branch**: Git context
- **Message Count**: Quick complexity indicator

### Clickable Details (Expanded View)

- Full first message
- Timeline of messages with timestamps
- Tool usage breakdown
- File changes
- Model usage and token counts
- Summary (if available via `type: "summary"`)

---

## Integration with Viewing Feature

### For "Better Ctrl-O" Menu

Parse all recent JSONL files:

```bash
# Find all recent JSONL files in current project
find ~/.claude/projects/$(echo "$PWD" | sed 's/\//\-/g') \
  -name "*.jsonl" \
  -mtime -1 \
  -exec stat -c '%Y %n' {} \; \
  | sort -rn \
  | awk '{print $2}' \
  | head -20
```

For each:
1. Extract sessionId and first message
2. Build fzf menu entry
3. When selected, display conversation viewer
4. Allow navigation back to original Claude session if desired

---

## Summary

**Key Takeaways:**

1. **One file = one session** (identified by `sessionId`)
2. **UUIDs are always unique** - use them as primary keys
3. **Sessions are complete JSONL files** - no partial/active sessions during execution
4. **Metadata is rich** - timestamps, branches, tools, models all captured
5. **Summaries exist** - `type: "summary"` gives quick overview
6. **Timestamps are ISO 8601** - sort and compare reliably
7. **Tool usage is traceable** - can rebuild what Claude did
8. **File changes are tracked** - snapshots preserve file edit history

For a conversation viewer feature, focus on:
- Fast JSONL parsing (one-line-at-a-time for memory efficiency)
- Caching with file mtime checks
- Extracting first message for title
- Counting messages and tools for metadata
- Building an index by sessionId and timestamp
