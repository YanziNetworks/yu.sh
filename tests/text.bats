#!/usr/bin/env bats

# Find yu.sh (tuned for Docker) and load modules
ROOT_DIR=$( cd -P -- "$(dirname -- "$(command -v -- "$0")")" && pwd -P )
[ -d "$ROOT_DIR/../../yu.sh" ] && YUSH_DIR="$ROOT_DIR/../../yu.sh"
[ -z "$YUSH_DIR" ] && [ -d "/yu.sh" ] && YUSH_DIR="/yu.sh"
[ -z "$YUSH_DIR" ] && echo "Cannot find yu.sh root!" >/dev/stderr && exit 1
YUSH_LOG_LEVEL=warn
. "$YUSH_DIR/log.sh"
. "$YUSH_DIR/text.sh"


@test "Default sized password" {
    passwd=$(yush_password)
    echo "$passwd" | grep -Eqo '^[a-zA-Z0-9]{24}$'
}

@test "Sized password" {
    passwd=$(yush_password 16)
    echo "$passwd" | grep -Eqo '^[a-zA-Z0-9]{16}$'
}

@test "0 sized password" {
    passwd=$(yush_password 0)
    [ -z "$passwd" ]
}