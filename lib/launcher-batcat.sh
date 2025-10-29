#!/usr/bin/env bash
#
# Batcat Launcher
#
# Display files with syntax highlighting using batcat

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"
source "$SCRIPT_DIR/config-reader.sh"

# Detect batcat command (some systems use 'bat', some 'batcat')
if command_exists batcat; then
    BAT_CMD="batcat"
elif command_exists bat; then
    BAT_CMD="bat"
else
    die "batcat/bat not found. Install with: sudo apt install bat"
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
        log_info "No files specified, nothing to display"
        return 0
    fi

    log_debug "Displaying $file_count file(s) with batcat"

    # Display each file
    for (( i=0; i<file_count; i++ )); do
        local path=$(get_file_path "$i")
        local line=$(get_file_line "$i")
        local description=$(get_file_description "$i")

        if [[ -z "$path" || "$path" == "null" ]]; then
            continue
        fi

        if [[ ! -f "$path" ]]; then
            log_error "File not found: $path"
            continue
        fi

        # Print header with description if available
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        if [[ -n "$description" && "$description" != '""' ]]; then
            echo "📄 $path - $description"
        else
            echo "📄 $path"
        fi
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo

        # Display file with batcat
        if [[ -n "$line" && "$line" != "null" ]]; then
            # Highlight specific line
            $BAT_CMD --style=numbers,changes --highlight-line "$line" "$path"
        else
            $BAT_CMD --style=numbers,changes "$path"
        fi

        echo
        echo

        # Pause between files if there are multiple
        if [[ $((i + 1)) -lt "$file_count" ]]; then
            read -p "Press Enter to continue to next file..." -r
        fi
    done

    # Wait for user to acknowledge before exiting
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "End of files. Press Enter to exit..."
    read -r
}

main "$@"
