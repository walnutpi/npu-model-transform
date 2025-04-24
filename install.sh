#!/bin/bash
PATH_PWD="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"

creat_lnk() {
    local name=$1
    local link_path="/usr/bin/${name}"
    local link_file_name="tools/${name}.sh"
    if [ -L $link_path ]; then
        rm ${link_path}
    fi
    ln -s ${PATH_PWD}/$link_file_name ${link_path}
}

creat_lnk npu-model-export
creat_lnk npu-model-generate
creat_lnk npu-tool
creat_lnk npu-transfer-yolo
