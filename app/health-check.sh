#!/usr/bin/env bash
# health-check.sh - verify the diagnostic tool is installed and working.
# Used by the Dockerfile HEALTHCHECK and can be run by hand.
# Exit 0 = healthy, 1 = unhealthy.
set -u

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOL="$DIR/diagnostic.sh"

fail() {
    echo "UNHEALTHY: $*" >&2
    exit 1
}

[ -f "$TOOL" ] || fail "diagnostic.sh not found at $TOOL"
[ -x "$TOOL" ] || fail "diagnostic.sh is not executable"

for cmd in bash awk grep df uname getent; do
    command -v "$cmd" >/dev/null 2>&1 || fail "required command '$cmd' is missing"
done

"$TOOL" help >/dev/null 2>&1 || fail "'diagnostic help' did not succeed"
"$TOOL" disk >/dev/null 2>&1 || fail "'diagnostic disk' did not succeed"

echo "HEALTHY"
exit 0
