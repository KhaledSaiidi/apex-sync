#!/bin/sh
set -eu

workdir="$(mktemp -d)"
cleanup() {
    rm -rf "$workdir"
}
trap cleanup EXIT

src="$workdir/src"
mkdir -p "$src"
cp -R ./. "$src"
cd "$src"

find . -type f \( -name '*.yaml' -o -name '*.yml' \) | while IFS= read -r file; do
    tmp="$file.tmp"
    envsubst <"$file" >"$tmp"
    mv "$tmp" "$file"
done

kustomize build --enable-helm .
