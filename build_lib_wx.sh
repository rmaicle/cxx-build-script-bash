#!/usr/bin/env bash

# wxWidgets library build script for GNU/Linux
#
# References:
# https://github.com/NREL/wex/wiki/Linux-Build-Instructions
# https://wiki.wxwidgets.org/Compiling_and_getting_started
#
# Issues:
#   1. Secret Store error (missing include libsecret/secret.h)
#      Add --disable-secretstore to configure command.
#   2. GTK Unix Print error (missing include gtk/gtkunixprint.h)
#      Pass -I/usr/include/gtk-3.0/unix-print to CXXFLAGS in configure command.
# CMake Issue on wxWidgets 3.2.0:
#   Not working on MSYS -- looking for GTK3 library
#
# Example:
#   ./build_lib_wx.sh           \
#       --compiler=gcc:10.3.0   \
#       --cxx-std=c++17         \
#       --build=debug           \
#       --version=3.1.6         \
#       -t 2
#
# Windows MSYS2 Requirement:
#   7zip - pacman -S p7zip



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
declare BUILD_CONFIG_TITLE="Auto-generated build configuration for the ${LIB_WX_NAME} library"



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
      --version ${LIB_WX_VERSION_DEFAULT} \\
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
      --rebuild        clean, rebuild, and install to staging
  -t, --thread=[n]     thread count; uses half of CPU threads by default
  -v, --version=x.y.z  library version (x.y.z); default is ${LIB_WX_VERSION_DEFAULT} or use
                       one of
$(printf '                         %s\n' ${LIB_WX_VERSIONS[@]})
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
declare arg_version="${LIB_WX_VERSION_DEFAULT}"
declare arg_gtk_version="${LIB_WX_GTK_VERSION_DEFAULT}"
declare arg_thread_count=$((${THREAD_COUNT_MAX} / 2))

declare -r CLI_ARG="${@}"



# read the options
OPTIONS_SHORT=b:c:it:v:
OPTIONS_LONG=""
OPTIONS_LONG+=",build:"
OPTIONS_LONG+=",compiler:"
OPTIONS_LONG+=",cxx-std:"
OPTIONS_LONG+=",debug"
OPTIONS_LONG+=",gtk"
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
        --gtk)              arg_gtk_version="${2}" ; shift ;;
        --help)             show_usage ; shift ; exit ;;
        --info-only)        flag_info_only=1 ; flag_rebuild=0 ; shift ;;
        --rebuild)          flag_rebuild=1 ; flag_info_only=0 ; flag_initial_build=1 ; shift ;;
        -t|--thread)        arg_thread_count=${2} ; shift 2 ;;
        -v|--version)       arg_version="${2}"
                            shift 2
                            check_arg_in_array "-b|--build" "${arg_version}" "LIB_WX_VERSIONS"
                            arg_version=$(get_id "${arg_version}" "LIB_WX_VERSIONS")
                            ;;
        *)                  break ;;
    esac
done



init_compiler_vars "${arg_compiler}" "${arg_compiler_version}"

declare -a v_cxx_flags=()
v_cxx_flags+=($(get_compile_flags ${arg_compiler} ${arg_compiler_version} ${arg_build} ${arg_cpp_std}))
v_cxx_flags+=($(get_compile_defs ${arg_compiler} ${arg_compiler_version} ${arg_build} ${arg_cpp_std}))
v_cxx_flags+=(${LIB_WX_CXX_FLAGS[@]})
v_cxx_flags+=(${LIB_WX_CXX_COMPILE_DEFS[@]})
if [[ "${arg_build}" == "${BUILD_TYPE_DEBUG}" ]]; then
    v_cxx_flags+=(${LIB_WXWIDGETS_CXX_COMPILE_DEFS_DEBUG[@]})
fi
declare v_link_flags="$(get_link_flags ${arg_compiler} ${arg_compiler_version} ${arg_cpp_std})"
echo_info "Compiler variable initializations: Done"



init_wx_build_dir               \
    ${arg_version}              \
    ${arg_compiler}             \
    ${arg_compiler_version}     \
    ${arg_cpp_std}              \
    ${arg_build}                \
    ${OSTYPE}
echo_info "wxWidgets variable initializations: Done"


