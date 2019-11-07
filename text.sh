#!/bin/sh

set -e

# Generate a good and shell-safe password, length is passed as an argument
# (defaults to 24 chars).
yush_password() {
    tr -dc A-Za-z0-9 </dev/urandom 2>/dev/null | head -c"${1:-24}"; echo
}