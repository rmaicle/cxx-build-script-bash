#!/usr/bin/env bash

# How best to include other scripts?
# https://stackoverflow.com/a/12694189/6091491
DIR="${BASH_SOURCE%/*}"
[[ ! -d "$DIR" ]] && DIR="$(pwd)"

source "${DIR}/init_system.sh"
source "${DIR}/utils.sh"



declare -g TOOL_PGMODELER="pgmodeler"
declare -g TOOL_POSTGRESQL="postgresql"
declare -g TOOL_SQLITE="sqlite"

declare -g -a TOOLS=(
    "${TOOL_PGMODELER}"
    "${TOOL_POSTGRESQL}"
    "${TOOL_SQLITE}"
)

declare -g TOOL_PGMODELER_NAME="pgModeler"
declare -g TOOL_POSTGRESQL_NAME="PostgreSQL"
declare -g TOOL_SQLITE_NAME="SQLite"

declare -g TOOL_PGMODELER_VERSION_DEFAULT="0.9.3"
declare -g -a TOOL_PGMODELER_VERSIONS=(
    "${TOOL_PGMODELER_VERSION_DEFAULT}"
    "0.9.4"
)

declare -g TOOL_POSTGRESQL_VERSION_DEFAULT="14.2"
declare -g -a TOOL_POSTGRESQL_VERSIONS=(
    "${TOOL_POSTGRESQL_VERSION_DEFAULT}"
)

declare -g TOOL_SQLITE_VERSION_DEFAULT="3.35.5"
declare -g -a TOOL_SQLITE_VERSIONS=(
    "${TOOL_SQLITE_VERSION_DEFAULT}"
    "3.36.0"
)



