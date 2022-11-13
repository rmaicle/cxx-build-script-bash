#
# Date/time utilities
#


#
# Return current UTC date/time in ISO-8601 basic format.
#
get_utc_iso8601_basic() {
    echo $(date -u +'%Y%m%dT%H%M%SZ')
}

#
# Return current UTC date/time in ISO-8601 extended  format.
#
get_utc_iso8601_ext() {
    echo $(date -u +'%Y-%m-%d %H:%M:%SZ')
}




#
# Return local date/time in ISO-8601 basic format without TZ.
#
get_local_iso8601_basic() {
    echo $(date +'%Y%m%dT%H%M%S')
}

#
# Return local date/time in ISO-8601 extended format without TZ.
#
get_local_iso8601_ext() {
    echo $(date +'%Y-%m-%d %H:%M:%S')
}



#
# Return local date/time in ISO-8601 basic format with TZ.
#
get_local_tz_iso8601_basic() {
    echo $(date +'%Y%m%dT%H%M%S%z')
}

#
# Return local date/time in ISO-8601 extended format with TZ.
#
get_local_tz_iso8601_ext() {
    echo $(date +'%Y-%m-%d %H:%M:%S%z')
}



#
# Return local date/time in custom format without TZ:
#   yyyymmdd-hhmmss
#
get_local_custom() {
    echo $(date +'%Y%m%d-%H%M%S')
}

#
# Return local date/time in custom format with TZ:
#   yyyymmdd-hhmmss+hhmm
#
get_local_tz_custom() {
    echo $(date +'%Y%m%d-%H%M%S%z')
}
