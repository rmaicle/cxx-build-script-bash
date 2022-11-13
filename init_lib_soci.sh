#!/usr/bin/env bash

# How best to include other scripts?
# https://stackoverflow.com/a/12694189/6091491
DIR="${BASH_SOURCE%/*}"
[[ ! -d "$DIR" ]] && DIR="$(pwd)"

source "${DIR}/utils.sh"
source "${DIR}/init_system.sh"
source "${DIR}/init_compiler.sh"



declare -g LIB_SOCI="soci"
declare -g LIB_SOCI_NAME="SOCI"

declare -g LIB_SOCI_VERSION_DEFAULT="4.0.3"
declare -g -a LIB_SOCI_VERSIONS=(
    "${LIB_SOCI_VERSION_DEFAULT}"
    "4.0.4"
)

declare -g LIB_SOCI_GTK_VERSION_DEFAULT=3

declare -g LIB_SOCI_ARCHIVE_EXT="tar.gz"
[[ "${OSTYPE}" == "${OSTYPE_MSYS}" ]] && LIB_SOCI_ARCHIVE_EXT="tar.gz"
declare -g LIB_SOCI_ARCHIVE_EXT_ALT="zip"

# declare -g FILENAME_SOCI_ARCHIVE
declare -g DIR_SOCI_EXTRACT
declare -g DIR_SOCI_BUILD
declare -g DIR_SOCI_STAGING
declare -g DIR_SOCI_STAGING_LIBRARY
declare -g DIR_SOCI_STAGING_LIBRARY_BIN
declare -g DIR_SOCI_STAGING_INCLUDE
# declare -a BIN_LIB_FILENAMES_SOCI=()

declare PATH_SOCI_ARCHIVE



declare -a LIB_SOCI_CXX_FLAGS=()
LIB_SOCI_CXX_FLAGS+=("-fPIC")
# LIB_SOCI_CXX_FLAGS+=("-m64")

declare -a LIB_SOCI_CXX_COMPILE_DEFS_DEBUG=()

declare -a LIB_SOCI_CXX_COMPILE_DEFS=()



declare -a LIB_SOCI_FILES=()
if [[ "${OSTYPE}" == "${OSTYPE_LINUX}"* ]]; then
    LIB_SOCI_FILES+=("libsoci_core.so.000")
    LIB_SOCI_FILES+=("libsoci_empty.so.000")
    # LIB_SOCI_FILES+=("libsoci_odbc.so")
    # LIB_SOCI_FILES+=("libsoci_postgresql.so")
    LIB_SOCI_FILES+=("libsoci_sqlite3.so.000")
elif [[ "${OSTYPE}" == "${OSTYPE_MSYS}" ]]; then
    LIB_SOCI_FILES+=("libsoci_core-000.dll")
    LIB_SOCI_FILES+=("libsoci_empty-000.dll")
    LIB_SOCI_FILES+=("libsoci_sqlite3-000.dll")
fi



# Sets the file, path, build and staging directory variables.
#
# Arguments:
#   Library version
#   Compiler
#   Compiler version
#   C++ standard id
#   Build type
#   OS type
init_soci_build_dir () {
    local v_common_compile_string=$(init_common_compile_string ${2} ${3} ${4} ${5})

    FILENAME="${LIB_SOCI}-${1}"
    FILENAME_SOCI_ARCHIVE="${FILENAME}.${LIB_SOCI_ARCHIVE_EXT}"
    PATH_SOCI_ARCHIVE="${DIR_LIB}/${FILENAME_SOCI_ARCHIVE}"
    DIR_SOCI_EXTRACT="${DIR_BUILD}/${v_common_compile_string}/${FILENAME}"

    DIR_SOCI_BUILD="${DIR_SOCI_EXTRACT}/build"
    DIR_SOCI_STAGING="${DIR_SOCI_EXTRACT}/staging"

    DIR_SOCI_STAGING_INCLUDE_CONFIG="${DIR_SOCI_BUILD}/include"
    DIR_SOCI_STAGING_INCLUDE="${DIR_SOCI_EXTRACT}/include"
    DIR_SOCI_STAGING_LIBRARY="${DIR_SOCI_BUILD}/lib"

    if [[ "${OSTYPE}" == "${OSTYPE_LINUX}"* ]]; then
        DIR_SOCI_STAGING_LIBRARY_BIN="${DIR_SOCI_BUILD}/lib"
    elif [[ "${OSTYPE}" == "${OSTYPE_MSYS}" ]]; then
        DIR_SOCI_STAGING_LIBRARY_BIN="${DIR_SOCI_BUILD}/bin"
    fi

    rewrite_soci_cmake_include_file "${1}"
}