# Return the default version for the specified tool
# Argument:
#   Tool
get_tool_default_version () {
    if [[ $# -eq 0 ]]; then
        echo_error "Missing tool  argument to get_tool_default_version().\nAborting."
        exit 1
    fi
    local v_var_name="TOOL_${1^^}_VERSION_DEFAULT"
    echo "${!v_var_name}"
}



declare -g -a TOOL_IDS=()
for item in "${TOOL_PGMODELER_VERSIONS[@]}"; do
    TOOL_IDS+=("${TOOL_PGMODELER}:${item}")
done
for item in "${TOOL_POSTGRESQL_VERSIONS[@]}"; do
    TOOL_IDS+=("${TOOL_POSTGRESQL}:${item}")
done
for item in "${TOOL_SQLITE_VERSIONS[@]}"; do
    TOOL_IDS+=("${TOOL_SQLITE}:${item}")
done



declare -g TOOL_PGMODELER_ARCHIVE_EXT="tar.gz"
declare -g TOOL_POSTGRESQL_ARCHIVE_EXT="tar.bz2"
declare -g TOOL_SQLITE_ARCHIVE_EXT="zip"
# Alternative extension
declare -g TOOL_PGMODELER_ARCHIVE_EXT_ALT="tar.gz"
declare -g TOOL_POSTGRESQL_ARCHIVE_EXT_ALT="tar.gz"
declare -g TOOL_SQLITE_ARCHIVE_EXT_ALT="zip"



declare -g -A TOOL_PGMODELER_ARCHIVES=()
declare -g -A TOOL_PGMODELER_ARCHIVES_ALT=()
declare -g -A TOOL_PGMODELER_EXTRACT_NAME=()
declare -g -A TOOL_PGMODELER_BUILD_BASE_DIR=()
# declare -g -A TOOL_PGMODELER_STAGING_BASE_DIR=()
for item in "${TOOL_PGMODELER_VERSIONS[@]}"; do
    TOOL_PGMODELER_ARCHIVES[${item}]="${TOOL_PGMODELER}-${item}.${TOOL_PGMODELER_ARCHIVE_EXT}"
    TOOL_PGMODELER_ARCHIVES_ALT[${item}]="${TOOL_PGMODELER}-${item}.${TOOL_PGMODELER_ARCHIVE_EXT_ALT}"
    TOOL_PGMODELER_EXTRACT_NAME[${item}]="${TOOL_PGMODELER}-${item}"
    if [[ "${OSTYPE}" == "${OSTYPE_LINUX}"* ]]; then
        TOOL_PGMODELER_BUILD_BASE_DIR[${item}]="${TOOL_PGMODELER_EXTRACT_NAME[${item}]}"
        # TOOL_PGMODELER_STAGING_BASE_DIR[${item}]="${TOOL_PGMODELER_EXTRACT_NAME[${item}]}/staging"
    elif [[ "${OSTYPE}" == "${OSTYPE_MSYS}" ]]; then
        TOOL_PGMODELER_BUILD_BASE_DIR[${item}]="${TOOL_PGMODELER_EXTRACT_NAME[${item}]}"
        # TOOL_PGMODELER_STAGING_BASE_DIR[${item}]="${TOOL_PGMODELER_EXTRACT_NAME[${item}]}/staging"
    fi
done

# Argument(s):
#   Tool version
get_pgmodeler_archive_path () {
    echo "${TOOL_PGMODELER}-${1}.${TOOL_PGMODELER_ARCHIVE_EXT}"
}

# Argument(s):
#   Root directory
#   Tool version
#   Build type
#   Compiler
#   Compiler version
#   C++ standard id
get_pgmodeler_extract_dir () {
    local v_dir_compile_info=$(get_app_dir_suffix ${3} ${4,,} ${5} ${6})
    echo "${1}/${v_dir_compile_info}/${TOOL_PGMODELER}-${2}"
}

# Argument:
#   Root directory
#   Application version
#   Build type
#   Compiler
#   Compiler version
#   C++ standard id
get_pgmodeler_build_dir () {
    local v_dir_compile_info=$(get_app_dir_suffix ${3} ${4,,} ${5} ${6})
    echo "${1}/${v_dir_compile_info}/${TOOL_PGMODELER}-${2}"
}

# Return staging directory.
# Argument:
#   Root directory
#   Application version
#   Build type
#   Compiler
#   Compiler version
#   C++ standard id
get_pgmodeler_staging_dir () {
    local v_dir_compile_info=$(get_app_dir_suffix ${3} ${4,,} ${5} ${6})
    echo "${1}/${v_dir_compile_info}/${TOOL_PGMODELER}-${2}/staging"
}

# Argument:
#   Archive path
#   Destination directory
extract_pgmodeler_archive () {
    echo "Extracting $(basename ${1}) to ${2}"
    [[ ! -d "${2}" ]] && mkdir -p "${2}"
    tar -xf "${1}" --directory "${2}"
    echo "Archive extracted."
}

declare -g -A TOOL_POSTGRESQL_ARCHIVES=()
declare -g -A TOOL_POSTGRESQL_ARCHIVES_ALT=()
declare -g -A TOOL_POSTGRESQL_EXTRACT_NAME=()
declare -g -A TOOL_POSTGRESQL_BUILD_BASE_DIR=()
# declare -g -A TOOL_POSTGRESQL_STAGING_BASE_DIR=()
declare -g -A TOOL_POSTGRESQL_INCLUDE_DIR=()
declare -g -A TOOL_POSTGRESQL_LIBRARY_DIR=()
for item in "${TOOL_POSTGRESQL_VERSIONS[@]}"; do
    TOOL_POSTGRESQL_ARCHIVES[${item}]="${TOOL_POSTGRESQL}-${item}.${TOOL_POSTGRESQL_ARCHIVE_EXT}"
    TOOL_POSTGRESQL_ARCHIVES_ALT[${item}]="${TOOL_POSTGRESQL}-${item}.${TOOL_POSTGRESQL_ARCHIVE_EXT_ALT}"
    TOOL_POSTGRESQL_EXTRACT_NAME[${item}]="${TOOL_POSTGRESQL}-${item}"
    if [[ "${OSTYPE}" == "${OSTYPE_LINUX}"* ]]; then
        TOOL_POSTGRESQL_BUILD_BASE_DIR[${item}]="${TOOL_POSTGRESQL_EXTRACT_NAME[${item}]}"
        # TOOL_POSTGRESQL_STAGING_BASE_DIR[${item}]="${TOOL_POSTGRESQL_EXTRACT_NAME[${item}]}/staging"
    elif [[ "${OSTYPE}" == "${OSTYPE_MSYS}" ]]; then
        TOOL_POSTGRESQL_BUILD_BASE_DIR[${item}]="${TOOL_POSTGRESQL_EXTRACT_NAME[${item}]}"
        # TOOL_POSTGRESQL_STAGING_BASE_DIR[${item}]="${TOOL_POSTGRESQL_EXTRACT_NAME[${item}]}/staging"
    fi
    # TOOL_POSTGRESQL_INCLUDE_DIR[${item}]="TOOL_POSTGRESQL_STAGING_BASE_DIR[${item}]/lib"
    # TOOL_POSTGRESQL_LIBRARY_DIR[${item}]="TOOL_POSTGRESQL_STAGING_BASE_DIR[${item}]/lib"
done

# Argument(s):
#   Tool version
get_postgresql_archive_path () {
    echo "${TOOL_POSTGRESQL}-${1}.${TOOL_POSTGRESQL_ARCHIVE_EXT}"
}

# Argument(s):
#   Root directory
#   Tool version
#   Build type
#   Compiler
#   Compiler version
#   C++ standard id
get_postgresql_extract_dir () {
    local v_dir_compile_info=$(get_app_dir_suffix ${3} ${4,,} ${5} ${6})
    echo "${1}/${v_dir_compile_info}/${TOOL_POSTGRESQL}-${2}"
}

# Argument:
#   Extract directory
# get_postgresql_build_dir () {
#     if [[ "${OSTYPE}" == "${OSTYPE_LINUX}"* ]]; then
#         echo "${1}"
#     elif [[ "${OSTYPE}" == "${OSTYPE_MSYS}" ]]; then
#         echo "${1}"
#     fi
# }

# Argument:
#   Root directory
#   Application version
#   Build type
#   Compiler
#   Compiler version
#   C++ standard id
get_postgresql_build_dir () {
    local v_dir_compile_info=$(get_app_dir_suffix ${3} ${4,,} ${5} ${6})
    echo "${1}/${v_dir_compile_info}/${TOOL_POSTGRESQL}-${2}/build"
}

# Return staging directory.
# Argument:
#   Root directory
#   Application version
#   Build type
#   Compiler
#   Compiler version
#   C++ standard id
get_postgresql_staging_dir () {
    local v_dir_compile_info=$(get_app_dir_suffix ${3} ${4,,} ${5} ${6})
    echo "${1}/${v_dir_compile_info}/${TOOL_POSTGRESQL}-${2}/staging"
}

# Argument:
#   Archive path
#   Destination directory
extract_postgresql_archive () {
    echo "Extracting $(basename ${1}) to ${2}"
    [[ ! -d "${2}" ]] && mkdir -p "${2}"
    tar --bzip2 -xf "${1}" --directory "${2}"
    echo "Archive extracted."
}

declare -g -A TOOL_SQLITE_ARCHIVES=()
declare -g -A TOOL_SQLITE_ARCHIVES_ALT=()
declare -g -A TOOL_SQLITE_EXTRACT_NAME=()
declare -g -A TOOL_SQLITE_BUILD_BASE_DIR=()
# declare -g -A TOOL_SQLITE_STAGING_BASE_DIR=()
for item in "${TOOL_SQLITE_VERSIONS[@]}"; do
    TOOL_SQLITE_ARCHIVES[${item}]="${TOOL_SQLITE}-${item}.${TOOL_SQLITE_ARCHIVE_EXT}"
    TOOL_SQLITE_ARCHIVES_ALT[${item}]="${TOOL_SQLITE}-${item}.${TOOL_SQLITE_ARCHIVE_EXT_ALT}"
    TOOL_SQLITE_EXTRACT_NAME[${item}]="${TOOL_SQLITE}-${item}"
    if [[ "${OSTYPE}" == "${OSTYPE_LINUX}"* ]]; then
        TOOL_SQLITE_BUILD_BASE_DIR[${item}]="${TOOL_SQLITE_EXTRACT_NAME[${item}]}"
        # TOOL_SQLITE_STAGING_BASE_DIR[${item}]="${TOOL_SQLITE_EXTRACT_NAME[${item}]}/staging"
    elif [[ "${OSTYPE}" == "${OSTYPE_MSYS}" ]]; then
        TOOL_SQLITE_BUILD_BASE_DIR[${item}]="${TOOL_SQLITE_EXTRACT_NAME[${item}]}"
        # TOOL_SQLITE_STAGING_BASE_DIR[${item}]="${TOOL_SQLITE_EXTRACT_NAME[${item}]}/staging"
    fi
done



# Return staging directory.
# Arguments:
#   root directory
#   tool
#   tool version
#   build type
#   compiler
#   compiler version
#   c++ standard id
get_staging_dir () {
    local v_var_name="TOOL_${2^^}_STAGING_BASE_DIR[${3}]"
    local v_dir_suffix=$(get_app_dir_suffix ${4} ${5,,} ${6} ${7})
    echo "${1}/${!v_var_name}/${v_dir_suffix}"
}



declare -a LIB_PGMODELER_CXX_FLAGS=()
LIB_PGMODELER_CXX_FLAGS+=("-fPIC")
LIB_PGMODELER_CXX_FLAGS+=("-m64")

declare -a LIB_POSTGRESQL_CXX_FLAGS=()
LIB_POSTGRESQL_CXX_FLAGS+=("-fPIC")
LIB_POSTGRESQL_CXX_FLAGS+=("-m64")

declare -a LIB_SQLITE_CXX_FLAGS=()
LIB_SQLITE_CXX_FLAGS+=("-fPIC")
LIB_SQLITE_CXX_FLAGS+=("-m64")




# Arguments:
#   Compiler
#   Compiler version
#   C++ standard
#   Use gold linker flag
#     [0=do not use gold linker, 1=use gold linker]
#     By default, gold linker flag is set.
get_pgmodeler_link_flags () {
    if [[ $# -lt 3 ]]; then
        echo_error "Missing argument to get_link_flags().\nAborting."
        exit 1
    fi
    local v_use_gold_linker=1
    [[ $# -eq 4 ]] && v_use_gold_linker="${4}"
    local v_flags=()

    v_flags+=("-std=${3}")
    v_flags+=("-L.")
    if [[ "${1}" == "${COMPILER_GCC}" ]]; then
        if [[ "${OSTYPE}" == "${OSTYPE_LINUX}"* ]]; then
            [[ ${v_use_gold_linker} -eq 1 ]] && v_flags+=("-fuse-ld=gold")
        fi
        v_flags+=("-L${COMPILER_LIB64_DIR}")
    elif [[ "${1}" == "${COMPILER_CLANG}" ]]; then
        # v_flags+=("-stdlib=libstdc++")
        v_flags+=("-L${COMPILER_LIB64_DIR}")
    fi
    # if [[ "${OSTYPE}" == "${OSTYPE_LINUX}"* ]]; then
        # Qt Library file location used when building pgModeler
        # This should be specified after the compiler library directory
        # otherwise, the compiler library of the system compiler in
        # /usr/lib will be used.
        # v_flags+=("-L/usr/lib")
    # fi
    echo "${v_flags[@]}"
}
