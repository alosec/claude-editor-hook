# Tmux Menu Patterns for Command Palette

Research and implementation options for creating a Ctrl-G command palette experience.

---

## Pattern 1: Native display-menu (Modal Overlay)

**What it is:** The approach we tried - shows a centered modal menu using `tmux display-menu`

**How it works:**
```bash
tmux new-session bash -c "
    tmux display-menu -T 'Command Palette' -x C -y C \
        'Edit in Emacs' e 'emacs -nw file.md' \
        'Edit in Vi' v 'vi file.md' \
        'View in Batcat' b 'batcat file.md' \
        'View Server Logs' s 'tail -f /var/log/server.log' \
        'View Browser Logs' l 'tail -f ~/.browser/console.log'
"
```

**Pros:**
- Native tmux, no external dependencies
- Clean modal overlay UI
- Keyboard shortcuts (e/v/b/s/l)

**Cons:**
- Commands run in bash -c context, hard to debug
- Exit behavior is tricky

**Status:** ⚠️ Menu shows but exits immediately after selection

---

## Pattern 2: display-popup + fzf (Interactive Picker)

**What it is:** Use tmux popup window with fzf for fuzzy-searchable command palette

**How it works:**
```bash
#!/usr/bin/env bash
FILE="$1"

# Create menu data
MENU="Edit with Emacs:emacs -nw \"$FILE\"
Edit with Vi:vi \"$FILE\"
View with Batcat:batcat \"$FILE\"
Server Logs:tail -f /var/log/server.log
Browser Logs:tail -f ~/.browser/console.log"

# Show popup with fzf and execute selection
unset TMUX
exec tmux new-session bash -c "
    choice=\$(echo '$MENU' | fzf --height=10 --prompt='Command: ')
    if [ -n \"\$choice\" ]; then
        cmd=\$(echo \"\$choice\" | cut -d: -f2)
        exec bash -c \"\$cmd\"
    fi
"
```

**Pros:**
- Fuzzy search
- Very flexible
- Great UX (VSCode-like command palette)

**Cons:**
- Requires fzf installation
- More complex

**Status:** 🔵 Worth testing

---

## Pattern 3: Persistent Popup Session (Dismissable)

**What it is:** Create a background tmux session that persists, popup shows/hides it

**How it works:**
```bash
#!/usr/bin/env bash
FILE="$1"
SESSION="_editor_popup"

# Create persistent session if it doesn't exist
if ! tmux has-session -t "$SESSION" 2>/dev/null; then
    tmux new-session -d -s "$SESSION" nano "$FILE"
    tmux set-option -t "$SESSION" status off
fi

# Attach in popup mode
unset TMUX
exec tmux attach -t "$SESSION"
```

**Pros:**
- Session persists across invocations
- Can switch editors mid-session with hotkey
- Natural "workspace" feel

**Cons:**
- Session management overhead
- Need to handle file changes between invocations

**Status:** 🔵 Interesting for workspace concept

---

## Pattern 4: Simple Default + Tmux Keybinding Menu

**What it is:** Launch default editor (nano), bind Ctrl-A m to show menu inside session

**How it works:**
```bash
#!/usr/bin/env bash
FILE="$1"

# Create temp tmux conf with menu binding
TMUX_CONF=$(mktemp)
cat > "$TMUX_CONF" <<'EOF'
bind-key m display-menu -T "Switch Tool" -x C -y C \
    "Emacs" e "respawn-pane emacs -nw" \
    "Vi" v "respawn-pane vi" \
    "Batcat" b "respawn-pane batcat"
EOF

unset TMUX
exec tmux -f "$TMUX_CONF" new-session nano "$FILE"
```

**Pros:**
- Default works immediately (nano)
- Power users can switch on demand
- Natural tmux UX

**Cons:**
- Respawn-pane might lose file context
- Need to pass file path through

**Status:** 🟢 Solid fallback option

---

## Pattern 5: Split Pane Layout with Menu

**What it is:** Open with split layout - top shows menu/info, bottom is editor

**How it works:**
```bash
#!/usr/bin/env bash
FILE="$1"

unset TMUX
exec tmux new-session bash -c "
    # Show menu in top pane
    echo 'Commands: (e)macs | (v)i | (n)ano | (b)atcat'
    echo 'Press key to launch editor...'

    # Wait for keypress
    read -n1 choice

    # Launch editor
    case \$choice in
        e) exec emacs -nw '$FILE' ;;
        v) exec vi '$FILE' ;;
        n) exec nano '$FILE' ;;
        b) exec batcat '$FILE' ;;
    esac
"
```

