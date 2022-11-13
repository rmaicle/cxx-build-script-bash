#!/usr/bin/env bash

# Internal library cscommon build script for GNU/Linux
#
# Example:
#   ./build_lib_cscommon.sh     \
#       --compiler=gcc:10.3.0   \
#       --cxx-std=c++17         \
#       --build=debug           \
#       -t 2



# Use the Unofficial Bash Strict Mode
# http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -e
set -u
# Saner programming env: these switches turn some bugs into errors
set -o errexit -o pipefail -o noclobber -o nounset



# How best to include other scripts?
# https://stackoverflow.com/a/12694189/6091491
DIR="${BASH_SOURCE%/*}"
[[ ! -d "$DIR" ]] && DIR="$(pwd)"

source "${DIR}/dirstack.sh"
source "${DIR}/debug.sh"
source "${DIR}/cpu.sh"
source "${DIR}/echo.sh"

source "${DIR}/utils.sh"
source "${DIR}/init_common.sh"
source "${DIR}/init_system.sh"
source "${DIR}/init_compiler.sh"
source "${DIR}/init_dir.sh"
init_dir_vars
source "${DIR}/init_lib.sh"



declare SCRIPTNAME=${0##*/}
declare BUILD_CONFIG_TITLE="Auto-generated build configuration for the ${LIB_SOCI_NAME} library"



show_usage() {
cat << EOF
${SCRIPT_TITLE}
${SCRIPT_COPYRIGHT}

Usage:
  ${SCRIPTNAME} [options]

Example:
  ${SCRIPTNAME} \\
      --compiler gcc:${COMPILER_GCC_VERSIONS[-1]} \\
      --cxx-std ${CXX_STD_DEFAULT} \\
      --build ${BUILD_TYPE_OPTIMIZED} \\
      --version ${LIB_SOCI_VERSION_DEFAULT} \\
      --thread 2

Options:
  -b, --build=type      build type; default is ${BUILD_TYPE_DEFAULT} or use
                        one of
$(printf '                          %s\n' ${BUILD_TYPES[@]})
  -c, --compiler=id     compiler id; default is ${COMPILER_GCC}:${COMPILER_GCC_VERSION_DEFAULT} or use
                        one of
$(printf '                          %s\n' ${COMPILER_IDS[@]})
      --cxx-std=std     C++ standard; default is ${CXX_STD_DEFAULT}
$(printf '                          %s\n' ${CXX_STANDARDS[@]})
      --debug           print debug messages
      --help            print help and exit
      --info-only       print build information then exit
      --lib=id          build library id; if version is unspecified then the
                        default version is used.
      --rebuild         clean, rebuild, and install to staging
  -t, --thread=[n]      thread count; uses half of CPU threads by default
  -v, --version=x.y.z   library version (x.y.z); default is ${LIB_CSCOMMON_VERSION_DEFAULT} or use
                        one of
$(printf '                          %s\n' ${LIB_CSCMN_VERSIONS[@]})
EOF
}



declare flag_help=0
declare flag_info_only=0
declare flag_rebuild=0
declare flag_initial_build=0

declare arg_compiler="${COMPILER_DEFAULT}"
declare arg_compiler_version="${COMPILER_DEFAULT_VERSION[${arg_compiler}]}"
declare arg_compiler_id="${arg_compiler}:${arg_compiler_version}"
declare arg_cpp_std="${CXX_STD_DEFAULT}"
declare arg_build="${BUILD_TYPE_DEFAULT}"
declare arg_version="${LIB_CSCMN_VERSION_DEFAULT}"
declare arg_thread_count=$((${THREAD_COUNT_MAX} / 2))

declare -r CLI_ARG="${@}"



# read the options
OPTIONS_SHORT=b:c:it:v:
OPTIONS_LONG=""
OPTIONS_LONG+=",build:"
OPTIONS_LONG+=",compiler:"
OPTIONS_LONG+=",cxx-std:"
OPTIONS_LONG+=",debug"
OPTIONS_LONG+=",help"
OPTIONS_LONG+=",info-only"
OPTIONS_LONG+=",rebuild"
OPTIONS_LONG+=",thread:"
OPTIONS_LONG+=",version:"
OPTIONS_TEMP=$(getopt               \
    --options ${OPTIONS_SHORT}      \
    --longoptions ${OPTIONS_LONG}   \
    --name "${SCRIPTNAME}" -- "$@")
# Append unrecognized arguments after --
eval set -- "${OPTIONS_TEMP}"



while true; do
    case "${1}" in
        -b|--build)         arg_build="${2,,}"
                            shift 2
                            check_arg_in_array "-b|--build" "${arg_build}" "BUILD_TYPES"
                            arg_build=$(get_id "${arg_build}" "BUILD_TYPES")
                            ;;
        -c|--compiler)      arg_compiler_id="${2,,}"
                            shift 2
                            # Check for compiler types first so we can convert it to its 'name'
                            # and allow the search through the compiler set
                            if [[ "${COMPILER_TYPES[@]}" =~ "${arg_compiler_id}" ]]; then
                                [[ "${arg_compiler_id}" == "${COMPILER_TYPE_GNU}" ]] && arg_compiler_id="${COMPILER_GCC}"
                                [[ "${arg_compiler_id}" == "${COMPILER_TYPE_CLANG}" ]] && arg_compiler_id="${COMPILER_CLANG}"
                            fi
                            get_name_and_version "-c|--compiler" "${arg_compiler_id}" "COMPILERS" "COMPILER_IDS"
                            [[ "${PROCESSED_ID}" =~ ":" ]]              \
                                && arg_compiler_id="${PROCESSED_ID}"    \
                                || arg_compiler_id="${PROCESSED_ID}:${COMPILER_DEFAULT_VERSION[${PROCESSED_ID}]}"
                            # Get the library and the version separately
                            arg_compiler="${arg_compiler_id%%:*}"
                            arg_compiler_version="${arg_compiler_id##*:}"
                            ;;
        --cxx-std)          arg_cpp_std="${2,,}"
                            shift 2
                            check_arg_in_array "--cxx-std" "${arg_cpp_std}" "CXX_STANDARDS"
                            arg_cpp_std=$(get_id "${arg_cpp_std}" "CXX_STANDARDS")
                            ;;
        --debug)            flag_debug_mode=1 ; shift ;;
        --help)             show_usage ; shift ; exit ;;
        --info-only)        flag_info_only=1 ; flag_rebuild=0 ; shift ;;
        --rebuild)          flag_rebuild=1 ; flag_info_only=0 ; flag_initial_build=1 ; shift ;;
        -t|--thread)        arg_thread_count=${2} ; shift 2 ;;
        -v|--version)       arg_version="${2}"
                            shift 2
                            check_arg_in_array "-b|--build" "${arg_version}" "LIB_CSCMN_VERSIONS"
                            arg_version=$(get_id "${arg_version}" "LIB_CSCMN_VERSIONS")
                            ;;
        *)                  break ;;
    esac
