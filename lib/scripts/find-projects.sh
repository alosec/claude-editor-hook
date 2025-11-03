#!/usr/bin/env bash
# Discover code projects in ~/code directory
# Returns list of directories suitable for FZF

CODE_DIR="${1:-$HOME/code}"

if [ ! -d "$CODE_DIR" ]; then
    echo "Error: Directory $CODE_DIR does not exist" >&2
    exit 1
fi

# Use fd if available, otherwise fall back to find
if command -v fd &>/dev/null; then
    # fd is faster and respects .gitignore by default
    fd -t d -d 2 . "$CODE_DIR" 2>/dev/null
else
    # Fallback to find with depth limit
    find "$CODE_DIR" -mindepth 1 -maxdepth 2 -type d 2>/dev/null
fi
