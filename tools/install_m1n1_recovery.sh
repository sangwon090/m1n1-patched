#!/bin/sh
set -eu

TARGET_NAME="macOSDebug"
TARGET_VOLUME="/Volumes/${TARGET_NAME}"
TARGET_VGID="DF3A27F6-981B-4B59-99FE-0799EB560D59"
EXPECTED_SHA256="15ad3604ff387d7136fda9667127c7d738354b93fb6e59d5ff77f3514c6ce6e2"

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
M1N1_BIN="${SCRIPT_DIR}/m1n1.bin"

if [ ! -d "${TARGET_VOLUME}" ]; then
    echo "ERROR: ${TARGET_VOLUME} is not mounted. Mount/unlock it in Disk Utility first."
    exit 1
fi

ACTUAL_VGID=$(diskutil info "${TARGET_VOLUME}" |
    awk -F: '/APFS Volume Group/ {gsub(/[[:space:]]/, "", $2); print toupper($2); exit}')

if [ "${ACTUAL_VGID}" != "${TARGET_VGID}" ]; then
    echo "ERROR: target volume-group UUID mismatch."
    echo "Expected: ${TARGET_VGID}"
    echo "Actual:   ${ACTUAL_VGID:-unknown}"
    exit 1
fi

if [ ! -f "${M1N1_BIN}" ]; then
    echo "ERROR: ${M1N1_BIN} not found."
    exit 1
fi

ACTUAL_SHA256=$(shasum -a 256 "${M1N1_BIN}" | awk '{print $1}')
if [ "${ACTUAL_SHA256}" != "${EXPECTED_SHA256}" ]; then
    echo "ERROR: m1n1.bin checksum mismatch."
    exit 1
fi

echo "Target: ${TARGET_NAME} (${TARGET_VGID})"
echo "This changes only this volume group's boot policy and boot object."
printf "Type INSTALL to continue: "
read -r CONFIRM
[ "${CONFIRM}" = "INSTALL" ] || exit 1

bputil -nkcas -v "${TARGET_VGID}"
csrutil disable
nvram boot-args=-v
kmutil configure-boot \
    -c "${M1N1_BIN}" \
    --raw \
    --entry-point 2048 \
    --lowest-virtual-address 0 \
    -v "${TARGET_VOLUME}"

echo "m1n1 installed for ${TARGET_NAME}. Shut down; do not boot the main macOS volume."
