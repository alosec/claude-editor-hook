#!/usr/bin/env bash
# Fuzzy file search in current directory
# Optimized for performance with common exclusions

SEARCH_DIR="${1:-.}"

if [ ! -d "$SEARCH_DIR" ]; then
    echo "Error: Directory $SEARCH_DIR does not exist" >&2
    exit 1
fi

# Use fd if available, otherwise fall back to find
if command -v fd &>/dev/null; then
    # fd respects .gitignore and is much faster
    # -t f = files only
    # -H = include hidden files
    # Excludes .git, node_modules, etc. by default
    fd -t f -H . "$SEARCH_DIR" 2>/dev/null
else
    # Fallback to find with common exclusions
    find "$SEARCH_DIR" -type f \
        -not -path "*/\.git/*" \
        -not -path "*/node_modules/*" \
        -not -path "*/__pycache__/*" \
        -not -path "*/\.venv/*" \
        -not -path "*/build/*" \
        -not -path "*/dist/*" \
        2>/dev/null
fi
