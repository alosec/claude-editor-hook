# JSONL Parsing Code Examples

## Bash Examples (Using jq)

### Parse All Sessions for a Project

```bash
#!/bin/bash
PROJECT_DIR="$1"  # e.g., /home/alex/code/pedicab512

# Find all JSONL files
find ~/.claude/projects \
  -path "*$(echo "$PROJECT_DIR" | sed 's/.*\///')*" \
  -name "*.jsonl" \
  -type f | while read file; do
  
  echo "=== Session: $(basename $file) ==="
  
  # Extract first message (title)
  jq -r 'select(.parentUuid==null) | .message.content | if type == "string" then . else .[0].text // "" end' \
    "$file" | head -c 100
  
  # Count messages
  echo ""
  echo "Messages: $(jq -c 'select(.type | IN("user", "assistant"))' "$file" | wc -l)"
  
  # Extract tools used
  echo "Tools: $(jq -r '.message.content[]? | select(.type=="tool_use") | .name' "$file" 2>/dev/null | sort | uniq | tr '\n' ',' | sed 's/,$//')"
  
  # Get timestamps
  START=$(jq -r '.timestamp' "$file" | head -1)
  END=$(jq -r '.timestamp' "$file" | tail -1)
  echo "Time: $START to $END"
  echo ""
done
```

### Extract Session Metadata

```bash
#!/bin/bash
# Extract metadata for one JSONL file into JSON

FILE="$1"

jq -n \
  --arg file "$(basename $FILE)" \
  --slurpfile data <(cat "$FILE") \
  '
  ($data | map(select(.parentUuid==null)) | .[0]) as $first |
  ($data | map(select(.parentUuid!=null and .type=="user")) | .[0]) as $second |
  ($data | reverse | .[0]) as $last |
  {
    filename: $file,
    sessionId: ($first.sessionId // "unknown"),
    startTime: ($first.timestamp // "unknown"),
    endTime: ($last.timestamp // "unknown"),
    project: ($first.cwd // "unknown"),
    branch: ($first.gitBranch // "unknown"),
    topic: (
      $second.message.content |
      if type == "string" then . else 
        ([.[] | select(.type == "text") | .text] | join(" ")) 
      end | 
      .[0:100]
    ),
    messageCount: (
      $data | 
      map(select(.type | IN("user", "assistant"))) | 
      length
    ),
    toolsUsed: (
      $data | 
      map(.message.content[]? | select(.type=="tool_use") | .name) | 
      unique | 
      sort
    )
  }
  ' 2>/dev/null
```

### Stream-Friendly Parsing (for large files)

```bash
#!/bin/bash
# Process JSONL line-by-line without loading entire file

FILE="$1"

declare -a message_types
declare -a tools_used

while IFS= read -r line; do
  # Skip empty lines
  [[ -z "$line" ]] && continue
  
  # Extract type
  type=$(echo "$line" | jq -r '.type')
  
  # Count message types
  ((message_types[$type]++))
  
  # Extract tool names if present
  if [[ "$type" == "assistant" ]]; then
    tools=$(echo "$line" | jq -r '.message.content[]? | select(.type=="tool_use") | .name' 2>/dev/null)
    while IFS= read -r tool; do
      [[ -n "$tool" ]] && tools_used["$tool"]=1
    done <<< "$tools"
  fi
done < "$FILE"

echo "Message types:"
for type in "${!message_types[@]}"; do
  echo "  $type: ${message_types[$type]}"
done

echo "Tools used:"
for tool in "${!tools_used[@]}"; do
  echo "  $tool"
done
```

---

## Python Examples

### Minimal Parser

