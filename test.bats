#!/usr/bin/env bats

# Load environment variables
setup() {
    # Source .env file if it exists
    if [ -f ".env" ]; then
        export $(cat .env | grep -v '^#' | xargs)
    fi

    # Set script path
    SCRIPT="./mixpanel-micro.sh"

    # Ensure script is executable
    chmod +x "$SCRIPT"

    # Test data
    TEST_EVENT="BATS Test Event"
    TEST_DISTINCT_ID="bats_test_user_$$"
    TEST_PROPS='{"test": true, "runner": "bats"}'
}

# ============================================================================
# BASIC FUNCTIONALITY TESTS
# ============================================================================

@test "script exists and is executable" {
    [ -x "$SCRIPT" ]
}

@test "script exits successfully with minimal args" {
    run "$SCRIPT" "$MIXPANEL_TOKEN" "$TEST_EVENT"
    [ "$status" -eq 0 ]
}

@test "script exits successfully with all args" {
    run "$SCRIPT" "$MIXPANEL_TOKEN" "$TEST_EVENT" "$TEST_PROPS" "$TEST_DISTINCT_ID"
    [ "$status" -eq 0 ]
}

@test "script exits successfully with empty properties" {
    run "$SCRIPT" "$MIXPANEL_TOKEN" "$TEST_EVENT" "{}" "$TEST_DISTINCT_ID"
    [ "$status" -eq 0 ]
}

# ============================================================================
# VALIDATION TESTS (Should Fail)
# ============================================================================

@test "fails when no token provided" {
    run "$SCRIPT"
    [ "$status" -eq 1 ]
}

@test "fails when only token provided (no event)" {
    run "$SCRIPT" "$MIXPANEL_TOKEN"
    [ "$status" -eq 1 ]
}

# ============================================================================
# DRY-RUN MODE TESTS
# ============================================================================

@test "dry-run shows payload and doesn't send" {
    run "$SCRIPT" "$MIXPANEL_TOKEN" "$TEST_EVENT" "$TEST_PROPS" "$TEST_DISTINCT_ID" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Payload:" ]]
    [[ "$output" =~ "Dry Run Complete" ]]
    [[ "$output" =~ "$TEST_EVENT" ]]
}

@test "dry-run payload contains event name" {
    run "$SCRIPT" "$MIXPANEL_TOKEN" "Custom Event Name" "$TEST_PROPS" "$TEST_DISTINCT_ID" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Custom Event Name" ]]
}

@test "dry-run payload contains token" {
    run "$SCRIPT" "$MIXPANEL_TOKEN" "$TEST_EVENT" "$TEST_PROPS" "$TEST_DISTINCT_ID" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" =~ "$MIXPANEL_TOKEN" ]]
}

@test "dry-run payload contains distinct_id" {
    run "$SCRIPT" "$MIXPANEL_TOKEN" "$TEST_EVENT" "$TEST_PROPS" "test_user_123" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" =~ "test_user_123" ]]
}

@test "dry-run payload contains custom properties" {
    run "$SCRIPT" "$MIXPANEL_TOKEN" "$TEST_EVENT" '{"foo": "bar", "count": 42}' "$TEST_DISTINCT_ID" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" =~ "foo" ]]
    [[ "$output" =~ "bar" ]]
}

@test "dry-run payload contains source tag" {
    run "$SCRIPT" "$MIXPANEL_TOKEN" "$TEST_EVENT" "$TEST_PROPS" "$TEST_DISTINCT_ID" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" =~ "mixpanel-micro" ]]
}

# ============================================================================
# VERBOSE MODE TESTS
# ============================================================================

@test "verbose mode shows payload" {
    run "$SCRIPT" "$MIXPANEL_TOKEN" "$TEST_EVENT" "$TEST_PROPS" "$TEST_DISTINCT_ID" --verbose
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Payload:" ]]
}

@test "verbose mode with minimal args shows auto-generated distinct_id" {
    run "$SCRIPT" "$MIXPANEL_TOKEN" "$TEST_EVENT" --verbose
    [ "$status" -eq 0 ]
    [[ "$output" =~ "distinct_id" ]]
}

# ============================================================================
# FLAG POSITION TESTS
# ============================================================================

@test "verbose flag works at the end" {
    run "$SCRIPT" "$MIXPANEL_TOKEN" "$TEST_EVENT" "$TEST_PROPS" "$TEST_DISTINCT_ID" --verbose
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Payload:" ]]
}

