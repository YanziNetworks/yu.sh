#!/usr/bin/env bats

# Find yu.sh (tuned for Docker) and load modules
ROOT_DIR=$( cd -P -- "$(dirname -- "$(command -v -- "$0")")" && pwd -P )
[ -d "$ROOT_DIR/../../yu.sh" ] && YUSH_DIR="$ROOT_DIR/../../yu.sh"
[ -z "$YUSH_DIR" ] && [ -d "/yu.sh" ] && YUSH_DIR="/yu.sh"
[ -z "$YUSH_DIR" ] && echo "Cannot find yu.sh root!" >/dev/stderr && exit 1
YUSH_LOG_LEVEL=warn
. "$YUSH_DIR/log.sh"
. "$YUSH_DIR/file.sh"

@test "First line of file" {
    [ "$(yush_head 1 "$YUSH_DIR"/file.sh)" = "#!/usr/bin/env sh" ]
}

@test "First line of stdin" {
    [ "$(echo "test" | yush_head 1)" = "test" ]
}

@test "First (default=10) lines of stdin" {
    [ "$(yush_head < "$YUSH_DIR"/file.sh | wc -l)" = "10" ]
}

@test "Count lines of file" {
    [ "$(yush_lines "$YUSH_DIR"/file.sh)" = "$(wc -l "$YUSH_DIR"/file.sh | awk '{print $1}')" ]
}

@test "Count lines of stdin" {
    [ "$(echo "test" | yush_lines)" = "1" ]
}

@test "Directory name of path" {
    [ "$(dirname /home/user/file.txt)" = "/home/user" ]
}

@test "Directory name of /" {
    [ "$(dirname /)" = "/" ]
}

@test "Directory name of relative filename" {
    [ "$(dirname file.txt)" = "." ]
}

@test "Basename of path" {
    [ "$(basename "/home/user/file.txt")" = "file.txt" ]
}

@test "Basename of path without extension" {
    [ "$(basename "/home/user/file.txt" ".txt")" = "file" ]
}

@test "Basename of directory path" {
    [ "$(basename "/home/user/")" = "user" ]
}