```python
import json
from pathlib import Path
from typing import List, Dict, Optional

class SessionParser:
    def __init__(self, jsonl_file: Path):
        self.file = jsonl_file
        self.messages = []
    
    def parse(self) -> List[Dict]:
        """Parse JSONL file into list of messages."""
        with open(self.file, 'r') as f:
            for line in f:
                if line.strip():
                    self.messages.append(json.loads(line))
        return self.messages
    
    def get_first_message(self) -> Optional[str]:
        """Extract first user message as session title."""
        for msg in self.messages:
            if msg.get('parentUuid') is None and msg.get('type') == 'user':
                content = msg.get('message', {}).get('content', '')
                if isinstance(content, str):
                    return content[:100]
                elif isinstance(content, list) and content:
                    for item in content:
                        if item.get('type') == 'text':
                            return item.get('text', '')[:100]
        return None
    
    def get_tools_used(self) -> List[str]:
        """Extract all tools used in session."""
        tools = set()
        for msg in self.messages:
            if msg.get('type') == 'assistant':
                content = msg.get('message', {}).get('content', [])
                if isinstance(content, list):
                    for item in content:
                        if item.get('type') == 'tool_use':
                            tools.add(item.get('name', 'unknown'))
        return sorted(list(tools))
    
    def get_metadata(self) -> Dict:
        """Extract session metadata."""
        messages = [m for m in self.messages 
                   if m.get('type') in ('user', 'assistant')]
        
        if not messages:
            return {}
        
        first = messages[0]
        last = messages[-1]
        
        return {
            'sessionId': first.get('sessionId'),
            'startTime': first.get('timestamp'),
            'endTime': last.get('timestamp'),
            'project': first.get('cwd'),
            'branch': first.get('gitBranch'),
            'topic': self.get_first_message(),
            'messageCount': len(messages),
            'toolsUsed': self.get_tools_used(),
            'modelsUsed': list(set(
                m.get('message', {}).get('model') 
                for m in messages 
                if m.get('type') == 'assistant'
            ))
        }
```

### With Caching

```python
import json
import hashlib
from pathlib import Path
from datetime import datetime
from typing import Dict, Optional

class CachedSessionIndex:
    def __init__(self, cache_file: Path = Path('~/.cache/claude-sessions.json')):
        self.cache_file = Path(cache_file).expanduser()
        self.cache_file.parent.mkdir(parents=True, exist_ok=True)
        self.cache: Dict = self._load_cache()
    
    def _load_cache(self) -> Dict:
        """Load cached metadata."""
        if self.cache_file.exists():
            with open(self.cache_file, 'r') as f:
                return json.load(f)
        return {}
    
    def _save_cache(self):
        """Save cache to disk."""
        with open(self.cache_file, 'w') as f:
            json.dump(self.cache, f, indent=2)
    
    def _get_file_hash(self, file_path: Path) -> str:
        """Get file modification hash."""
        stat = file_path.stat()
        return f"{stat.st_mtime}:{stat.st_size}"
    
    def get_session_metadata(self, jsonl_file: Path) -> Dict:
        """Get metadata with caching."""
        key = str(jsonl_file.absolute())
        file_hash = self._get_file_hash(jsonl_file)
        
        # Check cache
        if key in self.cache:
            cached = self.cache[key]
            if cached.get('fileHash') == file_hash:
                return cached['metadata']
        
        # Parse file
        parser = SessionParser(jsonl_file)
        parser.parse()
        metadata = parser.get_metadata()
        
        # Cache result
        self.cache[key] = {
            'fileHash': file_hash,
            'metadata': metadata,
            'cached_at': datetime.now().isoformat()
        }
        self._save_cache()
        
        return metadata
    
    def index_project(self, project_path: Path) -> List[Dict]:
        """Index all sessions in a project."""
        project_dir = Path(f"~/.claude/projects/-{str(project_path).replace('/', '-')}").expanduser()
        
        results = []
        if project_dir.exists():
            for jsonl_file in sorted(project_dir.glob('*.jsonl')):
                try:
                    metadata = self.get_session_metadata(jsonl_file)
                    results.append({**metadata, 'file': str(jsonl_file)})
                except Exception as e:
                    print(f"Error parsing {jsonl_file}: {e}")
        
        return sorted(results, key=lambda x: x.get('startTime', ''), reverse=True)
```

### Streaming Parser for Large Files

