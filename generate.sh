#!/bin/bash
PATH_SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
source $PATH_SCRIPT_DIR/common.sh $@

ONNX_FILE_PATH=$1

if [ ! -f "$ONNX_FILE_PATH" ]; then
    echo "请传入一个.onnx文件"
    exit 1
fi
# 文件是否以onnx结尾
if [ "${ONNX_FILE_PATH##*.}" != "onnx" ]; then
    echo "文件不是onnx格式"
    exit 1
fi

ONNX_FILENAME=$(basename "$ONNX_FILE_PATH")
ONNX_FILENAME_no_suffix=${ONNX_FILENAME%.*}
ONNX_FILE_ABS_PATH=$(realpath "$ONNX_FILE_PATH")
ONNX_FILE_ABS_DIR=$(dirname "$ONNX_FILE_PATH")

TMP_DIR="${ONNX_FILE_ABS_DIR}/.tmp-$ONNX_FILENAME_no_suffix"
TMP_FILE_PREFIX="${TMP_DIR}/${ONNX_FILENAME_no_suffix}"
if [ -d "$TMP_DIR" ]; then
    rm -rf "$TMP_DIR"
fi
mkdir -p "$TMP_DIR"

# 判断是否需要在docker内挂载对应文件夹
MOUNT_PATH=""
if [ "${ONNX_FILE_ABS_PATH%/*}" != "$(pwd)" ]; then
    docker_mount "$(dirname $ONNX_FILE_ABS_PATH)"
fi
set -e


generate_model_data $ONNX_FILE_PATH $TMP_FILE_PREFIX

