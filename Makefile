SHELL := /bin/bash
WORK_ROOT := $(shell pwd)
APT_FILE_PATH := /etc/apt/sources.list
TEMP_DIR := $(WORK_ROOT)/temp
PYTHON_VERSION := 3.11.0
MIRROR_TUNA := https://mirrors.tuna.tsinghua.edu.cn
MIRROR_HUAWEICLOUD := https://mirrors.huaweicloud.com

.PHONY: all setup_environment install_python check_modules install_wiringpi config_hardware clean install_sysbench install_kazu bench install_utils

all: check_modules set_py_mirror setup_pdm install_wiringpi config_hardware  bench install_kazu


set_apt_mirror:
	@echo "Setting apt mirror..."
	sudo sh -c "echo 'deb $(MIRROR_TUNA)/raspbian/raspbian/ bullseye main non-free contrib rpi' > $(APT_FILE_PATH)"
	sudo sh -c "echo 'deb-src $(MIRROR_TUNA)/raspbian/raspbian/ bullseye main non-free contrib rpi' >> $(APT_FILE_PATH)"

update_apt:set_apt_mirror
	sudo apt update

upgrade_apt:update_apt
	sudo apt upgrade -y

setup_environment:
	@echo "Setting up environment..."
	mkdir -p $(TEMP_DIR)
	sudo chmod 777 $(TEMP_DIR)
	sudo apt install -y  gcc cmake

install_python: setup_environment
	@echo "Checking for Python $(PYTHON_VERSION) installation..."
	if ! python3 --version 2>&1 | grep -qF $PYTHON_VERSION; then \
		echo "Python $(PYTHON_VERSION) not found, installing dependencies..."; \
		sudo apt install -y build-essential libffi-dev libssl-dev openssl; \
		cd $(TEMP_DIR) && \
		wget $(MIRROR_HUAWEICLOUD)/python/$(PYTHON_VERSION)/Python-$(PYTHON_VERSION).tar.xz && \
		tar -xf Python-$(PYTHON_VERSION).tar.xz && \
		cd Python-$(PYTHON_VERSION) && \
		./configure --enable-optimizations && \
		make -j4 && \
		sudo make install; \
	else \
		echo "Python $(PYTHON_VERSION) is already installed."; \
	fi
set_py_mirror:install_python
	@echo "Setting Python mirror..."
	pip config set global.index-url https://pypi.mirrors.ustc.edu.cn/simple && \
	pip install --upgrade pip
setup_pdm: set_py_mirror
	@echo "Setting up pdm..."
	pip install pdm --verbose
	pdm config pypi.url https://pypi.tuna.tsinghua.edu.cn/simple

check_modules: install_python
	@echo "Checking Python modules..."
	@[ -z "$(python3 -c 'import ssl' 2>&1)" ] || (echo "ssl module installed." && exit 0) || (echo "ssl module not found." && make install_python)
	@[ -z "$(python3 -c 'import ctypes' 2>&1)" ] || (echo "ctypes module installed." && exit 0) || (echo "ctypes module not found." && make install_python)

install_wiringpi:
	@command -v gpio || (echo "Installing WiringPi..." && \
	cd $(TEMP_DIR) && \
	rm -f wiringpi-latest.deb && \
	wget https://project-downloads.drogon.net/wiringpi-latest.deb && \
	sudo dpkg -i wiringpi-latest.deb)

config_hardware: install_wiringpi
	@echo "Configuring hardware..."
	sudo raspi-config nonint do_i2c 0
	sudo raspi-config nonint do_spi 0
	sudo raspi-config nonint do_gpio 0
	sudo raspi-config nonint do_fan 0 18 60000
	sudo apt-get install -y libtinfo-dev raspberrypi-kernel-headers libpigpiod-if2-1 pigpiod
	@if ! systemctl is-enabled pigpiod >/dev/null 2>&1; then \
		sudo systemctl enable pigpiod && sudo pigpiod && echo "pigpiod enabled on startup"; \
	else \
		echo "pigpiod already enabled on startup"; \
	fi

clean:
	@echo "Cleaning up..."
	rm -rf $(TEMP_DIR)

install_sysbench:
	sudo apt install -y sysbench


install_kazu: install_git setup_pdm
	@echo "Cloning kazu..."
	cd $(WORK_ROOT) && \
	git clone https://github.com/Kazu-Kusa/kazu.git && \
	cd kazu && \
	pdm add --save-only https://mirror.ghproxy.com/https://github.com/Kazu-Kusa/built-packages/releases/download/2024.5.30/numpy-1.26.4-cp311-cp311-linux_armv7l.whl https://mirror.ghproxy.com/https://github.com/Kazu-Kusa/built-packages/releases/download/2024.5.30/opencv_python_headless-4.9.0.80-cp311-cp311-linux_armv7l.whl && \
	pdm install -v
bench:install_sysbench
	sysbench cpu --cpu-max-prime=10000 --threads=4 run

	echo "Usually, the Event per Second  is around 460~560"


install_utils: upgrade_apt
	sudo apt install -y htop git fish

help:
	@echo "all: all"
	@echo "setup_environment: setup environment"
	@echo "install_python: install python dependencies"
	@echo "check_modules: check python modules"
	@echo "install_wiringpi: install wiringpi"
	@echo "config_hardware: config hardware"
	@echo "clean: clean up"
	@echo "install_sysbench: install sysbench"
	@echo "install_fish: install fish"
	@echo "clone_kazu: clone kazu"
	@echo "bench: bench"
	@echo "install_utils: install utils"
