#!/usr/bin/env bash

find . -name '*.gyb' |                                                                   \
    while read file; do                                                                  \
        ./utils/gyb.py                                                                   \
            -Dtemplate_header="$(< utils/template_header.txt)"                           \
            --line-directive ''                                                          \
            -o "`dirname ${file%.gyb}`/GENERATED-`basename ${file%.gyb}`"                \
            "$file";                                                                     \
    done