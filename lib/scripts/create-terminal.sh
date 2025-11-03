#!/usr/bin/env bash
# Create a new numbered terminal window in Claude session
# Returns the window name (e.g., "terminal-1")

SESSION_NAME="Claude"
PROMPT_FILE="$1"

# Check if session exists
if ! tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    echo "Error: Claude session does not exist" >&2
    exit 1
fi

# Find next available terminal number
# Get all terminal-* windows, extract numbers, find max, add 1
existing_nums=$(tmux list-windows -t "$SESSION_NAME" -F '#{window_name}' 2>/dev/null | grep '^terminal-' | grep -o '[0-9]*$' | sort -n)

if [ -z "$existing_nums" ]; then
    # No terminals exist yet, start with 1
    next_num=1
else
    # Find max and increment
    max_num=$(echo "$existing_nums" | tail -1)
    next_num=$((max_num + 1))
fi

# Create window name
window_name="terminal-$next_num"

# Create new tmux window with bash shell
tmux new-window -t "$SESSION_NAME" -n "$window_name"

# Set up the terminal environment
# 1. Export PROMPT variable pointing to current prompt file
# 2. Set up menu alias to return to command palette
# 3. Launch bash with user's .bashrc and menu alias

# Build the initialization command
init_cmd="export PROMPT='$PROMPT_FILE'; alias menu='claude-editor-menu'; exec bash --rcfile <(cat ~/.bashrc 2>/dev/null; echo 'alias menu=\"claude-editor-menu\"'; echo 'export PROMPT=\"$PROMPT_FILE\"')"

# Send commands to the new window
tmux send-keys -t "$SESSION_NAME:$window_name" "$init_cmd" Enter

# Output the window name for caller
echo "$window_name"
