#!/usr/bin/env bash
# Terminal metadata management - stores terminal display name mappings
# Storage: lib/cache/terminal-metadata.json
# Format: {"terminal-1": "workspace", "terminal-2": "logs", ...}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
METADATA_FILE="$SCRIPT_DIR/../cache/terminal-metadata.json"

# Ensure cache directory exists
mkdir -p "$(dirname "$METADATA_FILE")"

# Initialize metadata file if it doesn't exist
if [ ! -f "$METADATA_FILE" ]; then
    echo '{}' > "$METADATA_FILE"
fi

# Usage: manage-terminal-metadata.sh get <terminal-name>
# Returns: display name or empty string
get_display_name() {
    local terminal_name="$1"
    jq -r ".[\"$terminal_name\"] // empty" "$METADATA_FILE"
}

# Usage: manage-terminal-metadata.sh set <terminal-name> <display-name>
set_display_name() {
    local terminal_name="$1"
    local display_name="$2"

    # Update JSON file
    local temp_file=$(mktemp)
    jq ".[\"$terminal_name\"] = \"$display_name\"" "$METADATA_FILE" > "$temp_file"
    mv "$temp_file" "$METADATA_FILE"
}

# Usage: manage-terminal-metadata.sh delete <terminal-name>
delete_terminal() {
    local terminal_name="$1"

    # Remove from JSON file
    local temp_file=$(mktemp)
    jq "del(.[\"$terminal_name\"])" "$METADATA_FILE" > "$temp_file"
    mv "$temp_file" "$METADATA_FILE"
}

# Main command dispatcher
case "$1" in
    get)
        get_display_name "$2"
        ;;
    set)
        set_display_name "$2" "$3"
        ;;
    delete)
        delete_terminal "$2"
        ;;
    *)
        echo "Usage: $0 {get|set|delete} <terminal-name> [display-name]"
        exit 1
        ;;
esac
