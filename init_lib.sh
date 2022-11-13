#!/usr/bin/env bash

#
# Must be included after init_lib_common.sh and init_lib_xxx.sh
#


# How best to include other scripts?
# https://stackoverflow.com/a/12694189/6091491
DIR="${BASH_SOURCE%/*}"
[[ ! -d "$DIR" ]] && DIR="$(pwd)"

source "${DIR}/init_lib_common.sh"
# source "${DIR}/init_lib_internal.sh"
# source "${DIR}/init_lib_external.sh"
source "${DIR}/init_lib_boost.sh"
source "${DIR}/init_lib_wx.sh"
source "${DIR}/init_lib_soci.sh"
source "${DIR}/init_lib_cscommon.sh"



declare -g -a LIB_EXTERNAL=(
    "${LIB_BOOST}"
    "${LIB_WX}"
    "${LIB_SOCI}"
)

declare -g -a LIB_INTERNAL=(
    "${LIB_CSCMN}"
)

declare -g -a LIBRARIES=()
for item in "${LIB_EXTERNAL[@]}"; do
    LIBRARIES+=("${item}")
done
for item in "${LIB_INTERNAL[@]}"; do
    LIBRARIES+=("${item}")
done



# declare -g -A LIB_NAMES=(
#     [${LIB_BOOST}]="${LIB_BOOST_NAME}"
#     [${LIB_WX}]="${LIB_WX_NAME}"
#     [${LIB_SOCI}]="${LIB_SOCI_NAME}"
#     [${LIB_CSUI}]="${LIB_CSUI_NAME}"
#     [${LIB_CSCMN}]="${LIB_CSCMN_NAME}"
# )



declare -g -A LIB_DEFAULT_VERSION=(
    [${LIB_BOOST}]="${LIB_BOOST_VERSION_DEFAULT}"
    [${LIB_WX}]="${LIB_WX_VERSION_DEFAULT}"
    # [${LIB_DECNUMBER}]="${LIB_DECNUMBER_VERSION_DEFAULT}"
    [${LIB_SOCI}]="${LIB_SOCI_VERSION_DEFAULT}"
    [${LIB_CSCMN}]="${LIB_CSCMN_VERSION_DEFAULT}"
)



declare -g -a LIBRARY_IDS=()
for item in "${LIB_BOOST_VERSIONS[@]}"; do
    LIBRARY_IDS+=("${LIB_BOOST}:${item}")
done
for item in "${LIB_CSCMN_VERSIONS[@]}"; do
    LIBRARY_IDS+=("${LIB_CSCMN}:${item}")
done
# for item in "${LIB_CSUI_VERSIONS[@]}"; do
#     LIBRARY_IDS+=("${LIB_CSUI}:${item}")
# done
# for item in "${LIB_DECNUMBER_VERSIONS[@]}"; do
#     LIBRARY_IDS+=("${LIB_DECNUMBER}:${item}")
# done
for item in "${LIB_SOCI_VERSIONS[@]}"; do
    LIBRARY_IDS+=("${LIB_SOCI}:${item}")
done
for item in "${LIB_WX_VERSIONS[@]}"; do
    LIBRARY_IDS+=("${LIB_WX}:${item}")
done




# Argument:
#   library
#   library version
get_app_build_config () {
    local file="${1}-${2}.config"
    local path="${DIR_BUILD}/app/${v_dir_build_common}/${file}"
    echo "${path}"
}

# Argument:
#   library
#   library version
#   library build dir common
get_lib_build_config () {
    local file="${1}-${2}.config"
    local path="${DIR_BUILD}/lib/${3}/${file}"
    echo "${path}"
}



# Argument:
#   Archive path
#   Destination directory
extract_archive () {
    echo "Extracting $(basename ${1}) to ${2}"
    [[ ! -d "${2}" ]] && mkdir -p "${2}"
    if [[ ${1} == *.tar.bz2 ]]; then
        echo "tar --bzip2 -xf ${1} --directory ${2}"
        tar --bzip2 -xf "${1}" --directory "${2}"
    elif [[ ${1} == *.tar.gz ]]; then
        echo "tar --gzip -xf ${1} --directory ${2}"
        tar --gzip -xf "${1}" --directory "${2}"
    elif [[ ${1} == *.7z ]]; then
        echo "7z x -bd ${1} -o${2}"
        7z x -bd "${1}" -o${2}
    elif [[ ${1} == *.zip ]]; then
        echo "unzip ${1} -d ${2}"
        unzip -q "${1}" -d "${2}"
    fi
    echo "Archive extracted."
}

# Argument:
#   Archive path
#   Destination directory
extract_archive_2 () {

    if [[ ! -d "${v_dir_extract}" ]]; then
        if [[ ! -f "${v_path_archive}" ]]; then
            echo_error "Archive file not found: ${v_path_archive}\nAborting."
            exit 1
        fi
        extract_archive ${v_path_archive} $(dirname ${v_dir_extract})
    fi

    echo "Extracting $(basename ${1}) to ${2}"
    [[ ! -d "${2}" ]] && mkdir -p "${2}"
    if [[ ${1} == *.tar.bz2 ]]; then
        echo "tar --bzip2 -xf ${1} --directory ${2}"
        tar --bzip2 -xf "${1}" --directory "${2}"
    elif [[ ${1} == *.tar.gz ]]; then
        echo "tar --gzip -xf ${1} --directory ${2}"
        tar --gzip -xf "${1}" --directory "${2}"
    elif [[ ${1} == *.7z ]]; then
        echo "7z x -bd ${1} -o${2}"
        7z x -bd "${1}" -o${2}
    elif [[ ${1} == *.zip ]]; then
        echo "unzip ${1} -d ${2}"
        unzip "${1}" -d "${2}"
    fi
    echo "Archive extracted."
}
