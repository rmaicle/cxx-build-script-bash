#!/usr/bin/env bash



# How best to include other scripts?
# https://stackoverflow.com/a/12694189/6091491
DIR="${BASH_SOURCE%/*}"
[[ ! -d "$DIR" ]] && DIR="$(pwd)"

source "${DIR}/utils.sh"
source "${DIR}/init_system.sh"
source "${DIR}/init_compiler.sh"



declare -g LIB_BOOST="boost"
declare -g LIB_BOOST_NAME="Boost"

declare -g LIB_BOOST_VERSION_DEFAULT="1.82.0"
declare -g -a LIB_BOOST_VERSIONS=(
    "1.76.0"
    "1.77.0"
    "1.79.0"
    "${LIB_BOOST_VERSION_DEFAULT}"
)

declare -g LIB_BOOST_ARCHIVE_EXT="tar.bz2"
[[ "${OSTYPE}" == "${OSTYPE_MSYS}" ]] && LIB_BOOST_ARCHIVE_EXT="tar.bz2"
declare -g LIB_BOOST_ARCHIVE_EXT_ALT="zip"

declare -g DIR_BOOST_EXTRACT
declare -g DIR_BOOST_BUILD
declare -g DIR_BOOST_STAGING
declare -g DIR_BOOST_STAGING_LIBRARY
declare -g DIR_BOOST_STAGING_INCLUDE

declare -a BIN_LIB_FILENAMES_BOOST=()
declare PATH_BOOST_ARCHIVE



declare -a LIB_BOOST_CXX_FLAGS=()
LIB_BOOST_CXX_FLAGS+=("-fPIC")


declare -a LIB_BOOST_FILES=()
if [[ "${OSTYPE}" == "${OSTYPE_LINUX}"* ]]; then
    LIB_BOOST_FILES+=("libboost_atomic.so.000")
    LIB_BOOST_FILES+=("libboost_chrono.so.000")
    LIB_BOOST_FILES+=("libboost_filesystem.so.000")
    LIB_BOOST_FILES+=("libboost_prg_exec_monitor.so.000")
    LIB_BOOST_FILES+=("libboost_program_options.so.000")
    LIB_BOOST_FILES+=("libboost_system.so.000")
    LIB_BOOST_FILES+=("libboost_unit_test_framework.so.000")
elif [[ "${OSTYPE}" == "${OSTYPE_MSYS}" ]]; then
    LIB_BOOST_FILES+=("libboost_atomic-mgw000-mt-d-x64-111.dll")
    LIB_BOOST_FILES+=("libboost_chrono-mgw000-mt-d-x64-111.dll")
    LIB_BOOST_FILES+=("libboost_filesystem-mgw000-mt-d-x64-111.dll")
    LIB_BOOST_FILES+=("libboost_prg_exec_monitor-mgw000-mt-d-x64-111.dll")
    LIB_BOOST_FILES+=("libboost_program_options-mgw000-mt-d-x64-111.dll")
    LIB_BOOST_FILES+=("libboost_system-mgw000-mt-d-x64-111.dll")
    LIB_BOOST_FILES+=("libboost_unit_test_framework-mgw000-mt-d-x64-111.dll")
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
init_boost_build_dir () {
    local v_common_compile_string=$(init_common_compile_string ${2} ${3} ${4} ${5})

    local v_filename="${LIB_BOOST}_${1//./_}"
    # FILENAME_BOOST_ARCHIVE="${v_filename}.${LIB_BOOST_ARCHIVE_EXT}"
    PATH_BOOST_ARCHIVE="${DIR_LIB}/${v_filename}.${LIB_BOOST_ARCHIVE_EXT}"
    DIR_BOOST_EXTRACT="${DIR_BUILD}/${v_common_compile_string}/${v_filename}"

    DIR_BOOST_BUILD="${DIR_BOOST_EXTRACT}/build"
    DIR_BOOST_STAGING="${DIR_BOOST_EXTRACT}/staging"
    DIR_BOOST_STAGING_LIBRARY="${DIR_BOOST_STAGING}/lib"

    # Get major and minor version number string and convert period symbol
    # to underscore.
    local v_version="${1%.*}"
    v_version="${v_version/./_}"
    DIR_BOOST_STAGING_INCLUDE="${DIR_BOOST_STAGING}/include/${LIB_BOOST}-${v_version}"

    # Prepare the library filenames before operating on them
    local arg_compiler_version="${3%%.*}"
    local arg_lib_version="${1%.*}"
    arg_lib_version="${arg_lib_version/./_}"
    local v_file_source=""
    for item in "${LIB_BOOST_FILES[@]}"; do
        if [[ "${6}" == "${OSTYPE_LINUX}"* ]]; then
            v_file_source="${item/000/${1}}"
        elif [[ "${6}" == "${OSTYPE_MSYS}" ]]; then
            v_file_source="${item/000/${arg_compiler_version}}"
            v_file_source="${v_file_source/111/${arg_lib_version}}"
        fi
        BIN_LIB_FILENAMES_BOOST+=("${v_file_source}")
        echo_debug "init_boost_build_dir: ${v_file_source}"
    done

    write_boost_cmake_include_file
}



