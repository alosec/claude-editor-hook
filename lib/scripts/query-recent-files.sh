#!/usr/bin/env bash

# Query mem-sqlite database for recently touched files
# Returns one file path per line, ordered by recency (most recent first)
# Exit codes: 0 (success), 1 (db missing), 2 (query error)

DB_PATH="$HOME/.local/share/memory-sqlite/claude_code.db"

# Check if database exists
if [ ! -f "$DB_PATH" ]; then
    echo "Error: mem-sqlite database not found at $DB_PATH" >&2
    echo "Run: cd ~/code/mem-sqlite && npm run cli sync" >&2
    exit 1
fi

# Optional: Filter by project directory (pass as first argument)
PROJECT_FILTER="${1:-}"

# Build SQL query
if [ -n "$PROJECT_FILTER" ]; then
    QUERY="
    SELECT DISTINCT
      json_extract(tu.parameters, '\$.file_path') AS file_path,
      MAX(tu.created) AS last_touched
    FROM tool_uses tu
    WHERE
      tu.toolName IN ('Read', 'Edit', 'Write')
      AND json_extract(tu.parameters, '\$.file_path') IS NOT NULL
      AND json_extract(tu.parameters, '\$.file_path') != ''
      AND json_extract(tu.parameters, '\$.file_path') LIKE '%${PROJECT_FILTER}%'
    GROUP BY file_path
    ORDER BY last_touched DESC
    LIMIT 25;
    "
else
    QUERY="
    SELECT DISTINCT
      json_extract(tu.parameters, '\$.file_path') AS file_path,
      MAX(tu.created) AS last_touched
    FROM tool_uses tu
    WHERE
      tu.toolName IN ('Read', 'Edit', 'Write')
      AND json_extract(tu.parameters, '\$.file_path') IS NOT NULL
      AND json_extract(tu.parameters, '\$.file_path') != ''
    GROUP BY file_path
    ORDER BY last_touched DESC
    LIMIT 25;
    "
fi

# Execute query and extract just the file paths
sqlite3 "$DB_PATH" "$QUERY" 2>&1 | while IFS='|' read -r file_path timestamp; do
    echo "$file_path"
done

# Check for errors
if [ ${PIPESTATUS[0]} -ne 0 ]; then
    echo "Error: Query execution failed" >&2
    exit 2
fi

exit 0