@test "verbose flag works at the beginning" {
    run "$SCRIPT" --verbose "$MIXPANEL_TOKEN" "$TEST_EVENT" "$TEST_PROPS" "$TEST_DISTINCT_ID"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Payload:" ]]
}

@test "dry-run flag works in different positions" {
    run "$SCRIPT" --dry-run "$MIXPANEL_TOKEN" "$TEST_EVENT" "$TEST_PROPS" "$TEST_DISTINCT_ID"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Dry Run Complete" ]]
}

@test "multiple flags work together" {
    run "$SCRIPT" "$MIXPANEL_TOKEN" "$TEST_EVENT" --verbose --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Payload:" ]]
    [[ "$output" =~ "Dry Run Complete" ]]
}

# ============================================================================
# DISTINCT_ID AUTO-GENERATION TESTS
# ============================================================================

@test "auto-generates distinct_id when not provided" {
    run "$SCRIPT" "$MIXPANEL_TOKEN" "$TEST_EVENT" --dry-run
    [ "$status" -eq 0 ]
    # Should contain hostname or username
    [[ "$output" =~ "distinct_id" ]]
}

@test "uses provided distinct_id over auto-generation" {
    run "$SCRIPT" "$MIXPANEL_TOKEN" "$TEST_EVENT" "{}" "explicit_user_id" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" =~ "explicit_user_id" ]]
}

# ============================================================================
# PROPERTY HANDLING TESTS
# ============================================================================

@test "handles empty properties object" {
    run "$SCRIPT" "$MIXPANEL_TOKEN" "$TEST_EVENT" "{}" "$TEST_DISTINCT_ID" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" =~ "properties" ]]
}

@test "handles numeric properties" {
    run "$SCRIPT" "$MIXPANEL_TOKEN" "$TEST_EVENT" '{"count": 42, "price": 19.99}' "$TEST_DISTINCT_ID" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" =~ "count" ]]
    [[ "$output" =~ "42" ]]
}

@test "handles boolean properties" {
    run "$SCRIPT" "$MIXPANEL_TOKEN" "$TEST_EVENT" '{"active": true, "deleted": false}' "$TEST_DISTINCT_ID" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" =~ "true" ]]
    [[ "$output" =~ "false" ]]
}

@test "handles string properties with spaces" {
    run "$SCRIPT" "$MIXPANEL_TOKEN" "$TEST_EVENT" '{"message": "hello world"}' "$TEST_DISTINCT_ID" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" =~ "hello world" ]]
}

@test "handles nested properties" {
    run "$SCRIPT" "$MIXPANEL_TOKEN" "$TEST_EVENT" '{"user": {"name": "Alice", "age": 30}}' "$TEST_DISTINCT_ID" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Alice" ]]
}

@test "handles array properties" {
    run "$SCRIPT" "$MIXPANEL_TOKEN" "$TEST_EVENT" '{"tags": ["bats", "test", "ci"]}' "$TEST_DISTINCT_ID" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" =~ "tags" ]]
}

# ============================================================================
# EVENT NAME TESTS
# ============================================================================

@test "handles event names with spaces" {
    run "$SCRIPT" "$MIXPANEL_TOKEN" "User Logged In" "{}" "$TEST_DISTINCT_ID" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" =~ "User Logged In" ]]
}

@test "handles event names with special characters" {
    run "$SCRIPT" "$MIXPANEL_TOKEN" "Order #123 Completed" "{}" "$TEST_DISTINCT_ID" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Order #123 Completed" ]]
}

@test "handles event names with underscores" {
    run "$SCRIPT" "$MIXPANEL_TOKEN" "user_signup_completed" "{}" "$TEST_DISTINCT_ID" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" =~ "user_signup_completed" ]]
}

# ============================================================================
# REAL API TESTS (Optional - can be slow)
# ============================================================================

@test "sends real event successfully (verbose mode)" {
    skip "Uncomment to test real API calls"
    run "$SCRIPT" "$MIXPANEL_TOKEN" "BATS Integration Test" '{"timestamp": "'"$(date -u +%Y-%m-%dT%H:%M:%S)"'"}' "$TEST_DISTINCT_ID" --verbose
    [ "$status" -eq 0 ]
    # Mixpanel API returns: {"status": 1, "error": null} on success
    # But since we background the request, we won't see this in normal mode
}

@test "non-verbose mode returns immediately" {
    # This test ensures the async behavior works
    start=$(date +%s)
    run "$SCRIPT" "$MIXPANEL_TOKEN" "$TEST_EVENT" "$TEST_PROPS" "$TEST_DISTINCT_ID"
    end=$(date +%s)
    duration=$((end - start))

    [ "$status" -eq 0 ]
    # Should complete in less than 1 second (async fire-and-forget)
    [ "$duration" -lt 2 ]
}

