#!/usr/bin/env bash

# PostgreSQL build script for GNU/Linux
#
# References:
# Chapter 17 - Installation from Source Code, PostgreSQL 14 Documentation
#
# Example:
#   ./build_tool_postgresql.sh  \
#       --compiler=gcc:10.3.0   \
#       --cxx-std=c++17         \
#       --build=release         \
#       -t 2



# Use the Unofficial Bash Strict Mode
# http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -e
set -u
# Saner programming env: these switches turn some bugs into errors
set -o errexit -o pipefail -o noclobber -o nounset



source dirstack.sh
source debug.sh
source cpu.sh
source echo.sh
source utils.sh

source init_system.sh
source init_compiler.sh
source init_dir.sh
source init_tool.sh
init_dir_vars



declare SCRIPTNAME=${0##*/}
declare SCRIPT_TITLE="Codespheare Project Builder Script for ${TOOL_POSTGRESQL_NAME}"
declare COPYRIGHT="Created by Ricardo Maicle 2021"



show_usage() {
cat << EOF
${SCRIPT_TITLE}
${COPYRIGHT}

Usage:
  ${0##*/} [options]

Example:
    ${0##*/} \\
        --compiler gcc:${COMPILER_GCC_VERSIONS[-1]} \\
        --cxx-std ${CXX_STD_DEFAULT} \\
        --build ${BUILD_TYPE_OPTIMIZED} \\
        --version ${TOOL_POSTGRESQL_VERSION_DEFAULT}

Options:
  -b, --build=type     build type; default is ${BUILD_TYPE_DEFAULT} or use
                       one of
$(printf '                         %s\n' ${BUILD_TYPES[@]})
  -c, --compiler=id    compiler id; default is ${COMPILER_GCC}:${COMPILER_GCC_VERSION_DEFAULT} or use
                       one of
$(printf '                         %s\n' ${COMPILER_IDS[@]})
      --cxx-std=std    C++ standard; default is ${CXX_STD_DEFAULT}
      --debug          print debug messages
      --help           print help and exit
      --info-only      print build information then exit
  -r, --rebuild        clean, rebuild, and install to staging
  -t, --thread [n]     thread count; uses half of CPU threads by default
  -v, --version=x.y.z  library version (x.y.z); default is ${TOOL_POSTGRESQL_VERSION_DEFAULT}
EOF
}



if [[ ${#} -gt 0 ]] && [[ "${1}" = "--debug" ]]; then
    shift
    flag_debug_mode=1
fi

declare flag_help=0
declare flag_info_only=0
declare flag_rebuild=0

declare arg_compiler_id=""
declare arg_compiler="${COMPILER_DEFAULT}"
declare arg_compiler_version="$(get_compiler_default_version ${arg_compiler})"
declare arg_cpp_std="${CXX_STD_DEFAULT}"
declare arg_build="${BUILD_TYPE_DEFAULT}"
declare arg_version="${TOOL_POSTGRESQL_VERSION_DEFAULT}"
declare arg_thread_count=$((${THREAD_COUNT_MAX} / 2))

declare -r CLI_ARG="${@}"



# read the options
OPTIONS_SHORT=b:c:irt:v:
OPTIONS_LONG=""
OPTIONS_LONG+=",build:"
OPTIONS_LONG+=",compiler:"
OPTIONS_LONG+=",cxx-std:"
OPTIONS_LONG+=",help"
OPTIONS_LONG+=",info-only"
OPTIONS_LONG+=",install:"
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
                            if [[ ! "${BUILD_TYPES[@]}" =~ "${arg_build}" ]]; then
                                echo_error "Unrecognized build type: ${arg_build}.\nAborting." \
                                    "Use one of: ${BUILD_TYPES[@]}"
                                exit 1
                            fi
                            ;;
        -c|--compiler)      arg_compiler_id="${2,,}"
                            shift 2
                            if [[ ! "${COMPILER_IDS[@]}" =~ "${arg_compiler_id}" ]]; then
                                if [[ ! "${COMPILER_TYPES[@]}" =~ "${arg_compiler_id}" ]]; then
                                    echo_error "Unrecognized compiler argument: ${arg_compiler_id}\nAborting." \
                                        "\nUse one of: ${COMPILER_IDS[@]}"
                                    exit 1
                                fi
                            fi
                            # Check for compiler types first so we can convert it to its 'name'
                            # and allow the search through the compiler set
                            if [[ "${COMPILER_TYPES[@]}" =~ "${arg_compiler_id}" ]]; then
                                [[ "${arg_compiler_id}" == "${COMPILER_TYPE_GNU}" ]] && arg_compiler_id="${COMPILER_GCC}"
                                [[ "${arg_compiler_id}" == "${COMPILER_TYPE_CLANG}" ]] && arg_compiler_id="${COMPILER_CLANG}"
                            fi
                            if [[ ! "${arg_compiler_id}" =~ ":" ]]; then
                                # If no colon, use the default version
                                arg_compiler="${arg_compiler_id}"
                                arg_compiler_version="$(get_compiler_default_version ${arg_compiler})"
                            else
                                # Find similar
                                for cid in "${COMPILER_IDS[@]}"; do
                                    if [[ "${cid}" =~ "${arg_compiler_id}" ]]; then
                                        arg_compiler="${cid%%:*}"
                                        arg_compiler_version="${cid##*:}"
                                    fi
                                done
                            fi
                            ;;
        cxx-std)            arg_cpp_std="${2,,}"
                            shift 2
                            if [[ ! "${CXX_STANDARDS[@]}" =~ "${arg_cpp_std}" ]]; then
                                echo_error "Unrecognized C++ standard: ${arg_cpp_std}.\nAborting." \
                                    "Use one of: ${CPP_STANDARDS[@]}"
                                exit 1
                            fi
                            ;;
        # --debug)          flag_debug_mode=1 ; shift ;;
        --help)             show_usage ; shift ; exit ;;
        --info-only)        flag_info_only=1 ; shift ;;
        -r|--rebuild)       flag_rebuild=1 ; shift ;;
        -t|--thread)        arg_thread_count=${2} ; shift 2 ;;
        -v|--version)       if [ ${#TOOL_POSTGRESQL_VERSIONS[@]} -eq 0 ]; then
                                echo_error "No pre-defined ${TOOL_POSTGRESQL_NAME} library versions.\nAborting."
                                exit 1
                            fi
                            if [[ ! "${TOOL_POSTGRESQL_VERSIONS[@]}" =~ "${2}" ]]; then
                                echo_error "Unrecognized ${TOOL_POSTGRESQL_NAME} library version: ${2}.\nAborting." \
                                    "Use one of: ${TOOL_POSTGRESQL_VERSIONS[@]}"
                                exit 1
                            fi
                            for lid in "${TOOL_POSTGRESQL_VERSIONS[@]}"; do
                                [[ "${lid}" =~ "${2}" ]] && arg_version="${lid}"
                            done
                            shift 2
                            ;;
        *)                  break ;;
    esac
done



init_compiler_vars "${arg_compiler}" "${arg_compiler_version}"

# declare v_cxx_flags="$(get_compile_flags ${arg_compiler} ${arg_compiler_version} ${arg_build} ${arg_cpp_std})"
# v_cxx_flags="${v_cxx_flags} -std=${arg_cpp_std} -fPIC -m64"
declare -a v_cxx_flags=()
v_cxx_flags+=(-std=${arg_cpp_std})
v_cxx_flags+=($(get_compile_flags ${arg_compiler} ${arg_compiler_version} ${arg_build} ${arg_cpp_std}))
v_cxx_flags+=(${LIB_POSTGRESQL_CXX_FLAGS[@]})
declare v_link_flags="$(get_link_flags ${arg_compiler} ${arg_compiler_version} ${arg_cpp_std})"



# declare v_dir_suffix=""
# if [[ "${OSTYPE}" == "${OSTYPE_LINUX}"* ]]; then
#     v_dir_suffix=$(get_app_dir_suffix \
#         ${arg_build} \
#         ${arg_compiler,,} \
#         ${COMPILER_VERSION} \
#         ${arg_cpp_std})
# fi

# declare v_archive_filename="${TOOL_POSTGRESQL_ARCHIVES[${arg_version}]}"
# declare v_archive_filename_alt="${TOOL_POSTGRESQL_ARCHIVES_ALT[${arg_version}]}"
# declare v_dir_extract_name="${TOOL_POSTGRESQL_EXTRACT_NAME[${arg_version}]}"
declare v_path_archive="${DIR_LIB_EXTERNAL}/$(get_postgresql_archive_path ${arg_version})"
declare v_dir_extract="$(get_postgresql_extract_dir     \
    ${DIR_BUILD}                                        \
    ${arg_version}                                      \
    ${arg_build}                                        \
    ${arg_compiler,,}                                   \
    ${COMPILER_VERSION}                                 \
    ${arg_cpp_std})"

# if [ ${flag_info_only} -eq 0 ]; then
#     [[ ! -d "${DIR_LIB_EXTERNAL}/${v_dir_extract_name}" ]] && flag_rebuild=1
# fi

# declare v_dir_build="${DIR_LIB_EXTERNAL}/${TOOL_POSTGRESQL_BUILD_BASE_DIR[${arg_version}]}"
# [[ "${v_os_type}" == "linux" ]] && v_dir_build="${v_dir_build}/${v_dir_suffix}"
declare v_dir_build="$(get_postgresql_build_dir     \
    ${DIR_BUILD}                                    \
    ${arg_version}                                  \
    ${arg_build}                                    \
    ${arg_compiler,,}                               \
    ${COMPILER_VERSION}                             \
    ${arg_cpp_std})"

# declare v_dir_db_suffix="${v_dir_suffix}"
# if [[ "${v_os_type}" == "win" && "${arg_build}" == "${BUILD_TYPE_DEBUG}" ]]; then
#     v_dir_db_suffix="d"
# fi
# declare v_dir_staging="${DIR_BUILD}/${TOOL_POSTGRESQL_STAGING_BASE_DIR[${arg_version}]}/${v_dir_suffix}"
declare v_dir_staging="$(get_postgresql_staging_dir \
    ${DIR_BUILD}                                    \
    ${arg_version}                                  \
    ${arg_build}                                    \
    ${arg_compiler,,}                               \
    ${COMPILER_VERSION}                             \
    ${arg_cpp_std})"



cat << EOF
${SCRIPT_TITLE}
${COPYRIGHT}

Tool:            ${TOOL_POSTGRESQL_NAME} ${arg_version}
Archive:         $(get_postgresql_archive_path ${arg_version})
Build:           ${arg_build^}
C++ Standard:    ${arg_cpp_std}
ICU:             $(echo "$(uconv --version)" | awk '{print $NF}')
Rebuild:         ${YESNO[$flag_rebuild]}
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
  Extract:       ${v_dir_extract}
  Build:         ${v_dir_build}
  Staging:       ${v_dir_staging}
EOF



if [ ${flag_info_only} -eq 0 ]; then
    [[ ! -d "${v_dir_extract}" ]] && flag_rebuild=1
fi

if [[ ${flag_rebuild} -eq 0 && ${flag_info_only} -gt 0 ]]; then
    exit 0
fi



# Delete the previous extract directory
# if [[ ${flag_rebuild} -gt 0 ]]; then
#     [[ -d "${DIR_LIB_EXTERNAL}/${v_dir_extract_name}" ]] && rm -rf "${DIR_LIB_EXTERNAL}/${v_dir_extract_name}"
#     # Delete the tool directory in the build directory.
#     [[ -d "${v_dir_build}" ]] && rm -rf "${DIR_BUILD}/${TOOL_POSTGRESQL_BUILD_BASE_DIR[${arg_version}]}"
# fi


# if [[ ! -d "${DIR_LIB_EXTERNAL}/${v_dir_extract_name}" ]]; then
#     if [[ -f "${DIR_LIB_EXTERNAL}/${v_archive_filename}" ]]; then
#         extract_to_dir ${DIR_LIB_EXTERNAL} ${v_archive_filename} ${v_dir_extract_name}
#     elif [[ -f "${DIR_LIB_EXTERNAL}/${v_archive_filename_alt}" ]]; then
#         extract_to_dir ${DIR_LIB_EXTERNAL} ${v_archive_filename_alt} ${v_dir_extract_name}
#     else
#         echo_error "Archive file not found: ${v_archive_filename}\nAborting."
#         exit 1
#     fi
# fi
if [[ ! -d "${v_dir_extract}" ]]; then
    if [[ ! -f "${v_path_archive}" ]]; then
        echo_error "Archive file not found: ${v_path_archive}\nAborting."
        exit 1
    fi
    extract_postgresql_archive ${v_path_archive} $(dirname ${v_dir_extract})
fi

[[ ! -d "${v_dir_build}" ]] && mkdir -p "${v_dir_build}"



pushd "${v_dir_build}"
if [[ ${flag_rebuild} -gt 0 ]]; then
    echo -e "\nRebuilding in directory '$(pwd)'..."
    echo -e "Calling configure\n"
    CC=${COMPILER_C_BIN}                \
    CXX=${COMPILER_CXX_BIN}             \
    CXXFLAGS="${v_cxx_flags[@]}"        \
    LDFLAGS="${v_link_flags}"           \
    ${v_dir_extract}/configure          \
        --prefix=${v_dir_staging}       \
        --with-perl                     \
        --with-python                   \
        --with-icu                      \
        --with-lz4                      \
        --with-ssl=openssl              \
        --with-libxml                   \
        --with-libxslt                  \
        2>&1 | tee ./configure.log
fi

echo -e "\nCalling make\n"
time make -j 2 2>&1 | tee ./make.log
echo -e "\nSee make.log for details.\n"

time make install 2>&1 | tee ./install.log
echo -e "\nSee install.log for details."
popd



pushd "${v_dir_staging}"
cat << EOF > build.config
Arguments:       ${CLI_ARG}
Tool:            ${TOOL_POSTGRESQL_NAME} ${arg_version}
Archive:         $(get_postgresql_archive_path ${arg_version})
OS:              ${OSTYPE}
Build:           ${arg_build^}
C++ Standard:    ${arg_cpp_std}
ICU:             $(echo "$(uconv --version)" | awk '{print $NF}')
Rebuild:         ${YESNO[$flag_rebuild]}
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
  Extract:       ${v_dir_extract}
  Build:         ${v_dir_build}
  Staging:       ${v_dir_staging}
EOF
popd



echo "Done."
