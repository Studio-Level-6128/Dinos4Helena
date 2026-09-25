#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "${PROJECT_ROOT}/build/android"
"${PROJECT_ROOT}/scripts/godot.sh" --headless --path "${PROJECT_ROOT}" --export-debug "Android Release" "${PROJECT_ROOT}/build/android/Dinos4Helena-debug.apk"

