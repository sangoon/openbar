#!/bin/sh
set -eu

UUID=openbar@neuromorph
HELPER=unsafemode@local
REPO=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)

widen_metadata=yes
mutate_expr=''
eval_js=''

while [ $# -gt 0 ]; do
	case $1 in
	--as-is) widen_metadata=no ;;
	--mutate)
		mutate_expr=$2
		shift
		;;
	--eval)
		eval_js=$2
		shift
		;;
	*)
		echo "unknown option: $1" >&2
		exit 2
		;;
	esac
	shift
done

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

prepare_session_dirs() {
	XDG_DATA_HOME="$work/data"
	XDG_CONFIG_HOME="$work/config"
	XDG_CACHE_HOME="$work/cache"
	XDG_RUNTIME_DIR="$work/run"
	GSETTINGS_BACKEND=keyfile
	export XDG_DATA_HOME XDG_CONFIG_HOME XDG_CACHE_HOME XDG_RUNTIME_DIR GSETTINGS_BACKEND
	mkdir -p "$XDG_DATA_HOME/gnome-shell/extensions" \
		"$XDG_CONFIG_HOME/glib-2.0/settings" "$XDG_CACHE_HOME" "$XDG_RUNTIME_DIR"
	chmod 700 "$XDG_RUNTIME_DIR"
}

install_payload() {
	cp -r "$REPO/$UUID" "$XDG_DATA_HOME/gnome-shell/extensions/$UUID"
	cp -r "$REPO/tools/harness/$HELPER" "$XDG_DATA_HOME/gnome-shell/extensions/$HELPER"
}

widen_scratch_metadata() {
	[ "$widen_metadata" = yes ] || return 0
	metadata="$XDG_DATA_HOME/gnome-shell/extensions/$UUID/metadata.json"
	running_major=$(gnome-shell --version | sed 's/[^0-9]*\([0-9]*\).*/\1/')
	python3 -I -c '
import json, sys
path, major = sys.argv[1], sys.argv[2]
with open(path) as handle:
    meta = json.load(handle)
if major not in meta["shell-version"]:
    meta["shell-version"].append(major)
with open(path, "w") as handle:
    json.dump(meta, handle, indent=2)
' "$metadata" "$running_major"
}

mutate_scratch_source() {
	[ -n "$mutate_expr" ] || return 0
	sed -i "$mutate_expr" "$XDG_DATA_HOME/gnome-shell/extensions/$UUID/extension.js"
}

enable_extensions() {
	gsettings set org.gnome.shell disable-user-extensions false
	gsettings set org.gnome.shell enabled-extensions "['$HELPER', '$UUID']"
	[ "$(gsettings get org.gnome.shell enabled-extensions)" != '@as []' ] ||
		fail 'gsettings writes are not persisting; the keyfile backend is not in effect'
}

start_shell() {
	WAYLAND_DISPLAY="openbar-verify-$$"
	export WAYLAND_DISPLAY
	gnome-shell --headless --virtual-monitor 1280x720 >"$work/shell.log" 2>&1 &
	shell_pid=$!
	waited=0
	while [ "$waited" -lt 40 ]; do
		if shell_version >/dev/null 2>&1; then return 0; fi
		sleep 1
		waited=$((waited + 1))
	done
	fail 'the test Shell never answered on the session bus'
}

shell_version() {
	gdbus call --session -d org.gnome.Shell -o /org/gnome/Shell \
		-m org.freedesktop.DBus.Properties.Get org.gnome.Shell ShellVersion
}

extension_field() {
	gdbus call --session -d org.gnome.Shell -o /org/gnome/Shell \
		-m org.gnome.Shell.Extensions.GetExtensionInfo "$UUID" |
		tr ',' '\n' | sed -n "s/.*'$1': <\(.*\)>.*/\1/p" | head -1
}

shell_eval() {
	gdbus call --session -d org.gnome.Shell -o /org/gnome/Shell \
		-m org.gnome.Shell.Eval "$1"
}

fail() {
	echo "FAIL: $1" >&2
	[ -n "${shell_pid:-}" ] && kill "$shell_pid" 2>/dev/null
	exit 1
}

report() {
	state=$(extension_field state)
	error=$(extension_field error)
	echo "shell: $(shell_version)"
	echo "state: $state"
	echo "error: $error"
	[ "$state" != '6.0' ] ||
		fail 'state INITIALIZED: the extension was never enabled, nothing was measured'
	[ -n "$eval_js" ] && echo "eval: $(shell_eval "$eval_js")"
	stylesheet="$XDG_RUNTIME_DIR/io.github.neuromorph.openbar/stylesheet.css"
	[ -f "$stylesheet" ] && echo "stylesheet: generated" || echo "stylesheet: absent"
	grep -c 'Openbar: Error loading stylesheet' "$work/shell.log" |
		sed 's/^/stylesheet load errors: /'
	grep -E 'JS ERROR' "$work/shell.log" | head -5 || true
	[ "$state" = '1.0' ]
}

prepare_session_dirs
install_payload
widen_scratch_metadata
mutate_scratch_source
enable_extensions
start_shell
sleep 8
report
status=$?
kill "$shell_pid" 2>/dev/null
exit "$status"
