#!/usr/bin/env bash

# How best to include other scripts?
# https://stackoverflow.com/a/12694189/6091491
DIR="${BASH_SOURCE%/*}"
[[ ! -d "$DIR" ]] && DIR="$(pwd)"

source "${DIR}/utils.sh"
source "${DIR}/init_system.sh"
source "${DIR}/init_compiler.sh"



declare -g LIB_WX="wx"
declare -g LIB_WX_NAME="wxWidgets"

declare -g LIB_WX_VERSION_DEFAULT="3.2.1"
declare -g -a LIB_WX_VERSIONS=(
    "3.0.5"
    "3.1.6"
    "3.1.7"
    "${LIB_WX_VERSION_DEFAULT}"
)

# Stable versions use only the major and minor version numbers as
# version strings in its file naming convention instead of major, minor
# and release version string:
#   libwx_baseu-32.so (Linux, Linux-like OS)
#   wxbase32ud_gcc_custom.dll (Microsoft Windows)
#
# The following array of stable versions, beginning with 3.2, will be
# used to determine whether the library version being built is a stable
# version or not. Only the major and minor version numbers are used.
declare -g -a LIB_WX_VERSIONS_STABLE=(
    "${LIB_WX_VERSION_DEFAULT%.*}"
)

declare -g LIB_WX_GTK_VERSION_DEFAULT=3

declare -g LIB_WX_ARCHIVE_EXT="tar.bz2"
[[ "${OSTYPE}" == "${OSTYPE_MSYS}" ]] && LIB_WX_ARCHIVE_EXT="tar.bz2"
declare -g LIB_WX_ARCHIVE_EXT_ALT="zip"

declare -g DIR_WX_EXTRACT
declare -g DIR_WX_BUILD
declare -g DIR_WX_STAGING
declare -g DIR_WX_STAGING_LIBRARY
declare -g DIR_WX_CLIENT_INCLUDE_1
declare -g DIR_WX_CLIENT_INCLUDE_2
declare -a BIN_LIB_FILENAMES_WX=()

# The build operation puts intermediate files in this directory.
declare DIR_WX_BUILD_DEST
declare PATH_WX_ARCHIVE



declare -a LIB_WX_CXX_FLAGS=()
LIB_WX_CXX_FLAGS+=("-fPIC")
# LIB_WX_CXX_FLAGS+=("-D_FILE_OFFSET_BITS=64")
# LIB_WX_CXX_FLAGS+=("-DwxUSE_GUI=1") --> # Causes an error
# LIB_WX_CXX_FLAGS+=("-m64")

declare -a LIB_WX_CXX_COMPILE_DEFS_DEBUG=()
LIB_WX_CXX_COMPILE_DEFS_DEBUG+=("-DDEBUG")
LIB_WX_CXX_COMPILE_DEFS_DEBUG+=("-D__WXDEBUG__")

declare -a LIB_WX_CXX_COMPILE_DEFS=()
LIB_WX_CXX_COMPILE_DEFS+=("-DwxNO_RTTI")
LIB_WX_CXX_COMPILE_DEFS+=("-DWXUSINGDLL")
# Implicit and explicit encoding of wxString data
# http://wxwidgets.org/blog/2020/08/implicit_explicit_encoding/
# LIB_WX_CXX_COMPILE_DEFS+=("-DwxNO_IMPLICIT_WXSTRING_ENCODING")
if [[ "${OSTYPE}" == "${OSTYPE_LINUX}"* ]]; then
    LIB_WX_CXX_COMPILE_DEFS+=("-D__WXGTK__")
    LIB_WX_CXX_COMPILE_DEFS+=("-DwxUSE_LIBMSPACK")
