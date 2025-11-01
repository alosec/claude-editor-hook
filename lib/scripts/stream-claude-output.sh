#!/usr/bin/env bash
# Parse Claude CLI stream-json output and display readable, live-updating output
# Usage: claude -p --output-format stream-json --verbose | stream-claude-output.sh

# ANSI color codes
RESET='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'
CYAN='\033[36m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
MAGENTA='\033[35m'
RED='\033[31m'

# Function to truncate long strings
truncate_string() {
    local str="$1"
    local max_len="${2:-80}"

    if [ ${#str} -gt $max_len ]; then
        echo "${str:0:$max_len}..."
    else
        echo "$str"
    fi
}

# Function to extract JSON field (simple jq-free parser for basic fields)
get_json_field() {
    local json="$1"
    local field="$2"

    # Extract field value using grep and sed
    echo "$json" | grep -o "\"$field\":[^,}]*" | sed 's/^"[^"]*":\s*"\?\([^"]*\)"\?/\1/' | head -1
}

# Function to extract nested field like content[0].text
get_nested_text() {
    local json="$1"

    # Look for "text":"..." pattern in content array
    echo "$json" | grep -o '"text":"[^"]*"' | head -1 | sed 's/"text":"\([^"]*\)"/\1/' | sed 's/\\n/\n/g'
}

# Function to extract tool name from tool_use content
get_tool_name() {
    local json="$1"

    # Look for "name":"..." pattern
    echo "$json" | grep -o '"name":"[^"]*"' | head -1 | sed 's/"name":"\([^"]*\)"/\1/'
}

# Function to get tool input description or other details
get_tool_input() {
    local json="$1"

    # Try to extract description, pattern, or file_path from input
    local desc=$(echo "$json" | grep -o '"description":"[^"]*"' | head -1 | sed 's/"description":"\([^"]*\)"/\1/')
    if [ -n "$desc" ]; then
        echo "$desc"
        return
    fi

    local pattern=$(echo "$json" | grep -o '"pattern":"[^"]*"' | head -1 | sed 's/"pattern":"\([^"]*\)"/\1/')
    if [ -n "$pattern" ]; then
        echo "pattern: $pattern"
        return
    fi

    local file_path=$(echo "$json" | grep -o '"file_path":"[^"]*"' | head -1 | sed 's/"file_path":"\([^"]*\)"/\1/')
    if [ -n "$file_path" ]; then
        echo "$file_path"
        return
    fi

    # Default: show abbreviated input
    echo "$json" | grep -o '"input":{[^}]*}' | head -c 60
}

echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${BOLD}${CYAN}Claude Non-Interactive Enhancement${RESET}"
echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

# Track state
session_started=false
tool_count=0
message_count=0

# Read NDJSON line by line
while IFS= read -r line; do
    # Skip empty lines
    [ -z "$line" ] && continue

    # Extract event type
    event_type=$(get_json_field "$line" "type")

    case "$event_type" in
        system)
            subtype=$(get_json_field "$line" "subtype")
            if [ "$subtype" = "init" ]; then
                model=$(get_json_field "$line" "model")
                session_id=$(get_json_field "$line" "session_id" | head -c 8)
                echo -e "${DIM}Session: $session_id | Model: $model${RESET}"
                echo ""
                session_started=true
            fi
            ;;

        tool_use)
            ((tool_count++))
            tool_name=$(get_tool_name "$line")
            tool_input=$(get_tool_input "$line")

            # Different icons for different tools
            case "$tool_name" in
                Read)
                    icon="📖"
                    color="$BLUE"
                    ;;
                Write|Edit|MultiEdit)
                    icon="✍️"
                    color="$GREEN"
                    ;;
                Grep|Glob)
                    icon="🔍"
                    color="$YELLOW"
                    ;;
                Bash)
                    icon="⚡"
                    color="$MAGENTA"
                    ;;
                *)
                    icon="🔧"
                    color="$CYAN"
                    ;;
            esac

            truncated_input=$(truncate_string "$tool_input" 60)
            echo -e "${color}${icon} ${BOLD}${tool_name}${RESET}${color}: ${truncated_input}${RESET}"
            ;;

        tool_result)
            # Don't show full results (too verbose), just acknowledge
            # Uncomment if you want to see result status
            # is_error=$(get_json_field "$line" "is_error")
            # if [ "$is_error" = "true" ]; then
            #     echo -e "${RED}  └─ Error${RESET}"
            # fi
            ;;

        assistant)
            # Check if this contains tool_use (nested in content array)
            if echo "$line" | grep -q '"type":"tool_use"'; then
                # Extract tool information from content array
                tool_name=$(echo "$line" | grep -o '"name":"[^"]*"' | head -1 | sed 's/"name":"\([^"]*\)"/\1/')

                # Try to extract description, file_path, or pattern from input
                tool_input=""
                desc=$(echo "$line" | grep -o '"description":"[^"]*"' | head -1 | sed 's/"description":"\([^"]*\)"/\1/')
                if [ -n "$desc" ]; then
                    tool_input="$desc"
                else
                    file_path=$(echo "$line" | grep -o '"file_path":"[^"]*"' | head -1 | sed 's/"file_path":"\([^"]*\)"/\1/')
                    if [ -n "$file_path" ]; then
                        tool_input="$file_path"
                    else
                        pattern=$(echo "$line" | grep -o '"pattern":"[^"]*"' | head -1 | sed 's/"pattern":"\([^"]*\)"/\1/')
                        if [ -n "$pattern" ]; then
                            tool_input="pattern: $pattern"
                        else
                            command=$(echo "$line" | grep -o '"command":"[^"]*"' | head -1 | sed 's/"command":"\([^"]*\)"/\1/')
                            if [ -n "$command" ]; then
                                tool_input="$command"
                            fi
                        fi
                    fi
                fi

                if [ -n "$tool_name" ]; then
                    ((tool_count++))

                    # Different icons for different tools
                    case "$tool_name" in
                        Read)
                            icon="📖"
                            color="$BLUE"
                            ;;
                        Write|Edit|MultiEdit)
                            icon="✍️"
                            color="$GREEN"
                            ;;
                        Grep|Glob)
                            icon="🔍"
                            color="$YELLOW"
                            ;;
                        Bash)
                            icon="⚡"
                            color="$MAGENTA"
                            ;;
                        *)
                            icon="🔧"
                            color="$CYAN"
                            ;;
                    esac

                    truncated_input=$(truncate_string "$tool_input" 60)
                    echo -e "${color}${icon} ${BOLD}${tool_name}${RESET}${color}: ${truncated_input}${RESET}"
                fi
            else
                # Extract assistant message text
                text=$(get_nested_text "$line")

                if [ -n "$text" ]; then
                    ((message_count++))
                    echo -e "${BOLD}💬 Claude:${RESET} $text"
                    echo ""
                fi
            fi
            ;;

        result)
            subtype=$(get_json_field "$line" "subtype")

            if [ "$subtype" = "success" ]; then
                duration=$(get_json_field "$line" "duration_ms")
                duration_sec=$(echo "scale=1; $duration / 1000" | bc 2>/dev/null || echo "?")

                total_cost=$(get_json_field "$line" "total_cost_usd")

                # Extract usage tokens
                input_tokens=$(echo "$line" | grep -o '"input_tokens":[0-9]*' | head -1 | sed 's/[^0-9]//g')
                output_tokens=$(echo "$line" | grep -o '"output_tokens":[0-9]*' | head -1 | sed 's/[^0-9]//g')

                echo ""
                echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
                echo -e "${GREEN}✅ Enhancement Complete${RESET}"
                echo -e "${DIM}Duration: ${duration_sec}s | Tools: $tool_count | Tokens: ${input_tokens}→${output_tokens} | Cost: \$$total_cost${RESET}"
                echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
            elif [ "$subtype" = "error" ]; then
                error_msg=$(get_nested_text "$line")
                echo ""
                echo -e "${BOLD}${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
                echo -e "${RED}❌ Error:${RESET} $error_msg"
                echo -e "${BOLD}${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
            fi
            ;;

        *)
            # Unknown event type - skip silently
            ;;
    esac
done

# If we didn't get a proper session, show warning
if [ "$session_started" = false ]; then
    echo -e "${YELLOW}⚠️  No streaming data received${RESET}"
fi
