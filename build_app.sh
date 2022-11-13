#!/usr/bin/env bash

#
# Main build script
#

#  build.sh --app=test:dev          \
#           --lib=spheare:dev       \
#           --lib=boost:1.67.0      \
#           --lib=wx:3.1.5          \
#           --lib=decnumber:3.68.0  \
#           --compiler=gcc:9.3.0    \
#           --cxx-std=c++17         \
#           --build=optimized       \
#           -t 2

# ./build_app.sh --app test:0.1.0 --lib wx --compiler gcc --build debug
# ./build_app.sh --app test:0.1.0 --rebuild --run



# Issue
# -----
# Running the application from the command line is alright but
# double-clicking the application from the Windows explorer causes
# an error, something like:
# procedure entry point
#   _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEC1EPKcRKS3_
#   could not be located
#
# Solution
# --------
# Copy libstdc++-6.dll from C:\msys64\mingw64\bin to any directory
# where executables can read the DLL file (same directory as the
# executable).
#
# Ref: the procedure entry point __gxx_personality_v0 could not be located
#      https://stackoverflow.com/questions/18668003/



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
source "${DIR}/init_compiler.sh"
source "${DIR}/init_dir.sh"
init_dir_vars
source "${DIR}/init_lib.sh"
source "${DIR}/init_app.sh"
search_apps_in_source_dir



