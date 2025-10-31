#!/usr/bin/env bash
# Shared menu logic for both claude-editor-hook and claude-editor-menu
# This ensures menu options and behavior stay in sync

# Usage: show_menu <file-path>
show_menu() {
    local FILE="$1"

    # Get script directory for finding helper scripts
    local SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    # Menu definition - single source of truth
    local MENU="Edit with Emacs:emacs -nw \"$FILE\"
Edit with Vi:vi \"$FILE\"
Edit with Nano:nano \"$FILE\"
Open Terminal:open-terminal
Recent Files:recent-files
Detach:detach
Enhance (Interactive):claude-spawn-interactive
Enhance (Non-interactive):claude-enhance-auto"

    # Show FZF menu
    local choice=$(echo "$MENU" | fzf --height=100% --prompt='Command: ' --border --reverse)

    if [ -z "$choice" ]; then
        # User cancelled
        return 0
    fi

    # Extract command from selection
    local cmd=$(echo "$choice" | cut -d: -f2)

    # Execute command
    case "$cmd" in
        open-terminal)
            # Open terminal - set PROMPT env var and drop into bash
            export PROMPT="$FILE"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "Claude Editor Workspace"
            echo "Type 'menu' to open command palette"
            echo "Access prompt file: \$PROMPT"
            echo "File: $PROMPT"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo ""
            # Set up menu alias and launch bash with it available
            exec bash --rcfile <(cat ~/.bashrc 2>/dev/null; echo 'alias menu="claude-editor-menu"')
            ;;

        recent-files)
            # Recent Files - query JSONL logs directly with caching
            local QUERY_SCRIPT="$SCRIPT_DIR/scripts/query-recent-files-jsonl.sh"

            # Get project root and home directory for path truncation
            local PROJECT_DIR="$PWD"
            local HOME_DIR="$HOME"

            # Query recent files, truncate paths, and show in FZF
            # Create temporary file to store full_path:truncated_path mapping
            local MAPPING_FILE="/tmp/recent-files-mapping.$$"
            local DISPLAY_FILE="/tmp/recent-files-display.$$"

            # Clear temp files
            > "$MAPPING_FILE"
            > "$DISPLAY_FILE"

            # Process paths: truncate and create mapping
            while IFS= read -r full_path; do
                local truncated_path="$full_path"

                # Truncate project directory to ./
                if [[ "$full_path" == "$PROJECT_DIR"/* ]]; then
                    truncated_path="./${full_path#$PROJECT_DIR/}"
                # Truncate home directory to ~/
                elif [[ "$full_path" == "$HOME_DIR"/* ]]; then
                    truncated_path="~/${full_path#$HOME_DIR/}"
                fi

                # Store mapping: truncated_path -> full_path
                echo "$truncated_path|$full_path" >> "$MAPPING_FILE"
                echo "$truncated_path" >> "$DISPLAY_FILE"
            done < <(bash "$QUERY_SCRIPT" 2>/tmp/recent-files-error.$$)

            # Show truncated paths in FZF
            local selected_truncated=$(cat "$DISPLAY_FILE" | fzf --height=100% --prompt='Recent Files (JSONL): ' --border --reverse --preview="
                # Extract full path from mapping file
                full_path=\$(grep -F '{}|' '$MAPPING_FILE' | head -1 | cut -d'|' -f2)
                if [ -n \"\$full_path\" ]; then
                    batcat --color=always --style=numbers \"\$full_path\"
                else
                    echo 'File path not found in mapping'
                fi
            " --preview-window=up:70%:wrap)

            # Map truncated selection back to full path
            local selected_file=$(grep "^${selected_truncated}|" "$MAPPING_FILE" | cut -d"|" -f2)

            # Cleanup temp files
            rm -f "$MAPPING_FILE" /tmp/recent-files-display.$$

            # Check for errors
            if [ -s /tmp/recent-files-error.$$ ]; then
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                cat /tmp/recent-files-error.$$
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                read -p "Press Enter to continue..."
            elif [ -n "$selected_file" ]; then
                # File selected - check if it exists
                if [ -f "$selected_file" ]; then
                    # File exists - show sub-menu for action choice
                    local action=$(echo -e "View (batcat)\nEdit (emacs)" | fzf --height=40% --prompt='Action: ' --border --reverse)

                    case "$action" in
                        "View (batcat)")
                            batcat --paging=always "$selected_file"
                            ;;
                        "Edit (emacs)")
                            emacs -nw "$selected_file"
                            ;;
                        *)
                            # User cancelled sub-menu
                            ;;
                    esac
                elif [ -d "$(dirname "$selected_file")" ]; then
                    # File doesn't exist but directory does - cd to directory
                    echo "File not found: $selected_file"
                    echo "Directory exists. Opening parent directory..."
                    read -p "Press Enter to continue..."
                else
                    # Neither file nor directory exists
                    echo "File not found: $selected_file"
                    read -p "Press Enter to continue..."
                fi
            fi
            rm -f /tmp/recent-files-error.$$
            ;;

        detach)
            # Just exit cleanly - returns to Claude Code
            exit 0
            ;;

        claude-spawn-interactive)
            # Interactive subagent - spawn new Claude window with context package
            # Subagent reads context files and writes enhanced output back to prompt file

            # Create subagent context package
            local CONTEXT_DIR="/tmp/claude-subagent-$$"
            bash "$SCRIPT_DIR/scripts/create-subagent-context.sh" "$FILE" "$CONTEXT_DIR"

            # Spawn subagent with context in new tmux window
            tmux new-window bash -c "
              export CONTEXT_DIR='$CONTEXT_DIR'
              cd '$PWD'
              exec claude \\
                --dangerously-skip-permissions \\
                --append-system-prompt \"\$(cat '$CONTEXT_DIR/system-prompt.txt')\"
            "
            ;;

        claude-enhance-auto)
            # Non-interactive enhancement - auto-replace *** markers *** with context
            # Uses lightweight context package pattern optimized for Haiku
            local STREAM_PARSER="$SCRIPT_DIR/scripts/stream-claude-output.sh"

            # Create lightweight subagent context package
            local CONTEXT_DIR="/tmp/claude-subagent-lite-$$"
            bash "$SCRIPT_DIR/scripts/create-subagent-context-lite.sh" "$FILE" "$CONTEXT_DIR"

            # Show context preview before calling Haiku
            echo "Here's what I'm telling Haiku about the current situation:"
            echo ""
            echo "=== SYSTEM PROMPT ==="
            cat "$CONTEXT_DIR/system-prompt.txt"
            echo ""
            echo "=== RECENT CONVERSATION (last 2000 chars) ==="
            if [[ -f "$CONTEXT_DIR/parent-context.md" ]]; then
                # Show last 2000 characters to avoid cutting mid-message
                # This typically captures 2-3 recent exchanges
                tail -c 2000 "$CONTEXT_DIR/parent-context.md"
            else
                echo "(No parent context available)"
            fi
            echo ""
            echo "=== RECENT FILES (3 most recent) ==="
            if [[ -f "$CONTEXT_DIR/recent-files.txt" ]]; then
                head -3 "$CONTEXT_DIR/recent-files.txt"
            else
                echo "(No recent files available)"
            fi
            echo ""
            echo "=== LAUNCHING HAIKU ENHANCEMENT ==="
            echo ""

            # Call claude with context package (system prompt + user prompt)
            cat "$CONTEXT_DIR/user-prompt.txt" | claude -p --verbose --output-format stream-json --dangerously-skip-permissions --model haiku --append-system-prompt "$(cat "$CONTEXT_DIR/system-prompt.txt")" | bash "$STREAM_PARSER"

            echo ""
            echo "Press Enter to return to Claude Code..."
            read
            ;;

        *)
            # Regular editor command - run without exec so tmux keybindings work
            bash -c "$cmd"
            ;;
    esac
}

# Export function so it can be called from sourcing scripts
export -f show_menu
