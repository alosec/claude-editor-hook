# Memory Bank Structure

This memory bank follows the Oct 2025 organizational pattern for Claude Code projects.

## Quick Start for Claude

**Read these files first (every session):**
1. `02-active/currentWork.md` - What's happening now (~100 lines)
2. `02-active/blockers.md` - What's stuck (~50 lines)
3. `02-active/nextUp.md` - What's next (~100 lines)

**When you need context:**
- Project foundation: `00-core/projectbrief.md`
- Architecture: `01-architecture/systemPatterns.md`

## Directory Structure

```
memory-bank/
├── 00-core/                    # Foundation (rarely changes)
│   └── projectbrief.md         # What we're building
│
├── 01-architecture/            # System design (evolves slowly)
│   └── systemPatterns.md       # Hook architecture and config schema
│
├── 02-active/                  # Current work (changes daily) ← START HERE
│   ├── currentWork.md          # This week's focus
│   ├── nextUp.md               # Top 10 prioritized tasks
│   └── blockers.md             # Active obstacles
│
├── 03-guides/                  # How-to reference (stable)
│   └── [Future: usage guides]
│
├── 04-history/                 # Completed work (append-only archive)
│   └── [Future: session logs]
│
├── 05-roadmap/                 # Future planning
│   └── [Future: feature roadmaps]
│
└── README.md                   # This file
```

## Maintenance

- Keep `currentWork.md` under ~100 lines
- Archive completed work to `04-history/sessions/`
- Update `nextUp.md` when priorities change
- Document blockers immediately when encountered
