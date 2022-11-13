#!/usr/bin/env bash

# How best to include other scripts?
# https://stackoverflow.com/a/12694189/6091491
DIR="${BASH_SOURCE%/*}"
[[ ! -d "$DIR" ]] && DIR="$(pwd)"

source "${DIR}/utils.sh"
source "${DIR}/init_system.sh"
source "${DIR}/init_compiler.sh"



declare -g LIB_CSCMN="cscommon"
declare -g LIB_CSCMN_NAME="Codespheare Common"

# Tells the build to use the latest version available.
declare -g LIB_VERSION_LATEST="0.0.0.0"
declare -g LIB_VERSION_LATEST_SHORTHAND="dev"

declare -g LIB_CSCMN_VERSION_DEFAULT="${LIB_VERSION_LATEST}"
declare -g -a LIB_CSCMN_VERSIONS=(
    "${LIB_CSCMN_VERSION_DEFAULT}"
)

declare LIB_CSCMN_ARCHIVE_EXT="tar.bz2"
[[ "${OSTYPE}" == "${OSTYPE_MSYS}" ]] && LIB_CSCMN_ARCHIVE_EXT="7z"
declare LIB_CSCMN_ARCHIVE_EXT_ALT="zip"



declare -a LIB_CSCMN_CXX_FLAGS=()
LIB_CSCMN_CXX_FLAGS+=("-fPIC")
# LIB_SOCI_CXX_FLAGS+=("-m64")

declare -a LIB_CSCMN_CXX_COMPILE_DEFS_DEBUG=()

declare -a LIB_CSCMN_CXX_COMPILE_DEFS=()




declare -a LIB_CSCMN_FILES=()
if [[ "${OSTYPE}" == "${OSTYPE_LINUX}"* ]]; then
    LIB_CSCMN_FILES+=("lib${LIB_CSCMN}.so")
elif [[ "${OSTYPE}" == "${OSTYPE_MSYS}" ]]; then
    LIB_CSCMN_FILES+=("lib${LIB_CSCMN}.dll")
fi



declare -g DIR_CSCMN_SOURCE="lib_${LIB_CSCMN}"
declare -g DIR_CSCMN_EXTRACT
declare -g DIR_CSCMN_BUILD
declare -g DIR_CSCMN_STAGING
declare -g DIR_CSCMN_STAGING_INCLUDE
declare DIR_CSCMN_STAGING_LIB
declare DIR_CSCMN_STAGING_BIN

declare PATH_CSCMN_ARCHIVE=""

# Sets the file, path, build and staging directory variables.
#
# Arguments:
#   Library version
#   Compiler
#   Compiler version
#   C++ standard id
#   Build type
init_cscmn_build_dir () {
    local v_common_compile_string=$(init_common_compile_string ${2} ${3} ${4} ${5})

    local v_filename="${LIB_CSCMN}-${1}"
    PATH_CSCMN_ARCHIVE="${DIR_LIB}/${v_filename}.${LIB_CSCMN_ARCHIVE_EXT}"
    DIR_CSCMN_EXTRACT="${DIR_BUILD}/${v_common_compile_string}/${v_filename}"

    DIR_CSCMN_BUILD="${DIR_CSCMN_EXTRACT}/build"
    DIR_CSCMN_STAGING="${DIR_CSCMN_EXTRACT}/staging"
    DIR_CSCMN_STAGING_INCLUDE="${DIR_CSCMN_EXTRACT}/include"

    if [[ "${OSTYPE}" == "${OSTYPE_LINUX}"* ]]; then
        DIR_CSCMN_STAGING_LIB="${DIR_CSCMN_STAGING}/lib"
        DIR_CSCMN_STAGING_BIN="${DIR_CSCMN_STAGING}/bin"
    elif [[ "${OSTYPE}" == "${OSTYPE_MSYS}" ]]; then
        # TODO: Check this location
        DIR_CSCMN_STAGING_LIB="${DIR_CSCMN_STAGING}/lib"
        DIR_CSCMN_STAGING_BIN="${DIR_CSCMN_STAGING}/bin"
    fi



    rewrite_cscmn_cmake_include_file
}



# Create archive file of the source directory.
#
# Argument:
#   Library version
create_cscommon_archive () {
    if [[ "${1}" == "${LIB_VERSION_LATEST}" ]]; then
        [[ -f "${PATH_CSCMN_ARCHIVE}" ]] && rm -f "${PATH_CSCMN_ARCHIVE}"
        pushd "${DIR_SRC}/lib_${LIB_CSCMN}"
        create_archive "${PATH_CSCMN_ARCHIVE}"
        popd
    fi
}



