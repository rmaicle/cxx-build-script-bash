#!/usr/bin/env bash

#
# Boost library build script
#
# The Boost library is built out-of-source.
#
# Example:
#   ./build_lib_boost.sh        \
#       --compiler=gcc:10.3.0   \
#       --cxx-std=c++17         \
#       --build=debug           \
#       --version=1.76.0        \
#       -t 2
#

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
      --version ${LIB_BOOST_VERSION_DEFAULT} \\
      --thread 2

Options:
  -b, --build=type     build type; default is ${BUILD_TYPE_DEFAULT} or use
                       one of
$(printf '                         %s\n' ${BUILD_TYPES[@]})
  -c, --compiler=id    compiler id; default is ${COMPILER_GCC}:${COMPILER_GCC_VERSION_DEFAULT} or use
                       one of
$(printf '                         %s\n' ${COMPILER_IDS[@]})
      --cxx-std=std    C++ standard; default is ${CXX_STD_DEFAULT}
$(printf '                          %s\n' ${CXX_STANDARDS[@]})
      --debug          print debug messages
      --help           print help and exit
      --info-only      print build information then exit
      --rebuild        relink only and install to staging
  -t, --thread=[n]     thread count; uses half of CPU threads by default
  -v, --version=x.y.z  library version (x.y.z); default is ${LIB_BOOST_VERSION_DEFAULT} or use
                       one of
$(printf '                         %s\n' ${LIB_BOOST_VERSIONS[@]})
EOF
}



declare flag_help=0
declare flag_info_only=0
declare flag_rebuild=0
declare flag_initial_build=0

declare arg_compiler="${COMPILER_DEFAULT}"
# declare arg_compiler_version="$(get_compiler_default_version ${arg_compiler})"
declare arg_compiler_version="${COMPILER_DEFAULT_VERSION[${arg_compiler}]}"
declare arg_compiler_id="${arg_compiler}:${arg_compiler_version}"
declare arg_cpp_std="${CXX_STD_DEFAULT}"
declare arg_build="${BUILD_TYPE_DEFAULT}"
declare arg_version="${LIB_BOOST_VERSION_DEFAULT}"
declare arg_thread_count=$((${THREAD_COUNT_MAX} / 2))

declare -r CLI_ARG="${@}"



# read the options
OPTIONS_SHORT=b:c:it:v:
OPTIONS_LONG=""
OPTIONS_LONG+=",build:"
OPTIONS_LONG+=",compiler:"
OPTIONS_LONG+=",cxx-std:"
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
                            check_arg_in_array "-b|--build" "${arg_version}" "LIB_BOOST_VERSIONS"
                            arg_version=$(get_id "${arg_version}" "LIB_BOOST_VERSIONS")
                            ;;
        *)                  break ;;
    esac
done



init_compiler_vars "${arg_compiler}" "${arg_compiler_version}"

declare v_cxx_lib_path="${COMPILER_LIB64_DIR}"
declare -a v_cxx_flags=()
v_cxx_flags+=($(get_compile_flags ${arg_compiler} ${arg_compiler_version} ${arg_build} ${arg_cpp_std}))
v_cxx_flags+=(${LIB_BOOST_CXX_FLAGS[@]})
declare v_link_flags="$(get_link_flags ${arg_compiler} ${arg_compiler_version} ${arg_cpp_std})"



init_boost_build_dir            \
    ${arg_version}              \
    ${arg_compiler}             \
    ${arg_compiler_version}     \
    ${arg_cpp_std}              \
    ${arg_build}                \
    ${OSTYPE}



declare v_info_text=$(cat <<EOF
${BUILD_CONFIG_TITLE}
${SCRIPT_TITLE}
${SCRIPT_COPYRIGHT}

Library:         ${LIB_BOOST}
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
  Extract:       ${DIR_BOOST_EXTRACT}
  Build:         ${DIR_BOOST_BUILD}
  Staging:       ${DIR_BOOST_STAGING}

Date created:    $(date --iso-8601=seconds)
EOF
)



extract_boost_archive flag_initial_build
if [ ${flag_info_only} -gt 0 ]; then
    echo "${v_info_text}"
    exit
fi
recreate_boost_build_and_staging_dirs ${flag_rebuild}

declare v_cmd_b2="b2"
[[ "${OSTYPE}" == "${OSTYPE_MSYS}" ]] && v_cmd_b2="${v_cmd_b2}.exe"

