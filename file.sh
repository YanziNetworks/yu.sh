#!/usr/bin/env sh

yush_abspath() {
    if [ -d "$1" ]; then
        ( cd -P -- "$1" && pwd -P )
    else
        echo "$(yush_abspath "$(yush_dirname "$1")")/$(yush_basename "$1")"
    fi
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

yush_head() {
    # Usage: head "n" "file"
    while IFS= read -r line; do
        printf '%s\n' "$line"
        i=$((i+1))
        [ "$i" = "${1:-10}" ] && return
    done < "${2:-/dev/stdin}"

    # 'read' used in a loop will skip over
    # the last line of a file if it does not contain
    # a newline and instead contains EOF.
    #
    # The final line iteration is skipped as 'read'
    # exits with '1' when it hits EOF. 'read' however,
    # still populates the variable.
    #
    # This ensures that the final line is always printed
    # if applicable.
    [ -n "$line" ] && printf %s "$line"
}

yush_lines() {
    # Usage: lines "file"

    # '|| [ -n "$line" ]': This ensures that lines
    # ending with EOL instead of a newline are still
    # operated on in the loop.
    #
    # 'read' exits with '1' when it sees EOL and
    # without the added test, the line isn't sent
    # to the loop.
    while IFS= read -r line || [ -n "$line" ]; do
        lines=$((lines+1))
    done < "${1:-/dev/stdin}"

    printf '%s\n' "$lines"
}

yush_dirname() {
    # Usage: dirname "path"

    # If '$1' is empty set 'dir' to '.', else '$1'.
    dir=${1:-.}

    # Strip all trailing forward-slashes '/' from
    # the end of the string.
    #
    # "${dir##*[!/]}": Remove all non-forward-slashes
    # from the start of the string, leaving us with only
    # the trailing slashes.
    # "${dir%%"${}"}:  Remove the result of the above
    # substitution (a string of forward slashes) from the
    # end of the original string.
    dir=${dir%%"${dir##*[!/]}"}

    # If the variable *does not* contain any forward slashes
    # set its value to '.'.
    [ "${dir##*/*}" ] && dir=.

    # Remove everything *after* the last forward-slash '/'.
    dir=${dir%/*}

    # Again, strip all trailing forward-slashes '/' from
    # the end of the string (see above).
    dir=${dir%%"${dir##*[!/]}"}

    # Print the resulting string and if it is empty,
    # print '/'.
    printf '%s\n' "${dir:-/}"
}

yush_basename() {
    # Usage: basename "path" ["suffix"]

    # Strip all trailing forward-slashes '/' from
    # the end of the string.
    #
    # "${1##*[!/]}": Remove all non-forward-slashes
    # from the start of the string, leaving us with only
    # the trailing slashes.
    # "${1%%"${}"}:  Remove the result of the above
    # substitution (a string of forward slashes) from the
    # end of the original string.
    dir=${1%${1##*[!/]}}

    # Remove everything before the final forward-slash '/'.
    dir=${dir##*/}

    # If a suffix was passed to the function, remove it from
    # the end of the resulting string.
    dir=${dir%"$2"}

    # Print the resulting string and if it is empty,
    # print '/'.
    printf '%s\n' "${dir:-/}"
}

# This file needs to end with an empty lines for tests to work properly!
