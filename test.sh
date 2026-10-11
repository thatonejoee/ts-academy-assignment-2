#!/usr/bin/env bash
# test.sh - tests for the diagnostic tool.
#
# Usage:
#   ./test.sh            build the Docker image and test it
#   ./test.sh --local    test app/diagnostic.sh directly (no Docker needed)
#
# Environment:
#   IMAGE   image name to build/test (default: diagnostic-tool)
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE="${IMAGE:-diagnostic-tool}"
MODE="docker"
[ "${1:-}" = "--local" ] && MODE="local"

PASS=0
FAIL=0
OUT=""
RC=0

if [ "$MODE" = "docker" ]; then
    if ! command -v docker >/dev/null 2>&1; then
        echo "docker is not installed. Install it or run: ./test.sh --local" >&2
        exit 1
    fi
    echo "Building image '$IMAGE'..."
    if ! docker build -q -t "$IMAGE" "$ROOT" >/dev/null; then
        echo "FAIL: docker build failed" >&2
        exit 1
    fi
    run() { docker run --rm "$IMAGE" "$@"; }
else
    run() { "$ROOT/app/diagnostic.sh" "$@"; }
fi

# capture <args...>: run the tool, store combined output in OUT and exit code in RC
capture() {
    OUT="$(run "$@" 2>&1)"
    RC=$?
}

pass() { PASS=$((PASS + 1)); echo "  [PASS] $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  [FAIL] $1"; }

# expect_exit <name> <expected-code> <args...>
expect_exit() {
    local name="$1" want="$2"
    shift 2
    capture "$@"
    if [ "$RC" -eq "$want" ]; then
        pass "$name (exit $RC)"
    else
        fail "$name (expected exit $want, got $RC)"
    fi
}

# expect_output <name> <pattern>: check the last captured output
expect_output() {
    if printf '%s' "$OUT" | grep -qi -- "$2"; then
        pass "$1"
    else
        fail "$1 (output did not contain '$2')"
    fi
}

echo "Running tests ($MODE mode)"
echo

echo "help"
expect_exit   "help succeeds" 0 help
expect_output "help lists the commands" "system"
expect_output "help shows usage" "usage"

echo "system"
expect_exit   "system succeeds" 0 system
expect_output "system shows hostname" "hostname"
expect_output "system shows kernel" "kernel"
expect_output "system shows memory" "memory"

echo "disk"
expect_exit   "disk succeeds" 0 disk
expect_output "disk shows usage" "usage"
expect_exit   "disk rejects a missing path" 2 disk /nonexistent-path

echo "network"
expect_exit   "network resolves localhost" 0 network localhost
expect_output "network shows resolved address" "resolved"
expect_exit   "network without host is invalid" 2 network
expect_exit   "network with malformed host is invalid" 2 network 'bad_host!'
expect_exit   "network with unresolvable host fails" 1 network nonexistent.invalid

echo "invalid input"
expect_exit   "unknown command is invalid" 2 notacommand
expect_output "invalid command explains the error" "unknown command"
expect_exit   "no command is invalid" 2
expect_exit   "extra argument to system is invalid" 2 system extra

echo
echo "Passed: $PASS   Failed: $FAIL"
[ "$FAIL" -eq 0 ] && exit 0
exit 1
