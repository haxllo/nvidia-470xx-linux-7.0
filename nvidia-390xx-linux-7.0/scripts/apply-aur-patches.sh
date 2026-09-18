#!/usr/bin/env bash

set -euo pipefail

readonly AUR_REPOSITORY='https://aur.archlinux.org/nvidia-390xx-utils.git'
readonly AUR_REFERENCE='e0f6ac587b2e2d40af7929c57a1f827082872585'

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repository_dir=$(cd -- "$script_dir/.." && pwd)
readonly checksum_file="$repository_dir/patches/aur-390.157-linux-7.0.sha256"
readonly patch_order_file="$repository_dir/patches/aur-390.157-linux-7.0.order"

source_dir=$PWD
patch_dir=''
dry_run=false
temporary_dir=''

usage() {
    cat <<'EOF'
Apply the verified Linux 7.0 patch series to an extracted NVIDIA 390.157 tree.

Usage:
  scripts/apply-aur-patches.sh [--source DIRECTORY] [--dry-run]
                               [--patch-dir DIRECTORY]

Options:
  --source DIRECTORY   Extracted NVIDIA-Linux-x86_64-390.157 directory.
                       Defaults to the current directory.
  --dry-run            Apply patches to a temporary copy without changing source.
  --patch-dir DIRECTORY
                       Use an existing nvidia-390xx-utils checkout instead of
                       downloading it. Intended for auditing and development.
  -h, --help           Show this help text.
EOF
}

fail() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

cleanup() {
    if [[ -n "$temporary_dir" ]]; then
        rm -rf -- "$temporary_dir"
    fi
}

while (($#)); do
    case $1 in
        --source)
            (($# >= 2)) || fail '--source requires a directory'
            source_dir=$2
            shift 2
            ;;
        --patch-dir)
            (($# >= 2)) || fail '--patch-dir requires a directory'
            patch_dir=$2
            shift 2
            ;;
        --dry-run)
            dry_run=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            fail "unknown option: $1"
            ;;
    esac
done

for command in patch sha256sum mktemp cp; do
    command -v "$command" >/dev/null 2>&1 || fail "required command not found: $command"
done

[[ -f "$checksum_file" ]] || fail "missing checksum manifest: $checksum_file"
[[ -f "$patch_order_file" ]] || fail "missing patch order: $patch_order_file"
[[ -f "$source_dir/kernel/conftest.sh" ]] || fail \
    "expected an extracted NVIDIA 390.157 tree containing kernel/conftest.sh: $source_dir"

temporary_dir=$(mktemp -d "${TMPDIR:-/tmp}/nvidia-390xx-linux-7.0.XXXXXX")
trap cleanup EXIT

if [[ -z "$patch_dir" ]]; then
    command -v git >/dev/null 2>&1 || fail 'required command not found: git'
    patch_dir="$temporary_dir/nvidia-390xx-utils"
    printf 'Downloading AUR patch source (%s)…\n' "$AUR_REFERENCE"
    git clone --quiet "$AUR_REPOSITORY" "$patch_dir"
    git -C "$patch_dir" checkout --quiet --detach "$AUR_REFERENCE"
fi

[[ -d "$patch_dir" ]] || fail "patch directory does not exist: $patch_dir"

printf 'Verifying patch checksums…\n'
(
    cd -- "$patch_dir"
    sha256sum --check --strict "$checksum_file"
)

target_dir=$source_dir
if "$dry_run"; then
    target_dir="$temporary_dir/source"
    mkdir -p -- "$target_dir"
    cp -a -- "$source_dir/." "$target_dir"
    printf 'Dry run: applying patches to a temporary copy…\n'
fi

while IFS= read -r patch_name; do
    [[ -n "$patch_name" ]] || continue
    [[ -f "$patch_dir/$patch_name" ]] || fail "missing verified patch: $patch_name"
    printf 'Applying %s…\n' "$patch_name"
    patch --directory="$target_dir" --batch --forward --strip=1 \
        --input="$patch_dir/$patch_name"
done < "$patch_order_file"

if "$dry_run"; then
    printf 'Success: all patches apply cleanly to the temporary copy.\n'
else
    printf 'Success: patched NVIDIA source tree: %s\n' "$source_dir"
fi
