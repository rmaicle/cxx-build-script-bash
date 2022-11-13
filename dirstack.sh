#
# "Silenced" directory stack functions
#



# Silent pushd command
pushd() {
    command pushd "$@" > /dev/null
}

# Silent popd command
popd() {
    command popd "$@" > /dev/null
}
