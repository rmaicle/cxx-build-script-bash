#!/usr/bin/env bash

#
# System variables
#



# Get OS type
# https://stackoverflow.com/questions/394230/how-to-detect-the-os-from-a-bash-script


declare -g OSTYPE_LINUX="linux"
declare -g OSTYPE_GNU="linux"
declare -g OSTYPE_DARWIN="darwin"
declare -g OSTYPE_CYGWIN="cygwin"
declare -g OSTYPE_MSYS="msys"
declare -g OSTYPE_FREEBSD="freebsd"
declare -g OSTYPE_UNKNOWN="unknown"

declare -g CMAKE_GEN_FILE_TYPE="Unix Makefiles"
declare -g v_make_bin="make"

if [[ "${OSTYPE}" == "${OSTYPE_LINUX}"* ]]; then
    v_make_bin="make"
elif [[ "${OSTYPE}" == "${OSTYPE_MSYS}" ]]; then
    v_make_bin="mingw32-make.exe"
else
    echo "Unsupported operating system: ${OSTYPE}"
    exit
fi



check_if_command_exists () {
    if ! command -v ${1} &>/dev/null; then
        echo_error "Could not find ${1} archive utility.\nAborting."
        exit 1
    fi
}



if [[ "${OSTYPE}" == "${OSTYPE_LINUX}"* ]]; then
    check_if_command_exists tar
    check_if_command_exists bzip2
    check_if_command_exists gzip
    check_if_command_exists gunzip
elif [[ "${OSTYPE}" == "${OSTYPE_MSYS}" ]]; then
    check_if_command_exists 7z
    check_if_command_exists zip
    check_if_command_exists unzip
fi
