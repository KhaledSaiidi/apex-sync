#!/bin/sh
set -eu

rendered="$(mktemp)"
cleanup() {
    rm -f "$rendered"
}
trap cleanup EXIT

kustomize build . >"$rendered"
envsubst <"$rendered" | awk '
function reset_context() {
    in_app = 0
    in_source = 0
    in_plugin = 0
    in_env = 0
    source_indent = -1
    plugin_indent = -1
    env_indent = -1
}

function indent_of(line, copy) {
    copy = line
    sub(/[^ ].*$/, "", copy)
    return length(copy)
}

function quote_env_value(line, indent, value) {
    indent = line
    sub(/value:[[:space:]]*.*$/, "", indent)
    value = line
    sub(/^[[:space:]]*value:[[:space:]]*/, "", value)
    gsub(/\\/, "\\\\", value)
    gsub(/"/, "\\\"", value)
    return indent "value: \"" value "\""
}

BEGIN {
    reset_context()
}

/^---$/ {
    reset_context()
    print
    next
}

{
    current_indent = indent_of($0)

    if ($0 ~ /^kind:[[:space:]]*Application[[:space:]]*$/) {
        in_app = 1
    }

    if (in_env && current_indent <= env_indent && $0 !~ /^[[:space:]]*-/) {
        in_env = 0
    }
    if (in_plugin && current_indent <= plugin_indent && $0 !~ /^[[:space:]]*-/) {
        in_plugin = 0
        in_env = 0
    }
    if (in_source && current_indent <= source_indent && $0 !~ /^[[:space:]]*-/) {
        in_source = 0
        in_plugin = 0
        in_env = 0
    }

    if (in_app && $0 ~ /^[[:space:]]*source:[[:space:]]*$/) {
        in_source = 1
        source_indent = current_indent
    } else if (in_source && $0 ~ /^[[:space:]]*plugin:[[:space:]]*$/) {
        in_plugin = 1
        plugin_indent = current_indent
    } else if (in_plugin && $0 ~ /^[[:space:]]*env:[[:space:]]*$/) {
        in_env = 1
        env_indent = current_indent
    } else if (in_env && $0 ~ /^[[:space:]]*value:[[:space:]]*/) {
        print quote_env_value($0)
        next
    }

    print
}
'
