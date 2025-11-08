# Claude Code JSONL Quick Reference

## TL;DR

- **One file = one session** (UUID-named `.jsonl` files)
- **One line = one message** (complete JSON object)
- **All sessions together** = rich conversation history
- **sessionId field** = primary key for deduplication
- **First message with parentUuid:null** = session start
- **Last message in file** = session end

---

## Session File Locations

```
~/.claude/projects/
├── -home-alex-code/                    # Project name encoded in dir name
│   └── 0507b4e4-48a1-4ec4-a682-51b1dca9d613.jsonl  # One session
├── -home-alex-code-pedicab512/
│   ├── 02a992ed-fb8a-4d0b-8a81-7998432eab11.jsonl
│   ├── agent-32335b9b.jsonl            # Subagent session (still one file)
│   └── ...
```

---

## Essential Fields (Every Message)

```json
{
  "sessionId": "550e8400-e29b-41d4-a716-446655440000",  // Primary key
  "timestamp": "2025-10-29T07:35:14.293Z",              // ISO 8601
  "type": "user | assistant | summary | file-history-snapshot",
  "parentUuid": "previous-message-uuid or null",        // null = session start
  "cwd": "/home/alex/code/project",                     // Working directory
  "gitBranch": "main",                                  // Git context
  "message": {...}                                       // Content (varies)
}
```

---

## Message Type Patterns

### User Message
```json
{
  "type": "user",
  "message": {
    "role": "user",
    "content": "Your question or tool result"
  }
}
```

### Assistant Message
```json
{
  "type": "assistant",
  "message": {
    "model": "claude-sonnet-4-5-20250929",
    "role": "assistant",
    "content": [
      {"type": "text", "text": "...response..."},
      {"type": "tool_use", "name": "Bash", "input": {...}},
      {"type": "tool_result", "content": "...output..."}
    ]
  }
}
```

### Summary Message
```json
{
  "type": "summary",
  "summary": "Quick session description",
  "leafUuid": "some-uuid"
}
```

### File History Snapshot
```json
{
  "type": "file-history-snapshot",
  "snapshot": {
    "trackedFileBackups": {
      "path/to/file.js": {"backupFileName": "...", "version": 3}
    }
  }
}
```

---

## One-Liners for Quick Analysis

```bash
# Count messages in a session
jq -c 'select(.type | IN("user", "assistant"))' session.jsonl | wc -l

# Get first user message (title)
jq -r 'select(.parentUuid==null) | .message.content | if type == "string" then . else .[0].text // "" end' session.jsonl | head -c 100

# List all tools used
jq -r '.message.content[]? | select(.type=="tool_use") | .name' session.jsonl | sort | uniq

# Get session duration
echo "Start: $(jq -r '.timestamp' session.jsonl | head -1)"
echo "End: $(jq -r '.timestamp' session.jsonl | tail -1)"

# Extract session metadata as JSON
jq -n --slurpfile data <(cat session.jsonl) '
  {
    sessionId: $data[0].sessionId,
    messages: ($data | map(select(.type | IN("user", "assistant"))) | length),
    tools: ($data | map(.message.content[]? | select(.type=="tool_use") | .name) | unique),
    branch: $data[0].gitBranch,
    project: $data[0].cwd
  }'
```

---

## Identifying Sessions Programmatically

### The Rule
- **sessionId** is unique per session
- **Filename UUID** usually matches sessionId (for main sessions)
- **All messages in one file** have same sessionId

### Examples
```bash
# Extract sessionId
jq -r '.sessionId' session.jsonl | head -1

# List all sessions in a project with counts
for f in ~/.claude/projects/-home-alex-code/*.jsonl; do
  ID=$(jq -r '.sessionId' "$f" | head -1)
  COUNT=$(jq -c 'select(.type=="user" or .type=="assistant")' "$f" | wc -l)
  echo "$ID: $COUNT messages"
done
```

---

## Building a Summary

For each session, extract and display:

```
📅 2025-10-29 | 07:35-07:40 (5 min) | 12 messages
Branch: mvp | ~/code/claude-editor-hook

"Run /prepare to orient yourself..."

Tools: Bash, Read (3 invocations)
Model: claude-sonnet-4-5-20250929
```

**Key metrics:**
- **startTime**: First message timestamp
- **endTime**: Last message timestamp  
- **messageCount**: User + assistant messages
- **toolsUsed**: Unique tool names in assistant messages
- **topic**: First 80 chars of first user message
- **branch**: gitBranch from first message
- **model**: message.model from assistant messages

---

## Gotchas

