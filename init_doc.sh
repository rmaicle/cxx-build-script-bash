if [ ! -v flag_utility ]; then
    . utility.sh
fi

if [ ! -v flag_init_dir ]; then
    . init_dir.sh
    init_dir_vars
fi

declare -g flag_init_doc=1



#
# Document variables initialization.
#
#
init_doc_vars() {
    #local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

    declare -g DOC_BIN="${DIR_ROOT}/tools/md-to-pdf/build.sh"
    if [ ! -e "${DOC_BIN}" ]; then
        echo_error "File not found: ${DOC_BIN}"
        exit 1
    fi

    declare -g DOC_DEV_GUIDE="devguide"
    declare -g DOC_CPP_GUIDE="cppguide"
    declare -g DOC_APP_ACCOUNTING="accounting"

    declare -g -a DOCUMENTS=(
        ${DOC_DEV_GUIDE}
        ${DOC_CPP_GUIDE}
        ${DOC_APP_ACCOUNTING}
    )

    # See DIR_DOC value in init_dir.sh.
    declare -g DIR_DOC_DEV_GUIDE="${DIR_DOC}/dev-guide"
    declare -g DIR_DOC_CPP_GUIDE="${DIR_DOC}/cpp-guide"
    declare -g DIR_DOC_APP_ACCOUNTING="${DIR_DOC}/app-accounting"

    declare -g -a DIR_DOCUMENTS=(
        ${DIR_DOC_DEV_GUIDE}
        ${DIR_DOC_CPP_GUIDE}
        ${DIR_DOC_APP_ACCOUNTING}
    )

    # Document filenames
    declare -g DOC_FILE_DEV_GUIDE="dev-guide"
    declare -g DOC_FILE_CPP_GUIDE="cpp-guide"
    declare -g DOC_FILE_APP_ACCOUNTING="app-accg"

    declare -g -a FILE_DOCUMENTS=(
        ${DOC_FILE_DEV_GUIDE}
        ${DOC_FILE_CPP_GUIDE}
        ${DOC_FILE_APP_ACCOUNTING}
    )
}

#
# Show values of document variables
#
show_doc_vars() {
    echo "Documents:"
}
