SHELL := /bin/bash
WORK_ROOT := $(shell pwd)
APT_FILE_PATH := /etc/apt/sources.list
TEMP_DIR := $(WORK_ROOT)/temp
PYTHON_VERSION := 3.11.0
MIRROR_TUNA := https://mirrors.tuna.tsinghua.edu.cn
MIRROR_HUAWEICLOUD := https://mirrors.huaweicloud.com
CONFIG_FILE := /boot/config.txt
ARM_FREQ := arm_freq=2100
OVER_VOLTAGE := over_voltage=10
CORE_FREQ := core_freq=750
ARM_64BIT := arm_64bit=0
KAZU_REPO := https://mirror.ghproxy.com/https://github.com/Kazu-Kusa/kazu.git
CV_URL := https://mirror.ghproxy.com/https://github.com/Kazu-Kusa/built-packages/releases/download/2024.5.30/opencv_python_headless-4.9.0.80-cp311-cp311-linux_armv7l.whl
NP_URL := https://mirror.ghproxy.com/https://github.com/Kazu-Kusa/built-packages/releases/download/2024.5.30/numpy-1.26.4-cp311-cp311-linux_armv7l.whl
.PHONY: all set_apt_mirror update_apt upgrade_apt setup_environment install_python set_py_mirror setup_pdm check_modules install_wiringpi config_hardware clean install_sysbench install_kazu overclock bench install_utils help

all: check_modules set_py_mirror setup_pdm install_wiringpi config_hardware  bench install_kazu overclock
# 检查并追加字符串到文件的函数
define check-and-append-string
	if grep -q $(2) $(1); then \
		echo "String '$(2)' already exists in the file '$(1)', do nothing."; \
	else \
		echo "$(2)" >> $(1); \
		echo "String '$(2)' appended to the file '$(1)."; \
	fi
endef

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
	git clone $(KAZU_REPO) && \
	cd kazu  && \
	pdm add --save-only $(CV_URL) $(NP_URL) && \
	pdm install -v

overclock:
	$(call check-and-append-string,$(CONFIG_FILE),$(ARM_FREQ))
	$(call check-and-append-string,$(CONFIG_FILE),$(OVER_VOLTAGE))
	$(call check-and-append-string,$(CONFIG_FILE),$(CORE_FREQ))
	$(call check-and-append-string,$(CONFIG_FILE),$(ARM_64BIT))
	$(call check-and-append-string,$(CONFIG_FILE),"avoid_warnings=1")
	@echo "注意：如果超频设置更改后必须要重启后才会生效"

bench:install_sysbench
	sysbench cpu --cpu-max-prime=10000 --threads=4 run

	echo "Usually, the Event per Second  is around 460~560"


install_utils: upgrade_apt
	sudo apt install -y htop git fish

help:
	@echo "all: all"
	@echo "setup_environment: setup environment for installation of the project"
	@echo "install_python: install python$(PYTHON_VERSION) interpreter"
	@echo "check_modules: check python modules' normal function"
	@echo "install_wiringpi: install wiringpi which is required to control the fan"
	@echo "config_hardware: config hardware to fit the project"
	@echo "clean: clean up temp files"
	@echo "install_sysbench: install sysbench using apt"
	@echo "install_fish: install fish using apt"
	@echo "clone_kazu: clone kazu repo from github, see $(KAZU_REPO)"
	@echo "bench: benchmark with sysbench"
	@echo "install_utils: install utils"
	@echo "overclock: overclock settings $(ARM_FREQ)| $(OVER_VOLTAGE)| $(CORE_FREQ)| $(ARM_64BIT)"
