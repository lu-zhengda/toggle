#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="Toggle"
BUNDLE_ID="com.local.toggle"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="${ROOT_DIR}/build/${APP_NAME}.app"
APP_BINARY="${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

usage() {
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
}

case "${MODE}" in
    run|--debug|debug|--logs|logs|--telemetry|telemetry|--verify|verify) ;;
    *)
        usage
        exit 2
        ;;
esac

if [ "$#" -gt 1 ]; then
    usage
    exit 2
fi

# Stop every existing Toggle instance so the freshly built bundle is the only
# one running, even when a release copy is installed in /Applications.
/usr/bin/pkill -x "${APP_NAME}" >/dev/null 2>&1 || true
for _ in 1 2 3 4 5 6 7 8 9 10; do
    if ! /usr/bin/pgrep -x "${APP_NAME}" >/dev/null 2>&1; then
        break
    fi
    sleep 0.1
done
if /usr/bin/pgrep -x "${APP_NAME}" >/dev/null 2>&1; then
    echo "error: ${APP_NAME} did not terminate" >&2
    exit 1
fi

"${ROOT_DIR}/build-app.sh"

open_app() {
    /usr/bin/open -n "${APP_BUNDLE}"
}

verify_running() {
    local attempt pid executable
    for attempt in 1 2 3 4 5 6 7 8 9 10; do
        for pid in $(/usr/bin/pgrep -x "${APP_NAME}" 2>/dev/null || true); do
            executable="$(/bin/ps -p "${pid}" -o comm=)"
            if [ "${executable}" = "${APP_BINARY}" ]; then
                return 0
            fi
        done
        sleep 0.25
    done
    echo "error: ${APP_NAME} did not start from ${APP_BINARY}" >&2
    return 1
}

case "${MODE}" in
    run)
        open_app
        ;;
    --debug|debug)
        exec /usr/bin/xcrun lldb -- "${APP_BINARY}"
        ;;
    --logs|logs)
        open_app
        verify_running
        exec /usr/bin/log stream --info --style compact \
            --predicate "process == \"${APP_NAME}\""
        ;;
    --telemetry|telemetry)
        open_app
        verify_running
        exec /usr/bin/log stream --info --style compact \
            --predicate "subsystem == \"${BUNDLE_ID}\""
        ;;
    --verify|verify)
        open_app
        verify_running
        echo "${APP_NAME} is running from ${APP_BUNDLE}"
        ;;
esac