# ============================================================================
# HTTP CLIENT DETECTION TESTS
# ============================================================================

@test "detects available HTTP client" {
    # Just verify curl, wget, or httpie exists
    run bash -c "command -v curl || command -v wget || command -v httpie"
    [ "$status" -eq 0 ]
}

# ============================================================================
# PAYLOAD STRUCTURE TESTS
# ============================================================================

@test "payload is valid JSON" {
    run "$SCRIPT" "$MIXPANEL_TOKEN" "$TEST_EVENT" "$TEST_PROPS" "$TEST_DISTINCT_ID" --dry-run
    [ "$status" -eq 0 ]

    # Extract payload and validate with jq (if available)
    if command -v jq >/dev/null 2>&1; then
        payload=$(echo "$output" | grep "Payload:" | sed 's/.*Payload: //')
        run bash -c "echo '$payload' | jq ."
        [ "$status" -eq 0 ]
    fi
}

@test "payload contains all required Mixpanel fields" {
    run "$SCRIPT" "$MIXPANEL_TOKEN" "$TEST_EVENT" "$TEST_PROPS" "$TEST_DISTINCT_ID" --dry-run
    [ "$status" -eq 0 ]

    # Check for required fields
    [[ "$output" =~ '"event"' ]]
    [[ "$output" =~ '"properties"' ]]
    [[ "$output" =~ '"token"' ]]
    [[ "$output" =~ '"distinct_id"' ]]
}

# ============================================================================
# USE CASE EXAMPLES FROM examples.md
# ============================================================================

@test "example: minimal usage (auto-generated ID)" {
    run "$SCRIPT" "$MIXPANEL_TOKEN" "Script Started" "{}" --dry-run
    [ "$status" -eq 0 ]
}

@test "example: with properties" {
    run "$SCRIPT" "$MIXPANEL_TOKEN" "File Uploaded" '{"size_mb": 12.5, "type": "pdf"}' --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" =~ "12.5" ]]
}

@test "example: login event" {
    run "$SCRIPT" "$MIXPANEL_TOKEN" "Login" '{"method": "password"}' "user_alice" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" =~ "password" ]]
}

@test "example: API request tracking" {
    run "$SCRIPT" "$MIXPANEL_TOKEN" "API Request" '{"endpoint": "/v1/users", "latency": 45}' "user_123" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" =~ "/v1/users" ]]
}

@test "example: payment processing" {
    run "$SCRIPT" "$MIXPANEL_TOKEN" "Payment Processed" '{"amount": 49.99, "currency": "USD"}' "user_bob" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" =~ "49.99" ]]
}

@test "example: temperature sensor (IoT)" {
    run "$SCRIPT" "$MIXPANEL_TOKEN" "Temperature Reading" '{"temp": 24.5, "unit": "C"}' "sensor_01" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" =~ "24.5" ]]
}

@test "example: job completion tracking" {
    run "$SCRIPT" "$MIXPANEL_TOKEN" "Job Completed" '{"duration_ms": 400, "status": "success"}' "worker_1" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" =~ "400" ]]
}

@test "example: page view tracking" {
    run "$SCRIPT" "$MIXPANEL_TOKEN" "Page View" '{"path": "/dashboard", "duration_ms": 245}' "user_123" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" =~ "/dashboard" ]]
}


# ============================================================================
# SPECIAL CHARACTERS & QUOTING HELL (The hardest part of Shell)
# ============================================================================

@test "handles single quotes in property values (O'Reilly)" {
    # We escape the single quote for the test runner, passing "O'Reilly" to the script
    run "$SCRIPT" "$MIXPANEL_TOKEN" "$TEST_EVENT" '{"name": "O'\''Reilly"}' "$TEST_DISTINCT_ID" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" =~ "O'Reilly" ]]
}



@test "handles shell special characters in event name ($ ! &)" {
    run "$SCRIPT" "$MIXPANEL_TOKEN" "Event with $ and ! and &" "{}" "$TEST_DISTINCT_ID" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Event with $ and ! and &" ]]
}

@test "handles emoji in event name and properties" {
    run "$SCRIPT" "$MIXPANEL_TOKEN" "🚀 Launch" '{"mood": "🔥"}' "$TEST_DISTINCT_ID" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" =~ "🚀 Launch" ]]
    [[ "$output" =~ "🔥" ]]
}

