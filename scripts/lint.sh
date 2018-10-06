#! /usr/bin/env bash

non_camel=$(find . -name "*.tf" -exec grep -l "^[a-z].*-" {} \;)
if [[ ! -z "$non_camel" ]]; then
    echo "Resources should be camel_case and not use hyphens:"
    for f in "$non_camel"; do
        grep -n "^[a-z].*-" $f
    done
    exit 1
fi