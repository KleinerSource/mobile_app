#!/bin/sh

set -e
set -u

SRC_DIR="$1"
SYMLINKS_DIR="$2"

relpath() {
    [ $# -ge 1 ] && [ $# -le 2 ] || return 1
    current="${2:+"$1"}"
    target="${2:-"$1"}"
    [ "$target" != . ] || target=/
    target="/${target##/}"
    [ "$current" != . ] || current=/
    current="${current:="/"}"
    current="/${current##/}"
    appendix="${target##/}"
    relative=''
    while appendix="${target#"$current"/}"
        [ "$current" != '/' ] && [ "$appendix" = "$target" ]; do
        if [ "$current" = "$appendix" ]; then
            relative="${relative:-.}"
            echo "${relative#/}"
            return 0
        fi
        current="${current%/*}"
        relative="$relative${relative:+/}.."
    done
    relative="$relative${relative:+${appendix:+/}}${appendix#/}"
    echo "$relative"
}

create_framework_symlinks() {
    SRC_DIR="$1"
    SYMLINKS_DIR="$2"
    find "${SRC_DIR}" -mindepth 1 -maxdepth 1 -type d | while read SRC; do
        SLUG="$(basename "${SRC}")"
        NAME="$(echo "${SLUG}" | cut -d '-' -f 1 -f 3)"
        SRC_RELATIVE="$(relpath "${SYMLINKS_DIR}" "${SRC}")"
        ln -s "${SRC_RELATIVE}" "${SYMLINKS_DIR}/${NAME}"
    done
}

create_framework_symlinks "${SRC_DIR}" "${SYMLINKS_DIR}"
