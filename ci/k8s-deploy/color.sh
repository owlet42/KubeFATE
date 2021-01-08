#!/bin/bash
INFO="\033[36mINFO:\033[0m"
Warning="\033[33mWarning:\033[0m"
ERROR="\033[31mERROR:\033[0m"
Success="\033[32mSuccess:\033[0m"
DEBUG="\033[34mSuccess:\033[0m"

log() {
    echo $@
}

loginfo() {
    echo -e $INFO $@
}

logwarning() {
    echo -e $Warning $@
}

logerror() {
    echo -e $ERROR $@
}

logsuccess() {
    echo -e $Success $@
}

logdebug() {
    echo -e $DEBUG $@
}
