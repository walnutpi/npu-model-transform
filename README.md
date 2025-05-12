# npu-model-transform
用于将模型转为t527上npu所用的格式

运行以下命令进行安装，然后就可以在命令行使用几条命令
```shell
sudo ./install.sh
```

## npu-transfer-yolo
yolo格式专用的快捷指令
1. 启用npu自带的前处理对输入数据自动转为浮点数
2. 设置为uint8量化

