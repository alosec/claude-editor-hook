#!/usr/bin/env bash
#
# Config Reader - Parse YAML context files
#
# Exports environment variables based on context file content:
#   EDITOR_HOOK_MODE - The mode (emacs, batcat, menu, tmux, custom)
#   EDITOR_HOOK_FILES - JSON array of file objects
#   EDITOR_HOOK_CUSTOM_LAUNCHER - Path to custom launcher script
#

# Check for yq or jq
if command_exists yq; then
    YAML_PARSER="yq"
elif command_exists jq; then
    YAML_PARSER="jq"
else
    log_error "Neither yq nor jq found. Install with: pip install yq"
    return 1
fi

# Parse context file and export variables
parse_context() {
    local context_file="$1"

    if [[ ! -f "$context_file" ]]; then
        log_error "Context file not found: $context_file"
        return 1
    fi

    # Determine file format
    local format="yaml"
    if [[ "$context_file" == *.json ]]; then
        format="json"
    fi

    # Parse based on format
    if [[ "$format" == "yaml" ]]; then
        if [[ "$YAML_PARSER" == "yq" ]]; then
            export EDITOR_HOOK_MODE=$(yq -r '.mode // "emacs"' "$context_file")
            export EDITOR_HOOK_FILES=$(yq -c '.files // []' "$context_file")
            export EDITOR_HOOK_CUSTOM_LAUNCHER=$(yq -r '.custom_launcher // ""' "$context_file")
        else
            log_error "Cannot parse YAML without yq. Install with: pip install yq"
            return 1
        fi
    else
        # JSON format
        export EDITOR_HOOK_MODE=$(jq -r '.mode // "emacs"' "$context_file")
        export EDITOR_HOOK_FILES=$(jq -c '.files // []' "$context_file")
        export EDITOR_HOOK_CUSTOM_LAUNCHER=$(jq -r '.custom_launcher // ""' "$context_file")
    fi

    log_debug "Parsed mode: $EDITOR_HOOK_MODE"
    log_debug "Parsed files: $EDITOR_HOOK_FILES"

    return 0
}

# Get file count
get_file_count() {
    if [[ -z "${EDITOR_HOOK_FILES:-}" ]]; then
        echo 0
        return
    fi
    echo "$EDITOR_HOOK_FILES" | jq 'length'
}

# Get file path by index
get_file_path() {
    local index="$1"
    echo "$EDITOR_HOOK_FILES" | jq -r ".[$index].path"
}

# Get file line by index
get_file_line() {
    local index="$1"
    echo "$EDITOR_HOOK_FILES" | jq -r ".[$index].line // null"
}

# Get file description by index
get_file_description() {
    local index="$1"
    echo "$EDITOR_HOOK_FILES" | jq -r ".[$index].description // \"\""
}
