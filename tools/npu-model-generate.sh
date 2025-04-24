#!/bin/bash

DATA_PATH=$1
IMAGE_FILES_PATH=$2
PWD_PATH=$(pwd)
echo "PWD_PATH=$PWD_PATH"
if [ -z "$DATA_PATH" ]; then
    echo ""
    echo -e "npu-model-generate <export data path> <image-files-path>"
    echo -e "  <export data path> : 指定一个存放了 npu-model-export命令 导出数据的路径"
    echo -e "  <image-files-path> : 指定一个存放了测试图片的路径"
    echo -e "对模型进行量化,生成.nb模型文件存放到 <export data path> 路径下"

    echo ""
    echo -e "example:\n  npu-model-generate yolov5s-data/ images/"
    echo ""
    exit 1
fi

PATH_SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
source $PATH_SCRIPT_DIR/common.sh $@

# 在DATA_PATH路径下查找后缀名为.onnx的第一个文件
MODEL_FILE_PATH=""
MODEL_SUFFIX=("onnx" "tflite")
# 遍历DATA_PATH路径下的所有文件，查找后缀名为MMODEL_SUFFIX内容的第一个文件
MODEL_FILENAME=""
for SUFFIX in ${MODEL_SUFFIX[@]}; do
    for file in $(find $DATA_PATH -name "*.${SUFFIX}"); do
        if [ -f "$file" ]; then
            MODEL_FILENAME=$(basename "$file")
            MODEL_FILE_PATH=$file
            break
        fi
    done
    if [ "x${MODEL_FILE_PATH}" != "x" ]; then
        break
    fi
done

if [ ! -f "$MODEL_FILE_PATH" ]; then
    echo "缺少模型文件"
    exit 1
fi
echo "查找到模型文件: $MODEL_FILE_PATH"

if [ -z "$IMAGE_FILES_PATH" ]; then
    echo "请传入图片文件所在路径"
    exit 1
fi

IMAGE_FILES_PATH="$(realpath $IMAGE_FILES_PATH)"
ONNX_FILE_ABS_PATH=$(realpath "$MODEL_FILE_PATH")
ONNX_FILE_ABS_PATH_no_suffix=${ONNX_FILE_ABS_PATH%.*}
# 判断是否需要在docker内挂载对应文件夹
if [ "${ONNX_FILE_ABS_PATH%/*}" != "$(pwd)" ]; then
    docker_add_mount "$(dirname $ONNX_FILE_ABS_PATH)"
fi

generate_quantize() {
    local IMAGE_FILES_PATH=$1
    local TMP_FILE_PREFIX=$2
    local dataset_path="$(dirname $TMP_FILE_PREFIX)/dataset.txt"
    if [ ! -d "$IMAGE_FILES_PATH" ]; then
        echo "路径不存在：$IMAGE_FILES_PATH"
        exit 1
    fi
    docker_add_mount "$(dirname $IMAGE_FILES_PATH)"
    find ${IMAGE_FILES_PATH}/* >${dataset_path}
    pegasus quantize --model ${TMP_FILE_PREFIX}.json --model-data ${TMP_FILE_PREFIX}.data --device CPU --with-input-meta ${TMP_FILE_PREFIX}_inputmeta.yml --compute-entropy --rebuild --model-quantize ${TMP_FILE_PREFIX}_uint8.quantize --quantizer asymmetric_affine --qtype uint8
}

generate_nb_model() {
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

set -e

echo "开始量化"
cd $DATA_PATH
generate_quantize $IMAGE_FILES_PATH $ONNX_FILE_ABS_PATH_no_suffix

echo "生成.nb模型文件"
PATH_OUT_FILE_NAME=$(realpath "${PWD_PATH}/${MODEL_FILENAME%.onnx}.nb")
generate_nb_model $ONNX_FILE_ABS_PATH_no_suffix $PATH_OUT_FILE_NAME
