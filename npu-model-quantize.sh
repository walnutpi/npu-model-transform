#!/bin/bash
PATH_SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
source $PATH_SCRIPT_DIR/common.sh $@

DATA_PATH=$1
IMAGE_FILES_PATH=$2

if [ -z "$DATA_PATH" ]; then
    echo -e "\t npu-model-quantize <model data path> <image-files-path>"
    echo -e "\t <model data path> : 指定一个存放了模型导出文件的路径"
    echo -e "\t <image-files-path> : 指定一个存放了测试图片的路径"
    echo -e "\t 对模型进行量化，并生成结果到 <model data path> 路径下"
    exit 1
fi



# 在DATA_PATH路径下查找后缀名为.onnx的第一个文件
ONNX_FILE_PATH=""
for file in $(find $DATA_PATH -name "*.onnx"); do
    if [ -f "$file" ]; then
        ONNX_FILE_PATH=$file
        break
    fi
done

if [ ! -f "$ONNX_FILE_PATH" ]; then
    echo "缺少.onnx文件"
    exit 1
fi
echo "查找到模型文件: $ONNX_FILE_PATH"

if [ -z "$IMAGE_FILES_PATH" ]; then
    echo "请传入图片文件所在路径"
    exit 1
fi

IMAGE_FILES_PATH="$(realpath $IMAGE_FILES_PATH)"
ONNX_FILE_ABS_PATH=$(realpath "$ONNX_FILE_PATH")
ONNX_FILE_ABS_PATH_no_suffix=${ONNX_FILE_ABS_PATH%.*}
# 判断是否需要在docker内挂载对应文件夹
if [ "${ONNX_FILE_ABS_PATH%/*}" != "$(pwd)" ]; then
    docker_add_mount "$(dirname $ONNX_FILE_ABS_PATH)"
fi
set -e

cd $DATA_PATH
generate_quantize $IMAGE_FILES_PATH $ONNX_FILE_ABS_PATH_no_suffix