elif [[ "${OSTYPE}" == "${OSTYPE_MSYS}" ]]; then
    # LIB_WX_CXX_COMPILE_DEFS+=("-DwxUSE_LIBMSPACK")
    LIB_WX_CXX_COMPILE_DEFS+=("-DwxUSE_RC_MANIFEST")
    LIB_WX_CXX_COMPILE_DEFS+=("-DwxUSE_DPI_AWARE_MANIFEST=2")
    LIB_WX_CXX_COMPILE_DEFS+=("-D__WXMSW__")
    LIB_WX_CXX_COMPILE_DEFS+=("-D__WIN64__")
fi



declare -a LIB_WX_FILES=()
declare LIB_WX_FILE_AFFIX="custom"
if [[ "${OSTYPE}" == "${OSTYPE_LINUX}"* ]]; then
    LIB_WX_FILES+=("libwx_baseu-000.so")
    LIB_WX_FILES+=("libwx_baseu_net-000.so")
    LIB_WX_FILES+=("libwx_baseu_xml-000.so")
    LIB_WX_FILES+=("libwx_gtk3u_adv-000.so")
    LIB_WX_FILES+=("libwx_gtk3u_aui-000.so")
    LIB_WX_FILES+=("libwx_gtk3u_core-000.so")
    LIB_WX_FILES+=("libwx_gtk3u_gl-000.so")
    LIB_WX_FILES+=("libwx_gtk3u_html-000.so")
    LIB_WX_FILES+=("libwx_gtk3u_media-000.so")
    LIB_WX_FILES+=("libwx_gtk3u_propgrid-000.so")
    LIB_WX_FILES+=("libwx_gtk3u_qa-000.so")
    LIB_WX_FILES+=("libwx_gtk3u_ribbon-000.so")
    LIB_WX_FILES+=("libwx_gtk3u_richtext-000.so")
    LIB_WX_FILES+=("libwx_gtk3u_stc-000.so")
    # LIB_WX_FILES+=("libwx_gtk3u_webview-000.so")
    LIB_WX_FILES+=("libwx_gtk3u_xrc-000.so")
