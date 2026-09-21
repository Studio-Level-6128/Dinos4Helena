#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLS_DIR="${PROJECT_ROOT}/.tools"
DOWNLOAD_DIR="${TOOLS_DIR}/downloads"
GODOT_VERSION="4.7.2"
GODOT_RELEASE="${GODOT_VERSION}-stable"
ANDROID_TOOLS_VERSION="15859902"

for command_name in curl unzip tar; do
	if ! command -v "${command_name}" >/dev/null; then
		echo "Missing required command: ${command_name}" >&2
		exit 1
	fi
done

mkdir -p "${DOWNLOAD_DIR}" "${TOOLS_DIR}/godot" "${PROJECT_ROOT}/.local/share/godot/export_templates"

download() {
	local url="$1"
	local destination="$2"
	if [[ ! -f "${destination}" ]]; then
		echo "Downloading $(basename "${destination}")..."
		curl --fail --location --retry 3 --output "${destination}" "${url}"
	fi
}

if [[ ! -x "${TOOLS_DIR}/godot/godot" ]]; then
	archive="${DOWNLOAD_DIR}/Godot_v${GODOT_RELEASE}_linux.x86_64.zip"
	download "https://github.com/godotengine/godot/releases/download/${GODOT_RELEASE}/Godot_v${GODOT_RELEASE}_linux.x86_64.zip" "${archive}"
	unzip -q -o "${archive}" -d "${TOOLS_DIR}/godot"
	mv "${TOOLS_DIR}/godot/Godot_v${GODOT_RELEASE}_linux.x86_64" "${TOOLS_DIR}/godot/godot"
	chmod +x "${TOOLS_DIR}/godot/godot"
fi

template_dir="${PROJECT_ROOT}/.local/share/godot/export_templates/${GODOT_VERSION}.stable"
if [[ ! -f "${template_dir}/android_debug.apk" ]]; then
	archive="${DOWNLOAD_DIR}/Godot_v${GODOT_RELEASE}_export_templates.tpz"
	download "https://github.com/godotengine/godot/releases/download/${GODOT_RELEASE}/Godot_v${GODOT_RELEASE}_export_templates.tpz" "${archive}"
	tmp_templates="$(mktemp -d)"
	unzip -q "${archive}" -d "${tmp_templates}"
	mkdir -p "${template_dir}"
	cp -a "${tmp_templates}/templates/." "${template_dir}/"
	rm -r "${tmp_templates}"
fi

if [[ ! -x "${TOOLS_DIR}/jdk-17/bin/java" ]]; then
	archive="${DOWNLOAD_DIR}/temurin-jdk-17.tar.gz"
	download "https://api.adoptium.net/v3/binary/latest/17/ga/linux/x64/jdk/hotspot/normal/eclipse" "${archive}"
	mkdir -p "${TOOLS_DIR}/jdk-17"
	tar -xzf "${archive}" --strip-components=1 -C "${TOOLS_DIR}/jdk-17"
fi

sdk_root="${TOOLS_DIR}/android-sdk"
if [[ ! -x "${sdk_root}/cmdline-tools/latest/bin/sdkmanager" ]]; then
	archive="${DOWNLOAD_DIR}/commandlinetools-linux-${ANDROID_TOOLS_VERSION}_latest.zip"
	download "https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_TOOLS_VERSION}_latest.zip" "${archive}"
	tmp_sdk="$(mktemp -d)"
	unzip -q "${archive}" -d "${tmp_sdk}"
	mkdir -p "${sdk_root}/cmdline-tools"
	mv "${tmp_sdk}/cmdline-tools" "${sdk_root}/cmdline-tools/latest"
	rm -r "${tmp_sdk}"
fi

export JAVA_HOME="${TOOLS_DIR}/jdk-17"
export ANDROID_HOME="${sdk_root}"
export PATH="${JAVA_HOME}/bin:${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/platform-tools:${PATH}"

echo "Accepting Android SDK licenses..."
yes | sdkmanager --sdk_root="${sdk_root}" --licenses >/dev/null || true

echo "Installing Android SDK components required by Godot ${GODOT_VERSION}..."
sdkmanager --sdk_root="${sdk_root}" \
	"platform-tools" \
	"build-tools;36.1.0" \
	"platforms;android-36" \
	"ndk;29.0.14206865" \
	"cmake;3.22.1"

mkdir -p "${PROJECT_ROOT}/.local/config/godot" "${PROJECT_ROOT}/.cache"
"${PROJECT_ROOT}/scripts/godot.sh" --headless --editor --path "${PROJECT_ROOT}" --script "res://scripts/configure_editor.gd"
"${PROJECT_ROOT}/scripts/godot.sh" --headless --editor --path "${PROJECT_ROOT}" --quit

echo
echo "Development environment ready."
echo "Open the editor: ./scripts/godot.sh --editor --path ."
echo "Run the game:   ./scripts/godot.sh --path ."
echo "Build Android:  ./scripts/build-android.sh"

