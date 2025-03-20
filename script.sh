#!/usr/bin/env bash

set -Eeuo pipefail

# Enable debugging if GitHub Actions debugging is enabled
if [[ "${ACTIONS_STEP_DEBUG:-false}" == "true" ]]; then set -x; fi

# Ensure required environment variables exist
if [[ -z "${GITHUB_WORKSPACE:-}" ]]; then
    echo "Error: GITHUB_WORKSPACE is not set."
    exit 1
fi

if [[ -z "${INPUT_GITHUB_TOKEN:-}" ]]; then
    echo "Warning: INPUT_GITHUB_TOKEN is not set. API calls may fail."
fi

# Ensure required binaries exist
command -v curl >/dev/null || { echo "curl is required"; exit 1; }
command -v unzip >/dev/null || { echo "unzip is required"; exit 1; }

cd "${GITHUB_WORKSPACE}/${INPUT_WORKING_DIRECTORY}" || exit

echo '::group::Preparing'
  unameOS="$(uname -s)"
  case "${unameOS}" in
    Linux*)     os=linux;;
    Darwin*)    os=darwin;;
    CYGWIN*|MINGW*|MSYS*) os=windows;;
    *)          echo "Unknown system: ${unameOS}" && exit 1
  esac

  unameArch="$(uname -m)"
  case "${unameArch}" in
    x86_64)    arch=amd64;;
    x86*)      arch=amd64;;
    aarch64*|arm64*)  arch=arm64;;
    *)         echo "Unsupported architecture: ${unameArch}" && exit 1
  esac

  TEMP_PATH="$(mktemp -d -t tflint.XXXXXX)"
  trap 'rm -rf "${TEMP_PATH}"' EXIT
  echo "Detected ${os} running on ${arch}, will install tools in ${TEMP_PATH}"
  TFLINT_PATH="${TEMP_PATH}/tflint"

  TFLINT_VERSION="${INPUT_TFLINT_VERSION:-latest}"
  if [[ "${TFLINT_VERSION}" == "latest" ]]; then
    echo "Looking up the latest tflint version ..."
    TFLINT_VERSION=$(curl -H "Authorization: Bearer ${INPUT_GITHUB_TOKEN}" --silent --show-error --fail --location \
    "https://api.github.com/repos/terraform-linters/tflint/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/') || {
      echo "Failed to fetch latest tflint version"; exit 1;
    }
  fi

  if [[ -z "${TFLINT_PLUGIN_DIR:-}" ]]; then
    export TFLINT_PLUGIN_DIR="${TFLINT_PATH}/.tflint.d/plugins"
    mkdir -p "${TFLINT_PLUGIN_DIR}"
  else
    echo "Found pre-configured TFLINT_PLUGIN_DIR=${TFLINT_PLUGIN_DIR}"
  fi
echo '::endgroup::'

echo "::group:: Installing tflint (${TFLINT_VERSION}) ..."
  curl --silent --show-error --fail --location \
    "https://github.com/terraform-linters/tflint/releases/download/${TFLINT_VERSION}/tflint_${os}_${arch}.zip" \
    --output "${TEMP_PATH}/tflint.zip" || { echo "Failed to download tflint"; exit 1; }

  unzip -u "${TEMP_PATH}/tflint.zip" -d "${TEMP_PATH}/temp-tflint"
  install -d "${TFLINT_PATH}"
  install "${TEMP_PATH}/temp-tflint/tflint" "${TFLINT_PATH}"
  rm -rf "${TEMP_PATH}/tflint.zip" "${TEMP_PATH}/temp-tflint"
echo '::endgroup::'

for RULESET in ${INPUT_TFLINT_RULESETS}; do
  PLUGIN="tflint-ruleset-${RULESET}"
  REPOSITORY="https://github.com/terraform-linters/${PLUGIN}"

  echo "::group:: Installing tflint plugin for ${RULESET} (latest) ..."
    curl --silent --show-error --fail \
      --location "${REPOSITORY}"/releases/latest/download/"${PLUGIN}"_"${os}"_"${arch}".zip \
      --output "${PLUGIN}.zip" || { echo "Failed to download plugin: ${PLUGIN}"; exit 1; }

    unzip "${PLUGIN}.zip" -d "${TFLINT_PLUGIN_DIR}" && rm "${PLUGIN}.zip"
  echo '::endgroup::'
done

if [[ "${INPUT_TFLINT_INIT:-false}" == "true" ]]; then
  echo "::group:: Initialize tflint from local configuration"
  TFLINT_PLUGIN_DIR="${TFLINT_PLUGIN_DIR}" GITHUB_TOKEN="${INPUT_GITHUB_TOKEN}" "${TFLINT_PATH}/tflint" --init -c "${INPUT_TFLINT_CONFIG}"
  echo "::endgroup::"
fi

echo "::group:: Print tflint details ..."
  "${TFLINT_PATH}/tflint" --version -c "${INPUT_TFLINT_CONFIG}"
echo '::endgroup::'

echo "::group:: Running TFLint..."

if [[ ! -d "${INPUT_TFLINT_TARGET_DIR}" ]]; then
  echo "Error: Target directory '${INPUT_TFLINT_TARGET_DIR}' does not exist!"
  exit 1
fi

# Configure chdir flag only if needed
CHDIR_COMMAND=""
if [[ "${INPUT_TFLINT_TARGET_DIR}" == "." ]]; then
  echo "Using default working directory. No need to specify chdir"
else
  echo "Custom target directory specified: ${INPUT_TFLINT_TARGET_DIR}"
  CHDIR_COMMAND="--chdir=${INPUT_TFLINT_TARGET_DIR}"
fi

# Check if TFLint configuration exists, warn if missing
if [[ ! -f "${INPUT_TFLINT_CONFIG}" ]]; then
  echo "Warning: TFLint config '${INPUT_TFLINT_CONFIG}' not found. Running without a config."
fi

# Run TFLint with proper directory handling
TFLINT_PLUGIN_DIR=${TFLINT_PLUGIN_DIR} "${TFLINT_PATH}/tflint" -c "${INPUT_TFLINT_CONFIG}" \
  --format=sarif ${INPUT_FLAGS} ${CHDIR_COMMAND} > "${GITHUB_WORKSPACE}/tflint.sarif" 2>&1

# Capture exit status
tflint_return="${PIPESTATUS[0]}" exit_code=$?
echo "tflint-return-code=${tflint_return}" >> "$GITHUB_ENV"

echo "::endgroup::"
exit "${exit_code}"
