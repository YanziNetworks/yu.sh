#!/bin/sh

set -e

yush_b64_encode() { base64; }
yush_b64_decode() {
    if [ "$(uname -s)" = "Darwin" ]; then
        base64 -D; # Mac takes -D or --decode
    else
        base64 -d; # Alpine/budybox does not understand --decode
    fi
}


# This is an expansion safe envsubst implementation in pure-shell and inspired
# by https://stackoverflow.com/a/40167919. It uses eval in a controlled-manner
# to avoid side-effects.
# shellcheck disable=SC2120
yush_envsubst() {
    if [ "$#" -gt "0" ]; then
        printf %s\\n "$1" | yush_envsubst
    else
        # Prepare a sed script that will replace all occurrences of the known
        # environment variables by their value
        _sed=$(mktemp)
        while IFS='=' read -r var val; do
            for separator in ! ~ ^ % \; /; do
                if ! printf %s\\n "$val" | grep -qo "$separator"; then
                    printf 's%s\x04%s%s%s%sg\n' \
                        "$separator" "$var" "$separator" "$val" "$separator" >> "$_sed"
                    break
                fi
            done
        done <<EOF
$(env|grep -E '^[0-9[:upper:]][0-9[:upper:]_]*=')
EOF

        while IFS= read -r line || [ -n "$line" ]; do  # Read, incl. non-empty last line
            # Transpose all chars that could trigger an expansion to control
            # characters, and perform expansion using the script above for pure
            # variable substitutions. Once done, transpose only the ${ back to
            # what they should (and escape the double quotes)
            _line=$(printf %s\\n "$line" |
                        tr '`([$' '\1\2\3\4' |
                        sed -f "$_sed" |
                        sed -e 's/\x04{/${/g' -e 's/"/\\\"/g')
            # At this point, eval is safe, since the only expansion left is for
            # ${} contructs. Perform the eval and convert back the control
            # characters to the real chars.
            eval "printf '%s\n' \"$_line\"" | tr '\1\2\3\4' '`([$'
        done

        # Get rid of the temporary sed script
        rm -f "$_sed"
    fi
}