#!/usr/bin/env bash
# Shared menu logic for both claude-editor-hook and claude-editor-menu
# This ensures menu options and behavior stay in sync
# Now supports context-aware menus: Claude session vs general tmux

# Usage: show_menu [file-path]
# If file-path is provided, we're in Claude context
# If omitted, we're in general tmux context
show_menu() {
    local FILE="$1"
    local IN_CLAUDE_CONTEXT=false

    # Detect context: are we in a Claude session?
    if [ -n "$FILE" ] || [ -n "$PROMPT" ]; then
        IN_CLAUDE_CONTEXT=true
        FILE="${FILE:-$PROMPT}"
    fi

    # Get script directory for finding helper scripts
    local SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    # Build context-aware menu
    local MENU=""

    if [ "$IN_CLAUDE_CONTEXT" = true ]; then
        # Claude-specific options (editing prompt, enhancement agents)
        MENU="Edit with Emacs:emacs -nw \"$FILE\"
Edit with Vi:vi \"$FILE\"
Edit with Nano:nano \"$FILE\""

        # Add dynamic terminal list
        # Query existing terminals and add to menu
        local LIST_TERMINALS="$SCRIPT_DIR/scripts/list-terminals.sh"
        if [ -f "$LIST_TERMINALS" ]; then
            # Get list of terminals: "terminal-1:Terminal 1", "terminal-2:Terminal 2 (workspace)", etc.
            while IFS=: read -r window_name display_label; do
                MENU="$MENU
$display_label:terminal:$window_name"
            done < <(bash "$LIST_TERMINALS")
        fi

        # Add "Create New Terminal" option
        MENU="$MENU
Create New Terminal:create-new-terminal
Recent Files (Claude):recent-files
Enhance (Interactive):claude-spawn-interactive
Enhance (Non-interactive):claude-enhance-auto
──────────────────:separator"
    fi

    # General productivity options (always available)
    MENU="${MENU}
Switch Project:switch-project
Find Files:find-files
Git Operations:git-operations"

    if [ "$IN_CLAUDE_CONTEXT" = true ]; then
        MENU="${MENU}
Detach:detach"
    fi

    # Show FZF menu with context-aware prompt
    local prompt="Command: "
    if [ "$IN_CLAUDE_CONTEXT" = true ]; then
        prompt="Claude + Tools: "
    else
        prompt="Tmux Tools: "
    fi

    local choice=$(echo "$MENU" | grep -v "^──────" | fzf --height=100% --prompt="$prompt" --border --reverse)

    if [ -z "$choice" ]; then
        # User cancelled
        return 0
    fi

    # Extract command from selection
    # Handle special format for terminals: "Terminal 1:terminal:terminal-1"
    # Standard format: "Edit with Emacs:emacs -nw file"
    local cmd=$(echo "$choice" | cut -d: -f2-)

    # If command starts with "terminal:", it's a terminal selection
    # Keep the full "terminal:terminal-N" format for the case statement

    # Execute command
    case "$cmd" in
        terminal:*)
            # Switch to existing terminal
            # Format: "terminal:terminal-1" or "terminal:terminal-2"
            local window_name=$(echo "$cmd" | cut -d: -f2)
            bash "$SCRIPT_DIR/scripts/switch-to-terminal.sh" "$window_name" "$FILE"
            ;;

        create-new-terminal)
            # Create and switch to new terminal
            local new_window=$(bash "$SCRIPT_DIR/scripts/create-terminal.sh" "$FILE")
            if [ -n "$new_window" ]; then
                # Switch to the newly created terminal
                tmux select-window -t "Claude:$new_window"
            fi
            ;;

        open-terminal)
            # Legacy support - treat as "create new terminal"
            # (In case anything still calls this directly)
            local new_window=$(bash "$SCRIPT_DIR/scripts/create-terminal.sh" "$FILE")
            if [ -n "$new_window" ]; then
                tmux select-window -t "Claude:$new_window"
            fi
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

        switch-project)
            # Project switcher - recent projects stacked on top of fuzzy find results
            local FIND_PROJECTS="$SCRIPT_DIR/scripts/find-projects.sh"
            local QUERY_RECENT_PROJECTS="$SCRIPT_DIR/scripts/query-recent-projects-jsonl.sh"
            local TRACK_PROJECT_ACCESS="$SCRIPT_DIR/scripts/track-project-access.sh"

            # Build combined project list: recent projects with ★ prefix, then separator, then all projects
            local COMBINED_LIST="/tmp/project-list-$$"
            > "$COMBINED_LIST"

            # Add recent projects with ★ prefix (suppress errors if no recent projects yet)
            if bash "$QUERY_RECENT_PROJECTS" 2>/dev/null | while IFS= read -r project; do
                echo "★ $project"
            done >> "$COMBINED_LIST"; then
                # Add separator if we have recent projects
                if [ -s "$COMBINED_LIST" ]; then
                    echo "───────────────────────────" >> "$COMBINED_LIST"
                fi
            fi

            # Add all projects from ~/code
            bash "$FIND_PROJECTS" >> "$COMBINED_LIST"

            # Enhanced preview with git metadata
            local preview_cmd='
                # Remove ★ prefix and separator lines
                project_path=$(echo {} | sed "s/^★ //")
                if [[ "$project_path" == "───"* ]]; then
                    echo "Recent Projects Above"
                    echo "────────────────────"
                    echo "All Projects Below"
                    exit 0
                fi

                # Show basic ls output
                echo "═══════════════════════════════════════════"
                ls -la "$project_path" 2>/dev/null | head -20
                echo ""

                # Show git info if available
                if [ -d "$project_path/.git" ]; then
                    cd "$project_path" 2>/dev/null || exit 0
                    echo "═══════════════════════════════════════════"
                    echo "Git Repository"
                    echo "═══════════════════════════════════════════"
                    echo "Branch: $(git branch --show-current 2>/dev/null || echo detached)"
                    echo "Last commit: $(git log -1 --format="%s (%ar)" 2>/dev/null || echo "No commits")"
                    echo ""
                    echo "Recent commits:"
                    git log -5 --oneline --format="%C(yellow)%h%C(reset) %s %C(green)(%ar)%C(reset)" 2>/dev/null || echo "No commit history"
                fi
            '

            local selected_project=$(cat "$COMBINED_LIST" | fzf \
                --height=100% \
                --prompt='Switch to Project: ' \
                --border \
                --reverse \
                --preview="$preview_cmd" \
                --preview-window=up:70%:wrap)

            rm -f "$COMBINED_LIST"

            if [ -n "$selected_project" ]; then
                # Skip if user selected the separator
                if [[ "$selected_project" == "───"* ]]; then
                    return 0
                fi

                # Remove ★ prefix if present
                selected_project=$(echo "$selected_project" | sed 's/^★ //')

                # Offer choice: cd here or open new window
                local action=$(echo -e "CD to project (current window)\nOpen in new window" | fzf --height=40% --prompt='Action: ' --border --reverse)

                case "$action" in
                    "CD to project (current window)")
                        # Track project access
                        bash "$TRACK_PROJECT_ACCESS" "$selected_project" 2>/dev/null || true

                        cd "$selected_project"
                        echo "Changed directory to: $selected_project"
                        exec bash
                        ;;
                    "Open in new window")
                        # Track project access
                        bash "$TRACK_PROJECT_ACCESS" "$selected_project" 2>/dev/null || true

                        tmux new-window -c "$selected_project" bash
                        ;;
                esac
            fi
            ;;

        find-files)
            # File finder in current directory
            local FIND_FILES="$SCRIPT_DIR/scripts/find-files.sh"
            local selected_file=$(bash "$FIND_FILES" | fzf --height=100% --prompt='Find File: ' --border --reverse --preview="batcat --color=always --style=numbers {}" --preview-window=up:70%:wrap)

            if [ -n "$selected_file" ]; then
                # Offer choice: view or edit
                local action=$(echo -e "View (batcat)\nEdit (emacs)" | fzf --height=40% --prompt='Action: ' --border --reverse)

                case "$action" in
                    "View (batcat)")
                        batcat --paging=always "$selected_file"
                        ;;
                    "Edit (emacs)")
                        emacs -nw "$selected_file"
                        ;;
                esac
            fi
            ;;

        git-operations)
            # Git operations submenu
            bash "$SCRIPT_DIR/scripts/git-menu.sh"
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
            # Non-interactive enhancement - directive-based enhancement system
            # Supports: #enhance, #spellcheck, #suggest, #investigate, #fix, #please
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

            # Show what Haiku wrote to the temp file
            echo ""
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "=== HAIKU WROTE TO TEMP FILE ==="
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            if [[ -f "$FILE" ]]; then
                batcat --color=always --style=numbers "$FILE"
            else
                echo "(File not found: $FILE)"
            fi
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

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
