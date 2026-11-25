#!/bin/bash
set -euo pipefail

VENDOR_DIR="${SRCROOT}/Vendor/m1ddc"
DEST_DIR="${BUILT_PRODUCTS_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"
BINARY="${DEST_DIR}/m1ddc"

cd "${VENDOR_DIR}"
/usr/bin/make

mkdir -p "${DEST_DIR}"
/usr/bin/install -m 755 "${VENDOR_DIR}/m1ddc" "${BINARY}"
/usr/bin/install -m 644 "${VENDOR_DIR}/LICENSE" "${DEST_DIR}/m1ddc-LICENSE.txt"

if [[ -n "${EXPANDED_CODE_SIGN_IDENTITY:-}" && "${EXPANDED_CODE_SIGN_IDENTITY}" != "-" ]]; then
  /usr/bin/codesign --force --sign "${EXPANDED_CODE_SIGN_IDENTITY}" --timestamp=none "${BINARY}"
fi
