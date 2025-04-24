#!/bin/bash

MODEL_FILE_PATH=$1
IMAGE_FILES_PATH=$2
if [ ! -f "$MODEL_FILE_PATH" ]; then
    echo "缺少模型文件"
    exit 1
fi
echo "查找到模型文件: $MODEL_FILE_PATH"

if [ -z "$IMAGE_FILES_PATH" ]; then
    echo "请传入图片文件所在路径"
    exit 1
fi

if [ -z "$MODEL_FILE_PATH" ]; then
    echo ""
    echo -e "npu-transfer-yolo <model-file> <image-files-path>"
    echo -e "  <model-file> : 指定一个由yolo导出的onnx文件路径"
    echo -e "  <image-files-path> : 指定一个存放了测试图片的路径,用于量化"
    echo -e "会生成同名.nb模型文件"
    echo -e "会生成一个 <modelfile>-data 文件夹,存放临时数据"

    echo ""
    echo -e "example:\n  npu-transfer-yolo ./yolov5s.onnx images/"
    echo ""
    exit 1
fi
IMAGE_FILES_PATH="$(realpath $IMAGE_FILES_PATH)"

source npu-model-export $MODEL_FILE_PATH

# 修改inputmeta文件里面的scale
inputmeta_file=$TMP_FILE_PREFIX"_inputmeta.yml"
sed -i '/scale:/,/preproc_node_params:/s/- 1.0/- 0.0039/g' "$inputmeta_file"

cd $PWD
npu-model-generate $TMP_DIR $IMAGE_FILES_PATH