elif [[ "${OSTYPE}" == "${OSTYPE_MSYS}" ]]; then
    LIB_WX_FILES+=("wxbase000ud_gcc_${LIB_WX_FILE_AFFIX}.dll")
    LIB_WX_FILES+=("wxbase000ud_net_gcc_${LIB_WX_FILE_AFFIX}.dll")
    LIB_WX_FILES+=("wxbase000ud_xml_gcc_${LIB_WX_FILE_AFFIX}.dll")
    LIB_WX_FILES+=("wxmsw000ud_adv_gcc_${LIB_WX_FILE_AFFIX}.dll")
    LIB_WX_FILES+=("wxmsw000ud_aui_gcc_${LIB_WX_FILE_AFFIX}.dll")
    LIB_WX_FILES+=("wxmsw000ud_core_gcc_${LIB_WX_FILE_AFFIX}.dll")
    LIB_WX_FILES+=("wxmsw000ud_gl_gcc_${LIB_WX_FILE_AFFIX}.dll")
    LIB_WX_FILES+=("wxmsw000ud_html_gcc_${LIB_WX_FILE_AFFIX}.dll")
    LIB_WX_FILES+=("wxmsw000ud_media_gcc_${LIB_WX_FILE_AFFIX}.dll")
    LIB_WX_FILES+=("wxmsw000ud_propgrid_gcc_${LIB_WX_FILE_AFFIX}.dll")
    LIB_WX_FILES+=("wxmsw000ud_ribbon_gcc_${LIB_WX_FILE_AFFIX}.dll")
    LIB_WX_FILES+=("wxmsw000ud_richtext_gcc_${LIB_WX_FILE_AFFIX}.dll")
    LIB_WX_FILES+=("wxmsw000ud_stc_gcc_${LIB_WX_FILE_AFFIX}.dll")
    LIB_WX_FILES+=("wxmsw000ud_webview_gcc_${LIB_WX_FILE_AFFIX}.dll")
    LIB_WX_FILES+=("wxmsw000ud_xrc_gcc_${LIB_WX_FILE_AFFIX}.dll")
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
init_wx_build_dir () {
    local v_common_compile_string=$(init_common_compile_string ${2} ${3} ${4} ${5})

    local v_filename="${LIB_WX_NAME}-${1}"
    PATH_WX_ARCHIVE="${DIR_LIB}/${v_filename}.${LIB_WX_ARCHIVE_EXT}"
    DIR_WX_EXTRACT="${DIR_BUILD}/${v_common_compile_string}/${v_filename}"

    if [[ "${OSTYPE}" == "${OSTYPE_LINUX}"* ]]; then
        DIR_WX_BUILD="${DIR_WX_EXTRACT}/build/linux"
        DIR_WX_BUILD_DEST="${DIR_WX_BUILD}"
        DIR_WX_STAGING="${DIR_WX_EXTRACT}/lib/linux"
        DIR_WX_STAGING_LIBRARY="${DIR_WX_STAGING}/lib"
        DIR_WX_CLIENT_INCLUDE_1="${DIR_WX_STAGING}/include/wx-${1%.*}"
        DIR_WX_CLIENT_INCLUDE_2="${DIR_WX_STAGING}/lib/wx/include/gtk${LIB_WX_GTK_VERSION_DEFAULT}-unicode-${1%.*}"
    elif [[ "${OSTYPE}" == "${OSTYPE_MSYS}" ]]; then
        local suffix="gcc_mswu"
        [[ "${5}" == "${BUILD_TYPE_DEBUG}" ]] && suffix="${suffix}d"
        suffix="${suffix}dll"
        # When rebuilding, the object file directory is the one to be deleted:
        #   ${DIR_WX_BUILD}/${DIR_WX_BUILD_SUFFIX}
        DIR_WX_BUILD="${DIR_WX_EXTRACT}/build/msw"
        DIR_WX_BUILD_DEST="${DIR_WX_BUILD}/${suffix}"
        DIR_WX_STAGING="${DIR_WX_EXTRACT}/lib/gcc_dll"
        DIR_WX_STAGING_LIBRARY="${DIR_WX_STAGING}"
        suffix="mswu"
        [[ "${5}" == "${BUILD_TYPE_DEBUG}" ]] && suffix="${suffix}d"
        DIR_WX_CLIENT_INCLUDE_1="${DIR_WX_STAGING}/${suffix}"
        DIR_WX_CLIENT_INCLUDE_2="${DIR_WX_EXTRACT}/include"
    fi



    # Prepare the library filenames before using them
    #   - Link files (.a) have their release version stripped off
    #   - Shared object files (.so) have complete version number string
    # Check against stable version strings
    local v_version="${1}"
    for item in "${LIB_WX_VERSIONS_STABLE[@]}"; do
        if [[ "${1%.*}" == "${item}" ]]; then
            v_version="${item}"
        fi
    done
    echo_debug "Library version string: ${v_version}"
    echo "------------------------------------------------------------"
    echo "TODO: Check wxWidgets stable release version usage in Linux."
    echo "------------------------------------------------------------"
    local v_file_source=""
    for item in "${LIB_WX_FILES[@]}"; do
        if [[ "${6}" == "${OSTYPE_LINUX}"* ]]; then
            v_file_source="${item/000/${1%.*}}"
        elif [[ "${6}" == "${OSTYPE_MSYS}" ]]; then
            v_file_source="${item/000/${v_version//./}}"
            # Replace 'lib' prefix with '-l'
            v_file_source="${v_file_source/lib/-l}"
            # Remove '.so' filename extension
            v_file_source="${v_file_source/.so/}"
        fi
        BIN_LIB_FILENAMES_WX+=("${v_file_source}")
        echo_debug "init_wx_build_dir: ${v_file_source}"
    done

    rewrite_wx_cmake_include_file
}



