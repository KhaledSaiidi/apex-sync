#!/bin/sh
set -eu

rendered="$(mktemp)"
cleanup() {
    rm -f "$rendered"
}
trap cleanup EXIT

kustomize build . >"$rendered"
envsubst <"$rendered"