# ============================================================================
# WHITESPACE ROBUSTNESS
# ============================================================================

@test "handles properties object with leading/trailing spaces" {
    # Your sed regex uses ^ and $, so this verifies it handles spaces before/after braces
    # Note: The script might actually fail this if not specifically stripping whitespace first.
    # If this fails, you might need to update the script to `echo "$RAW_PROPS" | tr -d '\n' | sed ...`
    run "$SCRIPT" "$MIXPANEL_TOKEN" "$TEST_EVENT" '  {"valid": true}  ' "$TEST_DISTINCT_ID" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" =~ "valid" ]]
}

@test "handles multiline JSON properties" {
    # Shell args generally flatten newlines unless carefully quoted, 
    # but this tests if the script explodes on them
    json_props='{
        "multiline": true
    }'
    run "$SCRIPT" "$MIXPANEL_TOKEN" "$TEST_EVENT" "$json_props" "$TEST_DISTINCT_ID" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" =~ "multiline" ]]
}

# ============================================================================
# ARGUMENT PARSING EDGE CASES
# ============================================================================


@test "handles empty string as explicit distinct_id (should not auto-gen)" {
    # If I pass "" as the 4th arg, does it accept it or fallback?
    # The script checks [ -z "$DISTINCT_ID" ], so "" is treated as empty.
    # This test confirms that passing an explicit empty string results in auto-gen
    run "$SCRIPT" "$MIXPANEL_TOKEN" "$TEST_EVENT" "{}" "" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" =~ "distinct_id" ]]
}

@test "handles explicit '0' as distinct_id (should not auto-gen)" {
    # 0 is a valid ID, shouldn't be treated as false/empty
    run "$SCRIPT" "$MIXPANEL_TOKEN" "$TEST_EVENT" "{}" "0" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" =~ "\"distinct_id\":\"0\"" ]]
}

# ============================================================================
# SECURITY & PRIVACY
# ============================================================================

@test "does not output token to stdout in standard mode" {
    run "$SCRIPT" "$MIXPANEL_TOKEN" "$TEST_EVENT" "{}" "$TEST_DISTINCT_ID"
    [ "$status" -eq 0 ]
    [[ "$output" != *"$MIXPANEL_TOKEN"* ]]
}

@test "ignores external VERBOSE environment variable" {
    # The script sets VERBOSE=0 at start, overriding environment. 
    # This ensures we don't accidentally spam logs in production if env var leaks.
    export VERBOSE=1
    run "$SCRIPT" "$MIXPANEL_TOKEN" "$TEST_EVENT"
    [ "$status" -eq 0 ]
    [[ "$output" != *"Payload:"* ]]
}

# ============================================================================
# SED/REGEX SPECIFICS
# ============================================================================

@test "strips brackets correctly even if content contains brackets" {
    # We want to ensure s/^{// doesn't eat internal brackets
    run "$SCRIPT" "$MIXPANEL_TOKEN" "$TEST_EVENT" '{"meta": {"nested": true}}' "$TEST_DISTINCT_ID" --dry-run
    [ "$status" -eq 0 ]
    # Should still contain the nested structure
    [[ "$output" =~ '"meta": {"nested": true}' ]]
}

@test "handles properties with '}' at the end of a string value" {
    # e.g. {"icon": ":smile:}"}
    # We want to ensure the final s/}$// only matches the JSON closer, not the string content
    run "$SCRIPT" "$MIXPANEL_TOKEN" "$TEST_EVENT" '{"key": "value}"}' "$TEST_DISTINCT_ID" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" =~ '"key": "value}"' ]]
}



# TODOS

@test "handles event name that looks like a flag" {
    # If my event name is "--verbose", it shouldn't trigger verbose mode (unless logic is flawed)
    # Current logic loops all args for --verbose, so this MIGHT fail or trigger verbose.
    # It is good to know behavior.
    run "$SCRIPT" "$MIXPANEL_TOKEN" "--verbose" "{}" "$TEST_DISTINCT_ID" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" =~ "\"event\":\"--verbose\"" ]]
}

@test "handles escaped double quotes in JSON" {
    # JSON requires double quotes to be escaped like \"
    # We want to ensure the script doesn't strip them or break the string
    run "$SCRIPT" "$MIXPANEL_TOKEN" "$TEST_EVENT" '{"quote": "He said \"Hello\""}' "$TEST_DISTINCT_ID" --dry-run
    [ "$status" -eq 0 ]
    # In the output, we look for the escaped sequence
    [[ "$output" =~ 'He said \\"Hello\\"' ]]
}