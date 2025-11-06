#!/usr/bin/env bash
# Project orientation preview for FZF
# Displays git status, recent commits, and file listing
# Usage: preview-project-orientation.sh /path/to/project

PROJECT_PATH="$1"

if [ -z "$PROJECT_PATH" ] || [ ! -d "$PROJECT_PATH" ]; then
    echo "Error: Invalid project path"
    exit 1
fi

PROJECT_NAME=$(basename "$PROJECT_PATH")

# Header
echo "PROJECT: $PROJECT_NAME"
echo "═══════════════════════════════════════════════════════════════════"
echo ""

# Git information (if git repository)
if [ -d "$PROJECT_PATH/.git" ]; then
    cd "$PROJECT_PATH" 2>/dev/null || exit 1

    echo "Git Status:"

    # Current branch
    BRANCH=$(git branch --show-current 2>/dev/null || echo "detached HEAD")
    echo "  Branch: $BRANCH"

    # Commits ahead/behind
    UPSTREAM=$(git rev-parse --abbrev-ref @{upstream} 2>/dev/null)
    if [ -n "$UPSTREAM" ]; then
        AHEAD=$(git rev-list --count HEAD ^"$UPSTREAM" 2>/dev/null || echo "0")
        BEHIND=$(git rev-list --count "$UPSTREAM" ^HEAD 2>/dev/null || echo "0")

        if [ "$AHEAD" -gt 0 ] || [ "$BEHIND" -gt 0 ]; then
            echo -n "  "
            [ "$AHEAD" -gt 0 ] && echo -n "$AHEAD commits ahead"
            [ "$AHEAD" -gt 0 ] && [ "$BEHIND" -gt 0 ] && echo -n ", "
            [ "$BEHIND" -gt 0 ] && echo -n "$BEHIND commits behind"
            echo ""
        else
            echo "  Up to date with remote"
        fi
    fi

    # Working tree status
    if git diff-index --quiet HEAD -- 2>/dev/null; then
        echo "  Working tree: clean"
    else
        echo "  Working tree: modified (uncommitted changes)"
    fi

    echo ""
    echo "Recent Commits:"
    git log -5 --oneline --format="  %C(yellow)%h%C(reset) %s %C(green)(%ar)%C(reset)" 2>/dev/null || echo "  No commits"
    echo ""
else
    echo "Git Status: Not a git repository"
    echo ""
fi

# Separator
echo "───────────────────────────────────────────────────────────────────"
echo ""

# File listing
echo "Files:"
ls -la "$PROJECT_PATH" 2>/dev/null | head -20
