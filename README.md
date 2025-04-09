# npu-model-transform
用于将模型转为t527上npu所用的格式

运行以下命令进行安装，然后就可以在命令行使用几条命令
```shell
sudo ./install.sh
```


**npu-model-export** 导出指定onnx模型内的数据
**npu-model-quantize** 对onnx导出的模型进行uint8量化
**npu-model-generate** 将量化数据转为可用于npu的.nb格式文件
**npu-tool** 在当前路径打开npu工具的docker容器
