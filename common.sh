#!/bin/bash


DOCKER_IMAGE_NAME="ubuntu-npu"
DOCKER_IMAGE_VER="v1.8.11"
NPU_VERSION="VIP9000NANOSI_PLUS_PID0X10000016"
CONTAINER_NAME="${DOCKER_IMAGE_NAME}-$(date +%s)"
PATH_MOUNT=""


if docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "^${DOCKER_IMAGE_NAME}$"; then
    echo "docker 镜像 '$DOCKER_IMAGE_NAME' 不存在"
    exit 1
fi

docker_add_mount(){
    # 参数1是想要在docker运行时映射的路径
    local path_to_mount=$1
    if [ ! -d "$path_to_mount" ]; then
        echo "路径不存在：$path_to_mount"
        exit 1
    fi
    PATH_MOUNT="$PATH_MOUNT -v $path_to_mount:$path_to_mount"
}

docker_run_bash() {
    local command=$@
    echo "command=$command"
    docker run --name "$CONTAINER_NAME" \
    --network host \
    ${PATH_MOUNT} \
    -v /etc/hosts:/etc/hosts:ro \
    -v /etc/resolv.conf:/etc/resolv.conf:ro \
    -v /etc/localtime:/etc/localtime:ro \
    -v "$(pwd):$(pwd)" \
    -w "$(pwd)" \
    -it --rm "$DOCKER_IMAGE_NAME:$DOCKER_IMAGE_VER" /bin/bash -c "$command"
}

docker_run_python3() {
    local command=$@
    docker run --name "$CONTAINER_NAME" \
    --network host \
    ${PATH_MOUNT} \
    -v /etc/hosts:/etc/hosts:ro \
    -v /etc/resolv.conf:/etc/resolv.conf:ro \
    -v /etc/localtime:/etc/localtime:ro \
    -v "$(pwd):$(pwd)" \
    -w "$(pwd)" \
    -it --rm "$DOCKER_IMAGE_NAME:$DOCKER_IMAGE_VER" /bin/python3 -c "$command"
}

# export ACUITY_PATH=/root/acuity-toolkit-whl-6.21.16/bin
# export VIV_SDK=/root/Vivante_IDE/VivanteIDE5.8.2/cmdtools
# alias pegasus='python3 /root/acuity-toolkit-whl-6.21.16/bin/pegasus.py'
# alias nbinfo='/root/nbinfo'

# # set env variables
# export VSI_USE_IMAGE_PROCESS=1
# export VSI_NN_ENABLE_OCV_NV12=1

# # set optimize env variables
# export VIV_VX_ENABLE_GRAPH_TRANSFORM=-bn2dwconv:2
# #export VIV_VX_ENABLE_GRAPH_TRANSFORM=-Dump-bn2dwconv:2
pegasus() {
    docker_run_bash python3 /root/acuity-toolkit-whl-6.21.16/bin/pegasus.py $*
}

generate_model_data(){
    local ONNX_FILE_PATH=$1
    local TMP_FILE_PREFIX=$2
    
    # 获取输入输出节点的name属性值
    local INFO=$(docker_run_python3 "
import onnx
import json
import sys
model = onnx.load('$ONNX_FILE_PATH')
onnx.checker.check_model(model)
input_names = [node.name for node in model.graph.input]
output_names = [node.name for node in model.graph.output]
input_shapes = [[dim.dim_value for dim in input_node.type.tensor_type.shape.dim] for input_node in model.graph.input]
print(json.dumps({'input_names': input_names, 'output_names': output_names, 'input_shapes': input_shapes}))
    ")
    if [ -z "$INFO" ]; then
        echo "Failed to extract input/output names from the ONNX model."
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
        echo "Failed to extract input/output names from the ONNX model."
        exit 1
    fi
    echo "inputs: $INPUT_NAMES"
    echo "outputs: $OUTPUT_NAMES"
    echo "input shapes: $INPUT_SHAPES"
    
    pegasus "import onnx --model ${ONNX_FILE_PATH} --output-model ${TMP_FILE_PREFIX}.json --output-data ${TMP_FILE_PREFIX}.data --inputs '${INPUT_NAMES}' --input-size-list '$INPUT_SHAPES' --outputs '${OUTPUT_NAMES}'"
    pegasus generate inputmeta --model ${TMP_FILE_PREFIX}.json --separated-database --input-meta-output ${TMP_FILE_PREFIX}_inputmeta.yml
    pegasus generate postprocess-file --model ${TMP_FILE_PREFIX}.json --postprocess-file-output ${TMP_FILE_PREFIX}_postprocess_file.yml
}
generate_quantize(){
    local IMAGE_FILES_PATH=$1
    local TMP_FILE_PREFIX=$2
    local dataset_path="$(dirname $TMP_FILE_PREFIX)/dataset.txt"
    if [ ! -d "$IMAGE_FILES_PATH" ]; then
        echo "路径不存在：$IMAGE_FILES_PATH"
        exit 1
    fi
    docker_add_mount "$(dirname $IMAGE_FILES_PATH)"
    find ${IMAGE_FILES_PATH}/* > ${dataset_path}
    pegasus quantize --model ${TMP_FILE_PREFIX}.json --model-data ${TMP_FILE_PREFIX}.data --device CPU --with-input-meta ${TMP_FILE_PREFIX}_inputmeta.yml --compute-entropy --rebuild --model-quantize ${TMP_FILE_PREFIX}_uint8.quantize --quantizer asymmetric_affine --qtype uint8
}

generate_nb_model(){
    local TMP_FILE_PREFIX=$1
    local OUTPU_FILENAME=$2
    local VIV_SDK="/root/Vivante_IDE/VivanteIDE5.8.2/cmdtools"
    local tmp_dir="${TMP_FILE_PREFIX}_out"
    pegasus export ovxlib --model ${TMP_FILE_PREFIX}.json --model-data ${TMP_FILE_PREFIX}.data --dtype quantized --model-quantize ${TMP_FILE_PREFIX}_uint8.quantize --target-ide-project 'linux64' --with-input-meta ${TMP_FILE_PREFIX}_inputmeta.yml --postprocess-file ${TMP_FILE_PREFIX}_postprocess_file.yml --pack-nbg-unify --optimize ${NPU_VERSION} --viv-sdk ${VIV_SDK} --output-path "${tmp_dir}/model"
    cp "${tmp_dir}_nbg_unify/network_binary.nb" $OUTPU_FILENAME
    echo ""
    echo "output: $OUTPU_FILENAME"
    echo ""
}