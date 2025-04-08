#!/bin/bash
PATH_PWD="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"

creat_lnk() {
    link_path=$1
    link_file_name=$2
    if [  -L $link_path ]; then
        rm ${link_path}
    fi
    ln -s ${PATH_PWD}/$link_file_name ${link_path}
}

creat_lnk /usr/bin/npu-model-export  npu-model-export.sh 
creat_lnk /usr/bin/npu-model-quantize  npu-model-quantize.sh 
creat_lnk /usr/bin/npu-model-generate  npu-model-generate.sh 
