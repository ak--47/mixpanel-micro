#!/bin/sh
# ------------------------------------------------------------------------------
# MIXPANEL-MICRO
# this thing can survive anywhere
# by AK (ak@mixpanel.com)
# 
# Usage:
#   ./mixpanel-micro.sh <TOKEN> <EVENT> <JSON_PROPERTIES> [DISTINCT_ID] [--verbose] [--dry-run]
# ------------------------------------------------------------------------------

# --- 1. ARGUMENT PARSING & CONFIG ---

VERBOSE=0
DRY_RUN=0

# First pass: extract flags and count them
FLAG_COUNT=0
for arg in "$@"; do
    case "$arg" in
        --verbose) VERBOSE=1; FLAG_COUNT=$((FLAG_COUNT + 1)) ;;
        --dry-run) DRY_RUN=1; VERBOSE=1; FLAG_COUNT=$((FLAG_COUNT + 1)) ;;
    esac
done

# Second pass: extract positional args (skip flags)
TOKEN=""
EVENT_NAME=""
RAW_PROPS=""
DISTINCT_ID=""
POS=0

for arg in "$@"; do
    case "$arg" in
        --verbose|--dry-run) continue ;;  # Skip flags
        *)
            POS=$((POS + 1))
            case $POS in
                1) TOKEN="$arg" ;;
                2) EVENT_NAME="$arg" ;;
                3) RAW_PROPS="$arg" ;;
                4) DISTINCT_ID="$arg" ;;
            esac
            ;;
    esac
done

# --- 2. VALIDATION ---

# Show usage if no arguments provided
if [ $# -eq 0 ]; then
    cat >&2 <<'EOF'
Usage: mixpanel-micro.sh <TOKEN> <EVENT> [PROPERTIES] [DISTINCT_ID] [FLAGS]

Arguments:
  TOKEN        Your Mixpanel project token (required)
  EVENT        Event name (required)
  PROPERTIES   JSON object with event properties (default: {})
  DISTINCT_ID  User identifier (default: auto-generated)

Flags:
  --verbose    Show payload and API response
  --dry-run    Show payload without sending (implies --verbose)

Examples:
  ./mixpanel-micro.sh "TOKEN" "Page View"
  ./mixpanel-micro.sh "TOKEN" "Login" '{"method": "password"}' "user_123"
  ./mixpanel-micro.sh "TOKEN" "Test Event" '{}' "user" --dry-run
EOF
    exit 1
fi

if [ -z "$TOKEN" ] || [ -z "$EVENT_NAME" ]; then
    echo "❌ [Mixpanel-Micro] Error: Missing required arguments (TOKEN and EVENT)" >&2
    echo "Run './mixpanel-micro.sh' with no arguments to see usage." >&2
    exit 1
fi

# Defaults
if [ -z "$RAW_PROPS" ]; then RAW_PROPS="{}"; fi

# --- 3. ID GENERATION ---
# If no distinct_id is provided, we try (in order): 
# Current User > Hostname > Random fallback
if [ -z "$DISTINCT_ID" ]; then
    USER_ID=$(whoami 2>/dev/null || id -un 2>/dev/null || echo "unknown")
    HOST_ID=$(hostname 2>/dev/null || uname -n 2>/dev/null || echo "device")
    DISTINCT_ID="${HOST_ID}-${USER_ID}"
fi

# --- 4. ASYNC FIRE-AND-FORGET WRAPPER ---
# spawn a subshell `(...)` and background it `&` (ensuring non-blocking behavior)

# Function to execute tracking logic
_track() {
    # --- 5. DATA PREPARATION ---
    # Strip outer brackets from props to merge them
    CLEAN_PROPS=$(echo "$RAW_PROPS" | sed -e 's/^{//' -e 's/}$//')
    if [ -n "$CLEAN_PROPS" ]; then CLEAN_PROPS=",$CLEAN_PROPS"; fi

    # Construct JSON Payload (Mixpanel expects an array of events)
    # Note: We assume the caller provides valid JSON for $RAW_PROPS
    PAYLOAD="[{\"event\":\"$EVENT_NAME\",\"properties\":{\"token\":\"$TOKEN\",\"distinct_id\":\"$DISTINCT_ID\",\"\$source\":\"mixpanel-micro\"$CLEAN_PROPS}}]"

    if [ "$VERBOSE" -eq 1 ]; then
        echo "🔍 [Mixpanel-Micro] Payload: $PAYLOAD"
    fi

    if [ "$DRY_RUN" -eq 1 ]; then
        echo "✅ [Mixpanel-Micro] Dry Run Complete. Request not sent."
        exit 0
    fi

    # --- 6. UNIVERSAL TRANSPORT LAYER ---
    # We look for ANY available tool to make the request.
    API_URL="https://api.mixpanel.com/track?verbose=1"

    # Define Output Sink
    if [ "$VERBOSE" -eq 1 ]; then OUT="/dev/stdout"; else OUT="/dev/null"; fi

    if command -v curl >/dev/null 2>&1; then
        # 1. CURL (Best)
        curl -s -X POST \
            -H "Accept: text/plain" \
            -H "Content-Type: application/json" \
            -d "$PAYLOAD" \
            "$API_URL" > "$OUT" 2>&1

    elif command -v wget >/dev/null 2>&1; then
        # 2. WGET (Standard)
        # Note: We use --post-data. Some minimal wgets (BusyBox) prefer different flags,
        # but this covers 95% of cases.
        wget -q -O - \
            --header="Accept: text/plain" \
            --header="Content-Type: application/json" \
            --post-data="$PAYLOAD" \
            "$API_URL" > "$OUT" 2>&1

    elif command -v http >/dev/null 2>&1; then
        # 3. HTTPie (Python based tool, rare but possible)
        echo "$PAYLOAD" | http POST "$API_URL" \
            Accept:text/plain \
            Content-Type:application/json > "$OUT" 2>&1

    else
        # 4. FAILURE
        if [ "$VERBOSE" -eq 1 ]; then echo "❌ [Mixpanel-Micro] No HTTP client found (curl, wget, or http)." >&2; fi
        exit 127
    fi
}

# Background the function with conditional output suppression
if [ "$VERBOSE" -eq 1 ]; then
    # Verbose mode: show output
    _track &
else
    # Normal mode: suppress all output
    _track > /dev/null 2>&1 &
fi

# Immediate exit for the parent process
exit 0