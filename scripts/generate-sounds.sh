#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
env_file="${project_root}/.env"
output_root="${project_root}/assets/audio"
api_url="https://api.elevenlabs.io/v1/sound-generation?output_format=mp3_44100_128"

if [[ ! -f "${env_file}" ]]; then
  echo "Missing ${env_file}. Copy .env.example to .env and add ELEVENLABS_API_KEY." >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "${env_file}"
set +a

if [[ -z "${ELEVENLABS_API_KEY:-}" ]]; then
  echo "ELEVENLABS_API_KEY is missing from .env." >&2
  exit 1
fi

mkdir -p "${output_root}/dinosaurs" "${output_root}/ambient"

generate_effect() {
  local relative_path="$1"
  local duration="$2"
  local loop="$3"
  local prompt="$4"
  local target="${output_root}/${relative_path}.mp3"
  local temporary="${target}.part"
  local headers="${target}.headers"

  if [[ -s "${target}" ]]; then
    echo "Already generated: ${relative_path}.mp3"
    return
  fi

  mkdir -p "$(dirname "${target}")"
  echo "Generating: ${relative_path}.mp3"
  local json
  json="$(printf '{\"text\":\"%s\",\"duration_seconds\":%s,\"prompt_influence\":0.55,\"loop\":%s,\"model_id\":\"eleven_text_to_sound_v2\"}' "${prompt}" "${duration}" "${loop}")"

  if ! curl --silent --show-error --fail-with-body \
    --retry 4 --retry-delay 3 --retry-all-errors \
    --dump-header "${headers}" \
    --request POST "${api_url}" \
    --header "xi-api-key: ${ELEVENLABS_API_KEY}" \
    --header "Content-Type: application/json" \
    --data "${json}" \
    --output "${temporary}"; then
    echo "ElevenLabs request failed for ${relative_path}." >&2
    [[ -f "${temporary}" ]] && sed -n '1,8p' "${temporary}" >&2
    return 1
  fi

  if ! grep -Eiq '^content-type: audio/(mpeg|mp3)' "${headers}" || [[ ! -s "${temporary}" ]]; then
    echo "Unexpected response for ${relative_path}; refusing to store it as audio." >&2
    sed -n '1,12p' "${headers}" >&2
    return 1
  fi

  mv "${temporary}" "${target}"
  rm -f "${headers}"
}

generate_dinosaur() {
  local id="$1"
  local species="$2"
  local body="$3"
  local voice="$4"
  local movement="$5"

  generate_effect "dinosaurs/${id}/scream" 2.2 false \
    "Plausible cinematic ${species} territorial call: ${voice}, powerful animal vocalization, close perspective, no music, no human voice, clean game sound effect"
  generate_effect "dinosaurs/${id}/walk" 1.5 false \
    "${species} walking on damp prehistoric forest soil, ${movement}, leaves and earth underfoot, two clear steps, isolated realistic game foley, no music"
  generate_effect "dinosaurs/${id}/run" 1.3 false \
    "${species} running over damp prehistoric forest soil, faster ${movement}, several urgent footfalls, isolated realistic game foley, no music"
  generate_effect "dinosaurs/${id}/jump" 1.0 false \
    "${species} ${body} body jumping from forest soil, forceful takeoff thump and air movement, isolated realistic game sound, no vocal, no music"
  generate_effect "dinosaurs/${id}/duck" 0.9 false \
    "${species} ${body} body quickly crouching into dense ferns, hide and foliage rustle, subtle weight shift, isolated realistic game foley, no music"
  generate_effect "dinosaurs/${id}/attack" 1.2 false \
    "${species} making a sudden close-range attack, aggressive ${voice}, fast body movement and impact whoosh, cinematic realistic game effect, no music"
  generate_effect "dinosaurs/${id}/hurt" 1.0 false \
    "${species} short pain reaction after being struck, wounded ${voice}, single believable animal cry, clean isolated game effect, no music"
}

generate_dinosaur "trex" "Tyrannosaurus rex" "enormous muscular biped" "very deep chesty roar and guttural growl" "massive ground-shaking two-legged footfalls"
generate_dinosaur "triceratops" "Triceratops" "heavy horned quadruped" "deep cattle-like bellow, forceful snort and low rumble" "heavy four-legged stomps"
generate_dinosaur "stegosaurus" "Stegosaurus" "armored quadruped with a heavy tail" "low resonant bellow and breathy rumble" "slow weighty four-legged stomps"
generate_dinosaur "velociraptor" "Velociraptor" "light agile feathered biped" "sharp birdlike screech, hiss and clicking growl" "quick light clawed two-legged steps"
generate_dinosaur "parasaurolophus" "Parasaurolophus" "large crested herbivore" "rich resonant horn-like call through its long crest" "firm rhythmic two-legged footfalls"
generate_dinosaur "apatosaurus" "Apatosaurus" "colossal long-necked quadruped" "immense low-frequency bellow and infrasonic rumble" "extremely deep slow earth-shaking four-legged stomps"

generate_effect "ambient/prehistoric_jungle" 24.0 true \
  "Seamless prehistoric jungle ambience loop at daytime, humid forest, gentle wind through giant ferns, insects, distant primitive birds, sparse faraway dinosaur calls, natural and calm, no footsteps, no music, no humans"
generate_effect "ambient/distant_dinosaurs" 20.0 true \
  "Seamless subtle distant dinosaur valley ambience loop, occasional very far herbivore bellows and faint low rumbles across a vast landscape, airy natural reverb, no close animal, no music, no humans"

echo "Sound library complete in ${output_root}"
