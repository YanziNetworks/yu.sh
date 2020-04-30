#!/usr/bin/env bats

# Find yu.sh (tuned for Docker) and load modules
ROOT_DIR=$( cd -P -- "$(dirname -- "$(command -v -- "$0")")" && pwd -P )
[ -d "$ROOT_DIR/../../yu.sh" ] && YUSH_DIR="$ROOT_DIR/../../yu.sh"
[ -z "$YUSH_DIR" ] && [ -d "/yu.sh" ] && YUSH_DIR="/yu.sh"
[ -z "$YUSH_DIR" ] && echo "Cannot find yu.sh root!" >&2 && exit 1

@test "Idempotent oninput output on itself" {
    result=$(${YUSH_DIR}/bin/oninput.sh -- cat < ${YUSH_DIR}/bin/oninput.sh)
    [ "$result" = "$(cat ${YUSH_DIR}/bin/oninput.sh)" ]
}

@test "Changing oninput blocksize" {
    result=$(${YUSH_DIR}/bin/oninput.sh --size 128 -- cat < ${YUSH_DIR}/bin/oninput.sh)
    [ "$result" = "$(cat ${YUSH_DIR}/bin/oninput.sh)" ]
}

@test "oninput unsupported option" {
    ! ${YUSH_DIR}/bin/oninput.sh --non-existing-option
}

@test "Oninput waiting (This will pause 2 secs)" {
    result=$( (sleep 1; echo "test"; sleep 1; echo "second" ) | ${YUSH_DIR}/bin/oninput.sh --size 128 -- cat)
    [ "$(echo "$result"|head -1)" = "test" ] && [ "$(echo "$result"|tail -1)" = "second" ] 
}