SCRIPTNAME=${0##*/}



show_usage () {
cat << EOF
${SCRIPT_TITLE}
${SCRIPT_COPYRIGHT}

Usage:
  ${SCRIPTNAME} [options]

Examples:
  ${SCRIPTNAME} --app=app_test --rebuild --run
  ${SCRIPTNAME} --app=app_test:0.1.0 --rebuild --run
  ${SCRIPTNAME} --lib=boost:1.67.0 --compiler=gcc:9.3.0 --cxx-std=c++17 -t 2
  ${SCRIPTNAME} --lib=spheare:0.1.0 --compiler=gcc:9.3.0 --cxx-std=c++17 -t 2
  ${SCRIPTNAME} --lib=spheare:dev --compiler=gcc:9.3.0 --cxx-std=c++17 -t 2
  ${SCRIPTNAME} --app=app-one:dev \\
      --lib=spheare:dev \\
      --lib=boost:1.67.0 \\
      --lib=wx:3.1.5 \\
      --lib=decnumber:3.68.0 \\
      --compiler=gcc:9.3.0 \\
      --cxx-std=${CXX_STD_DEFAULT} \\
      --build=${BUILD_TYPE_OPTIMIZED} \\
      --thread 2
Options:
      --app=id         build application id with the corresponding version;
                       if version is unspecified, the default version is used;
                       default version is ${APP_VERSION_LATEST}.
  -b, --build=[type]   build type; default is ${BUILD_TYPE_DEBUG}
$(printf '                         %s\n' ${BUILD_TYPES[@]})
  -c, --compiler=id    compiler id; default is ${COMPILER_IDS[0]}
$(printf '                         %s\n' ${COMPILER_IDS[@]})
      --cxx-std=std    C++ standard; default is ${CXX_STD_DEFAULT}
$(printf '                         %s\n' ${CXX_STANDARDS[@]})
      --help           print help and exit.
      --info-only      print build information then exit.
      --lib=id         build library id with the corresponding version; if
                       version is unspecified, the default version is used:
                         ${LIB_BOOST}:${LIB_BOOST_VERSION_DEFAULT}
                         ${LIB_CSCMN}:${LIB_CSCMN_VERSION_DEFAULT}
                         ${LIB_SOCI}:${LIB_SOCI_VERSION_DEFAULT}
                         ${LIB_WX}:${LIB_WX_VERSION_DEFAULT}
      --rebuild        clean and rebuild application.
      --rebuild-dep    clean and rebuild dependencies.
      --run            run the executable.
  -t, --thread=[n]     number of threads to use; uses half of all CPU cores by
                       default.
      --verbose        verbose debug information; equivalent to GCC -g3 option.

Application IDs [name:version]:
$(printf '  %s\n' ${APP_IDS[@]})
Library IDs [name:version]:
$(printf '  %s\n' ${LIBRARY_IDS[@]})
EOF
}



declare flag_debug=0
declare flag_info_only=0
declare flag_rebuild=0
declare flag_initial_build=0
declare flag_rebuild_dep=0
declare flag_static=0
declare flag_run=0

declare arg_compiler="${COMPILER_DEFAULT}"
# declare arg_compiler_version="$(get_compiler_default_version ${arg_compiler})"
declare arg_compiler_version="${COMPILER_DEFAULT_VERSION[${arg_compiler}]}"
declare arg_compiler_id="${arg_compiler}:${arg_compiler_version}"
declare arg_cpp_std="${CXX_STD_DEFAULT}"
declare arg_build="${BUILD_TYPE_DEFAULT}"
declare flag_debug_verbose=0

# Temporary variables for library arguments
declare arg_lib_id=""
declare arg_lib=""
declare arg_lib_version=""

declare -a arg_libs=()
declare -a arg_lib_versions=()

declare arg_app_id=""
declare arg_app=""
declare arg_app_version=""

# declare arg_app_accg_version=""
# declare arg_app_coop_version=""
declare arg_lib_boost_version="${LIB_BOOST_VERSION_DEFAULT}"
# declare arg_lib_dec_version="${LIB_DECNUMBER_VERSION_DEFAULT}"
declare arg_lib_soci_version="${LIB_SOCI_VERSION_DEFAULT}"
# declare arg_lib_csui_version="${LIB_CSUI_VERSION_DEFAULT}"
declare arg_lib_cscmn_version="${LIB_CSCMN_VERSION_DEFAULT}"
declare arg_lib_wx_version="${LIB_WX_VERSION_DEFAULT}"
declare arg_thread_count=$((${THREAD_COUNT_MAX} / 2))

declare -r CLI_ARG="${@}"



# Short and long options
OPTIONS_SHORT=b:c:t:
OPTIONS_LONG=""
OPTIONS_LONG+=",app:"
OPTIONS_LONG+=",build:"
OPTIONS_LONG+=",compiler:"
OPTIONS_LONG+=",cxx-std:"
OPTIONS_LONG+=",debug"
OPTIONS_LONG+=",help"
OPTIONS_LONG+=",info-only"
OPTIONS_LONG+=",lib:"
OPTIONS_LONG+=",rebuild"
OPTIONS_LONG+=",rebuild-dep"
OPTIONS_LONG+=",run"
OPTIONS_LONG+=",thread:"
OPTIONS_LONG+=",verbose"
# Read options
OPTIONS_TEMP=$(getopt               \
    --options ${OPTIONS_SHORT}      \
    --longoptions ${OPTIONS_LONG}   \
    --name "${SCRIPTNAME}" -- "$@")
# Append unrecognized arguments after --
eval set -- "${OPTIONS_TEMP}"

if [ ${#} -eq 0 ]; then
    show_usage
    exit
fi



while true; do
    case "${1}" in
        --app)              arg_app_id="${2,,}"
                            shift 2
                            get_name_and_version "--app" "${arg_app_id}" "APPLICATIONS" "APP_IDS"
                            [[ "${PROCESSED_ID}" =~ ":" ]]          \
                                && arg_app_id="${PROCESSED_ID}"     \
                                || arg_app_id="${PROCESSED_ID}:$(get_app_default_version ${PROCESSED_ID})"
                            # Get app name before colon, version after colon
                            arg_app="${arg_app_id%%:*}"
                            arg_app_version="${arg_app_id##*:}"
                            ;;
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
                                || arg_compiler_id="${PROCESSED_ID}:$(get_app_default_version ${PROCESSED_ID})"
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
        # -d|--doc)           arg_doc=$(to_lowercase "${2}")
        #                     if [[ ! "${DOCUMENTS[@]}" =~ "${arg_doc}" ]]; then
        #                         echo_error "Unrecognized document: ${arg_doc}"
        #                         echo "Use one of: ${DOCUMENTS[@]}"
        #                         echo "Aborting."
        #                         exit 1
        #                     fi
        #                     shift 2
        #                     ;;
        --help)             show_usage ; shift ; exit ;;
        --info-only)        flag_info_only=1 ; flag_rebuild=0 ; flag_run=0 ; shift ;;

        --lib)              arg_lib_id="${2,,}"
                            shift 2
                            get_name_and_version "--lib" "${arg_lib_id}" "LIBRARIES" "LIBRARY_IDS"
                            [[ "${PROCESSED_ID}" =~ ":" ]]          \
                                && arg_lib_id="${PROCESSED_ID}"     \
                                || arg_lib_id="${PROCESSED_ID}:$(get_app_default_version ${PROCESSED_ID})"
                            # Get the library and the version separately
                            arg_lib="${arg_lib_id%%:*}"
                            arg_lib_version="${arg_lib_id##*:}"

                            # TODO: Make these library version variables into one array
                            #       arg_lib_version[${arg_lib}]="${arg_lib_version}"

                            if [[ ${arg_lib} =~ "${LIB_BOOST}" ]]; then
                                arg_lib_boost_version="${arg_lib_version}"
                            elif [[ ${arg_lib} =~ "${LIB_WXWIDGETS}" ]]; then
                                arg_lib_wx_version="${arg_lib_version}"
                            # elif [[ ${arg_lib} =~ "${LIB_DECNUMBER}" ]]; then
                            #     arg_lib_dec_version="${arg_lib_version}"
                            elif [[ ${arg_lib} =~ "${LIB_SOCI}" ]]; then
                                arg_lib_soci_version="${arg_lib_version}"
                            elif [[ ${arg_lib} =~ "${LIB_CSCMN}" ]]; then
                                arg_lib_cscmn_version="${arg_lib_version}"
                            # elif [[ ${arg_lib} =~ "${LIB_CSUI}" ]]; then
                            #     arg_lib_csui_version="${arg_lib_version}"
                            fi
                            arg_libs+=(${arg_lib})
                            arg_lib_versions+=(${arg_lib_version})
                            ;;
        --rebuild)          flag_rebuild=1 ; flag_info_only=0 ; flag_initial_build=1 ; shift ;;
        --rebuild-dep)      flag_rebuild_dep=1 ; shift ;;
        --run)              flag_run=1 ; flag_info_only=0 ; shift ;;
        -t|--thread)        arg_thread_count=${2} ; shift 2 ;;
           --verbose)       flag_debug_verbose=1 ; shift ;;
        *)                  break
                            ;;
    esac