done



init_compiler_vars "${arg_compiler}" "${arg_compiler_version}"

declare -a v_cxx_flags=()
v_cxx_flags+=(-std=${arg_cpp_std})
v_cxx_flags+=($(get_compile_flags ${arg_compiler} ${arg_compiler_version} ${arg_build} ${arg_cpp_std}))
declare v_link_flags="$(get_link_flags ${arg_compiler} ${arg_compiler_version} ${arg_cpp_std})"



init_cscmn_build_dir            \
    ${arg_version}              \
    ${arg_compiler}             \
    ${arg_compiler_version}     \
    ${arg_cpp_std}              \
    ${arg_build}



declare v_info_text=$(cat <<EOF
${BUILD_CONFIG_TITLE}
${SCRIPT_TITLE}
${SCRIPT_COPYRIGHT}

Library:         ${LIB_CSCMN}
Version:         ${arg_version}
OS:              ${OSTYPE}
Rebuild:         ${YESNO[$flag_rebuild]}
Build:           ${arg_build}
C++ Standard:    ${arg_cpp_std}
Compiler:        ${arg_compiler} ${arg_compiler_version}
  C:             ${COMPILER_C_BIN}
  C++:           ${COMPILER_CXX_BIN}
  Include:       ${COMPILER_INCLUDE_DIR}
  Library:       ${COMPILER_LIB64_DIR}
Thread count:    ${arg_thread_count}
Flags:
  Compile:       ${v_cxx_flags[@]}
  Link:          ${v_link_flags}
Directories:
  Extract:       ${DIR_CSCMN_EXTRACT}
  Build:         ${DIR_CSCMN_BUILD}
  Staging:       ${DIR_CSCMN_STAGING}

Date created:    $(date --iso-8601=seconds)
EOF
)



