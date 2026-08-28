#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
files_dir=${M1N1_FILES_DIR:-/home/sangwon/m1n1-files}
device=${M1N1DEVICE:-/dev/ttyACM0}
usb_busid=${M1N1_USB_BUSID:-2-9}

if [[ ! -e "$device" ]]; then
    usbipd.exe attach --wsl --busid "$usb_busid"
    for _ in {1..20}; do
        [[ -e "$device" ]] && break
        sleep 0.5
    done
fi

if [[ ! -r "$device" || ! -w "$device" ]]; then
    sudo chmod 666 "$device"
    if [[ -e /dev/ttyACM1 ]]; then
        sudo chmod 666 /dev/ttyACM1
    fi
fi

[[ -e "$device" ]] || {
    echo "m1n1 proxy device not found: $device" >&2
    exit 1
}

exec env M1N1DEVICE="$device" python3 \
    "$repo_dir/proxyclient/tools/run_guest.py" \
    -d \
    -s "$files_dir/kernel.development.t8103" \
    -l "$files_dir/25G83-hv.log" \
    --strip-node usb-drd \
    --strip-node dart-usb1 \
    --strip-node apciec1 \
    --strip-node acio1 \
    --strip-node acio-cpu1 \
    "$files_dir/dev-25G83.kc.macho.development" -- \
    "debug=0x14e serial=3 -enable-kprintf-spam wdt=-1 clpc=0"
