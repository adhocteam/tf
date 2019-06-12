#! /usr/bin/env bash

non_camel=$(find . -name "*.tf" -exec grep -El "^(resource|data|output|variable|module).*-" {} \;)
if [[ ! -z "$non_camel" ]]; then
    echo "Resources should be camel_case and not use hyphens:"
    for f in "$non_camel"; do
      echo "$f"
      grep -En '^(resource|data|output|variable|module).*-' $f
    done
    exit 1
fi