# Extract wxWidgets archive.
# Sets the flag argument whether this is an initial build operation.
# Initial build operation is true when the extract directory is missing.
extract_wx_archive () {
    local -n flag=${1}
    if [[ ! -d "${DIR_WX_EXTRACT}" ]]; then
        flag=1
        if [[ ! -f "${PATH_WX_ARCHIVE}" ]]; then
            echo_error "Archive file not found: ${PATH_WX_ARCHIVE}\nAborting."
            exit 1
        fi
        extract_archive ${PATH_WX_ARCHIVE} $(dirname ${DIR_WX_EXTRACT})
    fi
}



# Recreate the Build and Staging directories as necessary.
# When rebuilding, the contents of the Build and Staging directories are deleted.
recreate_wx_build_and_staging_dirs () {
    echo_debug "flag_rebuild: ${flag_rebuild}"
    local flag_rebuild=${1}
    if [ ${flag_rebuild} -gt 0 ]; then
        [[ -d "${DIR_WX_BUILD_DEST}" ]] && rm -rf "${DIR_WX_BUILD_DEST}"
        [[ -d "${DIR_WX_STAGING}" ]] && rm -rf "${DIR_WX_STAGING}"
    fi
    # NOTE: On MSYS, there is no need to create the actual build
    #       directory because it will be created by the Makefile
    if [[ "${OSTYPE}" == "${OSTYPE_LINUX}"* ]]; then
        [[ ! -d "${DIR_WX_BUILD_DEST}" ]] && mkdir -p "${DIR_WX_BUILD_DEST}"
    fi

    if [[ ! -d "${DIR_WX_STAGING}" ]]; then
        mkdir -p "${DIR_WX_STAGING}"
    fi
    echo_debug "function exit: recreate_wx_build_and_staging_dirs"
}



# Create CMake files for use by application CMake build scripts.
rewrite_wx_cmake_include_file () {
    local cmake_file="${DIR_CMAKE}/${LIB_WX}.cmake"
    [[ -f "${cmake_file}" ]] && rm -f "${cmake_file}"
    cat <<EOF > ${cmake_file}
set (WX_INCLUDE_DIR_1 ${DIR_WX_CLIENT_INCLUDE_1})
set (WX_INCLUDE_DIR_2 ${DIR_WX_CLIENT_INCLUDE_2})
set (wxWidgets_LIBRARY_DIRS ${DIR_WX_STAGING_LIBRARY})
list (APPEND WXWIDGETS_LIBRARY_FILES
$(echo "${BIN_LIB_FILENAMES_WX[@]}" | tr " " "\n")
)
EOF
}



# Copy wxWidgets library files
#
# Arguments:
#   Library version
#   Source directory
#   Destination directory
copy_wx_libraries () {
    local arg_lib_version="${1}"
    local arg_dest_dir="${2}"
    local v_source_dir="${DIR_WX_STAGING_LIBRARY}"
    local v_source_file=""
    echo -e "Copying ${LIB_WX_NAME} library files.\n  From: ${v_source_dir}\n  To: ${arg_dest_dir}"
    for item in "${BIN_LIB_FILENAMES_WX[@]}"; do
        if [[ "${OSTYPE}" == "${OSTYPE_LINUX}"* ]]; then
            v_source_file="${v_source_dir}/${item/000/${arg_lib_version%.*}}.6.0.0"
        elif [[ "${OSTYPE}" == "${OSTYPE_MSYS}" ]]; then
            v_source_file="${v_source_dir}/${item}"
        fi
        echo_debug "copy_wx_libraries: ${item} to ${v_source_file}"
        if [[ ! -f "${v_source_file}" ]]; then
            echo_error "${LIB_WX_NAME} library file does not exist: ${v_source_file}\nAborting."
            exit 1
        fi
        cp -u "${v_source_file}" "${arg_dest_dir}" 2>/dev/null
    done
}
