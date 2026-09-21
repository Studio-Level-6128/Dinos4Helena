#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
asset_dir="${project_root}/assets/models/environment"
mkdir -p "${asset_dir}"

download() {
  local name="$1"
  local url="$2"
  local target="${asset_dir}/${name}.glb"
  if [[ -s "${target}" ]]; then
    echo "Already downloaded: ${name}.glb"
    return
  fi
  echo "Downloading: ${name}.glb"
  curl --silent --show-error --fail --location --retry 3 --output "${target}.quantized" "${url}"
  npx --yes @gltf-transform/cli@3.10.1 dequantize "${target}.quantized" "${target}.part.glb"
  rm -f "${target}.quantized"
  mv "${target}.part.glb" "${target}"
}

download "araucaria_conifer" "https://cdn.3dassets.dev/assets/1736/v1/model.glb"
download "forest_fern" "https://cdn.3dassets.dev/assets/1740/v1/model.glb"
download "mossy_basalt_rock" "https://cdn.3dassets.dev/assets/1746/v1/model.glb"
download "cycad" "https://cdn.3dassets.dev/assets/38581/v1/model.glb"
download "forest_undergrowth" "https://cdn.3dassets.dev/assets/32689/v1/model.glb"
download "grass_cluster" "https://cdn.3dassets.dev/assets/37716/v1/model.glb"
download "tree_fern" "https://cdn.3dassets.dev/assets/38578/v1/model.glb"
download "dead_tree_snag" "https://cdn.3dassets.dev/assets/1762/v1/model.glb"
download "fallen_rainforest_log" "https://cdn.3dassets.dev/assets/36143/v1/model.glb"
download "horsetail_colony" "https://cdn.3dassets.dev/assets/1739/v1/model.glb"
download "fiddlehead_cluster" "https://cdn.3dassets.dev/assets/1734/v1/model.glb"

echo "Environment model library complete in ${asset_dir}"
