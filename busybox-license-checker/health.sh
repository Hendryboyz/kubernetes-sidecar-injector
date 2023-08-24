#!/usr/bin/env bash

log_info() {
  echo -e "\033[32m[info]\033[0m ${1}"
}

log_debug() {
  echo -e "\033[34m[debug]\033[0m ${1}"
}

log_warn() {
  echo -e "\033[33m[warn]\033[0m ${1}" >&2
}

log_error() {
  echo -e "\033[31m[error]\033[0m ${1}" >&2
}

# Assert that the account is set.
if [[ -z "${KEYGEN_ACCOUNT}" ]]
then
  log_error 'env var KEYGEN_ACCOUNT is not set!'

  exit 1
fi

# Assert a license id and key is set or provided.
if [[ -z "${KEYGEN_LICENSE_ID}" ]]
then
  log_warn "env var KEYGEN_LICENSE_ID is not set!"

  exit 1
fi

if [[ -z "${KEYGEN_LICENSE_KEY}" ]]
then
  log_warn "env var KEYGEN_LICENSE_KEY is not set!"

  exit 1
fi

# Assert a license server host is set or provided.
if [[ -z "${KEYGEN_HOST}" ]]
then
  logger_error 'env var KEYGEN_HOST is not set!'

  exit 1
fi

# Detect current OS.
os='linux'

# Fingerprint current machine.
fingerprint=$(cat /sys/class/dmi/id/product_uuid 2>/dev/null)

## Fallback to check testing product_uuid
if [[ -z "${fingerprint}" ]]
then
  fingerprint=$(cat /etc/id/product_uuid 2>/dev/null)
fi

if [[ -z "${fingerprint}" ]]
then
  log_error 'unable to fingerprint machine'

  exit 1
fi

# Hash the fingerprint, to anonymize it.
fingerprint=$(echo -n "$fingerprint" | shasum -a 256 | head -c 64)

# Validate the license, scoped to the current machine's fingerprint.
read -d '\n' code id <<<$( \
  curl -s -X POST "http://${KEYGEN_HOST}/v1/accounts/${KEYGEN_ACCOUNT}/licenses/actions/validate-key" \
    -H 'Content-Type: application/json' \
    -H 'Accept: application/json' \
    -H 'Keygen-Version: 1.2' \
    -d '{
          "meta": {
            "key": "'$KEYGEN_LICENSE_KEY'",
            "scope": { "fingerprint": "'$fingerprint'" }
          }
        }' | jq '.meta.code, .data.id' --raw-output
)

case "${code}"
in
  # When license is already valid, that means the machine has already been activated.
  VALID)
    log_info "license ${id} is already activated!"

    exit 0

    ;;
  # Otherwise, attempt to activate the machine.
  FINGERPRINT_SCOPE_MISMATCH|NO_MACHINES|NO_MACHINE)
    log_debug "license ${id} has not been activated yet!"
    log_debug 'activating...'

    debug=$(mktemp)
    status=$(
      curl -s -X POST "http://${KEYGEN_HOST}/v1/accounts/${KEYGEN_ACCOUNT}/machines" \
        -H "Authorization: License ${KEYGEN_LICENSE_KEY}" \
        -H 'Content-Type: application/json' \
        -H 'Accept: application/json' \
        -H 'Keygen-Version: 1.2' \
        -w '%{http_code}' \
        -o "$debug" \
        -d '{
              "data": {
                "type": "machines",
                "attributes": {
                  "fingerprint": "'$fingerprint'",
                  "platform": "'$os'"
                },
                "relationships": {
                  "license": {
                    "data": { "type": "licenses", "id": "'$KEYGEN_LICENSE_ID'" }
                  }
                }
              }
            }'
    )

    if [[ "$status" -eq 201 ]]
    then
      log_info "license ${id} has been activated!"

      exit 0
    fi

    log_error "license activation failed: ${status}"
    log_debug "$(cat $debug | jq -Mc '.errors[] | [.detail, .code]')"

    exit 1

    ;;
  *)
    log_error "License is invalid: ${code}"

    exit 1

    ;;
esac