if [ ${flag_initial_build} -gt 0 ]; then
    pushd "${DIR_BOOST_EXTRACT}"
    [[ -e "user-config.jam" ]] && rm -f user-config.jam
    echo "Creating user-config.jam..."
    declare v_name=""
    declare v_ver=""
    for id in ${COMPILER_IDS[@]}; do
        v_name="${id%%:*}"
        v_ver="${id##*:}"
        echo_debug "${v_name} ${v_ver}"
        init_compiler_vars ${v_name} ${v_ver}
        echo "using ${v_name,,} : ${v_ver} : ${COMPILER_CXX_BIN} : <cxxflags>\"-I${COMPILER_INCLUDE_DIR}\" <linkflags>\"-L${COMPILER_LIB64_DIR}\" ;" >> user-config.jam
    done
    if [ -e "user-config.jam" ]; then
        echo "File user-config.jam created."
    else
        echo_error "Failed to create user-config.jam.\nAborting."
        exit 1
    fi
    popd



    # IMPORTANT:
    # Re-initialize compiler variables
    # because they have been changed from the loop above.
    init_compiler_vars "${arg_compiler}" "${arg_compiler_version}"



    pushd "${DIR_BOOST_EXTRACT}/tools/build"
    # Avoid a lot of generated project configuration files.
    rm -f project-config.jam
    echo -e "\nCalling ./bootstrap.sh\n"
    echo "toolset: ${COMPILER_NAME%%-*}"
    ./bootstrap.sh                              \
        --with-toolset=${COMPILER_NAME%%-*}     \
        --without-libraries=context             \
        --without-libraries=contract            \
        --without-libraries=coroutine           \
        --without-libraries=date_time           \
        --without-libraries=fiber               \
        --without-libraries=graph               \
        --without-libraries=graph_parallel      \
        --without-libraries=headers             \
        --without-libraries=iostreams           \
        --without-libraries=locale              \
        --without-libraries=math                \
        --without-libraries=mpi                 \
        --without-libraries=python              \
        --without-libraries=random              \
        --without-libraries=regex               \
        --without-libraries=serialization       \
        --without-libraries=type_erasure        \
        --without-libraries=wave                \
        2>&1 | tee ${DIR_BOOST_BUILD}/bootstrap.log

    if ! command -v ./${v_cmd_b2} &> /dev/null; then
        echo_error "Command not found: ${v_cmd_b2}\nAborting."
        exit 1
    fi
    ./${v_cmd_b2} install --prefix=${DIR_BOOST_BUILD} &> /dev/null
    export PATH="${PATH}:${DIR_BOOST_BUILD}\bin"
    popd
fi



# $ ./tools/build/b2.exe --show-libraries
# The following libraries require building:
#     - atomic
#     - chrono
#     - container
#     - context
#     - contract
#     - coroutine
#     - date_time
#     - exception
#     - fiber
#     - filesystem
#     - graph
#     - graph_parallel
#     - headers
#     - iostreams
#     - json
#     - locale
#     - log
#     - math
#     - mpi
#     - nowide
#     - program_options
#     - python
#     - random
#     - regex
#     - serialization
#     - stacktrace
#     - system
#     - test
#     - thread
#     - timer
#     - type_erasure
#     - wave

pushd "${DIR_BOOST_EXTRACT}"

# This is only to differentiate this 'toolset' name from
# the one used in bootstrap.sh.
# NOTE: Uses tilde (~) character before the C++ standard ID.
declare v_user_config_toolset="${COMPILER_NAME}"
declare v_param_reconfigure=""
[[ ${flag_rebuild} -gt 0 ]] && v_param_reconfigure="--reconfigure -a"
echo -e "\nCalling ./b2\n"
time                                                    \
    LDFLAGS="${v_cxx_lib_path}"                         \
    ${DIR_BOOST_BUILD}/bin/${v_cmd_b2}                  \
    -j ${arg_thread_count}                              \
    ${v_param_reconfigure}                              \
    `#-d+2`                                             \
    -q                                                  \
    toolset="${v_user_config_toolset}"                  \
    variant=${arg_build}                                \
    cxxflags="$(echo ${v_cxx_flags[@]})"                \
    linkflags="${v_link_flags}"                         \
    link=shared                                         \
    architecture=x86                                    \
    address-model=64                                    \
    threading=multi                                     \
    runtime-link=shared                                 \
    `#hardcode-dll-paths=true`                          \
    define=BOOST_LOG_WITHOUT_DEBUG_OUTPUT               \
    define=BOOST_LOG_WITHOUT_EVENT_LOG                  \
    define=BOOST_LOG_WITHOUT_SYSLOG                     \
    define=BOOST_TEST_DYN_LINK                          \
    define=BOOST_NO_AUTO_PTR                            \
    --with-chrono                                       \
    `#--with-date_time`                                 \
    --with-filesystem                                   \
    --with-program_options                              \
    --with-system                                       \
    --with-test                                         \
    --build-dir=${DIR_BOOST_BUILD}                      \
    install                                             \
    --prefix=${DIR_BOOST_STAGING}                       \
    2>&1 | tee ${DIR_BOOST_BUILD}/b2-1.log

popd

pushd "${DIR_BOOST_STAGING}"
[[ -f "${LIB_BOOST}-build.config" ]] && rm -f ${LIB_BOOST}-build.config
echo "${v_info_text}" > ${LIB_BOOST}-build.config
popd



echo "Done."
