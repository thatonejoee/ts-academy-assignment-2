#!/usr/bin/env bash
# diagnostic.sh - small Linux diagnostic CLI.
#
# Usage:
#   diagnostic system
#   diagnostic network <host>
#   diagnostic disk [path]
#   diagnostic help
#
# Exit codes:
#   0  success
#   1  operational/runtime failure (e.g. host does not resolve)
#   2  invalid command or input
set -u

PROG="$(basename "$0")"

usage() {
    cat << EOF
Usage: $PROG <command> [arguments]

Commands:
  system             Show system information (host, OS, kernel, CPU, memory)
  network <host>     Resolve and check a hostname or IP address
  disk [path]        Show disk usage (default path: /)
  help               Show this help message

Exit codes:
  0  success
  1  operational failure
  2  invalid command or input
EOF
}

err() {
    echo "Error: $*" >&2
}

invalid() {
    err "$*"
    echo "Run '$PROG help' for usage." >&2
    exit 2
}

row() {
    printf '%-18s %s\n' "$1:" "$2"
}

# --- helpers (kept portable for Alpine/busybox and Debian/Ubuntu) ---------

get_os() {
    if [ -r /etc/os-release ]; then
        ( . /etc/os-release; echo "${PRETTY_NAME:-${NAME:-Unknown}}" )
    else
        uname -s
    fi
}

get_uptime() {
    local secs d h m
    if [ -r /proc/uptime ]; then
        secs="$(cut -d. -f1 /proc/uptime)"
        d=$((secs / 86400))
        h=$(((secs % 86400) / 3600))
        m=$(((secs % 3600) / 60))
        echo "${d}d ${h}h ${m}m"
    else
        uptime
    fi
}

get_cpu() {
    local model cores
    model="$(grep -m1 -i 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2- | sed 's/^ *//')"
    [ -z "$model" ] && model="$(uname -m)"
    cores="$(grep -c '^processor' /proc/cpuinfo 2>/dev/null || echo '?')"
    echo "$model ($cores cores)"
}

get_memory() {
    # Read /proc/meminfo directly: works the same on every Linux userland.
    awk '
        /^MemTotal:/     {t=$2}
        /^MemAvailable:/ {a=$2}
        END {
            if (t > 0) {
                printf "Total %d MiB, Available %d MiB, Used %d MiB\n", t/1024, a/1024, (t-a)/1024
            } else {
                print "Unknown"
            }
        }' /proc/meminfo 2>/dev/null || echo "Unknown"
}

valid_host() {
    local h="$1"
    [ -n "$h" ] && [ "${#h}" -le 253 ] || return 1
    if [[ "$h" =~ ^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$ ]] && [[ "$h" != *..* ]]; then
        return 0
    fi
    if [[ "$h" == *:* ]] && [[ "$h" =~ ^[0-9A-Fa-f:.]+$ ]]; then
        return 0
    fi
    return 1
}

# --- commands -------------------------------------------------------------

cmd_system() {
    [ $# -eq 0 ] || invalid "'system' takes no arguments (got: $*)"
    echo "================================="
    echo "       SYSTEM INFORMATION"
    echo "================================="
    row "Hostname"    "$(hostname 2>/dev/null || cat /proc/sys/kernel/hostname)"
    row "User"        "$(id -un 2>/dev/null || echo unknown)"
    row "Date/Time"   "$(date '+%Y-%m-%d %H:%M:%S %Z')"
    row "OS"          "$(get_os)"
    row "Kernel"      "$(uname -r)"
    row "Architecture" "$(uname -m)"
    row "Uptime"      "$(get_uptime)"
    row "CPU"         "$(get_cpu)"
    row "Memory"      "$(get_memory)"
    echo "================================="
    return 0
}

cmd_network() {
    [ $# -ge 1 ] || invalid "'network' requires a host argument"
    [ $# -le 1 ] || invalid "'network' takes exactly one host (got: $*)"
    local host="$1"
    valid_host "$host" || invalid "'$host' is not a valid hostname or IP address"

    echo "================================="
    echo "         NETWORK CHECK"
    echo "================================="
    row "Target" "$host"

    local resolved
    resolved="$(getent ahosts "$host" 2>/dev/null | awk 'NR==1 {print $1}')"
    if [ -z "$resolved" ]; then
        row "Resolution" "FAILED - could not resolve '$host'"
        echo "================================="
        return 1
    fi
    row "Resolved address" "$resolved"

    # Ping is informational: many networks and containers block ICMP.
    if command -v ping >/dev/null 2>&1; then
        if ping -c 1 -W 2 "$host" >/dev/null 2>&1; then
            row "Ping" "reply received"
        else
            row "Ping" "no reply (ICMP may be blocked)"
        fi
    else
        row "Ping" "skipped (ping not installed)"
    fi
    echo "================================="
    return 0
}

cmd_disk() {
    [ $# -le 1 ] || invalid "'disk' takes at most one path (got: $*)"
    local path="${1:-/}"
    [ -e "$path" ] || invalid "path '$path' does not exist"

    echo "================================="
    echo "          DISK INFORMATION"
    echo "================================="
    if ! df -h -- "$path" 2>/dev/null; then
        err "could not read disk information for '$path'"
        return 1
    fi
    local pct
    pct="$(df -P -- "$path" 2>/dev/null | awk 'NR==2 {print $5}')"
    echo ""
    row "Path"  "$path"
    row "Usage" "${pct:-unknown}"
    echo "================================="
    return 0
}

# --- dispatch -------------------------------------------------------------

if [ $# -eq 0 ]; then
    usage >&2
    exit 2
fi

command="$1"
shift

case "$command" in
    system)  cmd_system "$@" ;;
    network) cmd_network "$@" ;;
    disk)    cmd_disk "$@" ;;
    help|-h|--help)
        usage
        ;;
    *)
        invalid "unknown command '$command'"
        ;;
esac
exit $?
