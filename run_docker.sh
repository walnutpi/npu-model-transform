#!/bin/bash


DOCKER_IMAGE_NAME="ubuntu-npu"
DOCKER_IMAGE_VER="v1.8.11"
CONTAINER_NAME="${DOCKER_IMAGE_NAME}-$(date +%s)"
PATH_MOUNT=""


if docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "^${DOCKER_IMAGE_NAME}$"; then
    echo "docker 镜像 '$DOCKER_IMAGE_NAME' 不存在"
    exit 1
fi

docker_mount(){
    # 参数1是想要在docker运行时映射的路径
    local path_to_mount=$1
    if [ ! -d "$path_to_mount" ]; then
        echo "路径不存在：$path_to_mount"
        exit 1
    fi
    PATH_MOUNT="-v $path_to_mount:$path_to_mount"
    
}

run() {
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

run_python3() {
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
    run python3 /root/acuity-toolkit-whl-6.21.16/bin/pegasus.py $*
}