#!/usr/bin/env bash

source "${DIR}/init_system.sh"
source "${DIR}/utils.sh"



# For now, we use only shared libraries
declare -g LIB_SHARED="shared"
declare -g LIB_STATIC="static"

# Last version string is the default
declare -g -a LIBRARY_TYPES=(
    "${LIB_STATIC}"
    "${LIB_SHARED}"
)
