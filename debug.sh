#
# Debug utility
#



declare flag_debug_mode=0

# Display debugging text(s)
# Parameters:
#   Label string - displayed in highlighted color
#   Info string - displayed in normal color
echo_debug () {
    if [ ${flag_debug_mode} -ne 0 ] && [ ${#} -gt 0 ] && [ ! -z "${1}" ]; then
        # local iorange="\033[38;5;208m"
        local local_iorange="\033[38;5;172m"
        local local_off='\033[0m'
        local output
        [ ${#} -eq 1 ] && output="${local_iorange}${@}${local_off}"
        [ ${#} -gt 1 ] && output="${local_iorange}${1}${local_off}${@:(-1)}"
        echo -e "${output}"
    fi
}
