#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export XDG_DATA_HOME="${PROJECT_ROOT}/.local/share"
export XDG_CONFIG_HOME="${PROJECT_ROOT}/.local/config"
export XDG_CACHE_HOME="${PROJECT_ROOT}/.cache"
export JAVA_HOME="${PROJECT_ROOT}/.tools/jdk-17"
export ANDROID_HOME="${PROJECT_ROOT}/.tools/android-sdk"
export PATH="${JAVA_HOME}/bin:${ANDROID_HOME}/platform-tools:${ANDROID_HOME}/cmdline-tools/latest/bin:${PATH}"

GODOT="${PROJECT_ROOT}/.tools/godot/godot"
if [[ ! -x "${GODOT}" ]]; then
	echo "Godot is not installed. Run: ./scripts/setup-dev.sh" >&2
	exit 1
fi

exec "${GODOT}" "$@"

