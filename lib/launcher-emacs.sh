#!/usr/bin/env bash
#
# Emacs Launcher
#
# Opens files in emacs at specific line numbers, supports multiple files

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"
source "$SCRIPT_DIR/config-reader.sh"

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
        log_info "No files specified, opening emacs normally"
        exec emacs -nw
        return
    fi

    log_debug "Opening $file_count file(s) in emacs"

    # Build emacs command with file arguments
    local emacs_args=("-nw")

    for (( i=0; i<file_count; i++ )); do
        local path=$(get_file_path "$i")
        local line=$(get_file_line "$i")

        if [[ -z "$path" || "$path" == "null" ]]; then
            continue
        fi

        # Add line number if specified
        if [[ -n "$line" && "$line" != "null" ]]; then
            emacs_args+=( "+$line" "$path" )
        else
            emacs_args+=( "$path" )
        fi
    done

    log_debug "Executing: emacs ${emacs_args[*]}"

    # Launch emacs with all files
    exec emacs "${emacs_args[@]}"
}

main "$@"
