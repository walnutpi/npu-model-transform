#!/bin/bash

MODEL_FILE_PATH=$1

if [ -z "$MODEL_FILE_PATH" ]; then
    echo ""
    echo -e "npu-model-export <modelfile>"
    echo -e "  <modelfile> : 指定一个onnx文件路径"
    echo -e "导出指定<modelfile>模型文件内的数据，会在模型路径下生成一个 xxx-data 文件夹,存放如下数据"
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

generate_model_data_onnx() {
    local MODEL_FILE_PATH=$1
    local TMP_FILE_PREFIX=$2
    echo "正在导出模型数据"
    echo "MODEL_FILE_PATH= $MODEL_FILE_PATH"
    # 获取输入输出节点的name属性值
    local INFO=$(docker_run_python3 "
import onnx
import json
import sys
model = onnx.load('$MODEL_FILE_PATH')
onnx.checker.check_model(model)
input_names = [node.name for node in model.graph.input]
output_names = [node.name for node in model.graph.output]
input_shapes = [[dim.dim_value for dim in input_node.type.tensor_type.shape.dim] for input_node in model.graph.input]
print(json.dumps({'input_names': input_names, 'output_names': output_names, 'input_shapes': input_shapes}))
    ")
    if [ -z "$INFO" ]; then
        echo "Failed to extract input/output names from the MODEL model."
        exit 1
    fi
    local INPUT_NAMES=$(echo "$INFO" | jq -r '.input_names | join(" ")')
    local OUTPUT_NAMES=$(echo "$INFO" | jq -r '.output_names | join(" ")')
    local INPUT_SHAPES=$(echo "$INFO" | jq -r '.input_shapes[0][1:] | join(",")')

    # 检查最后两个维度是否为0
    local LAST_TWO_DIMS=$(echo "$INFO" | jq -r '.input_shapes[0][-2:] | join(",")')
    if [ "$LAST_TWO_DIMS" == "0,0" ]; then
        echo "请固定输入维度"
        exit 1
    fi

    if [ -z "$INPUT_NAMES" ] || [ -z "$OUTPUT_NAMES" ]; then
        echo "Failed to extract input/output names from the MODEL model."
        exit 1
    fi
    echo "inputs: $INPUT_NAMES"
    echo "outputs: $OUTPUT_NAMES"
    echo "input shapes: $INPUT_SHAPES"
    pegasus "import onnx --model ${MODEL_FILE_PATH} --output-model ${TMP_FILE_PREFIX}.json --output-data ${TMP_FILE_PREFIX}.data --inputs '${INPUT_NAMES}' --input-size-list '$INPUT_SHAPES' --outputs '${OUTPUT_NAMES}'"

}

generate_model_data_tflite() {
    local MODEL_FILE_PATH=$1
    local TMP_FILE_PREFIX=$2

    pegasus "import tflite --model ${TMP_FILE_PREFIX}.tflite --output-model ${TMP_FILE_PREFIX}.json --output-data ${TMP_FILE_PREFIX}.data"
}

generate_model_yaml() {
    local TMP_FILE_PREFIX=$1

    pegasus generate inputmeta --model ${TMP_FILE_PREFIX}.json --separated-database --input-meta-output ${TMP_FILE_PREFIX}_inputmeta.yml
    pegasus generate postprocess-file --model ${TMP_FILE_PREFIX}.json --postprocess-file-output ${TMP_FILE_PREFIX}_postprocess_file.yml
}

if [ ! -f "$MODEL_FILE_PATH" ]; then
    echo "请传入一个模型文件"
    exit 1
fi

MODEL_FILE_SUFFIX=${MODEL_FILE_PATH##*.}
SUPPORT_MODEL_FILE_SUFFIX=("onnx" "tflite")
if [[ ! " ${SUPPORT_MODEL_FILE_SUFFIX[*]} " =~ " ${MODEL_FILE_SUFFIX} " ]]; then
    echo "本脚本暂不支持该文件格式"
    exit 1
fi

MODEL_FILENAME=$(basename "$MODEL_FILE_PATH")
MODEL_FILENAME_no_suffix=${MODEL_FILENAME%.*}
MODEL_FILE_ABS_PATH=$(realpath "$MODEL_FILE_PATH")
MODEL_FILE_ABS_DIR=$(dirname "$MODEL_FILE_PATH")
TMP_DIR="$(realpath ${MODEL_FILE_ABS_DIR}/$MODEL_FILENAME_no_suffix)-data"
TMP_FILE_PREFIX="${TMP_DIR}/${MODEL_FILENAME_no_suffix}"

# 判断是否需要在docker内挂载对应文件夹
if [ "${MODEL_FILE_ABS_PATH%/*}" != "$(pwd)" ]; then
    docker_add_mount "$(dirname $MODEL_FILE_ABS_PATH)"
fi

if [ -d "$TMP_DIR" ]; then
    rm -rf "$TMP_DIR"
fi
mkdir -p "$TMP_DIR"
cp $MODEL_FILE_PATH $TMP_DIR/
cd $TMP_DIR

set -e
if [ "${MODEL_FILE_SUFFIX}" == "onnx" ]; then
    echo "文件是 onnx 格式"
    generate_model_data_onnx "${TMP_FILE_PREFIX}.onnx" $TMP_FILE_PREFIX

elif [ "${MODEL_FILE_SUFFIX}" == "tflite" ]; then
    echo "文件是 tflite 格式"
    generate_model_data_tflite "${TMP_FILE_PREFIX}.tflite" $TMP_FILE_PREFIX

fi
generate_model_yaml $TMP_FILE_PREFIX
