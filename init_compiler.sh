#!/usr/bin/env bash

# How best to include other scripts?
# https://stackoverflow.com/a/12694189/6091491
DIR="${BASH_SOURCE%/*}"
[[ ! -d "$DIR" ]] && DIR="$(pwd)"

# echo "init_compiler.sh"
# echo "DIR: ${DIR}"

source "${DIR}/echo.sh"
source "${DIR}/utils.sh"
source "${DIR}/init_system.sh"



declare -g flag_init_compiler=0



declare -g COMPILER_TYPE_GNU="gnu"
declare -g COMPILER_TYPE_CLANG="clang"

# Last compiler is the default
declare -g -a COMPILER_TYPES=(
    "${COMPILER_TYPE_CLANG}"
    "${COMPILER_TYPE_GNU}"
)

declare -g COMPILER_GCC="gcc"
declare -g COMPILER_CLANG="clang"

declare -g COMPILER_DEFAULT="${COMPILER_GCC}"
declare -g -a COMPILERS=(
    "${COMPILER_GCC}"
    "${COMPILER_CLANG}"
)

declare -g COMPILER_NONE="0.0.0"

# NOTE: Last item will be chosen when incomplete compiler ID is provided
#       Example, user passes 'gcc' as compiler ID
declare -g COMPILER_GCC_VERSION_SYSTEM="$(gcc -dumpversion)"
declare -g COMPILER_GCC_VERSION_DEFAULT="${COMPILER_GCC_VERSION_SYSTEM}"
declare -g -a COMPILER_GCC_VERSIONS=(
    "${COMPILER_GCC_VERSION_SYSTEM}"
)

# NOTE: Last item will be chosen when incomplete compiler ID is provided
#       Example, user passes 'clang' as compiler ID
declare -g COMPILER_CLANG_VERSION_SYSTEM="${COMPILER_NONE}"
if command -v clang &> /dev/null; then
    COMPILER_CLANG_VERSION_SYSTEM="$(clang -dumpversion)"
fi
declare -g COMPILER_CLANG_VERSION_DEFAULT=""
declare -g -a COMPILER_CLANG_VERSIONS=()
if [[ "${COMPILER_CLANG_VERSION_SYSTEM}" != "${COMPILER_NONE}" ]]; then
    COMPILER_CLANG_VERSION_DEFAULT="${COMPILER_CLANG_VERSION_SYSTEM}"
    COMPILER_CLANG_VERSIONS+=("${COMPILER_CLANG_VERSION_DEFAULT}")
fi

declare -g -A COMPILER_DEFAULT_VERSION=(
    [${COMPILER_GCC}]=${COMPILER_GCC_VERSION_DEFAULT}
    [${COMPILER_CLANG}]=${COMPILER_CLANG_VERSION_DEFAULT}
)

# Concatenate arguments separated by a colon.
# Arguments:
#   Compiler name
#   Compiler version
# Example:
#   create_compiler_id ${COMPILER_GCC} ${COMPILER_GCC_VERSIONS[0]}
#   gcc:9.4.0
create_compiler_id () {
    echo "${1}:${2}"
}

# Get compiler type from a Compiler ID.
# Same as v="${1%%:*}"
get_compiler_type () {
    echo "${1%%:*}"
}

# Get compiler version from a Compiler ID.
# Same as v="${1##*:}"
get_compiler_version () {
    echo "${1##*:}"
}

# declare -g -a COMPILER_IDS=(
#     $(create_compiler_id ${COMPILER_CLANG} ${COMPILER_CLANG_VERSIONS[0]})
#     $(create_compiler_id ${COMPILER_CLANG} ${COMPILER_CLANG_VERSIONS[1]})
#     $(create_compiler_id ${COMPILER_GCC}   ${COMPILER_GCC_VERSIONS[0]})
#     $(create_compiler_id ${COMPILER_GCC}   ${COMPILER_GCC_VERSIONS[1]})
# )
declare -g -a COMPILER_IDS=()
for item in "${COMPILER_GCC_VERSIONS[@]}"; do
    COMPILER_IDS+=("${COMPILER_GCC}:${item}")
done
for item in "${COMPILER_CLANG_VERSIONS[@]}"; do
    COMPILER_IDS+=("${COMPILER_CLANG}:${item}")
done



declare -g BUILD_TYPE_DEBUG="debug"
declare -g BUILD_TYPE_RELEASE="release"
declare -g BUILD_TYPE_OPTIMIZED="optimized"
declare -g BUILD_TYPE_DEFAULT="${BUILD_TYPE_DEBUG}"