done



if [[ -z "${arg_app}" ]]; then
    echo_error "Application argument unspecified.\nAborting."
    exit 1
fi



init_compiler_vars "${arg_compiler}" "${arg_compiler_version}"



declare v_rebuild_dep_flag=""
[[ ${flag_rebuild_dep} -gt 0 ]] && v_rebuild_dep_flag="--rebuild"

# Build specified libraries and use them
if [ ${#arg_libs[@]} -gt 0 ]; then
    [[ ${#arg_libs[@]} -eq 1 ]] && echo -e "\nBuilding library dependency...\n"
    [[ ${#arg_libs[@]} -gt 1 ]] && echo -e "\nBuilding library dependencies...\n"
    declare index=0
    for lib in "${arg_libs[@]}"; do
        if [[ "${lib}" == "${LIB_BOOST}" ]]; then
            ./build_lib_boost.sh                            \
                ${v_rebuild_dep_flag}                       \
                --build ${arg_build}                        \
                --version ${arg_lib_versions[${index}]}     \
                --compiler ${arg_compiler_id}               \
                --cxx-std ${arg_cpp_std}                    \
                --thread ${arg_thread_count}
        # elif [[ "${lib}" == "${LIB_DECNUMBER}" ]]; then
        # elif [[ "${lib}" == "${LIB_CSCMN}" ]]; then
        #     ./build.sh                                          \
        #         -c ${arg_compiler_id}                           \
        #         -s ${arg_cpp_std}                               \
        #         -b ${arg_build}                                 \
        #         -l ${LIB_INTERNAL} ${arg_internal_version}      \
        #         -l ${LIB_DECNUMBER} ${arg_decnumber_version}    \
        #         -l ${LIB_BOOST} ${arg_boost_version}            \
        #         -t ${arg_thread_count}                          \
        #         ${param_extra}
        elif [[ "${lib}" == "${LIB_SOCI}" ]]; then
            ./build_lib_soc.sh                              \
                ${v_rebuild_dep_flag}                       \
                --build ${arg_build}                        \
                --version ${arg_lib_versions[${index}]}     \
                --compiler ${arg_compiler_id}               \
                --cxx-std ${arg_cpp_std}                    \
                --thread ${arg_thread_count}
        elif [[ "${lib}" == "${LIB_WXWIDGETS}" ]]; then
            ./build_lib_wx.sh                               \
                ${v_rebuild_dep_flag}                       \
                --build ${arg_build}                        \
                --version ${arg_lib_versions[${index}]}     \
                --compiler ${arg_compiler_id}               \
                --cxx-std ${arg_cpp_std}                    \
                --thread ${arg_thread_count}
        fi
        index=$(($index + 1))
    done
fi
unset v_rebuild_dep_flag



# declare v_cxx_flags="$(get_compile_flags ${arg_compiler} ${arg_compiler_version} ${arg_build} ${arg_cpp_std})"
declare -a v_cxx_flags=()
v_cxx_flags+=(-std=${arg_cpp_std})
v_cxx_flags+=($(get_compile_flags ${arg_compiler} ${arg_compiler_version} ${arg_build} ${arg_cpp_std}))
# declare v_link_flags="$(get_link_flags ${arg_compiler} ${arg_compiler_version} ${arg_cpp_std})"
declare v_link_flags="$(get_link_flags ${arg_compiler} ${arg_compiler_version} ${arg_cpp_std})"



# Application
init_app_build_dir              \
    ${arg_app}                  \
    ${arg_app_version}          \
    ${arg_compiler}             \
    ${arg_compiler_version}     \
    ${arg_cpp_std}              \
    ${arg_build}



# Boost library
init_boost_build_dir            \
    ${arg_lib_boost_version}    \
    ${arg_compiler,,}           \
    ${arg_compiler_version}     \
    ${arg_cpp_std}              \
    ${arg_build}                \
    ${OSTYPE}



# Decimal Number - if used



# SOCI library
init_soci_build_dir             \
    ${arg_lib_soci_version}     \
    ${arg_compiler,,}           \
    ${arg_compiler_version}     \
    ${arg_cpp_std}              \
    ${arg_build}                \
    ${OSTYPE}



# wxWidgets library
declare v_wx_compile_defs="${LIB_WX_CXX_COMPILE_DEFS[@]}"
if [[ "${arg_build}" == "${BUILD_TYPE_DEBUG}" ]]; then
    v_wx_compile_defs="${LIB_WX_CXX_COMPILE_DEFS_DEBUG[@]} ${v_wx_compile_defs}"
fi
init_wx_build_dir               \
    ${arg_lib_wx_version}       \
    ${arg_compiler}             \
    ${arg_compiler_version}     \
    ${arg_cpp_std}              \
    ${arg_build}                \
    ${OSTYPE}



# Common Library
init_cscmn_build_dir            \
    ${arg_lib_cscmn_version}    \
    ${arg_compiler}             \
    ${arg_compiler_version}     \
    ${arg_cpp_std}              \
    ${arg_build}                \
    ${OSTYPE}



declare v_executable="${arg_app}"
[[ "${OSTYPE}" == "${OSTYPE_MSYS}" ]] && v_executable="${v_executable}.exe"


declare BUILD_CONFIG_TITLE="Auto-generated build configuration for the application"
declare v_info_text=$(cat <<EOF
${BUILD_CONFIG_TITLE}
${SCRIPT_TITLE}
${SCRIPT_COPYRIGHT}

Executable:      ${arg_app} ${arg_app_version}
Libraries:       Internal Common: ${arg_lib_cscmn_version}
                 Boost: ${arg_lib_boost_version}
                 SOCI: ${arg_lib_soci_version}
                 wxWidgets: ${arg_lib_wx_version}
OS:              ${OSTYPE}
Rebuild:         ${YESNO[$flag_rebuild]}
Build:           ${arg_build^}
C++ Standard:    ${arg_cpp_std}
Compiler:        ${arg_compiler} ${arg_compiler_version}
  C:             ${COMPILER_C_BIN}
  C++:           ${COMPILER_CXX_BIN}
  Include:       ${COMPILER_INCLUDE_DIR}
  Library:       ${COMPILER_LIB64_DIR}
Flags:
  Compile:       ${v_cxx_flags[@]}
  Link:          ${v_link_flags}
Directories:
  Build:         ${DIR_APP_BUILD}
  Staging:       ${DIR_APP_STAGING}
  ${LIB_BOOST_NAME^}:
    Include:     ${DIR_BOOST_STAGING_INCLUDE}
    Library:     ${DIR_BOOST_STAGING_LIBRARY}
  ${LIB_SOCI_NAME}:
    Include:     ${DIR_SOCI_STAGING_INCLUDE_CONFIG}
    Include:     ${DIR_SOCI_STAGING_INCLUDE}
    Library:     ${DIR_SOCI_STAGING_LIBRARY}
  ${LIB_WX_NAME}:
    Definitions: ${v_wx_compile_defs}
    Include:     ${DIR_WX_CLIENT_INCLUDE_1}
                 ${DIR_WX_CLIENT_INCLUDE_2}
    Library:     ${DIR_WX_STAGING_LIBRARY}
  ${LIB_CSCMN_NAME}:
    Include:     ${DIR_CSCMN_STAGING_INCLUDE}
    Library:     ${DIR_CSCMN_STAGING_LIB}

Date created:    $(date --iso-8601=seconds)
EOF
)



# Always build for now.
# Determine if we need to archive and extract the application source files
# like it is done with the common library.
# flag_rebuild=1

if [ ${flag_info_only} -gt 0 ]; then
    echo "${v_info_text}"
    exit
fi
recreate_app_build_and_staging_dirs ${flag_rebuild}

if [[ ${flag_rebuild} -gt 0 ]]; then

    pushd "${DIR_APP_BUILD}"
    # declare v_generator_type="Unix Makefiles"
    # if [[ "${OSTYPE}" == "${OSTYPE_LINUX}"* ]]; then
    #     CC=${COMPILER_C_BIN}                                                        \
    #     CXX=${COMPILER_CXX_BIN}                                                     \
    #     CXXFLAGS="${v_cxx_flags[@]}"                                                \
    #     LDFLAGS="${v_link_flags}"                                                   \
    #     LD_LIBRARY_PATH="${COMPILER_LIB64_DIR}:${LD_LIBRARY_PATH}"                  \
    #     cmake                                                                       \
    #         -G "${CMAKE_GEN_FILE_TYPE}"                                             \
    #         -D CMAKE_SYSTEM_NAME="Linux"                                            \
    #         -D CMAKE_BUILD_TYPE=${arg_build^}                                       \
    #         -D CMAKE_CXX_COMPILER_VERSION="${arg_compiler_version}"                 \
    #         -D CMAKE_CXX_COMPILER="${COMPILER_CXX_BIN}"                             \
    #         -D CMAKE_CXX_STANDARD_INCLUDE_DIRECTORIES="${COMPILER_INCLUDE_DIR}"     \
    #         -D CMAKE_CXX_STANDARD="${arg_cpp_std:3}"                                \
    #         -D CMAKE_CXX_FLAGS="$(echo ${v_cxx_flags[@]})"                          \
    #         -D CMAKE_INSTALL_PREFIX="${DIR_APP_STAGING}"                            \
    #         -D WX_COMPILE_DEFS="${v_wx_compile_defs}"                               \
    #         ${DIR_SRC}/app_${arg_app}
    # elif [[ "${OSTYPE}" == "${OSTYPE_MSYS}" ]]; then
    #     cmake                                                                       \
    #         -G "${CMAKE_GEN_FILE_TYPE}"                                             \
    #         -D CMAKE_SYSTEM_NAME="MSYS"                                             \
    #         -D CMAKE_BUILD_TYPE=${arg_build^}                                       \
    #         -D CMAKE_CXX_COMPILER_VERSION="${arg_compiler_version}"                 \
    #         -D CMAKE_CXX_COMPILER="${COMPILER_CXX_BIN}"                             \
    #         -D CMAKE_CXX_STANDARD_INCLUDE_DIRECTORIES="${COMPILER_INCLUDE_DIR}"     \
    #         -D CMAKE_CXX_STANDARD="${arg_cpp_std:3}"                                \
    #         -D CMAKE_CXX_FLAGS="$(echo ${v_cxx_flags[@]})"                          \
    #         -D CMAKE_INSTALL_PREFIX="${DIR_APP_STAGING}"                            \
    #         -D WX_COMPILE_DEFS="${v_wx_compile_defs}"                               \
    #         ${DIR_SRC}/app_${arg_app}
    # fi

    echo_debug "Configuring build..."

    declare v_system_name="${OSTYPE_LINUX^}"
    [[ "${OSTYPE}" == "${OSTYPE_LINUX}"* ]] && v_system_name="${OSTYPE_LINUX^}"
    [[ "${OSTYPE}" == "${OSTYPE_MSYS}" ]] && v_system_name="${OSTYPE_MSYS^^}"
    CC=${COMPILER_C_BIN}                                                        \
    CXX=${COMPILER_CXX_BIN}                                                     \
    CXXFLAGS="${v_cxx_flags[@]}"                                                \
    LDFLAGS="${v_link_flags}"                                                   \
    LD_LIBRARY_PATH="${COMPILER_LIB64_DIR}"                                     \
    cmake                                                                       \
        -G "${CMAKE_GEN_FILE_TYPE}"                                             \
        -D CMAKE_SYSTEM_NAME="${v_system_name}"                                 \
        -D CMAKE_BUILD_TYPE=${arg_build^}                                       \
        -D CMAKE_CXX_COMPILER_VERSION="${arg_compiler_version}"                 \
        -D CMAKE_CXX_COMPILER="${COMPILER_CXX_BIN}"                             \
        -D CMAKE_CXX_STANDARD_INCLUDE_DIRECTORIES="${COMPILER_INCLUDE_DIR}"     \
        -D CMAKE_CXX_STANDARD="${arg_cpp_std:3}"                                \
        -D CMAKE_CXX_FLAGS="$(echo ${v_cxx_flags[@]})"                          \
        -D CMAKE_INSTALL_PREFIX="${DIR_APP_STAGING}"                            \
        -D WX_COMPILE_DEFS="${v_wx_compile_defs}"                               \
        ${DIR_SRC}/app_${arg_app}

    if [ $? -ne 0 ]; then
        popd
        echo_error "Call to CMake failed.\nAborting."
        exit
    fi

    echo_debug "Compiling source files..."
    make -j4
    if [ $? -ne 0 ]; then
        popd
        echo_error "Call to make failed.\nAborting."
        exit
    fi
    popd

    pushd "${DIR_APP_STAGING}"
    echo "${v_info_text}" > build.config
    popd


    echo_debug "Copying library files..."
    copy_boost_libraries "${DIR_APP_STAGING_BIN}"
    copy_soci_libraries "${arg_lib_soci_version}" "${DIR_APP_STAGING_BIN}"
    copy_wx_libraries "${arg_lib_wx_version}" "${DIR_APP_STAGING_BIN}"
    copy_cscmn_libraries "${arg_lib_cscmn_version}" "${DIR_APP_STAGING_BIN}"

    if [ -e "${DIR_APP_STAGING_BIN}/libstd++-6.dll" ]; then
        cp -u /ming64/bin/libstdc++-6.dll "${DIR_APP_STAGING_BIN}" 2>/dev/null
    fi

    echo_debug "Copying ${arg_app} executable"
    echo_debug "  From: ${DIR_APP_BUILD}"
    echo_debug "  To: ${DIR_APP_STAGING_BIN}"
    cp -u ${DIR_APP_BUILD}/${v_executable} "${DIR_APP_STAGING_BIN}" 2>/dev/null
fi



if [[ ${flag_run} -eq 1 ]]; then
    if [ ! -f "${DIR_APP_STAGING}/bin/${v_executable}" ]; then
        echo_error "Application binary file not found:\n"\
            "  ${DIR_APP_STAGING}/bin/${v_executable}"
        echo_red "Aborting."
        exit
    fi
    pushd "${DIR_APP_STAGING}/bin"
    ./${v_executable} &
    popd
fi

echo "Done."
