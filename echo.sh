#
# Echo with colors using 256 colors
#
# Reference:
# https://misc.flogisoft.com/bash/tip_colors_and_formatting
#



# color reset '\033[0m'
# color white '\033[38;5;15m'
# color cyan '\033[38;5;14m'
# color igreen '\033[38;5;34m'
# color iorange '\033[38;5;172m'
# color ired '\033[38;5;160m'
# color iyellow '\033[38;5;227m'

echo_info () {
    [ "${#}" -eq 0 ] && return
    [ "${#}" -eq 1 ] && echo -e "\033[38;5;15m${1}\033[0m"
    [ "${#}" -gt 1 ] && echo -e "\033[38;5;15m${1}\033[0m ${@:2:($#)}"
    return 0
}

echo_success () {
    [ "${#}" -eq 0 ] && return
    [ "${#}" -eq 1 ] && echo -e "\033[38;5;34mSuccess: ${1}\033[0m"
    [ "${#}" -gt 1 ] && echo -e "\033[38;5;34mSuccess: ${1}\033[0m${@:2:($#)}"
    return 0
}

echo_warn () {
    [ "${#}" -eq 0 ] && return
    [ "${#}" -eq 1 ] && echo -e "\033[38;5;227mWarning: ${1}\033[0m"
    [ "${#}" -gt 1 ] && echo -e "\033[38;5;227mWarning: ${1}\033[0m${@:2:($#)}"
    return 0
}

echo_error () {
    [ "${#}" -eq 0 ] && return
    [ "${#}" -eq 1 ] && echo -e "\033[38;5;160mError: ${1}\033[0m"
    [ "${#}" -gt 1 ] && echo -e "\033[38;5;160mError: ${1}\033[0m${@:2:($#)}"
    return 0
}

echo_green () {
    [ "${#}" -eq 0 ] && return
    [ "${#}" -eq 1 ] && echo -e "\033[38;5;34m${1}\033[0m"
    [ "${#}" -gt 1 ] && echo -e "\033[38;5;34m${1}\033[0m${@:2:($#)}"
    return 0
}

echo_yellow () {
    [ "${#}" -eq 0 ] && return
    [ "${#}" -eq 1 ] && echo -e "\033[38;5;227m${1}\033[0m"
    [ "${#}" -gt 1 ] && echo -e "\033[38;5;227m${1}\033[0m${@:2:($#)}"
    return 0
}

echo_red () {
    [ "${#}" -eq 0 ] && return
    [ "${#}" -eq 1 ] && echo -e "\033[38;5;160m${1}\033[0m"
    [ "${#}" -gt 1 ] && echo -e "\033[38;5;160m${1}\033[0m${@:2:($#)}"
    return 0
}

echo_cyan () {
    [ "${#}" -eq 0 ] && return
    [ "${#}" -eq 1 ] && echo -e "\033[38;5;14m${1}\033[0m"
    [ "${#}" -gt 1 ] && echo -e "\033[38;5;14m${1}\033[0m${@:2:($#)}"
    return 0
}

echo_orange () {
    [ "${#}" -eq 0 ] && return
    [ "${#}" -eq 1 ] && echo -e "\033[38;5;172m${1}\033[0m"
    [ "${#}" -gt 1 ] && echo -e "\033[38;5;172m${1}\033[0m${@:2:($#)}"
    return 0
}
