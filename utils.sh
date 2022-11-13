#
# Common utilities
#

#
# Unset a variable
#

# cat << EOF| sudo gdb
# attach $$
# call unbind_variable("a")
# detach
# EOF

# gdb --batch-silent --pid=$$ --eval-command='call unbind_variable("mySite")'



source ./echo.sh
source ./dirstack.sh



declare -g -a YESNO=(
    "no"
    "yes"
)

declare -g -a TRUEFALSE=(
    "false"
    "true"
)

# Return "common" directory name.
#   Format: <comiler type><compiler version>-<c++std>-shared-<build type>-x64
# Arguments:
#   compiler
#   compiler version
#   c++ standard id
#   build type
# get_common_dir_name () {
#     if [ $# -lt 3 ]; then
#         echo ""
#     else
#         echo "${1}$(undot ${2})-${3}-${LIBRARY_TYPES[-1]}-${4}"
#     fi
# }



#
# Convert specified string argument to lowercase
#
# ex.: declare v=$(to_lowercase "${1}")
#
to_lowercase () {
    echo "$(echo ${1} | tr 'A-Z' 'a-z')"
}



#
# Remove period characters from string
#
# ex.: declare v=$(undot "3.1.5")
undot () {
    # echo "$(echo "${1}" | tr -d . )"
    echo "${1//./}"
}



# Join items of an array separatd by spaces
# Example:
#   join_semicolon ${OPTIONS_LONG[@]
join_semicolon () {
    local IFS="; "
    echo "$*";
}



join_space () {
    local IFS=" "
    echo "$*";
}



# Create archive of current directory
#
# Argument:
#   File path of the archive to be created
create_archive () {
    if [[ "${OSTYPE}" == "${OSTYPE_LINUX}"* ]]; then
        tar -cjf "${1}" . 2>/dev/null
    elif [[ "${OSTYPE}" == "${OSTYPE_MSYS}"* ]]; then
        7z a -bb0 -t7z -m0=lzma -mx=9 -mfb=64 -md=32m -ms=off "${1}" . 2>/dev/null
    fi
}



