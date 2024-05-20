#!/bin/sh

pip install -i https://pypi.tuna.tsinghua.edu.cn/simple --upgrade pip

pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple

pip install pdm --verbose

pdm config pypi.url https://pypi.tuna.tsinghua.edu.cn/simple

