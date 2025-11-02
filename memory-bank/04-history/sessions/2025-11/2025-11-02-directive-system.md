# Session: Directive-Based Enhancement System (Nov 2, 2025)

**Status:** ✅ COMPLETE

## What We Shipped

Replaced the `*** marker ***` pattern with an explicit hashtag directive system for prompt enhancement.

**New Directive System:**
- `#enhance` - Investigate codebase, add file paths, line numbers, architectural context
- `#spellcheck` - Fix spelling and grammar errors
- `#suggest` - Suggest next steps based on conversation (works with blank prompts)
- `#investigate` - Deep dive into specific features/bugs
- `#fix` - Identify issues and explain solutions
- `#please <custom>` - Freeform enhancement request

**Design Benefits:**
- **More explicit** - Users control enhancement type directly
- **More flexible** - Freeform #please directive for custom requests
- **Better UX** - Hashtag syntax is familiar and self-documenting
- **Token efficient** - Context stored as files, Haiku reads on-demand
- **Composable** - Multiple directives can be used in one prompt

## Files Changed

**Core Implementation:**
- `lib/scripts/create-subagent-context-lite.sh` - Updated system and user prompts with directive syntax

**Documentation:**
- `README.md` - Replaced `***README***` example with `#enhance\nAdd dark mode`
- `public-posts/reddit-demo-enhancement.md` - Complete directive system section with examples
- `lib/menu-core.sh` - Updated comment about enhancement capabilities
- `bin/claude-editor-hook` - Deprecated Pattern 9 (old standalone enhancement)
- `memory-bank/00-core/projectbrief.md` - Added directive system features
- `memory-bank/02-active/currentWork.md` - Documented directive implementation

## Key Implementation Details

**System Prompt Changes:**
- Defined 6 directive types with clear descriptions
- Explained inline vs sectioned usage
- Set smart defaults: no directive → spellcheck, blank → suggest

**User Prompt Changes:**
- Instructions for parsing directives
- Behavior for each directive type
- Default behaviors for edge cases

**Pattern 9 Deprecation:**
- Old standalone enhancement pattern marked deprecated
- Directs users to Pattern 2 (FZF menu) instead
- Removes outdated `*** marker ***` code

## Context Package Design

The directive system leverages the existing context package architecture:

1. Creates temp directory: `/tmp/claude-subagent-lite-$$`
2. Populates with context files:
   - `system-prompt.txt` - Directive instructions and capabilities
   - `user-prompt.txt` - Enhancement request parsing
   - `parent-context.md` - Recent conversation (last 2000 chars)
   - `recent-files.txt` - Last 3 files edited
   - `meta.json` - Working directory and metadata

3. Haiku reads files on-demand using Read tool (token efficient)
4. Enhanced prompt written back to original prompt file

## UX Flow

**Before enhancement:**
```
#enhance
Add dark mode support
```

**Haiku receives:**
- System prompt explaining directives
- User prompt with parsing instructions
- Context files available for reading

**Haiku investigates:**
- Searches codebase for theme patterns
- Finds `src/styles/theme.ts:42`
- Reads implementation details

**Enhanced prompt returned:**
```
Add dark mode support to the application.

Existing theme system found in src/styles/theme.ts:42 uses a ThemeProvider
pattern with light/dark variants. Architecture uses CSS-in-JS with styled-components.

Implement toggle in Settings.tsx, add dark theme variant to theme.ts following
existing pattern, update ThemeProvider to support theme switching.
```

## Learnings

**Explicit > Implicit:**
- Hashtag directives are more discoverable than `*** markers ***`
- Users know exactly what they're requesting
- Self-documenting syntax

**Flexibility Matters:**
- Fixed directives (#enhance, #spellcheck) cover common cases
- #please directive allows custom requests
- Multiple directives support complex workflows

**Token Efficiency:**
- File-based context prevents prompt bloat
- Haiku only reads what it needs
- Smart for lightweight model usage

## Related Docs

- `lib/scripts/create-subagent-context-lite.sh` - Context package implementation
- `memory-bank/00-core/projectbrief.md` - Updated feature list
- `public-posts/reddit-demo-enhancement.md` - Public documentation

## Next Steps

1. Test directive system in real usage
2. Monitor which directives get used most
3. Consider adding more directives based on usage patterns
4. Gather feedback on UX and effectiveness

---

**Archive Date:** 2025-11-02
