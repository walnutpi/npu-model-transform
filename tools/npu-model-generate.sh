#!/bin/bash

DATA_PATH=$1
IMAGE_FILES_PATH=$2

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

for SUFFIX in ${MODEL_SUFFIX[@]}; do
    for file in $(find $DATA_PATH -name "*.${SUFFIX}"); do
        if [ -f "$file" ]; then
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
set -e

echo "开始量化"
cd $DATA_PATH
generate_quantize $IMAGE_FILES_PATH $ONNX_FILE_ABS_PATH_no_suffix

echo "生成.nb模型文件"
generate_nb_model $ONNX_FILE_ABS_PATH_no_suffix "${ONNX_FILE_ABS_PATH_no_suffix}.nb"
