#!/usr/bin/env bash
# Git operations submenu
# Provides common git shortcuts in FZF menu

# Check if we're in a git repository
if ! git rev-parse --git-dir &>/dev/null; then
    echo "Error: Not in a git repository" >&2
    exit 1
fi

# Git operations menu
MENU="Git Status:git-status
Git Log (Interactive):git-log
Git Branches:git-branches
Git Diff:git-diff
Back to Main Menu:back"

choice=$(echo "$MENU" | fzf --height=100% --prompt='Git: ' --border --reverse)

if [ -z "$choice" ]; then
    exit 0
fi

cmd=$(echo "$choice" | cut -d: -f2)

case "$cmd" in
    git-status)
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Git Status"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        git status
        echo ""
        read -p "Press Enter to continue..."
        ;;

    git-log)
        # Interactive log browser with FZF
        git log --oneline --decorate --color=always | \
            fzf --ansi --no-sort --reverse --tiebreak=index \
                --preview "echo {} | cut -d' ' -f1 | xargs -I@ git show --color=always @" \
                --preview-window=up:70%:wrap
        ;;

    git-branches)
        # Interactive branch switcher
        branch=$(git branch -a --color=always | \
            grep -v '/HEAD\s' | \
            fzf --ansi --no-sort --reverse \
                --preview "git log --oneline --graph --date=short --pretty='format:%C(auto)%cd %h%d %s' \$(echo {} | sed 's/^..//' | cut -d' ' -f1) | head -50" \
                --preview-window=up:70%:wrap | \
            sed 's/^..//' | cut -d' ' -f1 | \
            sed 's#remotes/[^/]*/##')

        if [ -n "$branch" ]; then
            git checkout "$branch"
            echo ""
            read -p "Switched to branch: $branch. Press Enter to continue..."
        fi
        ;;

    git-diff)
        # Show diff with syntax highlighting
        if command -v batcat &>/dev/null; then
            git diff --color=always | batcat --paging=always --language=diff
        else
            git diff | less
        fi
        ;;

    back)
        # Return to main menu (handled by caller)
        exit 0
        ;;
esac