# Extract CS Common archive.
# Sets the flag argument whether this is an initial build operation.
# Initial build operation is true when the extract directory is missing.
#
# Argument:
#   Initial build flag (reference)
# Example:
#   extract_cscommon_archive flag_initial_build
extract_cscommon_archive () {
    local -n flag=${1}
    if [[ ! -d "${DIR_CSCMN_EXTRACT}" ]]; then
        flag=1
        if [[ ! -f "${PATH_CSCMN_ARCHIVE}" ]]; then
            echo_error "Archive file not found: ${PATH_CSCMN_ARCHIVE}\nAborting."
            exit 1
        fi
        extract_archive ${PATH_CSCMN_ARCHIVE} ${DIR_CSCMN_EXTRACT}
    fi
}



# Recreate the Build and Staging directories as necessary.
# When rebuilding, the contents of the Build and Staging directories are deleted.
recreate_cscommon_build_and_staging_dirs () {
    local flag_rebuild=${1}
    if [ ${flag_rebuild} -gt 0 ]; then
        [[ -d "${DIR_CSCMN_BUILD}" ]] && rm -rf "${DIR_CSCMN_BUILD}"
        [[ -d "${DIR_CSCMN_STAGING}" ]] && rm -rf "${DIR_CSCMN_STAGING}"
    fi
    [[ ! -d "${DIR_CSCMN_BUILD}" ]] && mkdir -p "${DIR_CSCMN_BUILD}"
    [[ ! -d "${DIR_CSCMN_STAGING}" ]] && mkdir -p "${DIR_CSCMN_STAGING}"
}



# Create CMake files for use by application CMake build scripts.
rewrite_cscmn_cmake_include_file () {
    local cmake_file="${DIR_CMAKE}/${LIB_CSCMN}.cmake"
    [[ -f "${cmake_file}" ]] && rm -f "${cmake_file}"

    if [[ "${OSTYPE}" == "${OSTYPE_LINUX}"* ]]; then
        cat <<EOF > ${cmake_file}
set (CSCOMMON_INCLUDE_DIR ${DIR_CSCMN_STAGING_INCLUDE})
set (CSCOMMON_LIBRARY_DIR ${DIR_CSCMN_STAGING_LIB})
list (APPEND CSCOMMON_LIBRARY_FILES
$(echo "${LIB_CSCMN_FILES[@]}" | tr " " "\n")
)
EOF
    elif [[ "${OSTYPE}" == "${OSTYPE_MSYS}" ]]; then
        cat <<EOF > ${cmake_file}
set (CSCOMMON_INCLUDE_DIR ${DIR_CSCMN_STAGING_INCLUDE})
set (CSCOMMON_LIBRARY_DIR ${DIR_CSCMN_STAGING_LIB})
list (APPEND CSCOMMON_LIBRARY_FILES
$(echo "${LIB_CSCMN_FILES[@]}" | tr " " "\n")
)
EOF
    fi
}



# Copy CS Common library files (.so and .dll files)
# Arguments:
#   Library version
#   Destination directory
copy_cscmn_libraries () {
    local arg_version="${1}"
    local arg_dest_dir="${2}"
    local v_source_dir="${DIR_CSCMN_STAGING_BIN}"
    local v_source_file=""
    echo -e "Copying ${LIB_CSCMN_NAME} library files.\n  From: ${v_source_dir}\n  To: ${arg_dest_dir}"
    for item in "${LIB_CSCMN_FILES[@]}"; do
        if [[ "${OSTYPE}" == "${OSTYPE_LINUX}"* ]]; then
            v_source_file="${v_source_dir}/lib${item}.0.1.0"
        elif [[ "${OSTYPE}" == "${OSTYPE_MSYS}" ]]; then
            # Remove 'lib' prefix
            v_source_file="${item/lib/}"
            v_source_file="${v_source_dir}/${v_source_file}"
        fi
        if [[ ! -f "${v_source_file}" ]]; then
            echo_yellow "${LIB_CSCMN_NAME} library file not found: ${v_source_file}; skipping."
        else
            cp -u "${v_source_file}" "${arg_dest_dir}" 2>/dev/null
        fi
    done
}
