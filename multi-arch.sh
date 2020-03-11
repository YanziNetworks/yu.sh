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