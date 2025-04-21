#!/bin/bash
PATH_PWD="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"

creat_lnk() {
    link_path=$1
    link_file_name=$2
    if [ -L $link_path ]; then
        rm ${link_path}
    fi
    ln -s ${PATH_PWD}/$link_file_name ${link_path}
}

creat_lnk /usr/bin/npu-model-export tools/npu-model-export.sh
creat_lnk /usr/bin/npu-model-generate tools/npu-model-generate.sh
creat_lnk /usr/bin/npu-tool tools/npu-tool.sh
