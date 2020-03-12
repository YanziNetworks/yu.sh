#!/bin/sh

set -e

yush_b64_encode() { base64; }
yush_b64_decode() {
    if [ "$(uname -s)" = "Darwin" ]; then
        base64 -D; # Mac takes -D or --decode
    else
        base64 -d; # Alpine/budybox does not understand --decode
    fi
}


# This is a very-poor-man's envsubst. It has no support for default values.
yush_envsubst() {
    substituted=$1
    environment=$(env|grep -E '^[0-9[:upper:]_]+=')
    while IFS='=' read -r var val; do
        for separator in ! ~ ^ % \; /; do
            if ! echo "$val" | grep -qo "$separator"; then
                substituted=$(echo "$substituted" | sed -e "s${separator}\$${var}${separator}$val${separator}g")
                break
            fi
        done
    done <<EOF
$environment
EOF
    echo "$substituted"
}