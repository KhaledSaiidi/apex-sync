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

subst_vars="$(env | awk -F= '$1 ~ /^ARGOCD_ENV_/ { printf "${%s} ", $1 }')"

find . -type f \( -name '*.yaml' -o -name '*.yml' \) | while IFS= read -r file; do
    tmp="$file.tmp"
    envsubst "$subst_vars" <"$file" >"$tmp"
    mv "$tmp" "$file"
done

kustomize build --enable-helm .
