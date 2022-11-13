declare -g flag_init_dir=0



#
# Directory variables initialization
# Arguments:
#   Root directory
init_dir_vars () {
    if [[ ${flag_init_dir} -eq 0 ]]; then
        declare -g -r DIR_PROJECT_ROOT="$(cd ../.. && pwd)"
        declare -g -r DIR_BIN="${DIR_PROJECT_ROOT}/bin"

        # Out-of-source build
        declare -g -r DIR_BUILD="${DIR_PROJECT_ROOT}/build"
        # declare -g -r DIR_BUILD_LIB="${DIR_BUILD}/lib"
        # declare -g -r DIR_BUILD_APP="${DIR_BUILD}/app"
        # Try avoiding CMake's "multiple target patterns" error
        # by using relative path
        # declare -g -r DIR_BUILD="../../build"

        declare -g -r DIR_DEV="$(cd .. && pwd)"
        # declare -g DIR_BIN="${DIR_DEV}/bin"
        # declare -g DIR_BUILD="${DIR_DEV}/build"
        declare -g -r DIR_CMAKE="${DIR_DEV}/cmake"
        [[ ! -d "${DIR_CMAKE}" ]] && mkdir "${DIR_CMAKE}"
        declare -g -r DIR_LIB="${DIR_DEV}/lib"
        declare -g -r DIR_EXTERN="${DIR_DEV}/lib"
        declare -g -r DIR_SRC="${DIR_DEV}/src"
        # declare -g DIR_APP_ROOT="${DIR_SRC}/app"
        # declare -g -r DIR_APP_ROOT="${DIR_DEV}/src"
        # Set only by compiler utility function

        # Move the external libraries out of the lib root directory so the
        # project repository will not contain big binary files.
        # This will also allow creating branches/forks of the project
        # repository and still use the same external libraries.

        # declare -g DIR_APP_INTERNAL="${DIR_APP_ROOT}/internal.cpp"
        # declare -g DIR_APP_EXTERNAL="${DIR_APP_ROOT}/external.cpp"

        # TODO: Read configuration file from DIR_APP_INTERNAL for specific application directories
        # TODO: Read configuration file from DIR_APP_EXTERNAL for specific application directories

        flag_init_dir=1
    fi
}

#
# Show values of directory variables
#
show_dir_vars () {
    echo "Directories:"
    echo "  Project Root: ${DIR_PROJECT_ROOT}"
    echo "  Bin:          ${DIR_BIN}"
    echo "  Build:        ${DIR_BUILD}"
    echo "  Dev:          ${DIR_DEV}"
    echo "  CMake:        ${DIR_CMAKE}"
    echo "  Extern:       ${DIR_EXTERN}"
    echo "  Source:       ${DIR_SRC}"
}


# TODO: Rename to get_build_common_dir

# # Return directory name suffix for libraries.
# #   Format: <lib-type>-<build-type>-<compiler><compiler-version>-<c++std>
# # Arguments:
# #   library type
# #   build type
# #   compiler
# #   compiler version
# #   c++ standard id
# get_lib_dir_build_common () {
#     if [ $# -lt 5 ]; then
#         echo ""
#     fi
#     echo "${1}-${2}-${3}$(undot ${4})-${5}"
# }



# # Return directory name suffix for third-party applications.
# #   Format: <build-type>-<compiler><compiler-version>-<c++std>
# # Arguments:
# #   build type
# #   compiler
# #   compiler version
# #   c++ standard id
# get_app_dir_suffix () {
#     if [ $# -lt 4 ]; then
#         echo ""
#     fi
#     echo "${1}-${2}$(undot ${3})-${4}"
# }