1. **Empty files** - Some files only contain `file-history-snapshot` lines (skip these)
2. **Sidechain messages** - `isSidechain: true` = background work (optional to display)
3. **Tool results** - Appear as user messages, not separate user input
4. **Mixed models** - One session can use different models in different messages
5. **CWD changes** - Working directory can change mid-session (per-message field)
6. **No "end" marker** - Session ends when file writing stops
7. **Very long content** - Some fields truncate; use file-history-snapshot for full content

---

## Integration Ideas

### "Better Ctrl-O" Menu

```bash
# 1. Find recent sessions in current project
PROJ=$(pwd | sed 's|.*/||')
find ~/.claude/projects/-*$PROJ* -name "*.jsonl" -mtime -1 | head -20

# 2. For each, extract metadata
# 3. Display in fzf menu
# 4. Show full conversation on selection
```

### Session Viewer Features

- Sort by timestamp (newest first)
- Filter by branch, tool usage, duration
- Search by first message content
- Show tool invocation timeline
- Display file changes
- Link back to original conversation

### Analytics

- Total sessions per project
- Tools used most frequently
- Average session duration
- Time of day patterns
- Git branch usage
- Model selection patterns

---

## File Format Reliability

- JSONL format is **line-oriented** - one message per line
- Each line is **valid, parseable JSON** independently
- **No special escaping** needed beyond standard JSON
- **Large files** can be processed streaming (one line at a time)
- **Safe to append** - only new messages added, never modified
- **UTF-8 encoded** - standard JSON encoding

---

## Performance Considerations

| Task | Approach | Speed |
|------|----------|-------|
| Session count | Parse filenames | Instant |
| First message | Read first line only | Fast |
| Full metadata | Stream entire file | Medium |
| Build index | Parallel parse all files | Slow but cacheable |
| Search content | grep + jq filters | Medium |

**Best practice:** Cache metadata with file mtime checks

---

## Real Example Session

File: `0530c06c-0d82-401b-85d4-525103ec3912.jsonl` (43 lines)

**Line 1** (first message, starts session):
```json
{"parentUuid":null,"sessionId":"0530c06c-0d82-401b-85d4-525103ec3912","type":"user","message":{"role":"user","content":"*** Tell me about this repo. ***"},"timestamp":"2025-10-29T22:37:04.455Z"}
```

**Lines 2-40** (conversation):
- Various assistant responses
- Tool uses (Bash, Read, Glob)
- Tool results
- File history snapshots

**Lines 41-43** (metadata/summaries):
```json
{"type":"summary","summary":"Project Review: claude-editor-hook Overview","leafUuid":"..."}
```

**Analysis**:
- Session ID: `0530c06c-0d82-401b-85d4-525103ec3912`
- Duration: ~17 minutes
- Messages: ~15 (counting user + assistant)
- Tools: Bash, Read, Glob
- Topic: "Tell me about this repo"

---

## Export Formats

### Summary CSV
```bash
jq -r '[.sessionId, .timestamp, (.message.content | if type=="string" then . else .[0].text // "" end), .gitBranch, .cwd] | @csv' *.jsonl
```

### Full JSON Index
```bash
jq -s 'group_by(.sessionId) | map({sessionId: .[0].sessionId, messageCount: length, startTime: .[0].timestamp, endTime: .[-1].timestamp})' *.jsonl
```

### Timeline View
```bash
jq -r '.timestamp + " " + .type + " " + (.message.content | if type=="string" then . else .[0].type // "unknown" end | .[0:30])' *.jsonl | sort
```

---

## Quick Wins for Your Viewer

1. **Sort by recency**: `jq '.timestamp' | sort -r | head -1` per file
2. **Filter by branch**: `jq 'select(.gitBranch=="main")' | ...`
3. **Find tool usage**: `jq 'select(.message.content[]?.name=="Bash")' | ...`
4. **Group by project**: Key on directory name (encode project path)
5. **Calculate stats**: Parallel jq + aggregation
6. **Cache aggressively**: Use file mtime as cache invalidation

---

## Common Patterns

### Extract All Bash Commands Run
```bash
jq -r '.message.content[]? | select(.type=="tool_use" and .name=="Bash") | .input.command' *.jsonl
```

### Find All Files Read
```bash
jq -r '.message.content[]? | select(.type=="tool_use" and .name=="Read") | .input.file_path' *.jsonl | sort | uniq
```

### Get Conversation Transcript
```bash
jq -r 'select(.type | IN("user", "assistant")) | 
  (if .type=="user" then "User: " else "Claude: " end) + 
  (if .message.content | type=="string" then .message.content else 
   ([.message.content[]? | select(.type=="text") | .text] | join(" ")) end)' *.jsonl
```

### Find Longest Sessions
```bash
for f in *.jsonl; do
  COUNT=$(jq -c 'select(.type=="user" or .type=="assistant")' "$f" | wc -l)
  echo "$COUNT $f"
done | sort -rn | head -10
```

