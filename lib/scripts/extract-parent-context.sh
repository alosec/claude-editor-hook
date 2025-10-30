#!/usr/bin/env bash
# Extract recent conversation context from Claude Code JSONL logs with tool usage
# Output: Markdown format with ## USER/ASSISTANT headers and tool summaries

set -euo pipefail

PROJECTS_DIR="$HOME/.claude/projects"
PROJECT_DIR="$PROJECTS_DIR/$(echo "$PWD" | tr '/' '-')"

# Find most recent JSONL file
LATEST_JSONL=$(find "$PROJECT_DIR" -name "*.jsonl" -type f -printf "%T@ %p\n" 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)

if [ -z "$LATEST_JSONL" ] || [ ! -f "$LATEST_JSONL" ]; then
  echo "No recent conversation available"
  exit 0
fi

# Extract conversation with tool context
# Strategy: Process all messages and build structured output with tools
tail -400 "$LATEST_JSONL" | jq -r '
  # Only keep conversation messages
  select(.type == "user" or .type == "assistant") |
  select(.message.content != null) |

  # Normalize content structure
  {
    type: .type,
    timestamp: .timestamp,
    content_type: (
      if (.message.content | type) == "string" then
        "text"
      elif (.message.content | type) == "array" then
        .message.content[0].type
      else
        "unknown"
      end
    ),
    # Extract relevant data based on content type
    data: (
      if (.message.content | type) == "string" then
        {text: .message.content}
      elif (.message.content | type) == "array" then
        if .message.content[0].type == "text" then
          {text: .message.content[0].text}
        elif .message.content[0].type == "tool_use" then
          {
            tool_name: .message.content[0].name,
            tool_id: .message.content[0].id,
            tool_input: .message.content[0].input
          }
        elif .message.content[0].type == "tool_result" then
          {
            tool_id: .message.content[0].tool_use_id,
            is_error: (.message.content[0].is_error // false),
            content: .message.content[0].content
          }
        else
          {}
        end
      else
        {}
      end
    )
  }
' | jq -s '
  # Group into structured conversation with tool context
  # Build a map of tool_id -> tool_result for quick lookup
  reduce .[] as $msg (
    {tool_results: {}, messages: []};

    if $msg.content_type == "tool_result" then
      .tool_results[$msg.data.tool_id] = $msg.data
    else
      .messages += [$msg]
    end
  ) |

  # Group messages into conversation turns
  # A turn ends when type changes from assistant to user
  .messages |
  reduce .[] as $msg (
    {turns: [], current: null, current_type: null};

    if $msg.type != .current_type then
      # New turn starting
      if .current != null then
        .turns += [.current]
      else
        .
      end |
      .current = [$msg] |
      .current_type = $msg.type
    else
      # Continue current turn
      .current += [$msg]
    end
  ) |
  # Add final turn
  if .current != null then
    .turns += [.current]
  else
    .
  end |

  # Take last 15 turns and format
  .turns | .[-15:] | .[] |

  if .[0].type == "user" and .[0].content_type == "text" then
    {type: "user", text: .[0].data.text}
  elif .[0].type == "assistant" then
    # Collect all text and tools in this turn
    (map(select(.content_type == "text")) | map(.data.text) | join("\n\n")) as $text |
    (map(select(.content_type == "tool_use"))) as $tools |

    if ($text | length) > 0 then
      {
        type: "assistant",
        text: $text,
        tools: ($tools | map({
          name: .data.tool_name,
          summary: (
            if .data.tool_name == "Read" then
              .data.tool_input.file_path
            elif .data.tool_name == "Write" then
              "Created " + .data.tool_input.file_path
            elif .data.tool_name == "Edit" then
              .data.tool_input.file_path
            elif .data.tool_name == "Grep" then
              "Pattern: " + .data.tool_input.pattern
            elif .data.tool_name == "Glob" then
              .data.tool_input.pattern
            elif .data.tool_name == "Bash" then
              (.data.tool_input.description // .data.tool_input.command[0:60])
            elif .data.tool_name == "TodoWrite" then
              "Updated todo list"
            else
              ""
            end
          )
        }))
      }
    else
      null
    end
  else
    null
  end | select(. != null)
' | jq -r '
  # Final formatting pass - convert to markdown
  if .type == "user" then
    "## USER\n\n" + .text + "\n"
  elif .type == "assistant" then
    "## ASSISTANT\n\n" + .text +
    (if (.tools | length) > 0 then
      "\n\n**Tools Used:**\n" + (.tools | map("- `" + .name + "` → " + .summary) | join("\n")) + "\n"
    else
      "\n"
    end)
  else
    ""
  end
'