#
# Extract .tar.bz2 archive file.
#
extract_tar_bz2 () {
    if [ $# -eq 0 ]; then
        echo_error "${FUNCNAME[0]}: Missing argument.\nAborting."
        exit 1
    fi
    if command -v tar &>/dev/null; then
        echo "Extracting ${1}..."
        if command -v pv &>/dev/null; then
            pv ${1} | tar -xj --
        else
            tar -xjf "${1}"
        fi
        echo "Archive extracted."
    else
        echo_error "Could not find tar archive utility.\nAborting."
        exit 1
    fi
}



extract_tar_gz () {
    if [ $# -eq 0 ]; then
        echo_error "${FUNCNAME[0]}: Missing argument.\nAborting."
        exit 1
    fi
    if command -v tar &>/dev/null; then
        echo "Extracting ${1}..."
        if command -v pv &>/dev/null; then
            pv ${1} | tar -xz --
        else
            # tar -xz --file="${arg_input_file}"
            tar -xzf "${1}"
        fi
        echo "Archive extracted."
    else
        echo_error "Could not find tar archive utility.\nAborting."
        exit 1
    fi
}



#
# Extract .zip archive file.
#
extract_zip () {
    if [ $# -eq 0 ]; then
        echo_error "${FUNCNAME[0]}: Missing argument.\nAborting."
        exit 1
    fi
    if command -v unzip &>/dev/null; then
        echo "Extracting ${1}..."
        unzip "${1}" -d "${1%.*}"
        echo "Archive extracted."
    else
        echo_error "Could not find tar archive utility.\nAborting."
        exit 1
    fi
}



#
# Extract .zip archive file.
#
extract_zip_no_dir () {
    if [ $# -eq 0 ]; then
        echo_error "${FUNCNAME[0]}: Missing argument.\nAborting."
        exit 1
    fi
    if command -v unzip &>/dev/null; then
        echo "Extracting ${1}..."
        unzip "${1}"
        echo "Archive extracted."
    else
        echo_error "Could not find tar archive utility.\nAborting."
        exit 1
    fi
}



#
# Extract .7z archive file.
#
extract_7zip () {
    if [ $# -eq 0 ]; then
        echo_error "${FUNCNAME[0]}: Missing argument.\nAborting."
        exit 1
    fi
    if command -v unzip &>/dev/null; then
        echo "Extracting ${1}..."
        7z x -bd "${1}" -o"${1%.*}"
        echo "Archive extracted."
    else
        echo_error "Could not find tar archive utility.\nAborting."
        exit 1
    fi
}



#
# Extract .7z archive file.
#
extract_7zip_no_dir () {
    if [ $# -eq 0 ]; then
        echo_error "${FUNCNAME[0]}: Missing argument.\nAborting."
        exit 1
    fi
    if command -v unzip &>/dev/null; then
        echo "Extracting ${1}..."
        7z x -bd "${1}"
        echo "Archive extracted."
    else
        echo_error "Could not find tar archive utility.\nAborting."
        exit 1
    fi
}



#
# Extract an archive file into some directory with checks.
#
# Arguments:
#   root dir
#   archive filename
#   destination dir name
extract_to_dir () {
    if [ $# -lt 2 ]; then
        echo_error "${FUNCNAME[0]}: Missing argument(s).\nAborting."
        exit 1
    fi
    local arg_dir_root="${1}"
    local v_archive_filename="${2}"
    local v_archive_filename_ext="${2##*.}"
    local v_dir_destination="${arg_dir_root}"
    if [[ ${#} -gt 2 ]]; then
        v_dir_destination="${v_dir_destination}/${3}"
    fi

    if [ ! -d "${arg_dir_root}" ]; then
        echo_error "Directory not found:\n  ${arg_dir_root}\nAborting."
        echo "Aborting."
        exit 1
    fi

    pushd ${arg_dir_root}
    if [ ! -e "${v_archive_filename}" ]; then
        echo_error "Archive file does not exist:\n  ${v_archive_filename}\nAborting."
        echo "Aborting."
        exit 1
    fi

    if [[ "${v_archive_filename_ext}" == "bz2" ]]; then
        extract_tar_bz2 ${v_archive_filename}
    elif [[ "${v_archive_filename_ext}" == "gz" ]]; then
        extract_tar_gz ${v_archive_filename}
    elif [[ "${v_archive_filename_ext}" == "7z" ]]; then
        extract_7zip ${v_archive_filename}
    elif [[ "${v_archive_filename_ext}" == "zip" ]]; then
        extract_zip ${v_archive_filename}
    fi

    if [ ! -d "${v_dir_destination}" ]; then
        echo_error "Extract directory not found:\n  ${v_dir_destination}\nAborting."
        exit 1
    fi
    popd
}



#
# Send abort message then exit with error.
#
abort () {
    if [ $# -eq 0 ]; then
        echo "Aborting."
        exit 1
    fi
    if [ $# -eq 1 ]; then
        echo "${1}."
        exit 1
    fi
    if [ $# -eq 2 ]; then
        echo "${1}."
        exit ${2}
    fi
    if [ $# -gt 2 ]; then
        shift 2
        echo_error "Bash function ${FUNCNAME[0]} have extra argument(s):"
        echo_error "  $@"
        echo "Aborting."
        exit 1
    fi
}


# Return the corresponding ID of a partial ID string.
#
# Arguments:
#   Option value
#   Acceptable values
get_id () {
    if [ $# -lt 2 ]; then
        echo ""
        return 1
    fi
    local arg_value="${1}"
    local arg_name=$2[@]
    local -a arg_values=("${!arg_name}")
    for v_value in ${arg_values[@]}; do
        if [[ ${v_value} =~ ${arg_value} ]]; then
            # arg_value="${v_value}"
            echo "${v_value}"
            return 0
        fi
    done
    echo ""
    return 1
}


# Prompts a message and exit when a value is not in the list of values.
#
# Example:
#   check_in_array "--build" "nti" "${BUILD_TYPES[@]}" --> exits
#
# Arguments:
#   Option
#   Option value
#   Acceptable values
check_arg_in_array () {
    if [ $# -lt 3 ]; then
        echo_error "${FUNCNAME[0]}: Missing argument(s).\nAborting."
        exit 1
    fi
    local arg_option="${1}"
    local arg_value="${2}"
    local arg_name=$3[@]
    local -a arg_values=("${!arg_name}")
    # If value is partial, we can try and find the 'complete' equivalent value
    # for v_value in ${arg_values[@]}; do
    #     if [[ ${v_value} =~ ${arg_value} ]]; then
    #         arg_value="${v_value}"
    #     fi
    # done
    if [[ ! "${arg_values[@]}" =~ "${arg_value}" ]]; then
        echo_error "Unrecognized argument '${arg_value}' for option '${arg_option}'.\n"\
            "Use one of: ${arg_values[@]// /, }"
        return 1
    fi
    return 0
}



declare -g PROCESSED_ID=""

# Return name and version information.
# Sets global variable PROCESSED_ID.
#
# Arguments:
#   Option
#   Option value
#   Acceptable names
#   Acceptable IDs
get_name_and_version () {
    if [ $# -lt 4 ]; then
        echo_error "${FUNCNAME[0]}: Missing argument(s).\nAborting."
        exit 1
    fi
    local arg_option="${1}"
    local arg_value="${2}"
    local name=$3[@]
    local -a arg_names=("${!name}")
    name=$4[@]
    local -a arg_ids=("${!name}")

    # echo_debug "names: ${arg_names[@]}"
    # echo_debug "ids: ${arg_ids[@]}"

    PROCESSED_ID=""

    # Separate name and version information
    local v_name_part=""+
    local v_version_part=""
    if [[ "${arg_value}" =~ ":" ]]; then
        v_name_part="${arg_value%%:*}"
        v_version_part="${arg_value##*:}"
    else
        # We assume that the value is a name part
        v_name_part="${arg_value}"
    fi

    # Check the name information
    # If name is partial, we try and find the 'complete' equivalent name
    # If name is not found in the acceptable names, then error and abort
    for v_name in ${arg_names[@]}; do
        if [[ ${v_name} =~ ${v_name_part} ]]; then
            v_name_part="${v_name}"
        fi
    done
    if [[ ! "${arg_names[@]}" =~ "${v_name_part}" ]]; then
        echo_error "Unrecognized argument '${arg_value}' for option '${arg_option}'.\n"\
            "Use one of: ${arg_names[@]// /, }"
        return 1
    fi

    # Return the name part without version information
    if [[ -z "{v_version_part}" ]]; then
        PROCESSED_ID="${v_name_part}"
        return 0
    fi

    # Check the IDs
    arg_value="${v_name_part}:${v_version_part}"
    if [[ ! "${arg_ids[@]}" =~ "${arg_value}" ]]; then
        echo_error "Unrecognized argument '${arg_value}' for option '${arg_option}'.\n"\
            "Use one of: ${arg_ids[@]// /, }"
        return 1
    else
        for v_id in ${arg_ids[@]}; do
            if [[ ${v_id} =~ ${arg_value} ]]; then
                PROCESSED_ID="${v_id}"
                return 0
            fi
        done
    fi
    return 0
}
