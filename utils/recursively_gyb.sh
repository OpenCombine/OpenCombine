#!/usr/bin/env bash

# https://stackoverflow.com/a/4774063
SCRIPT_DIR="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

find . -name '*.gyb' |                                                                   \
    while read file; do                                                                  \
        $SCRIPT_DIR/gyb.py                                                               \
            -Dtemplate_header="$(< $SCRIPT_DIR/template_header.txt)"                     \
            --line-directive ''                                                          \
            -o "`dirname ${file%.gyb}`/GENERATED-`basename ${file%.gyb}`"                \
            "$file";                                                                     \
    done