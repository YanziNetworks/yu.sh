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

@test "Find first sub-string" {
    [ "$(yush_string_first "hello world" "world")" = "7" ]
}

@test "Find leading sub-string" {
    [ "$(yush_string_first "hello world" "hello")" = "1" ]
}

@test "Find empty sub-string" {
    [ "$(yush_string_first "hello world" "")" = "0" ]
}

@test "Find in empty sub-string" {
    [ "$(yush_string_first "" "world")" = "0" ]
}

@test "Strip leading string" {
    [ "$(yush_string_lstrip "hello world" "hello")" = " world" ]
}

@test "Strip empty leading string" {
    [ "$(yush_string_lstrip "hello world" "")" = "hello world" ]
}

@test "Strip ending string" {
    [ "$(yush_string_rstrip "hello world" "world")" = "hello " ]
}

@test "Strip empty ending string" {
    [ "$(yush_string_rstrip "hello world" "")" = "hello world" ]
}

@test "Strip from string" {
    [ "$(yush_string_strip "hello world hello" "hello")" = " world " ]
}

@test "Strip nothing from string" {
    [ "$(yush_string_strip "hello world" "")" = "hello world" ]
}

@test "Trim beginning of string" {
    [ "$(yush_string_ltrim "    hello world")" = "hello world" ]
}

@test "Trim ending of string" {
    [ "$(yush_string_rtrim "hello world  ")" = "hello world" ]
}

@test "Trim string" {
    [ "$(yush_string_trim "  hello world ")" = "hello world" ]
}

@test "Trim empty string" {
    [ -z "$(yush_string_trim "")" ]
}

@test "Trim nothing" {
    [ -z "$(yush_string_trim)" ]
}

@test "Trim string with only spaces" {
    [ -z "$(yush_string_trim "        ")" ]
}

@test "Single spaces" {
    [ "$(yush_string_trimall "    Hello,    World    ")" = "Hello, World" ]
}

@test "Single spaces from empty string" {
    [ -z "$(yush_string_trimall "")" ]
}

@test "Single spaces from nothing" {
    [ -z "$(yush_string_trimall)" ]
}

@test "Single spaces from only spaces" {
    [ -z "$(yush_string_trimall "         ")" ]
}

@test "Split on sub-string" {
    [ "$(yush_split "apple, bananas, oranges" ", " | wc -l)" = "3" ]
}

@test "Split on nothing" {
    [ "$(yush_split "apple, bananas, oranges" "")" = "apple, bananas, oranges" ]
}

@test "Length of string" {
    [ "$(yush_string_length "1234")" = "4" ]
}

@test "Length of empty string" {
    [ "$(yush_string_length "")" = "0" ]
}

@test "String is float" {
    yush_string_is_float "1.2"
}

@test "Integer string is float" {
    yush_string_is_float "1"
}

@test "Empty string is not int" {
    if [ yush_string_is_int "" ]; then
        return 1
    else
        return 0
    fi
}

@test "Empty string is not float" {
    if [ yush_string_is_float "" ]; then
        return 1
    else
        return 0
    fi
}

@test "Empty string is not strict float" {
    if [ yush_string_is_float_strict "" ]; then
        return 1
    else
        return 0
    fi
}

@test "Integer string is not a strict float" {
    if [ yush_string_is_float_strict "1" ]; then
        return 1
    else
        return 0
    fi
}

@test "Non-number is not float" {
    if [ yush_string_is_float "abc" ]; then
        return 1
    else
        return 0
    fi
}