declare v_info_text=$(cat <<EOF
${BUILD_CONFIG_TITLE}
${SCRIPT_TITLE}
${SCRIPT_COPYRIGHT}

Library:         ${LIB_WX}
Version:         ${arg_version}
GTK version:     ${arg_gtk_version}
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
  Extract:       ${DIR_WX_EXTRACT}
  Build:         ${DIR_WX_BUILD}
  Staging:       ${DIR_WX_STAGING}

Date created:    $(date --iso-8601=seconds)
EOF
)



extract_wx_archive flag_initial_build
echo_info "Archive extraction: Done"
if [ ${flag_info_only} -gt 0 ]; then
    echo "${v_info_text}"
    exit
fi
recreate_wx_build_and_staging_dirs ${flag_rebuild}
echo_info "Build and staging directories check: Done"

pushd "${DIR_WX_BUILD}"
if [[ "${OSTYPE}" == "${OSTYPE_LINUX}"* ]]; then
    if [[ ${flag_initial_build} -gt 0 ]]; then
        declare -a v_configure_options=()
        if [[ "${arg_build}" == "${BUILD_TYPE_DEBUG}" ]]; then
            v_configure_options+=("--disable-precomp-headers")
            # v_configure_options+=("--disable-no_exceptions")
            # v_configure_options+=("--disable-no_rtti")
            v_configure_options+=("--enable-debug")
            v_configure_options+=("--enable-debug_info")
            v_configure_options+=("--enable-debug_gdb")
            v_configure_options+=("--enable-cxx11")
        fi

        echo -e "\nRebuilding..."
        echo -e "Calling configure\n"
        CC=${COMPILER_C_BIN}                \
        CXX=${COMPILER_CXX_BIN}             \
        CXXFLAGS="${v_cxx_flags[@]}"        \
        LDFLAGS="${v_link_flags}"           \
        ${DIR_WX_EXTRACT}/configure         \
            --prefix=${DIR_WX_STAGING}      \
            ${v_configure_options[@]}       \
            --with-cxx=${arg_cpp_std:3}     \
            --with-gtk=${arg_gtk_version}   \
            --enable-utf8                   \
            --without-subdirs               \
            --with-expat=builtin            \
            --with-libjpeg=builtin          \
            --with-libpng=builtin           \
            --with-libtiff=builtin          \
            --with-regex=builtin            \
            --with-zlib=builtin             \
            2>&1 | tee ./configure.log
    fi
    echo -e "\nCalling make\n"
    time ${v_make_bin} -j 2 2>&1 | tee ./make.log
    echo -e "\nSee make.log for details.\n"
    # rm -rf "${v_dir_staging}"
    time ${v_make_bin} install 2>&1 | tee ./install.log
    echo -e "\nSee install.log for details."
elif [[ "${OSTYPE}" == "${OSTYPE_MSYS}" ]]; then

    # NOTE: Dynamic libraries are preferrable but check if building
    #       static libraries is possible.

    if ! command -v mingw32-make.exe &> /dev/null; then
        echo_error "Executable not found: mingw32-make.exe\nAborting."
        exit 1
    fi
    # VENDOR=codespheare
    ${v_make_bin}                                       \
        -f makefile.gcc                                 \
        BUILD=${arg_build}                              \
        SHARED=1                                        \
        CXXFLAGS="$(join_space ${v_cxx_flags[@]})"      \
        setup_h
    if [ $? -ne 0 ]; then
        echo_error "Make (1st call) failed.\nAborting."
        exit
    fi
    ${v_make_bin}                                       \
        -j 16                                           \
        -f makefile.gcc                                 \
        BUILD=${arg_build}                              \
        SHARED=1                                        \
        CXXFLAGS="$(join_space ${v_cxx_flags[@]})"
    if [ $? -ne 0 ]; then
        echo_error "Make (2nd call) failed.\nAborting."
        exit
    fi

else
    echo_error "Unknown operating system: ${OSTYPE}"
    exit 1
fi

popd

pushd "${DIR_WX_STAGING}"
[[ -f "${LIB_WX}-build.config" ]] && rm -f ${LIB_WX}-build.config
echo "${v_info_text}" > ${LIB_WX}-build.config
popd



echo "Done."
