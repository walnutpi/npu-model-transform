#!/bin/bash
PATH_SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
source $PATH_SCRIPT_DIR/run_docker.sh
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

# 获取输入输出节点的name属性值
INFO=$(run_python3 "
import onnx
import json
import sys
model = onnx.load('$ONNX_FILE_PATH')
onnx.checker.check_model(model)
input_names = [node.name for node in model.graph.input]
output_names = [node.name for node in model.graph.output]
print(json.dumps({'input_names': input_names, 'output_names': output_names}))
")
echo "inputs: $INFO"
if [ -z "$INFO" ]; then
    echo "Failed to extract input/output names from the ONNX model."
    exit 1
fi
INPUT_NAMES=$(echo "$INFO" | jq -r '.input_names | join(",")')
OUTPUT_NAMES=$(echo "$INFO" | jq -r '.output_names | join(",")')
if [ -z "$INPUT_NAMES" ] || [ -z "$OUTPUT_NAMES" ]; then
    echo "Failed to extract input/output names from the ONNX model."
    exit 1
fi
echo "inputs: $INPUT_NAMES"
echo "outputs: $OUTPUT_NAMES"


pegasus import onnx --model ${ONNX_FILE_PATH} --output-model ${TMP_FILE_PREFIX}.json --output-data ${TMP_FILE_PREFIX}.data --inputs ${INPUT_NAMES} --input-size-list '3,640,640' --outputs ${OUTPUT_NAMES} 
pegasus generate inputmeta --model ${TMP_FILE_PREFIX}.json --separated-database --input-meta-output ${TMP_FILE_PREFIX}_inputmeta.yml
pegasus generate postprocess-file --model ${TMP_FILE_PREFIX}.json --postprocess-file-output ${TMP_FILE_PREFIX}_postprocess_file.yml

