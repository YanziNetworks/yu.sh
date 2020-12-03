#!/bin/sh

set -e

# Generate a good and shell-safe password, length is passed as an argument
# (defaults to 24 chars). This is cumbersome on purpose to defeat Mac OSX
# behaviour
yush_password() {
    len="${1:-24}"
    LC_ALL=C sed -E 's/[^[:alnum:]]//g' </dev/urandom 2>/dev/null | head -c"$((len*2))" | tr -d '\n' | tr -d '\0' | head -c"$len"
}

yush_string_first() {
    [ -z "$1" ] && echo "0" && return
    [ -z "$2" ] && echo "0" && return
    echo "$1"|awk "END{print index(\$0,\"$2\")}"
}

yush_string_length() {
    echo "${#1}"
}

yush_regex_escape() {
    printf %s\\n "$1" | sed -e 's/[]\/$*.^|[]/\\&/g'
}

## Following functions adapted from https://github.com/dylanaraps/pure-sh-bible
#
# The MIT License (MIT)
#
# Copyright (c) 2019 Dylan Araps
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
###

yush_string_rstrip() {
    printf '%s\n' "${1%%$2}"
}

yush_string_lstrip() {
    printf '%s\n' "${1##$2}"
}

yush_string_strip() {
    yush_string_rstrip "$(yush_string_lstrip "$1" "$2")" "$2"
}

yush_string_ltrim() {
    # Remove all leading white-space.
    # '${1%%[![:space:]]*}': Strip everything but leading white-space.
    # '${1#${XXX}}': Remove the white-space from the start of the string.
    printf '%s\n' "${1#${1%%[![:space:]]*}}"
}

yush_string_rtrim() {
    # Remove all trailing white-space.
    # '${trim##*[![:space:]]}': Strip everything but trailing white-space.
    # '${trim#${XXX}}': Remove the white-space from the end of the string.
    printf '%s\n' "${1%${1##*[![:space:]]}}"
}

yush_string_trim() {
    yush_string_rtrim "$(yush_string_ltrim "$1")"
}

# shellcheck disable=SC2086,SC2048
yush_string_trimall() {
    # Disable globbing to make the word-splitting below safe.
    _oldstate=$(set +o); set -f

    # Set the argument list to the word-splitted string.
    # This removes all leading/trailing white-space and reduces
    # all instances of multiple spaces to a single ("  " -> " ").
    set -- $*

    # Print the argument list as a string.
    printf '%s\n' "$*"

    # Restore globbing state
    set +vx; eval "$_oldstate"
}

yush_split() {
    [ -z "$2" ] && echo "$1" && return

    # Disable globbing.
    # This ensures that the word-splitting is safe.
    _oldstate=$(set +o); set -f

    # Store the current value of 'IFS' so we
    # can restore it later.
    old_ifs=$IFS

    # Change the field separator to what we're
    # splitting on.
    IFS=$2

    # Create an argument list splitting at each
    # occurance of '$2'.
    #
    # This is safe to disable as it just warns against
    # word-splitting which is the behavior we expect.
    # shellcheck disable=2086
    set -- $1

    # Print each list value on its own line.
    printf '%s\n' "$@"

    # Restore the value of 'IFS'.
    IFS=$old_ifs

    # Restore globbing state
    set +vx; eval "$_oldstate"
}

# Performs glob matching, little like Tcl. Explicit support for |, which
# otherwise is outside POSIX. See: https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html#tag_18_13
# $1 is the matching pattern
# $2 is the string to test against
yush_glob() {
    # Disable globbing.
    # This ensures that the case is not globbed.
    _oldstate=$(set +o); set -f
    for ptn in $(yush_split "$1" "|"); do
        # shellcheck disable=2254
        case "$2" in
            $ptn) set +vx; eval "$_oldstate"; return 0;;
        esac
    done
    set +vx; eval "$_oldstate"
    return 1
}

# Remove non-printable characters, respecting the current locale as much as
# possible. In other words, this will only output ASCII characters whenever
# removal leads to error on the current locale.
yush_printable() {
    _oldstate=$(set +o); set +e
    clean=$(echo "$1" | tr -cd '[:print:]')
    # shellcheck disable=SC2181
    if [ "$?" != "0" ]; then
        clean=$(echo "$1" | LC_CTYPE=C tr -cd '[:print:]' 2>/dev/null)
    fi
    printf '%s\n' "$clean"
    set +vx; eval "$_oldstate"
}

yush_string_is_float_strict() {
    # Usage: is_float "number"

    # The test checks to see that the input contains
    # a '.'. This filters out whole numbers.
    [ -z "${1##*.*}" ] &&
        printf %f "$1" >/dev/null 2>&1
}

yush_string_is_int() {
    # usage: is_int "number"
    printf %d "$1" >/dev/null 2>&1
}

yush_string_is_float() {
    yush_string_is_int "$1" || yush_string_is_float_strict "$1"
}

yush_is_true() {
    case "$(printf %s\\n "$1" | tr '[:upper:]' '[:lower:]')" in
        "0" | "false" | "off" | "no")
            return 1;;
    esac
    return 0
}