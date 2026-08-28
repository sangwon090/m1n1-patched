#!/bin/sh
set -eu

expected_os_build="25G83"
expected_kdk_build="25G82"
expected_xnu="xnu-12377.161.14~5"
output_path="$HOME/dev-25G83.kc.macho"

actual_os_build="$(sw_vers -buildVersion)"
if [ "$actual_os_build" != "$expected_os_build" ]; then
    echo "오류: 현재 macOS 빌드는 $actual_os_build (예상: $expected_os_build)" >&2
    exit 1
fi

kdk_path=""
for candidate in /Library/Developer/KDKs/*"$expected_kdk_build"*.kdk; do
    if [ -d "$candidate" ]; then
        kdk_path="$candidate"
        break
    fi
done

if [ -z "$kdk_path" ]; then
    echo "오류: $expected_kdk_build KDK가 설치되어 있지 않습니다." >&2
    echo "Apple Developer Downloads에서 KDK 26.6.2 build $expected_kdk_build를 설치한 뒤 다시 실행하세요." >&2
    exit 1
fi

kernel_path="$kdk_path/System/Library/Kernels/kernel.development.t8103"
if [ ! -f "$kernel_path" ]; then
    echo "오류: T8103 development kernel을 찾을 수 없습니다:" >&2
    echo "$kernel_path" >&2
    exit 1
fi

kernel_version="$(strings "$kernel_path" | grep -m 1 'Darwin Kernel Version' || true)"
case "$kernel_version" in
    *"$expected_xnu"*) ;;
    *)
        echo "오류: KDK XNU 버전이 예상과 다릅니다." >&2
        echo "확인된 값: $kernel_version" >&2
        exit 1
        ;;
esac

echo "macOS: $actual_os_build"
echo "KDK:   $kdk_path"
echo "XNU:   $kernel_version"
echo "출력:  $output_path"
echo
echo "development kernelcache 생성 중..."

bundle_args="$(
    kmutil inspect -V release --no-header |
        awk '$1 !~ /SEPHiber/ { printf " -b %s", $1 }'
)"

# bundle_args is intentionally split into individual kmutil arguments.
# shellcheck disable=SC2086
kmutil create -zn boot -a arm64e \
    -B "$output_path" \
    -V development \
    -k "$kernel_path" \
    -r /System/Library/Extensions \
    -r /System/Library/DriverExtensions \
    -x $bundle_args

if [ ! -s "$output_path" ]; then
    echo "오류: kernelcache 출력 파일이 생성되지 않았습니다." >&2
    exit 1
fi

echo
echo "완료"
file "$output_path"
ls -lh "$output_path"
shasum -a 256 "$output_path"
echo
echo "다음 단계에서 이 파일을 Linux 호스트로 복사합니다:"
echo "$output_path"