**Pros:**
- Simple, visible menu
- No complex tmux commands
- Easy to understand flow

**Cons:**
- Less polished UX
- Takes screen space

**Status:** 🟢 Simple MVP option

---

## Pattern 6: Pre-launch Selection (External Menu)

**What it is:** Show menu BEFORE launching tmux session using terminal dialog

**How it works:**
```bash
#!/usr/bin/env bash
FILE="$1"

# Show menu using simple bash select
PS3="Choose editor: "
options=("Emacs" "Vi" "Nano" "Batcat" "Server Logs" "Browser Logs")

select opt in "${options[@]}"; do
    case $opt in
        "Emacs") EDITOR_CMD="emacs -nw \"$FILE\""; break ;;
        "Vi") EDITOR_CMD="vi \"$FILE\""; break ;;
        "Nano") EDITOR_CMD="nano \"$FILE\""; break ;;
        "Batcat") EDITOR_CMD="batcat \"$FILE\""; break ;;
        "Server Logs") EDITOR_CMD="tail -f /var/log/server.log"; break ;;
        "Browser Logs") EDITOR_CMD="tail -f ~/.browser/console.log"; break ;;
    esac
done

unset TMUX
exec tmux new-session bash -c "$EDITOR_CMD"
```

**Pros:**
- No tmux dependencies for menu
- Very reliable
- Easy to debug

**Cons:**
- Less polished visual
- Not a "palette" experience

**Status:** 🟢 Reliable fallback

---

## Pattern 7: run-shell with Command Execution

**What it is:** Use tmux run-shell to properly execute commands from menu

**How it works:**
```bash
#!/usr/bin/env bash
FILE="$1"

unset TMUX

# Create a wrapper script for each command
cat > /tmp/editor-emacs.sh <<EOF
#!/bin/bash
exec emacs -nw "$FILE"
EOF
chmod +x /tmp/editor-emacs.sh

cat > /tmp/editor-vi.sh <<EOF
#!/bin/bash
exec vi "$FILE"
EOF
chmod +x /tmp/editor-vi.sh

# Launch tmux with menu that uses run-shell
exec tmux new-session bash -c "
    tmux display-menu -T 'Choose Editor' -x C -y C \
        'Emacs' e 'run-shell /tmp/editor-emacs.sh' \
        'Vi' v 'run-shell /tmp/editor-vi.sh'
"
```

**Pros:**
- Proper command isolation
- Easier debugging

**Cons:**
- Temp file overhead
- run-shell might background the process

**Status:** 🔵 Worth testing to fix Pattern 1

---

## Pattern 8: Hybrid - Menu then Respawn

**What it is:** Start with a holding pattern, show menu, respawn pane with selection

**How it works:**
```bash
#!/usr/bin/env bash
FILE="$1"

# Create temp config
CONF=$(mktemp)
cat > "$CONF" <<EOF
bind-key e respawn-pane -k "emacs -nw '$FILE'"
bind-key v respawn-pane -k "vi '$FILE'"
bind-key n respawn-pane -k "nano '$FILE'"
EOF

unset TMUX
exec tmux -f "$CONF" new-session bash -c "
    tmux display-menu -T 'Choose Editor' -x C -y C \
        'Emacs' e 'send-keys e' \
        'Vi' v 'send-keys v' \
        'Nano' n 'send-keys n'

    # Hold session open
    sleep infinity
"
```

**Pros:**
- Menu works reliably
- Editor launches in same pane

**Cons:**
- Complex setup
- Respawn might have side effects

**Status:** 🔵 Creative solution

---

## Recommendation for Testing Order

1. **Pattern 6** (Pre-launch Select) - Most reliable, test first
2. **Pattern 5** (Simple read menu) - MVP fallback
3. **Pattern 2** (fzf popup) - Best UX if fzf available
4. **Pattern 4** (Default + hotkey) - Natural tmux flow
5. **Pattern 7** (run-shell fix) - Debug our original approach
6. **Pattern 3** (Persistent session) - Advanced workspace
7. **Pattern 8** (Respawn hybrid) - Creative but complex
8. **Pattern 1** (display-menu) - Already tested, needs fixing

---

## Next Steps

1. Test Pattern 6 (most reliable)
2. If that works, compare with Pattern 2 (best UX)
3. Document learnings
4. Choose final approach
