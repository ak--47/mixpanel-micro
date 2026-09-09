# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**mixpanel-micro** is a single-file, zero-dependency shell script for sending events to Mixpanel's analytics API. It's designed to be universally portable and work in any environment where a POSIX shell exists.

### Design Philosophy

The script prioritizes:
- **Universal compatibility**: Works with sh, bash, zsh, dash, and even BusyBox
- **Zero dependencies**: Only requires curl, wget, or httpie (checks for each in order)
- **Fire-and-forget**: Spawns a backgrounded subshell for truly async, non-blocking behavior
- **Minimal footprint**: Entire analytics solution in ~100 lines
- **Language-agnostic**: Called from any language that can execute shell commands

## Architecture

### Core Components

1. **Argument Parsing (lines 11-32)**: Extracts flags (--verbose, --dry-run) while preserving positional argument order
2. **Validation (lines 34-42)**: Ensures TOKEN and EVENT_NAME are provided
3. **ID Generation (lines 44-51)**: Auto-generates distinct_id from hostname + username if not provided
4. **Async Wrapper (lines 53-101)**: The entire request logic runs in a backgrounded subshell `(...) &`
5. **Data Preparation (lines 56-63)**: Merges user properties with required Mixpanel fields
6. **Universal Transport (lines 74-99)**: Falls back through curl → wget → httpie

### Key Implementation Details

- **Line 101**: `> /dev/null 2>&1 &` ensures the parent process exits immediately without waiting
- **Lines 57-59**: Property merging strips outer braces from user JSON and concatenates into the Mixpanel payload structure
- **Line 63**: All events are tagged with `"$source": "mixpanel-micro-sh"` for tracking
- **Verbose mode**: Routes output to stdout, otherwise to /dev/null

## Testing & Development

### Manual Testing

Always use --verbose flag when testing to see the payload and response:

```bash
./mixpanel-micro.sh "TEST_TOKEN" "Test Event" '{"foo":"bar"}' "test_user" --verbose
```

### Dry Run Testing

Test payload generation without sending requests:

```bash
./mixpanel-micro.sh "TOKEN" "Event" '{"key":"value"}' "user" --dry-run
```

### Validation Checklist

When making changes:
1. Test with missing TOKEN/EVENT (should fail gracefully)
2. Test with empty properties `{}` (should work)
3. Test without distinct_id (should auto-generate)
4. Test all three HTTP clients (curl, wget, httpie) if possible
5. Verify backgrounding works (script should return immediately)
6. Test with special characters in event names and property values

## Common Development Scenarios

### Testing HTTP Client Fallback

Temporarily disable curl to test wget:
```bash
alias curl=false
./mixpanel-micro.sh "TOKEN" "Event" '{}' "user" --verbose
```

### Debugging Payload Issues

Use jq to validate JSON structure:
```bash
./mixpanel-micro.sh "TOKEN" "Event" '{"test":123}' "user" --dry-run | grep Payload | sed 's/.*Payload: //' | jq .
```

### Performance Testing

Measure script startup overhead:
```bash
time ./mixpanel-micro.sh "TOKEN" "Event" '{}' "user"
```
Should return in <50ms (most time is shell fork, not HTTP request).

## Integration Patterns

The examples.md file demonstrates the "factory pattern" for wrapping this script in various languages. The pattern is:

1. Create a closure/function/class that captures TOKEN and DISTINCT_ID
2. Return a lightweight `track(event, properties)` function
3. Call the script using language-specific non-blocking subprocess APIs

This pattern is consistent across all language examples (Node, Python, Go, Ruby, PHP, Rust, etc.).