```python
from typing import Iterator, Dict
import json

def stream_jsonl(file_path: Path) -> Iterator[Dict]:
    """Stream JSONL file line by line."""
    with open(file_path, 'r') as f:
        for line in f:
            if line.strip():
                try:
                    yield json.loads(line)
                except json.JSONDecodeError:
                    continue

def extract_summary_from_stream(file_path: Path) -> Dict:
    """Extract metadata from JSONL without loading entire file."""
    first_msg = None
    last_msg = None
    msg_count = 0
    tools = set()
    
    for msg in stream_jsonl(file_path):
        # Get first message
        if first_msg is None and msg.get('parentUuid') is None:
            first_msg = msg
        
        # Count messages
        if msg.get('type') in ('user', 'assistant'):
            msg_count += 1
            last_msg = msg
        
        # Collect tools
        if msg.get('type') == 'assistant':
            content = msg.get('message', {}).get('content', [])
            if isinstance(content, list):
                for item in content:
                    if item.get('type') == 'tool_use':
                        tools.add(item.get('name'))
    
    return {
        'sessionId': first_msg.get('sessionId') if first_msg else None,
        'startTime': first_msg.get('timestamp') if first_msg else None,
        'endTime': last_msg.get('timestamp') if last_msg else None,
        'messageCount': msg_count,
        'toolsUsed': sorted(list(tools))
    }
```

---

## TypeScript/JavaScript Examples

### Basic Parser

```typescript
import * as fs from 'fs';
import * as readline from 'readline';
import { promisify } from 'util';

interface SessionMetadata {
  sessionId: string;
  startTime: string;
  endTime: string;
  topic: string;
  messageCount: number;
  toolsUsed: string[];
}

interface JSONLMessage {
  parentUuid?: string | null;
  type: 'user' | 'assistant' | 'summary' | 'file-history-snapshot';
  sessionId: string;
  message?: {
    content?: string | any[];
    model?: string;
  };
  timestamp: string;
}

async function parseSessionMetadata(filePath: string): Promise<SessionMetadata> {
  const fileStream = fs.createReadStream(filePath);
  const rl = readline.createInterface({
    input: fileStream,
    crlfDelay: Infinity
  });

  const messages: JSONLMessage[] = [];

  for await (const line of rl) {
    if (line.trim()) {
      messages.push(JSON.parse(line));
    }
  }

  const firstMsg = messages.find(m => m.parentUuid === null);
  const conversationMsgs = messages.filter(m => m.type === 'user' || m.type === 'assistant');
  const lastMsg = conversationMsgs[conversationMsgs.length - 1];

  const topic = extractTopic(firstMsg);
  const tools = extractTools(messages);

  return {
    sessionId: firstMsg?.sessionId || 'unknown',
    startTime: firstMsg?.timestamp || '',
    endTime: lastMsg?.timestamp || '',
    topic,
    messageCount: conversationMsgs.length,
    toolsUsed: tools
  };
}

function extractTopic(msg?: JSONLMessage): string {
  if (!msg) return '';
  
  const content = msg.message?.content;
  if (typeof content === 'string') {
    return content.substring(0, 100);
  }
  if (Array.isArray(content)) {
    const text = content.find(c => typeof c === 'string' || (typeof c === 'object' && c.type === 'text'));
    if (typeof text === 'string') return text.substring(0, 100);
    if (text?.text) return text.text.substring(0, 100);
  }
  return '';
}

function extractTools(messages: JSONLMessage[]): string[] {
  const tools = new Set<string>();
  
  for (const msg of messages) {
    if (msg.type === 'assistant' && Array.isArray(msg.message?.content)) {
      for (const content of msg.message.content) {
        if (content.type === 'tool_use' && content.name) {
          tools.add(content.name);
        }
      }
    }
  }
  
  return Array.from(tools).sort();
}
```

### Memory-Efficient Streaming Parser

```typescript
async function* streamJSONL(filePath: string) {
  const fileStream = fs.createReadStream(filePath);
  const rl = readline.createInterface({
    input: fileStream,
    crlfDelay: Infinity
  });

  for await (const line of rl) {
    if (line.trim()) {
      yield JSON.parse(line) as JSONLMessage;
    }
  }
}

async function getSessionSummary(filePath: string): Promise<SessionMetadata> {
  let firstMsg: JSONLMessage | null = null;
  let lastMsg: JSONLMessage | null = null;
  let messageCount = 0;
  const tools = new Set<string>();

  for await (const msg of streamJSONL(filePath)) {
    // Track first message
    if (!firstMsg && msg.parentUuid === null) {
      firstMsg = msg;
    }

    // Count conversation messages
    if (msg.type === 'user' || msg.type === 'assistant') {
      messageCount++;
      lastMsg = msg;
    }

    // Collect tools
    if (msg.type === 'assistant' && Array.isArray(msg.message?.content)) {
      for (const content of msg.message.content) {
        if (content.type === 'tool_use') {
          tools.add(content.name);
        }
      }
    }
  }

  return {
    sessionId: firstMsg?.sessionId || 'unknown',
    startTime: firstMsg?.timestamp || '',
    endTime: lastMsg?.timestamp || '',
    topic: extractTopic(firstMsg),
    messageCount,
    toolsUsed: Array.from(tools).sort()
  };
}
```

