#!/bin/sh

set -e

# Generate a good and shell-safe password, length is passed as an argument
# (defaults to 24 chars).
yush_password() {
    LC_ALL=C tr -dc A-Za-z0-9 </dev/urandom 2>/dev/null | head -c"${1:-24}"; echo
}

yush_string_first() {
    [ -z "$1" ] && echo "0" && return
    [ -z "$2" ] && echo "0" && return
    echo "$1"|awk "END{print index(\$0,\"$2\")}"
}

yush_string_length() {
    echo "${#1}"
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
    yush_string_rtrim "$(yush_string_ltrim "$1" "$2")" "$2"
}

# shellcheck disable=SC2086,SC2048
yush_string_trimall() {
    # Disable globbing to make the word-splitting below safe.
    set -f

    # Set the argument list to the word-splitted string.
    # This removes all leading/trailing white-space and reduces
    # all instances of multiple spaces to a single ("  " -> " ").
    set -- $*

    # Print the argument list as a string.
    printf '%s\n' "$*"

    # Re-enable globbing.
    set +f
}

yush_split() {
    [ -z "$2" ] && echo "$1" && return

    # Disable globbing.
    # This ensures that the word-splitting is safe.
    set -f

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

    # Re-enable globbing.
    set +f
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