# Extract SOCI archive.
# Sets the flag argument whether this is an initial build operation.
# Initial build operation is true when the extract directory is missing.
extract_soci_archive () {
    local -n flag=${1}
    if [[ ! -d "${DIR_SOCI_EXTRACT}" ]]; then
        flag=1
        if [[ ! -f "${PATH_SOCI_ARCHIVE}" ]]; then
            echo_error "Archive file not found: ${PATH_SOCI_ARCHIVE}\nAborting."
            exit 1
        fi
        extract_archive ${PATH_SOCI_ARCHIVE} $(dirname ${DIR_SOCI_EXTRACT})
    fi
}



# Recreate the Build and Staging directories as necessary.
# When rebuilding, the contents of the Build and Staging directories are deleted.
recreate_soci_build_and_staging_dirs () {
    # MSYS NOTE: Staging directory not used.
    if [ ${1} -gt 0 ]; then
        [[ -d "${DIR_SOCI_BUILD}" ]] && rm -rf "${DIR_SOCI_BUILD}"
        [[ -d "${DIR_SOCI_STAGING}" ]] && rm -rf "${DIR_SOCI_STAGING}"
    fi
    [[ ! -d "${DIR_SOCI_BUILD}" ]] && mkdir -p ${DIR_SOCI_BUILD}
    [[ ! -d "${DIR_SOCI_STAGING}" ]] && mkdir -p ${DIR_SOCI_STAGING}
}



# Create CMake files for use by application CMake build scripts.
rewrite_soci_cmake_include_file () {
    declare -a files=()
    if [[ "${OSTYPE}" == "${OSTYPE_LINUX}"* ]]; then
        for item in "${LIB_SOCI_FILES[@]}"; do
            files+=("${item/000/${1}}")
        done
    elif [[ "${OSTYPE}" == "${OSTYPE_MSYS}" ]]; then
        for item in "${LIB_SOCI_FILES[@]}"; do
            files+=("${item/-000/}")
        done
    fi
    local cmake_file="${DIR_CMAKE}/${LIB_SOCI}.cmake"
    [[ -f "${cmake_file}" ]] && rm -f "${cmake_file}"
    cat <<EOF > ${cmake_file}
set (SOCI_CONFIG_INCLUDE_DIR ${DIR_SOCI_STAGING_INCLUDE_CONFIG})
set (SOCI_INCLUDE_DIR ${DIR_SOCI_STAGING_INCLUDE})
set (SOCI_LIBRARY_DIR ${DIR_SOCI_STAGING_LIBRARY})
list (APPEND SOCI_LIBRARY_FILES
$(echo "${files[@]}" | tr ' ' '\n')
)
EOF
}



# Copy SOCI library files (.so and .dll files)
#
# Arguments:
#   Library version
#   Source directory
#   Destination directory
copy_soci_libraries () {
    local arg_lib_version="${1}"
    local arg_dest_dir="${2}"
    local v_source_dir="${DIR_SOCI_STAGING_LIBRARY_BIN}"
    local v_source_file=""
    local v_prefix=""
    echo -e "Copying ${LIB_SOCI_NAME} library files.\n  From: ${v_source_dir}\n  To: ${arg_dest_dir}"
    [[ "${OSTYPE}" == "${OSTYPE_MSYS}" ]] && v_prefix="${OSTYPE_MSYS,,}"
    for item in "${LIB_SOCI_FILES[@]}"; do
        if [[ "${OSTYPE}" == "${OSTYPE_LINUX}"* ]]; then
            v_source_file="${v_source_dir}/${item/000/${arg_lib_version}}"
        elif [[ "${OSTYPE}" == "${OSTYPE_MSYS}" ]]; then
            # MSYS: Remove OS-specific prefix
            v_source_file="${v_prefix}-${item/lib/}"
            v_source_file="${v_source_dir}/${v_source_file/000/${arg_lib_version%.*}}"
        fi
        if [[ ! -f "${v_source_file}" ]]; then
            echo_error "${LIB_SOCI_NAME} library file does not exist: ${v_source_file}\nAborting."
            exit 1
        fi
        cp -u "${v_source_file}" "${arg_dest_dir}" 2>/dev/null
    done
}
