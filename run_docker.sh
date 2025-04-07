#!/bin/bash


DOCKER_IMAGE_NAME="ubuntu-npu"
DOCKER_IMAGE_VER="v1.8.11"
CONTAINER_NAME="${DOCKER_IMAGE_NAME}-$(date +%s)"


if docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "^${DOCKER_IMAGE_NAME}$"; then
    echo "docker 镜像 '$DOCKER_IMAGE_NAME' 不存在"
    exit 1
fi

run() {
    # 如果附带参数 -docker_mount ，则代表要增加映射的文件夹
    local command=""
    local PATH_MOUNT=""
    while [ "x$#" != "x0" ];
    do
        if [ "x$1" == "x-docker_mount" ]; then
            shift
            PATH_MOUNT="-v $1:$1"
            shift
        fi
        command="$command $1"
        shift
    done
    
    docker run --name "$CONTAINER_NAME" \
    --network host \
    ${PATH_MOUNT} \
    -v /etc/hosts:/etc/hosts:ro \
    -v /etc/resolv.conf:/etc/resolv.conf:ro \
    -v /etc/localtime:/etc/localtime:ro \
    -v "$(pwd):$(pwd)" \
    -w "$(pwd)" \
    -it --rm "$DOCKER_IMAGE_NAME:$DOCKER_IMAGE_VER" bash -c "$command"
}