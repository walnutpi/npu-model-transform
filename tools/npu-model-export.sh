#!/bin/bash

ONNX_FILE_PATH=$1

if [ -z "$ONNX_FILE_PATH" ]; then
    echo ""
    echo -e "npu-model-export <XXX.onnx>"
    echo -e "  <XXX.onnx> : 指定一个onnx文件路径"
    echo -e "导出指定<XXX.onnx>模型文件内的数据，会在模型路径下生成一个 xxx-data 文件夹,存放如下数据"
    echo -e "    - XXX.json 网络结构文件"
    echo -e "    - XXX.data 网络权重文件"
    echo -e "    - XXX_inputmeta.yml 输入描述文件"
    echo -e "    - XXX_postprocess_file.yml 输出描述文件"
    
    echo ""
    echo -e "example:\n  npu-model-export ./yolov5s.onnx"
    echo ""
    exit 1
fi

PATH_SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
source $PATH_SCRIPT_DIR/common.sh $@

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

TMP_DIR="$(realpath ${ONNX_FILE_ABS_DIR}/$ONNX_FILENAME_no_suffix)-data"
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

generate_model_data "${TMP_DIR}/${ONNX_FILENAME}" $TMP_FILE_PREFIX

