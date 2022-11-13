#!/usr/bin/env bash

# How best to include other scripts?
# https://stackoverflow.com/a/12694189/6091491
DIR="${BASH_SOURCE%/*}"
[[ ! -d "$DIR" ]] && DIR="$(pwd)"

source "${DIR}/utils.sh"
source "${DIR}/init_system.sh"
source "${DIR}/init_compiler.sh"



declare -g -r DIR_APP_SOURCE_PREFIX="app"
declare -g -r APP_NAME_SEP="_"



# Application codes
declare -g APP_TEST="test"

declare -g -a APPLICATIONS=(
    "${APP_TEST}"
)

declare -g APP_TEST_NAME="Test Application"

# Tells the build to use the latest versions available.
declare -g APP_VERSION_LATEST="0.0.0"

declare -g APP_TEST_VERSION_DEFAULT="${APP_VERSION_LATEST}"
declare -g -a APP_TEST_VERSIONS=(
    "${APP_TEST_VERSION_DEFAULT}"
    "0.1.0"
    "0.2.0"
)



declare -g -a APP_IDS=()
for item in "${APP_TEST_VERSIONS[@]}"; do
    APP_IDS+=("${APP_TEST}:${item}")
done


declare APP_ARCHIVE_EXT="tar.bz2"
[[ "${OSTYPE}" == "${OSTYPE_MSYS}" ]] && APP_ARCHIVE_EXT="7z"
declare APP_ARCHIVE_EXT_ALT="zip"


search_apps_in_source_dir () {
    pushd "${DIR_SRC}"
    local v_name=""
    for i in $( ls -d app_*/ | cut -f1 -d'/' ); do
        v_name="${i:4}"
        if [[ "${v_name}" != "${APP_TEST}" ]]; then
            APPLICATIONS+=("${v_name}")
            APP_IDS+=("${v_name}:${APP_VERSION_LATEST}")
        fi
    done
    popd
}



# Return source directory name.
#
# Example (APP_DIR_PREFIX="app"):
#   echo "$(get_app_source_dir_name "test")" --> app_test
#
# Arguments:
#   Application code
get_app_source_dir_name () {
    echo "${DIR_APP_SOURCE_PREFIX}${APP_NAME_SEP}${1}"
}



# Return the application default version number as a string x.y.z.
# Argument:
#   Application code
get_app_default_version () {
    if [[ $# -lt 1 ]]; then
        echo_error "Missing argument to get_app_default_version().\nAborting."
        exit 1
    fi
    local v_var_name=""
    if [[ "${1}" == "${APP_TEST}" ]]; then
        v_var_name="APP_${1^^}_VERSION_DEFAULT"
        echo "${!v_var_name}"
    else
        echo "${APP_VERSION_LATEST}"
    fi
}



declare -g DIR_APP_EXTRACT
declare -g DIR_APP_BUILD
declare -g DIR_APP_STAGING
declare -g DIR_APP_STAGING_BIN

declare PATH_APP_ARCHIVE=""

# Sets the build and staging directory path variables.
#
# Arguments:
#   Application code
#   Application version
#   Compiler
#   Compiler version
#   C++ standard id
#   Build type
init_app_build_dir () {
    local v_common_compile_string=$(init_common_compile_string ${3} ${4} ${5} ${6})
    local v_filename="${1}-${2}"
    PATH_APP_ARCHIVE="${DIR_LIB}/${v_filename}.${APP_ARCHIVE_EXT}"
    DIR_APP_EXTRACT="${DIR_BUILD}/${v_common_compile_string}/${v_filename}"
    DIR_APP_BUILD="${DIR_APP_EXTRACT}/build"
    DIR_APP_STAGING="${DIR_APP_EXTRACT}/staging"
    DIR_APP_STAGING_BIN="${DIR_APP_STAGING}/bin"
}



# Create archive file of the source directory.
# Create the archive file only if the archive is non-existent.
#
# Argument:
#   Application code
#   Application version
create_app_archive () {
    if [[ ! -f "${PATH_APP_ARCHIVE}" ]]; then
        local v_app_dir=$(get_app_source_dir_name "${1}")
        if [[ ! -f "${v_app_dir}" ]]; then
            echo_error "Application source directory not found: ${v_app_dir}\nAborting."
            exit 1
        fi
        pushd "${DIR_SRC}/${v_app_dir}"
        create_archive "${PATH_APP_ARCHIVE}"
        popd
    fi
}



# Extract archive.
# Sets the flag argument whether this is an initial build operation.
# Initial build operation is true when the extract directory is missing.
#
# Argument:
#   Initial build flag (reference)
# Example:
#   extract_app_archive flag_initial_build
extract_app_archive () {
    local -n flag=${1}
    if [[ ! -d "${DIR_APP_EXTRACT}" ]]; then
        flag=1
        if [[ ! -f "${PATH_APP_ARCHIVE}" ]]; then
            echo_error "Archive file not found: ${PATH_APP_ARCHIVE}\nAborting."
            exit 1
        fi
        extract_archive ${PATH_APP_ARCHIVE} ${DIR_APP_EXTRACT}
    fi
}



# Recreate the Build and Staging directories as necessary.
# When rebuilding, the contents of the Build and Staging directories are deleted.
recreate_app_build_and_staging_dirs () {
    local flag_rebuild=${1}
    if [ ${flag_rebuild} -gt 0 ]; then
        [[ -d "${DIR_APP_BUILD}" ]] && rm -rf "${DIR_APP_BUILD}"
        [[ -d "${DIR_APP_STAGING}" ]] && rm -rf "${DIR_APP_STAGING}"
    fi
    [[ ! -d "${DIR_APP_BUILD}" ]] && mkdir -p "${DIR_APP_BUILD}"
    [[ ! -d "${DIR_APP_STAGING_BIN}" ]] && mkdir -p "${DIR_APP_STAGING_BIN}"
    return 0
}