### Indexed Session Finder

```typescript
import glob from 'glob';
import { promisify } from 'util';

const globAsync = promisify(glob);

async function indexProjectSessions(projectPath: string): Promise<SessionMetadata[]> {
  // Convert project path to Claude index format
  const projectName = projectPath.replace(/\//g, '-');
  const claudeDir = `${process.env.HOME}/.claude/projects/-${projectName}`;
  
  // Find all JSONL files
  const files = await globAsync(`${claudeDir}/*.jsonl`);
  
  const sessions: SessionMetadata[] = [];
  
  for (const file of files.sort().reverse()) { // Newest first
    try {
      const metadata = await getSessionSummary(file);
      sessions.push(metadata);
    } catch (error) {
      console.error(`Error parsing ${file}:`, error);
    }
  }
  
  return sessions.sort((a, b) => 
    new Date(b.endTime).getTime() - new Date(a.endTime).getTime()
  );
}
```

---

## Shell Script for Quick Viewing

```bash
#!/bin/bash
# view-sessions.sh - Quick session browser

PROJECT="${1:-.}"
PROJECT_KEY=$(echo "$PROJECT" | sed 's|.*/||;s/-/_/g')
SESSIONS_DIR="$HOME/.claude/projects/-${PROJECT##*/}"

if [ ! -d "$SESSIONS_DIR" ]; then
  echo "No sessions found for $PROJECT"
  exit 1
fi

# Generate session list with fzf
FZF_SELECTION=$(
  for file in "$SESSIONS_DIR"/*.jsonl; do
    [ -f "$file" ] || continue
    
    # Extract first message
    TOPIC=$(jq -r 'select(.parentUuid==null) | .message.content | if type == "string" then . else .[0].text // "" end' "$file" 2>/dev/null | head -c 60)
    
    # Count messages
    COUNT=$(jq -c 'select(.type | IN("user", "assistant"))' "$file" 2>/dev/null | wc -l)
    
    # Get date
    DATE=$(jq -r '.timestamp' "$file" 2>/dev/null | head -1 | cut -dT -f1)
    
    printf '%s|%d messages|%s|%s\n' "$file" "$COUNT" "$DATE" "$TOPIC"
  done | \
  sort -t'|' -k3 -r | \
  fzf --with-nth 4 --preview 'jq . {1} | head -50' \
      --preview-window 'right:50%' \
      --delimiter '|'
)

if [ -z "$FZF_SELECTION" ]; then
  exit 0
fi

SESSION_FILE=$(echo "$FZF_SELECTION" | cut -d'|' -f1)

# Display full session
echo "=== Session: $(basename $SESSION_FILE) ==="
echo ""

# Show full conversation
jq -r 'select(.type | IN("user", "assistant")) | 
  "[" + .timestamp + "] " + 
  (if .type == "user" then "👤 User" else "🤖 Claude" end) + 
  ": " + 
  (if .message.content | type == "string" then .message.content 
   elif .message.content[0].type == "text" then .message.content[0].text
   else "(" + (.message.content[0].type // "unknown") + ")"
   end | 
  .[0:100] + (if length > 100 then "..." else "" end))' \
  "$SESSION_FILE"
```

---

## Performance Tips

1. **For Large Files**: Use streaming parsers instead of loading entire JSON
2. **For Indexing**: Cache metadata with file mtime checks
3. **For Searching**: Build SQLite index for quick lookups
4. **For Filtering**: Use jq filters before parsing in shell
5. **For Dedup**: Use sessionId as primary key (usually matches filename)

