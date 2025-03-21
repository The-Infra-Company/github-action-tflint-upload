#!/bin/bash

# Fail fast on errors, unset variables, and failures in piped commands
set -Eeuo pipefail

# If DEBUG_MODE is set to true, print all executed commands
if [ "${DEBUG_MODE:-false}" == "true" ]; then
  set -x
fi

cd "${GITHUB_WORKSPACE}/${INPUT_WORKING_DIRECTORY}" || exit

echo '::group::Preparing'
  unameOS="$(uname -s)"
  case "${unameOS}" in
    Linux*)     os=linux;;
    Darwin*)    os=darwin;;
    CYGWIN*)    os=windows;;
    MINGW*)     os=windows;;
    MSYS_NT*)   os=windows;;
    *)          echo "Unknown system: ${unameOS}" && exit 1
  esac

  unameArch="$(uname -m)"
  case "${unameArch}" in
    x86*)      arch=amd64;;
    aarch64*)  arch=arm64;;
    arm64*)    arch=arm64;;
    *)         echo "Unsupported architecture: ${unameArch}" && exit 1
  esac

  TEMP_PATH="$(mktemp -d)"
  echo "Detected ${os} running on ${arch}, will install tools in ${TEMP_PATH}"
  TFLINT_PATH="${TEMP_PATH}/tflint"

  if [[ -z "${INPUT_TFLINT_VERSION}" ]] || [[ "${INPUT_TFLINT_VERSION}" == "latest" ]]; then
    echo "Looking up the latest tflint version ..."
    tflint_version=$(curl -H "Authorization: Bearer ${INPUT_GITHUB_TOKEN}" --silent --show-error --fail --location "https://api.github.com/repos/terraform-linters/tflint/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
  else
    tflint_version=${INPUT_TFLINT_VERSION}
  fi

  if [[ -z "${TFLINT_PLUGIN_DIR:-}" ]]; then
    export TFLINT_PLUGIN_DIR="${TFLINT_PATH}/.tflint.d/plugins"
    mkdir -p "${TFLINT_PLUGIN_DIR}"
  else
    echo "Found pre-configured TFLINT_PLUGIN_DIR=${TFLINT_PLUGIN_DIR}"
  fi
echo '::endgroup::'

echo "::group:: Installing tflint (${tflint_version}) ... https://github.com/terraform-linters/tflint"
  curl --silent --show-error --fail \
    --location "https://github.com/terraform-linters/tflint/releases/download/${tflint_version}/tflint_${os}_${arch}.zip" \
    --output "${TEMP_PATH}/tflint.zip"

  unzip -u "${TEMP_PATH}/tflint.zip" -d "${TEMP_PATH}/temp-tflint"
  test ! -d "${TFLINT_PATH}" && install -d "${TFLINT_PATH}"
  install "${TEMP_PATH}/temp-tflint/tflint" "${TFLINT_PATH}"
  rm -rf "${TEMP_PATH}/tflint.zip" "${TEMP_PATH}/temp-tflint"
echo '::endgroup::'

for RULESET in ${INPUT_TFLINT_RULESETS}; do
  PLUGIN="tflint-ruleset-${RULESET}"
  REPOSITORY="https://github.com/terraform-linters/${PLUGIN}"

  echo "::group:: Installing tflint plugin for ${RULESET} (latest) ... ${REPOSITORY}"
    curl --silent --show-error --fail \
      --location "${REPOSITORY}"/releases/latest/download/"${PLUGIN}"_"${os}"_"${arch}".zip \
      --output "${PLUGIN}".zip \
    && unzip "${PLUGIN}".zip -d "${TFLINT_PLUGIN_DIR}" && rm "${PLUGIN}".zip
  echo '::endgroup::'
done

case "${INPUT_TFLINT_INIT:-false}" in
    true)
        echo "::group:: Initialize tflint from local configuration"
        TFLINT_PLUGIN_DIR="${TFLINT_PLUGIN_DIR}" GITHUB_TOKEN="${INPUT_GITHUB_TOKEN}" "${TFLINT_PATH}/tflint" --init -c "${INPUT_TFLINT_CONFIG}"
        echo "::endgroup::"
        ;;
    false)
        true # do nothing
        ;;
    *)
        echo "::group:: Initialize tflint from local configuration"
        echo "Unknown option provided for tflint_init: ${INPUT_TFLINT_INIT}. Value must be one of ['true', 'false']."
        echo "::endgroup::"
        ;;
esac

echo "::group:: Print tflint details ..."
  "${TFLINT_PATH}/tflint" --version -c "${INPUT_TFLINT_CONFIG}"
echo '::endgroup::'

echo '::group:: Running tflint ...'
  set +Eeuo pipefail

  SARIF_FILE="${GITHUB_WORKSPACE}/tflint-results.sarif"
  touch "$SARIF_FILE"

  TFLINT_PLUGIN_DIR=${TFLINT_PLUGIN_DIR} "${TFLINT_PATH}/tflint" -c "${INPUT_TFLINT_CONFIG}" --format=sarif ${INPUT_FLAGS} ${CHDIR_COMMAND} | tee "$SARIF_FILE"

  # Validate SARIF file format
  if ! jq empty "$SARIF_FILE" 2>/dev/null; then
    echo "TFLint SARIF file is invalid. Exiting."
    exit 1
  fi

  # Check if SARIF file has results (non-empty "runs" key)
  if ! jq -e '.runs | length > 0' "$SARIF_FILE" >/dev/null; then
    echo "No TFLint issues found. Generating an empty SARIF file."
    echo '{"version": "2.1.0", "runs": []}' | tee "$SARIF_FILE"
  fi

  echo "TFLint SARIF report is ready."
  exit_code=0
  echo "tflint-return-code=${exit_code}" >> "${GITHUB_OUTPUT}"
echo '::endgroup::'

exit "${exit_code}"
