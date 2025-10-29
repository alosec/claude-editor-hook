#!/usr/bin/env bash
#
# Menu Launcher
#
# Present an interactive menu using fzf or dialog

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"
source "$SCRIPT_DIR/config-reader.sh"

# Detect available menu tool
if command_exists fzf; then
    MENU_TOOL="fzf"
elif command_exists dialog; then
    MENU_TOOL="dialog"
else
    die "Neither fzf nor dialog found. Install with: sudo apt install fzf"
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

    local file_count=$(get_file_count)

    if [[ "$file_count" -eq 0 ]]; then
        log_info "No files specified for menu"
        return 0
    fi

    log_debug "Presenting menu with $file_count option(s)"

    # Build menu items
    local menu_items=()
    for (( i=0; i<file_count; i++ )); do
        local path=$(get_file_path "$i")
        local line=$(get_file_line "$i")
        local description=$(get_file_description "$i")

        if [[ -z "$path" || "$path" == "null" ]]; then
            continue
        fi

        # Format: "index|path|line|description"
        local item="$i|$path|$line|$description"
        menu_items+=("$item")
    done

    # Present menu based on available tool
    if [[ "$MENU_TOOL" == "fzf" ]]; then
        present_fzf_menu "${menu_items[@]}"
    else
        present_dialog_menu "${menu_items[@]}"
    fi
}

present_fzf_menu() {
    local items=("$@")

    # Format items for display
    local display_items=()
    for item in "${items[@]}"; do
        IFS='|' read -r index path line description <<< "$item"

        local display_line=""
        if [[ -n "$line" && "$line" != "null" ]]; then
            display_line=":$line"
        fi

        local display_desc=""
        if [[ -n "$description" && "$description" != '""' ]]; then
            display_desc=" - $description"
        fi

        display_items+=("$index) $path$display_line$display_desc")
    done

    # Show menu with fzf
    local selection
    selection=$(printf '%s\n' "${display_items[@]}" | fzf --height=50% --border --prompt="Select file to open: ")

    if [[ -z "$selection" ]]; then
        log_info "No selection made"
        return 0
    fi

    # Extract index from selection
    local selected_index="${selection%%)*}"

    # Get the selected item details
    local selected_item="${items[$selected_index]}"
    IFS='|' read -r _ path line _ <<< "$selected_item"

    # Open with emacs
    log_debug "Opening: $path at line $line"
    if [[ -n "$line" && "$line" != "null" ]]; then
        exec emacs -nw "+$line" "$path"
    else
        exec emacs -nw "$path"
    fi
}

present_dialog_menu() {
    local items=("$@")

    # Build dialog menu items (tag, item, description)
    local dialog_items=()
    for item in "${items[@]}"; do
        IFS='|' read -r index path line description <<< "$item"

        local display_line=""
        if [[ -n "$line" && "$line" != "null" ]]; then
            display_line=":$line"
        fi

        dialog_items+=("$index" "$path$display_line")
    done

    # Show dialog menu
    local selection
    selection=$(dialog --menu "Select file to open:" 20 80 10 "${dialog_items[@]}" 2>&1 >/dev/tty)

    if [[ -z "$selection" ]]; then
        log_info "No selection made"
        return 0
    fi

    # Get the selected item details
    local selected_item="${items[$selection]}"
    IFS='|' read -r _ path line _ <<< "$selected_item"

    # Clear dialog artifacts
    clear

    # Open with emacs
    log_debug "Opening: $path at line $line"
    if [[ -n "$line" && "$line" != "null" ]]; then
        exec emacs -nw "+$line" "$path"
    else
        exec emacs -nw "$path"
    fi
}

main "$@"