create_cscommon_archive ${arg_version}
extract_cscommon_archive flag_initial_build
if [ ${flag_info_only} -gt 0 ]; then
    echo "${v_info_text}"
    exit
fi
recreate_cscommon_build_and_staging_dirs ${flag_rebuild}

pushd "${DIR_CSCMN_BUILD}"
declare v_system_name="${OSTYPE_LINUX^}"
[[ "${OSTYPE}" == "${OSTYPE_LINUX}"* ]] && v_system_name="${OSTYPE_LINUX^}"
[[ "${OSTYPE}" == "${OSTYPE_MSYS}" ]] && v_system_name="${OSTYPE_MSYS^^}"

if [[ "${OSTYPE}" == "${OSTYPE_LINUX}"* ]]; then

    if [[ ${flag_initial_build} -gt 0 ]]; then
        CC=${COMPILER_C_BIN}                                                        \
        CXX=${COMPILER_CXX_BIN}                                                     \
        CXXFLAGS="$(echo ${v_cxx_flags[@]})"                                        \
        LDFLAGS="${v_link_flags}"                                                   \
        cmake                                                                       \
            -G "${CMAKE_GEN_FILE_TYPE}"                                             \
            -D CMAKE_SYSTEM_NAME="${v_system_name}"                                 \
            -D CMAKE_BUILD_TYPE=${arg_build^}                                       \
            -D CMAKE_CXX_COMPILER_VERSION="${arg_compiler_version}"                 \
            -D CMAKE_CXX_COMPILER="${COMPILER_CXX_BIN}"                             \
            -D CMAKE_CXX_STANDARD_INCLUDE_DIRECTORIES="${COMPILER_INCLUDE_DIR}"     \
            -D CMAKE_CXX_STANDARD="${arg_cpp_std:3}"                                \
            -D CMAKE_CXX_FLAGS="$(echo ${v_cxx_flags[@]})"                          \
            -D CMAKE_INSTALL_PREFIX="${DIR_CSCMN_STAGING}"                          \
            ../
    fi

    echo -e "\nCalling make\n"
    time make -j 2 2>&1 | tee ./make.log
    echo -e "\nSee make.log for details.\n"

    time make install 2>&1 | tee ./install.log
    echo -e "\nSee install.log for details."

elif [[ "${OSTYPE}" == "${OSTYPE_MSYS}" ]]; then

    if [[ ${flag_initial_build} -gt 0 ]]; then
        CC=${COMPILER_C_BIN}                                                        \
        CXX=${COMPILER_CXX_BIN}                                                     \
        CXXFLAGS="$(echo ${v_cxx_flags[@]})"                                        \
        LDFLAGS="${v_link_flags}"                                                   \
        cmake                                                                       \
            -G "${CMAKE_GEN_FILE_TYPE}"                                             \
            -D CMAKE_SYSTEM_NAME="${v_system_name}"                                 \
            -D CMAKE_BUILD_TYPE=${arg_build^}                                       \
            -D CMAKE_CXX_COMPILER_VERSION="${arg_compiler_version}"                 \
            -D CMAKE_CXX_COMPILER="${COMPILER_CXX_BIN}"                             \
            -D CMAKE_CXX_STANDARD_INCLUDE_DIRECTORIES="${COMPILER_INCLUDE_DIR}"     \
            -D CMAKE_CXX_STANDARD="${arg_cpp_std:3}"                                \
            -D CMAKE_CXX_FLAGS="$(echo ${v_cxx_flags[@]})"                          \
            -D CMAKE_INSTALL_PREFIX="${DIR_CSCMN_STAGING}"                          \
            ../
    fi

    echo -e "\nCalling make\n"
    time make -j 2 2>&1 | tee ./make.log
    echo -e "\nSee make.log for details.\n"

    rm -rf "${DIR_CSCMN_STAGING}"
    time make install 2>&1 | tee ./install.log
    echo -e "\nSee install.log for details."

else

    echo_error "Unknown operating system: ${OSTYPE}"
    exit 1

fi
popd

pushd "${DIR_CSCMN_STAGING}"
[[ -f "${LIB_CSCMN}-build.config" ]] && rm -f ${LIB_CSCMN}-build.config
echo "${v_info_text}" > ${LIB_CSCMN}-build.config
popd



echo "Done."
