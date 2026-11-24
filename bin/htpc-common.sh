#!/bin/sh
# Shared helpers for the htpc-remote shell scripts. Sourced, not executed.
# Resolves HTPC_USER, its uid, and a working XAUTHORITY for `runuser` X calls.

CONF="${HTPC_REMOTE_CONF:-/etc/htpc-remote.conf}"
[ -r "$CONF" ] && . "$CONF"

# Auto-detect the graphical user if not configured.
if [ -z "$HTPC_USER" ]; then
    HTPC_USER=$(loginctl list-sessions --no-legend 2>/dev/null \
        | awk '$4=="seat0"{print $3; exit}')
fi
[ -n "$HTPC_USER" ] || HTPC_USER=$(id -un 1000 2>/dev/null)

HTPC_UID=$(id -u "$HTPC_USER" 2>/dev/null)
: "${XAUTHORITY_PATH:=/run/user/%UID%/gdm/Xauthority}"
XAUTH=$(printf '%s' "$XAUTHORITY_PATH" | sed "s/%UID%/$HTPC_UID/g")

# Run a command inside the user's graphical session.
run_as_user() {
    runuser -u "$HTPC_USER" -- env \
        DISPLAY=:0 \
        XAUTHORITY="$XAUTH" \
        XDG_RUNTIME_DIR="/run/user/$HTPC_UID" \
        DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$HTPC_UID/bus" \
        "$@"
}

seat0_session() {
    loginctl list-sessions --no-legend 2>/dev/null \
        | awk -v u="$HTPC_USER" '$3==u && $4=="seat0"{print $1; exit}'
}
