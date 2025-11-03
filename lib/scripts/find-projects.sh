#!/usr/bin/env bash
# Discover code projects in ~/code directory
# Returns list of directories suitable for FZF
# Supports optional git metadata mode for enhanced previews

CODE_DIR="${1:-$HOME/code}"
SHOW_GIT_METADATA="${2:-false}"

if [ ! -d "$CODE_DIR" ]; then
    echo "Error: Directory $CODE_DIR does not exist" >&2
    exit 1
fi

# Function to get git metadata for a directory
get_git_metadata() {
    local dir="$1"

    if [ ! -d "$dir/.git" ]; then
        echo "Not a git repository"
        return
    fi

    cd "$dir" 2>/dev/null || return

    # Get current branch
    local branch=$(git branch --show-current 2>/dev/null || echo "detached HEAD")

    # Get last commit info
    local last_commit=$(git log -1 --format="%s (%ar)" 2>/dev/null || echo "No commits")

    # Get file/dir count (cached for performance)
    local file_count=$(find . -type f 2>/dev/null | wc -l)
    local dir_count=$(find . -type d 2>/dev/null | wc -l)

    echo "Branch: $branch"
    echo "Last commit: $last_commit"
    echo "Files: $file_count  Dirs: $dir_count"
}

# Use fd if available, otherwise fall back to find
if command -v fd &>/dev/null; then
    # fd is faster and respects .gitignore by default
    fd -t d -d 2 . "$CODE_DIR" 2>/dev/null
else
    # Fallback to find with depth limit
    find "$CODE_DIR" -mindepth 1 -maxdepth 2 -type d 2>/dev/null
fi
