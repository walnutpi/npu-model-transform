#!/bin/bash
PATH_SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
source $PATH_SCRIPT_DIR/common.sh $@

ONNX_FILE_PATH=$1
IMAGE_FILES_PATH=$2

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

TMP_DIR="$(realpath ${ONNX_FILE_ABS_DIR}/.tmp-$ONNX_FILENAME_no_suffix)"
TMP_FILE_PREFIX="${TMP_DIR}/${ONNX_FILENAME_no_suffix}"
if [ -d "$TMP_DIR" ]; then
    rm -rf "$TMP_DIR"
fi
mkdir -p "$TMP_DIR"

cp $ONNX_FILE_PATH $TMP_DIR/

# 判断是否需要在docker内挂载对应文件夹
if [ "${ONNX_FILE_ABS_PATH%/*}" != "$(pwd)" ]; then
    docker_add_mount "$(dirname $ONNX_FILE_ABS_PATH)"
fi
set -e

echo "生成模型数据"
generate_model_data "${TMP_DIR}/${ONNX_FILENAME}" $TMP_FILE_PREFIX

echo "模型量化为uint8"
cd $TMP_DIR
generate_quantize $IMAGE_FILES_PATH $TMP_FILE_PREFIX

echo "生成.nb模型文件"
generate_nb_model $TMP_FILE_PREFIX "${ONNX_FILENAME_no_suffix}.nb"