# Last item is the default
declare -g BUILD_TYPES=(
    "${BUILD_TYPE_DEBUG}"
    "${BUILD_TYPE_RELEASE}"
    "${BUILD_TYPE_OPTIMIZED}"
)



# wxWidgets support only until c++17
declare -g CXX_STD_20="c++20"
declare -g CXX_STD_17="c++17"
declare -g CXX_STD_14="c++14"
declare -g CXX_STD_DEFAULT="${CXX_STD_17}"

# Last item is the default
declare -g -a CXX_STANDARDS=(
    "${CXX_STD_14}"
    "${CXX_STD_17}"
    "${CXX_STD_20}"
)



# # Return the default version for the specified compiler
# # Argument:
# #   Compiler - COMPILER_GCC | COMPILER_CLANG
# get_compiler_default_version () {
#     if [[ $# -eq 0 ]]; then
#         echo_error "Missing compiler argument to get_compiler_default_version().\nAborting."
#         exit 1
#     fi
#     local v_var_name="COMPILER_${1^^}_VERSION_DEFAULT"
#     echo "${!v_var_name}"
# }

# Return the system version for the specified compiler
# Argument:
#   Compiler - COMPILER_GCC | COMPILER_CLANG
get_compiler_system_version () {
    if [[ $# -eq 0 ]]; then
        echo_error "Missing compiler argument to get_compiler_default_version().\nAborting."
        exit 1
    fi
    local v_var_name="COMPILER_${1^^}_VERSION_SYSTEM"
    echo "${!v_var_name}"
}



# Return the compiler root directory.
# Arguments:
#   Compiler
#   Compiler version
get_compiler_root_dir () {
    local v_dir="/usr"
    if [[ "${1}" == "${COMPILER_GCC}" ]]; then
        if [[ "${OSTYPE}" == "${OSTYPE_LINUX}"* ]]; then
            [[ "${COMPILER_VERSION}" != "${COMPILER_GCC_VERSION_SYSTEM}" ]] && v_dir="/mnt/work/usr/local"
        elif [[ "${OSTYPE}" == "${OSTYPE_MSYS}" ]]; then
            v_dir="/mingw64"
        fi
    elif [[ "${1}" == "${COMPILER_CLANG}" ]]; then
        if [[ "${OSTYPE}" == "${OSTYPE_LINUX}"* ]]; then
            [[ "${COMPILER_VERSION}" != "${COMPILER_GCC_VERSION_SYSTEM}" ]] && v_dir="/mnt/work/usr/local"
        elif [[ "${OSTYPE}" == "${OSTYPE_MSYS}" ]]; then
            # TODO: Determine root directory when using Clang on MSYS
            v_dir=""
        fi
    fi
    echo "${v_dir}"
}


# Sets the following compiler-related variables:
#   COMPILER_ID
#   COMPILER_VERSION
#   COMPILER_NAME
#   COMPILER_C_BIN
#   COMPILER_CXX_BIN
#   COMPILER_INCLUDE_DIR
#   COMPILER_LIB64_DIR
# Argument(s):
#   Compiler version
#
# Library path in GCC
# https://transang.me/library-path-in-gcc/
#   echo | gcc -x c -E -Wp,-v - >/dev/null
#   echo | gcc -x c++ -E -Wp,-v - >/dev/null
#
init_gcc_compiler_vars () {
    if [[ $# -eq 0 ]]; then
        echo_error "Missing argument to init_gcc_compiler_vars().\nAborting."
        exit 1
    fi
    declare -g COMPILER_VERSION="${1}"

    local v_gcc_bin="gcc-${COMPILER_VERSION}"
    [[ "${COMPILER_VERSION}" == "${COMPILER_GCC_VERSION_SYSTEM}" ]] && v_gcc_bin="gcc"
    if ! command -v ${v_gcc_bin} &> /dev/null
    then
        echo_error "Compiler not found: ${COMPILER_GCC^^} ${COMPILER_VERSION}\nAborting."
        exit 1
    fi

    declare -g COMPILER_TYPE="${COMPILER_TYPE_GNU^^}"
    declare -g COMPILER_ID="${COMPILER_GCC}:${COMPILER_VERSION}"
    declare -g COMPILER_NAME="${COMPILER_GCC}-${COMPILER_VERSION}"

    declare -g COMPILER_C_BIN="$(command -v ${v_gcc_bin})"
    if [[ -z "${COMPILER_C_BIN}" ]]; then
        echo_error "${COMPILER_NAME} compiler not found."
        exit 1
    fi

    local v_gpp_bin="g++-${COMPILER_VERSION}"
    [[ "${COMPILER_VERSION}" == "${COMPILER_GCC_VERSION_SYSTEM}" ]] && v_gpp_bin="g++"
    declare -g COMPILER_CXX_BIN="$(command -v ${v_gpp_bin})"
    if [[ -z "${COMPILER_CXX_BIN}" ]]; then
        echo_error "${COMPILER_GCC^^} version ${COMPILER_VERSION} not found."
        exit 1
    fi

    local v_compiler_root_dir="$(get_compiler_root_dir ${COMPILER_GCC} ${COMPILER_VERSION})"
    declare -g COMPILER_INCLUDE_DIR="${v_compiler_root_dir}/include/c++/${COMPILER_VERSION}"
    if [[ "${OSTYPE}" == "${OSTYPE_LINUX}"* ]]; then
        if [[ "${COMPILER_VERSION}" != "${COMPILER_GCC_VERSION_SYSTEM}" ]]; then
            COMPILER_INCLUDE_DIR="${v_compiler_root_dir}/${COMPILER_NAME}/include/c++/${COMPILER_VERSION}"
        fi
    elif [[ "${OSTYPE}" == "${OSTYPE_MSYS}" ]]; then
        COMPILER_INCLUDE_DIR="${v_compiler_root_dir}/include/c++/${COMPILER_VERSION}"
    fi
    if [[ ! -d "${COMPILER_INCLUDE_DIR}" ]]; then
        echo_error "Include directory not found: ${COMPILER_INCLUDE_DIR}"
        exit 1
    fi
    declare -g COMPILER_LIB64_DIR="${v_compiler_root_dir}/lib"
    if [[ "${OSTYPE}" == "${OSTYPE_LINUX}"* ]]; then
        if [[ "${COMPILER_VERSION}" != "${COMPILER_GCC_VERSION_SYSTEM}" ]]; then
            COMPILER_LIB64_DIR="${v_compiler_root_dir}/${COMPILER_NAME}/lib64"
        fi
    elif [[ "${OSTYPE}" == "${OSTYPE_MSYS}" ]]; then
        COMPILER_LIB64_DIR="${v_compiler_root_dir}/lib/gcc/x86_64-w64-mingw32/${COMPILER_VERSION}"
    fi
    if [[ ! -d "${COMPILER_LIB64_DIR}" ]]; then
        echo_error "64-bit library directory not found: ${COMPILER_LIB64_DIR}"
        exit 1
    fi
}



# Sets the following compiler-related variables:
#   COMPILER_ID
#   COMPILER_VERSION
#   COMPILER_NAME
#   COMPILER_ARCHIVE_FILENAME
#   COMPILER_C_BIN
#   COMPILER_CXX_BIN
#   COMPILER_INCLUDE_DIR
#   COMPILER_LIB64_DIR
init_clang_compiler_vars () {
    if [[ $# -eq 0 ]]; then
        echo_error "Missing argument to init_clang_compiler_vars()."
        exit 1
    fi
    declare -g COMPILER_VERSION="${1}"

    # Check that the compiler version exists
    if [[ "${OSTYPE}" == "${OSTYPE_LINUX}"* ]]; then
        if ! command -v clang-${COMPILER_VERSION%%.*} &> /dev/null
        then
            echo_error "Compiler not found: ${COMPILER_CLANG^^} ${COMPILER_VERSION}\nAborting."
            exit 1
        fi
    fi

    declare -g COMPILER_ID="$(create_compiler_id ${COMPILER_CLANG} ${COMPILER_VERSION})"
    declare -g COMPILER_NAME="${COMPILER_CLANG}-${COMPILER_VERSION}"
    declare -g COMPILER_C_BIN=$(command -v ${COMPILER_CLANG}-${COMPILER_VERSION%%.*})
    echo "clang COMPILER_C_BIN: ${COMPILER_C_BIN}"
    if [[ -z "${COMPILER_C_BIN}" ]]; then
        echo_error "${COMPILER_NAME} compiler not found."
        exit 1
    fi
    declare -g COMPILER_CXX_BIN=$( command -v ${COMPILER_CLANG}-${COMPILER_VERSION%%.*})
    if [[ -z "${COMPILER_CXX_BIN}" ]]; then
        echo_error "${COMPILER_CLANG}-${COMPILER_VERSION} compiler not found."
        exit 1
    fi

    local v_compiler_root_dir="$(get_compiler_root_dir ${COMPILER_CLANG} ${COMPILER_VERSION})"
    declare -g COMPILER_INCLUDE_DIR="${v_compiler_root_dir}/include/c++/${COMPILER_VERSION}"
    if [[ "${COMPILER_VERSION}" != "${COMPILER_CLANG_VERSION_SYSTEM}" ]]; then
        COMPILER_INCLUDE_DIR="${v_compiler_root_dir}/${COMPILER_CLANG}-${COMPILER_VERSION}/include/c++/${COMPILER_VERSION}"
    fi

    declare -g COMPILER_LIB64_DIR="${v_compiler_root_dir}/lib"
    if [[ "${OSTYPE}" == "${OSTYPE_LINUX}"* ]]; then
        if [[ "${COMPILER_VERSION}" != "${COMPILER_CLANG_VERSION_SYSTEM}" ]]; then
            COMPILER_LIB64_DIR="${v_compiler_root_dir}/${COMPILER_NAME}/lib64"
        fi
    elif [[ "${OSTYPE}" == "${OSTYPE_MSYS}" ]]; then
        # TODO: Determine clang library directory when using msys.
        COMPILER_LIB64_DIR=""
    fi
}



# Sets the following compiler-related variables:
#   COMPILER_ID
#   COMPILER_VERSION
#   COMPILER_NAME
#   COMPILER_ARCHIVE_FILENAME
#   COMPILER_C_BIN
#   COMPILER_CXX_BIN
#   COMPILER_INCLUDE_DIR
#   COMPILER_LIB64_DIR
# Arguments:
#   Compiler
#   Compiler version
init_compiler_vars () {
    if [[ $# -lt 2 ]]; then
        echo_error "Missing argument(s) to init_compiler_vars()."
        exit 1
    fi
    if [[ "${1}" == "${COMPILER_GCC}" ]]; then
        init_gcc_compiler_vars "${2}"
    elif [[ "${1}" == "${COMPILER_CLANG}" ]]; then
        init_clang_compiler_vars "${2}"
    else
        echo_error "Unrecognized compiler: ${1}\nAborting."
        exit 1
    fi
}



# Arguments:
#   Compiler
#   Compiler version
#   Build type
#   C++ standard (number only)
#     Example, for c++17, the argument must be '17' without the quote marks.
get_compile_flags () {
    if [[ $# -lt 4 ]]; then
        echo_error "Missing argument to get_compiler_flags().\nAborting."
        exit 1
    fi
    local v_compiler="${1}"
    local v_compiler_version="${2}"
    local v_build_type="${3}"
    local v_cxx_std="${4}"
    local v_flags=()

    v_flags+=("-std=${4}")
    v_flags+=("-fPIC")
    v_flags+=("-I${COMPILER_INCLUDE_DIR}")
    # if [[ "${OSTYPE}" == "${OSTYPE_MSYS}" ]]; then
    #     v_flags+=("-I/mingw64/include/glib-2.0")
    # fi

    if [[ "${OSTYPE}" == "${OSTYPE_MSYS}" ]]; then
        v_flags+=("-D__USE_MINGW_ANSI_STDIO=1")
    fi

    if [[ "${v_compiler}" == "${COMPILER_GCC}" ]]; then
        # v_flags+=("-m64")
        # v_flags+=("-march=native")
        # v_flags+=("-fcolor-diagnostics")
        # v_flags+=("-ferror-limit=5")
        # v_flags+=("-fno-rtti")
        # v_flags+=("-fvisibility-inlines-hidden")
        # v_flags+=("-fsanitize=address")
        # v_flags+=("-fsanitize=bounds-strict")
        v_flags+=("-I/usr/include/gtk-3.0/unix-print")
        v_flags+=("-Wl,-rpath")
        v_flags+=("-Wl,${COMPILER_LIB64_DIR}")
        v_flags+=("-L${COMPILER_LIB64_DIR}")
        if [[ "${v_build_type}" == "${BUILD_TYPE_DEBUG}" ]]; then
            # 3.10 Options for Debugging Your Program
            # https://gcc.gnu.org/onlinedocs/gcc/Debugging-Options.html
            v_flags+=("-g")
            # Verbose debug info
            # v_flags+=("-g3")
            # v_flags+=("-Og")
        elif [[ "${v_build_type}" == "${BUILD_TYPE_RELEASE}" ]]; then
            v_flags+=("-O2")
            v_flags+=("-flto")
            # v_flags+=("-flto=4")
            v_flags+=("-Xlinker")
        elif [[ "${v_build_type}" == "${BUILD_TYPE_OPTIMIZED}" ]]; then
            echo "TODO."
            exit
        fi
    elif [[ "${1}" == "${COMPILER_CLANG}" ]]; then
        # v_flags+=("-stdlib=libstdc++")
        if [[ "${v_build_type}" == "${BUILD_TYPE_DEBUG}" ]]; then
            v_flags+=("-O0")
        elif [[ "${v_build_type}" == "${BUILD_TYPE_RELEASE}" ]]; then
            v_flags+=("-O3")
            v_flags+=("-Ofast")
            v_flags+=("-flto")
        elif [[ "${v_build_type}" == "${BUILD_TYPE_OPTIMIZED}" ]]; then
            echo "TODO."
            exit
        fi
    fi

    # Warnings, errors, etc.

    if [[ "${1}" == "${COMPILER_GCC}" ]]; then
        v_flags+=("-Wall")
        v_flags+=("-Wextra")
        # v_cpp_flags+=("-I/usr/include/gtk-3.0/unix-print")
        # if [[ "${v_os_type}" == "linux" ]]; then
        #     v_flags+=("-I${COMPILER_ROOT_DIR}/${1}-${2}/include/c++/${2}")
        #     v_flags+=("-Wl,-rpath")
        #     v_flags+=("-Wl,${COMPILER_ROOT_DIR}/${1}-${2}/lib64")
        # fi
        # if [[ "${v_os_type}" == "win" ]]; then
        #     v_flags+=("-I${COMPILER_ROOT_DIR}/include/c++/${2}")
        #     v_flags+=("-Wl,-rpath")
        #     v_flags+=("-Wl,${COMPILER_ROOT_DIR}/lib/gcc/x86_64-w64-mingw32/${2}")
        # fi

        # v_flags+=("-I${COMPILER_INCLUDE_DIR}")
        # v_flags+=("-Wl,-rpath")
        # v_flags+=("-Wl,${COMPILER_LIB64_DIR}")
    elif [[ "${1}" == "${COMPILER_CLANG}" ]]; then
        v_flags+=("-stdlib=libstdc++")
        # v_flags+=("${COMPILER_ROOT_DIR}/${1}-${2}/lib")
    fi

    echo "${v_flags[@]}"
}



# Arguments:
#   Compiler
#   Compiler version
#   Build type
#   C++ standard
get_compile_defs () {
    if [[ $# -lt 4 ]]; then
        echo_error "Missing argument to get_compiler_flags().\nAborting."
        exit 1
    fi
    local v_compiler="${1}"
    local v_compiler_version="${2}"
    local v_build_type="${3}"
    local v_cxx_std="${4}"
    local v_defs=()

    echo "${v_defs[@]}"
}



# Arguments:
#   Compiler
#   Compiler version
#   C++ standard
#   Use gold linker flag+
#     [0=do not use gold linker, 1=use gold linker]
#     By default, gold linker flag is set.
get_link_flags () {
    if [[ $# -lt 3 ]]; then
        echo_error "Missing argument to get_link_flags().\nAborting."
        exit 1
    fi
    local v_use_gold_linker=1
    [[ $# -eq 4 ]] && v_use_gold_linker="${4}"
    local v_flags=()

    v_flags+=("-std=${3}")

    if [[ "${OSTYPE}" == "${OSTYPE_MSYS}" ]]; then
        v_flags+=("-D__USE_MINGW_ANSI_STDIO=1")
    fi

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



# Return the common compiler and build string for directory names.
# Format: <compiler><version>-<c++std>-<buildtype>
#
# Example:
#   init_build_common_dir
#   echo "${DIR_COMMON_BUILD}" --> debug-gcc1130-c++17 (linux/MSYS)
#
# Arguments: These arguments are assumed to have been checked to conform
#            to internal formats.
#   Compiler
#   Compiler version
#   C++ standard
#   Build type
init_common_compile_string () {
    if [ $# -lt 4 ]; then
        echo_error "${FUNCNAME[0]}: Missing argument(s).\nAborting."
        exit 1
    fi
    echo "${1}${2//./}-${3}-${4}"
}



# init_gcc_compiler_vars "9.4.0"
# init_gcc_compiler_vars "10.3.0"
# init_clang_compiler_vars "9.0.1"
# init_clang_compiler_vars "10.0.1"

# echo "COMPILER_ID: ${COMPILER_ID}"
# echo "COMPILER_VERSION: ${COMPILER_VERSION}"
# echo "COMPILER_NAME: ${COMPILER_NAME}"
# echo "COMPILER_C_BIN: ${COMPILER_C_BIN}"
# echo "COMPILER_CXX_BIN: ${COMPILER_CXX_BIN}"
# echo "COMPILER_INCLUDE_DIR: ${COMPILER_INCLUDE_DIR}"
# echo "COMPILER_LIB32_DIR: ${COMPILER_LIB32_DIR}"
# echo "COMPILER_LIB64_DIR: ${COMPILER_LIB64_DIR}"
