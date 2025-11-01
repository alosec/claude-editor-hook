# Session: Unified Menu System (2025-10-30)

**Status:** ✅ COMPLETE

## What We Shipped

Unified the FZF menu system by extracting shared logic into `lib/menu-core.sh`, ensuring menu options and behavior stay consistent between `claude-editor-hook` (Ctrl-G) and `claude-editor-menu` (standalone).

## The Problem

Menu logic was duplicated in two places:
- `bin/claude-editor-hook` - Main Ctrl-G hook
- `bin/claude-editor-menu` - Standalone menu command

This created maintenance burden and risk of divergence.

## The Solution

**Single Source of Truth:**
- Extracted menu logic to `lib/menu-core.sh`
- Defined `show_menu()` function with all menu options
- Both entry points source and call shared function

**Architecture:**
```
bin/claude-editor-hook
    ↓
lib/menu-core.sh ← show_menu()
    ↑
bin/claude-editor-menu
```

## Files Changed

**Created:**
- `lib/menu-core.sh` - Shared menu logic and menu option definitions

**Modified:**
- `bin/claude-editor-hook` - Sources menu-core.sh, calls show_menu()
- `bin/claude-editor-menu` - Sources menu-core.sh, calls show_menu()

## Implementation Details

**Menu Definition (Single Source):**
```bash
# In lib/menu-core.sh
show_menu() {
    local FILE="$1"

    local MENU="Edit with Emacs:emacs -nw \"$FILE\"
Edit with Vi:vi \"$FILE\"
Edit with Nano:nano \"$FILE\"
Open Terminal:open-terminal
Recent Files:recent-files
Detach:detach
Enhance (Interactive):claude-spawn-interactive
Enhance (Non-interactive):claude-enhance-auto"

    # Show FZF, parse choice, execute command
    # ...
}
```

**Symlink Resolution:**
- Both scripts handle symlinks properly
- Resolves `~/.local/bin/claude-editor-hook` → actual project location
- Finds `lib/menu-core.sh` relative to resolved path

## Key Learnings

**Benefits of Extraction:**
1. **Consistency** - Menu changes apply everywhere
2. **Maintainability** - Single place to add features
3. **Testability** - Can test menu logic in isolation

**Symlink Handling Pattern:**
```bash
SCRIPT_SOURCE="${BASH_SOURCE[0]:-$0}"
while [ -L "$SCRIPT_SOURCE" ]; do
    SCRIPT_DIR="$(cd -P "$(dirname "$SCRIPT_SOURCE")" && pwd)"
    SCRIPT_SOURCE="$(readlink "$SCRIPT_SOURCE")"
    [[ $SCRIPT_SOURCE != /* ]] && SCRIPT_SOURCE="$SCRIPT_DIR/$SCRIPT_SOURCE"
done
SCRIPT_DIR="$(cd -P "$(dirname "$SCRIPT_SOURCE")" && pwd)"
```

## Commits

```
f0d88a1 feat: Unify menu system with shared lib/menu-core.sh
0092678 fix: Source menu-core.sh inside bash -c context
64f39f8 fix: Find menu-core.sh via claude-editor-hook symlink
6066bc0 feat: Add bin/claude-editor-menu with proper symlink resolution
95cfb08 Merge feature/unify-menu-system: Unified menu with shared core
```

## Impact

Menu options can now be added once and appear in both Ctrl-G hook and standalone menu, reducing maintenance and ensuring consistent user experience.
