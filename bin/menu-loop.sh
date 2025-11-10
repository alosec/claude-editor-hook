#!/usr/bin/env bash
# Persistent FZF menu loop for User session
# Runs continuously in window 0, handles window creation/switching

SESSION_NAME="User"

# Get the directory where this script lives
SCRIPT_SOURCE="${BASH_SOURCE[0]:-$0}"
while [ -L "$SCRIPT_SOURCE" ]; do
    SCRIPT_DIR="$(cd -P "$(dirname "$SCRIPT_SOURCE")" && pwd)"
    SCRIPT_SOURCE="$(readlink "$SCRIPT_SOURCE")"
    [[ $SCRIPT_SOURCE != /* ]] && SCRIPT_SOURCE="$SCRIPT_DIR/$SCRIPT_SOURCE"
done
SCRIPT_DIR="$(cd -P "$(dirname "$SCRIPT_SOURCE")" && pwd)"

# Helper scripts
SWITCH_OR_CREATE="$SCRIPT_DIR/../lib/scripts/switch-or-create-window.sh"
FIND_PROJECTS="$SCRIPT_DIR/../lib/scripts/find-projects.sh"
FIND_FILES="$SCRIPT_DIR/../lib/scripts/find-files.sh"
GIT_MENU="$SCRIPT_DIR/../lib/scripts/git-menu.sh"
PREVIEW_PROJECT="$SCRIPT_DIR/../lib/scripts/preview-project-orientation.sh"

# Build menu items
# Format: "Display Label:window-name:action-type:action-data"
build_menu() {
    cat <<EOF
🚀 Projects:projects:interactive:find-projects
📁 Files:files:interactive:find-files
🔀 Git:git:script:git-menu
💻 Terminal:terminal:create:bash
🔧 Build (npm):build:command:npm run build
🚀 Deploy:deploy:command:wrangler pages deploy dist/
──────────────:separator::
❌ Exit Menu:exit::
EOF
}

# Main loop
while true; do
    clear
    echo "╔════════════════════════════════════════╗"
    echo "║       Tmux Command Palette             ║"
    echo "║       Session: User                    ║"
    echo "╚════════════════════════════════════════╝"
    echo ""

    # Show menu and get selection
    selection=$(build_menu | grep -v "^──────" | fzf \
        --height=100% \
        --prompt='Select: ' \
        --border \
        --reverse \
        --no-info \
        --header='Press Ctrl-C to cancel')

    # Handle cancellation (Ctrl-C or Esc)
    if [ -z "$selection" ]; then
        continue
    fi

    # Parse selection
    # Format: "Display Label:window-name:action-type:action-data"
    display_label=$(echo "$selection" | cut -d: -f1)
    window_name=$(echo "$selection" | cut -d: -f2)
    action_type=$(echo "$selection" | cut -d: -f3)
    action_data=$(echo "$selection" | cut -d: -f4)

    case "$action_type" in
        exit)
            # Exit menu loop (window will close)
            exit 0
            ;;

        interactive)
            # Interactive selection (projects, files)
            case "$action_data" in
                find-projects)
                    # Let user pick project, then create/switch to window
                    selected_project=$("$FIND_PROJECTS" | fzf \
                        --height=100% \
                        --prompt='Project: ' \
                        --border \
                        --reverse \
                        --preview="bash '$PREVIEW_PROJECT' {}" \
                        --preview-window=up:90%:wrap)

                    if [ -n "$selected_project" ]; then
                        # Create window named after project
                        project_basename=$(basename "$selected_project")
                        bash "$SWITCH_OR_CREATE" "$SESSION_NAME" "$project_basename" \
                            "cd '$selected_project' && exec bash"
                    fi
                    ;;

                find-files)
                    # File finder
                    selected_file=$("$FIND_FILES" | fzf \
                        --height=100% \
                        --prompt='File: ' \
                        --border \
                        --reverse \
                        --preview='batcat --color=always --style=numbers {} 2>/dev/null')

                    if [ -n "$selected_file" ]; then
                        # Open in files window with editor
                        bash "$SWITCH_OR_CREATE" "$SESSION_NAME" "files" \
                            "emacs -nw '$selected_file'"
                    fi
                    ;;
            esac
            ;;

        script)
            # Run a script in dedicated window
            bash "$SWITCH_OR_CREATE" "$SESSION_NAME" "$window_name" \
                "bash '$SCRIPT_DIR/../lib/scripts/$action_data.sh'; exec bash"
            ;;

        command)
            # Run a one-shot command in dedicated window
            bash "$SWITCH_OR_CREATE" "$SESSION_NAME" "$window_name" \
                "$action_data; echo ''; echo 'Press Enter to continue...'; read; exec bash"
            ;;

        create)
            # Create new numbered terminal
            # Find next available terminal number
            existing_nums=$(tmux list-windows -t "$SESSION_NAME" -F '#{window_name}' 2>/dev/null \
                | grep '^terminal-' \
                | grep -o '[0-9]*$' \
                | sort -n)

            if [ -z "$existing_nums" ]; then
                next_num=1
            else
                max_num=$(echo "$existing_nums" | tail -1)
                next_num=$((max_num + 1))
            fi

            terminal_name="terminal-$next_num"
            bash "$SWITCH_OR_CREATE" "$SESSION_NAME" "$terminal_name" "exec bash"
            ;;
    esac
done
