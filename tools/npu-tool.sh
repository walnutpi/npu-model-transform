#!/bin/bash
PATH_SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
source $PATH_SCRIPT_DIR/common.sh $@

docker_enter