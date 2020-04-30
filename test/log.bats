#!/usr/bin/env bats

# Find yu.sh (tuned for Docker) and load modules
ROOT_DIR=$( cd -P -- "$(dirname -- "$(command -v -- "$0")")" && pwd -P )
[ -d "$ROOT_DIR/../../yu.sh" ] && YUSH_DIR="$ROOT_DIR/../../yu.sh"
[ -z "$YUSH_DIR" ] && [ -d "/yu.sh" ] && YUSH_DIR="/yu.sh"
[ -z "$YUSH_DIR" ] && echo "Cannot find yu.sh root!" >&2 && exit 1
. "$YUSH_DIR/log.sh"

@test "Default logging" {
    logline=$(yush_log "This is a test" 2>&1)
    echo "$YUSH_APPNAME"
    echo "$logline" | grep -Eqo '\[\s*info\s*\] \[[0-9]{8}\-[0-9]{6}\] \[bats(\w|\-)*\] This is a test'
}

@test "Module specific default logging" {
    logline=$(yush_log "This is a test" "test" 2>&1)
    echo "$logline" | grep -Eqo '\[\s*info\s*\] \[[0-9]{8}\-[0-9]{6}\] \[test\] This is a test'
}

@test "Default log level is info" {
    logline=$(yush_log "This is a test" "test" 2>&1)
    infoline=$(yush_info "This is a test" "test" 2>&1)
    [ "$logline" = "$infoline" ]
}

@test "Skipping debug logging" {
    logline=$(yush_debug "This is a test" "test" 2>&1)
    [ -z "$logline" ]
}

@test "Changing logging level" {
    PREV_LEVEL=$YUSH_LOG_LEVEL
    YUSH_LOG_LEVEL=debug
    logline=$(yush_debug "This is a test" "test" 2>&1)
    YUSH_LOG_LEVEL=$PREV_LEVEL
    [ -n "$logline" ]
}

@test "Changing application name" {
    PREV_NAME=$YUSH_APPNAME
    YUSH_APPNAME=myapp
    logline=$(yush_log "This is a test" 2>&1)
    YUSH_APPNAME=$PREV_NAME
    echo "$logline" | grep -Eqo '\[myapp\]'
}

@test "Changing log destination" {
    PREV_PATH=$YUSH_LOG_PATH
    YUSH_LOG_PATH=/dev/stdout
    logline=$(yush_log "This is a test")
    YUSH_LOG_PATH=$PREV_PATH
    [ -n "$logline" ]
}

@test "Forcing colouring off" {
    PREV_COLOUR=$YUSH_LOG_COLOUR
    YUSH_LOG_COLOUR=0
    logline=$(yush_log "This is a test" 2>&1)
    noprint=$(echo "$logline" | sed -E 's/^[:print:]//g')
    YUSH_LOG_COLOUR="$PREV_COLOUR"
    [ "$logline" = "$noprint" ]
}

@test "Forcing colouring" {
    PREV_COLOUR=$YUSH_LOG_COLOUR
    YUSH_LOG_COLOUR=1
    logline=$(yush_log "This is a test" 2>&1)
    YUSH_LOG_COLOUR="$PREV_COLOUR"
    echo "$logline" | grep -Eqo '[^[:print:]]'
}
