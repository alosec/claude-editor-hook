#!/usr/bin/env bash
# Initialize persistent User session with dedicated menu window
# Usage: init-user-session.sh
# Creates session "User" (or attaches if exists) with window 0 as persistent menu

SESSION_NAME="User"

# Get the directory where this script lives
SCRIPT_SOURCE="${BASH_SOURCE[0]:-$0}"
while [ -L "$SCRIPT_SOURCE" ]; do
    SCRIPT_DIR="$(cd -P "$(dirname "$SCRIPT_SOURCE")" && pwd)"
    SCRIPT_SOURCE="$(readlink "$SCRIPT_SOURCE")"
    [[ $SCRIPT_SOURCE != /* ]] && SCRIPT_SOURCE="$SCRIPT_DIR/$SCRIPT_SOURCE"
done
SCRIPT_DIR="$(cd -P "$(dirname "$SCRIPT_SOURCE")" && pwd)"

MENU_LOOP="$SCRIPT_DIR/menu-loop.sh"

# Unset TMUX to allow session creation from within tmux
unset TMUX

# Check if session exists
if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    # Session exists, just attach
    exec tmux attach -t "$SESSION_NAME"
else
    # Create new session with menu window
    # Window 0 = "menu" (runs persistent FZF loop)
    # Set base-index to 0 so menu is always window 0
    exec tmux new-session -s "$SESSION_NAME" -n "menu" \
        "bash '$MENU_LOOP'"
fi
