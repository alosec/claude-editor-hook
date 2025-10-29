#!/usr/bin/env bash
#
# Shared utilities for claude-editor-hook
#

# Enable debug logging with EDITOR_HOOK_DEBUG=1
DEBUG="${EDITOR_HOOK_DEBUG:-0}"

# Log debug message to stderr
log_debug() {
    if [[ "$DEBUG" == "1" ]]; then
        echo "[DEBUG] $*" >&2
    fi
}

# Log error message to stderr
log_error() {
    echo "[ERROR] $*" >&2
}

# Log info message to stderr
log_info() {
    echo "[INFO] $*" >&2
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Die with error message
die() {
    log_error "$*"
    exit 1
}
