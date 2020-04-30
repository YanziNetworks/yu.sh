#!/usr/bin/env bats

# Find yu.sh (tuned for Docker) and load modules
ROOT_DIR=$( cd -P -- "$(dirname -- "$(command -v -- "$0")")" && pwd -P )
[ -d "$ROOT_DIR/../../yu.sh" ] && YUSH_DIR="$ROOT_DIR/../../yu.sh"
[ -z "$YUSH_DIR" ] && [ -d "/yu.sh" ] && YUSH_DIR="/yu.sh"
[ -z "$YUSH_DIR" ] && echo "Cannot find yu.sh root!" >&2 && exit 1
YUSH_LOG_LEVEL=warn
. "$YUSH_DIR/log.sh"
. "$YUSH_DIR/date.sh"


@test "Pure integer duration" {
    [ "$(yush_howlong 3)" = "3" ]
}

@test "Short seconds duration" {
    [ "$(yush_howlong "4 s")" = "4" ]
}

@test "Longer seconds duration" {
    [ "$(yush_howlong "5 seCs")" = "5" ]
}

@test "Shorter seconds duration without separator" {
    [ "$(yush_howlong "4s")" = "4" ]
}

@test "Short days duration" {
    [ "$(yush_howlong "4 d")" = "345600" ]
}

@test "Longer days duration" {
    [ "$(yush_howlong "4 DaYS")" = "345600" ]
}

@test "Shorter days duration without separator" {
    [ "$(yush_howlong "4d")" = "345600" ]
}

@test "Garbage non-duration" {
    [ -z "$(yush_howlong "blob")" ]
}

@test "Short human period" {
    [ "$(yush_human_period "3")" = "3 seconds " ]
}

@test "Complex human period (minutes)" {
    [ "$(yush_human_period "67")" = "1 minute " ]
}

@test "Complex human period (hours)" {
    [ "$(yush_human_period "4567")" = "1 hour 16 minutes " ]
}

@test "iso8601 date with UTC TZ" {
    [ "$(yush_iso8601 "2019-11-11T21:57:53+00:00")" = "1573509473" ]
}

@test "iso8601 date with UTC Z" {
    [ "$(yush_iso8601 "2019-11-11T21:57:53Z")" = "1573509473" ]
}

@test "iso8601 date with TZ" {
    [ "$(yush_iso8601 "2019-11-11T23:04:47+01:00")" = "1573509887" ]
}