# Extract Boost archive.
# Sets the flag argument whether this is an initial build operation.
# Initial build operation is true when the extract directory is missing.
extract_boost_archive () {
    local -n flag=${1}
    if [[ ! -d "${DIR_BOOST_EXTRACT}" ]]; then
        flag=1
        if [[ ! -f "${PATH_BOOST_ARCHIVE}" ]]; then
            echo_error "Archive file not found: ${PATH_BOOST_ARCHIVE}\nAborting."
            exit 1
        fi
        extract_archive ${PATH_BOOST_ARCHIVE} $(dirname ${DIR_BOOST_EXTRACT})
    fi
}



# Recreate the Build and Staging directories as necessary.
# When rebuilding, the contents of the Build and Staging directories are deleted.
recreate_boost_build_and_staging_dirs () {
    local flag_rebuild=${1}
    if [ ${flag_rebuild} -gt 0 ]; then
        [[ -d "${DIR_BOOST_BUILD}" ]] && rm -rf "${DIR_BOOST_BUILD}"
        [[ -d "${DIR_BOOST_STAGING}" ]] && rm -rf "${DIR_BOOST_STAGING}"
    fi
    [[ ! -d "${DIR_BOOST_BUILD}" ]] && mkdir -p ${DIR_BOOST_BUILD}
    [[ ! -d "${DIR_BOOST_STAGING}" ]] && mkdir -p ${DIR_BOOST_STAGING}
}



# Create CMake files for use by application CMake build scripts.
write_boost_cmake_include_file () {
    local cmake_file="${DIR_CMAKE}/${LIB_BOOST}.cmake"
    [[ -f "${cmake_file}" ]] && rm -f "${cmake_file}"
    cat <<EOF > ${cmake_file}
set (BOOST_INCLUDE_DIR ${DIR_BOOST_STAGING_INCLUDE})
set (BOOST_LIBRARY_DIR ${DIR_BOOST_STAGING_LIBRARY})
list (APPEND BOOST_LIBRARY_FILES
$(echo "${BIN_LIB_FILENAMES_BOOST[@]}" | tr " " "\n")
)
EOF
}



# Copy Boost library files
# Arguments:
#   Destination directory
copy_boost_libraries () {
    local arg_dest_dir="${1}"
    local v_source_dir="${DIR_BOOST_STAGING_LIBRARY}"
    local v_source_file=""
    echo -e "Copying ${LIB_BOOST_NAME} library files.\n  From: ${v_source_dir}\n  To: ${arg_dest_dir}"
    for item in "${BIN_LIB_FILENAMES_BOOST[@]}"; do
        v_source_file="${v_source_dir}/${item}"
        if [[ ! -f "${v_source_file}" ]]; then
            echo_error "${LIB_BOOST_NAME} library file does not exist: ${v_source_file}\nAborting."
            exit 1
        fi
        echo_debug "copy_boost_libraries: ${item} to ${v_source_file}"
        cp -u "${v_source_file}" "${arg_dest_dir}" 2>/dev/null
    done
}
