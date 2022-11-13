#
# CPU variables and utility functions
#

# Obtain number of CPUs/cores
# https://stackoverflow.com/a/6481016
CPU_COUNT_MAX=$(grep ^cpu\\scores /proc/cpuinfo | uniq |  awk '{print $4}')
THREAD_COUNT_MAX=$(grep -c ^processor /proc/cpuinfo)
