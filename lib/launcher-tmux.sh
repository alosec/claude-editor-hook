#!/usr/bin/env bash
#
# Tmux Launcher
#
# Orchestrate tmux sessions with multiple panes

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"
source "$SCRIPT_DIR/config-reader.sh"

# Check for tmux
if ! command_exists tmux; then
    die "tmux not found. Install with: sudo apt install tmux"
fi

main() {
    local context_file="${1:-}"

    if [[ -z "$context_file" ]]; then
        die "No context file provided"
    fi

    # Parse context if not already done
    if [[ -z "${EDITOR_HOOK_FILES:-}" ]]; then
        parse_context "$context_file"
    fi

    # Session name
    local session_name="claude-editor-$(date +%s)"

    log_debug "Creating tmux session: $session_name"

    # Create new tmux session (detached)
    tmux new-session -d -s "$session_name"

    # Get file count
    local file_count=$(get_file_count)

    # Pane 1: Editor with files
    if [[ "$file_count" -gt 0 ]]; then
        local first_file=$(get_file_path 0)
        local first_line=$(get_file_line 0)

        if [[ -n "$first_line" && "$first_line" != "null" ]]; then
            tmux send-keys -t "$session_name:0" "emacs -nw +$first_line \"$first_file\"" C-m
        else
            tmux send-keys -t "$session_name:0" "emacs -nw \"$first_file\"" C-m
        fi
    else
        tmux send-keys -t "$session_name:0" "emacs -nw" C-m
    fi

    # Split horizontally for additional panes
    tmux split-window -h -t "$session_name:0"

    # Pane 2: Shell for commands
    tmux send-keys -t "$session_name:0.1" "# Additional files or commands go here" C-m
    tmux send-keys -t "$session_name:0.1" "# Press Ctrl-B then arrow keys to navigate panes" C-m

    # If there are additional files, list them
    if [[ "$file_count" -gt 1 ]]; then
        tmux send-keys -t "$session_name:0.1" "echo 'Additional files:'" C-m
        for (( i=1; i<file_count; i++ )); do
            local path=$(get_file_path "$i")
            local line=$(get_file_line "$i")
            local desc=$(get_file_description "$i")

            if [[ -n "$desc" && "$desc" != '""' ]]; then
                tmux send-keys -t "$session_name:0.1" "echo '  $path:$line - $desc'" C-m
            else
                tmux send-keys -t "$session_name:0.1" "echo '  $path:$line'" C-m
            fi
        done
    fi

    # Focus on editor pane
    tmux select-pane -t "$session_name:0.0"

    # Attach to session
    exec tmux attach-session -t "$session_name"
}

main "$@"
