SHELL := /bin/bash
WORK_ROOT := $(shell pwd)
APT_FILE_PATH := /etc/apt/sources.list
APT_FILE_PATH0 := /etc/apt/sources.list.d/raspi.list
TEMP_DIR := $(WORK_ROOT)/temp
PYTHON_VERSION := 3.11.0
SIMPLIFIED_PY_VERSION := $(subst .0,,${PYTHON_VERSION})
TAR_FILE=Python-$(PYTHON_VERSION).tar.xz
MIRROR_TUNA := https://mirrors.tuna.tsinghua.edu.cn
MIRROR_HUAWEICLOUD := https://mirrors.huaweicloud.com
PYTHON_DOWNLOAD_URL=$(MIRROR_HUAWEICLOUD)/python/$(PYTHON_VERSION)/$(TAR_FILE)
PYPI_INDEX=https://pypi.tuna.tsinghua.edu.cn/simple
CONFIG_FILE := /boot/config.txt
ARM_FREQ := arm_freq=2100
OVER_VOLTAGE := over_voltage=10
CORE_FREQ := core_freq=750
ARM_64BIT := arm_64bit=0
#KAZU_REPO := https://mirror.ghproxy.com/https://github.com/Kazu-Kusa/kazu.git
KAZU_REPO :=https://github.com/Kazu-Kusa/kazu
#GIT_RELEASE_BASE_URL := https://mirror.ghproxy.com/https://github.com/Kazu-Kusa/built-packages/releases/download/2024.5.30
GIT_RELEASE_BASE_URL := https://github.com/Kazu-Kusa/built-packages/releases/download/2024.5.30
CV_URL := $(GIT_RELEASE_BASE_URL)/opencv_python_headless-4.10.0.84-cp311-cp311-linux_armv7l.whl
NP_URL := $(GIT_RELEASE_BASE_URL)/numpy-2.0.0-cp311-cp311-linux_armv7l.whl

PACKAGES_REPO :=https://mirror.ghproxy.com/https://github.com/Kazu-Kusa/built-packages.git
#PACKAGES_REPO :=https://github.com/Kazu-Kusa/built-packages.git
REPO_NAME :=built-packages
.PHONY: all set_apt_mirror update_apt upgrade_apt setup_environment install_python set_py_mirror \
		setup_pdm check_modules install_wiringpi config_hardware clean install_sysbench install_kazu \
 		overclock bench install_utils help install_git install_python311

all:  install_utils check_modules set_py_mirror setup_pdm \
	  install_wiringpi config_hardware install_kazu_using_built_packages overclock enable_32bit
# 检查并追加字符串到文件的函数
define check-and-append-string
	if grep -q $(2) $(1); then \
		echo "String '$(2)' already exists in the file '$(1)', do nothing."; \
	else \
		sudo sh -c 'echo "$(2)" >> $(1)'; \
		echo "String '$(2)' appended to the file '$(1)."; \
	fi
endef

set_apt_mirror:
	@echo "Setting apt mirror..."
	sudo sh -c "echo 'deb $(MIRROR_TUNA)/raspbian/raspbian/ bullseye main non-free contrib rpi' > $(APT_FILE_PATH)"
	sudo sh -c "echo 'deb-src $(MIRROR_TUNA)/raspbian/raspbian/ bullseye main non-free contrib rpi' >> $(APT_FILE_PATH)"
	sudo sh -c "echo 'deb $(MIRROR_TUNA)/raspberrypi/ bullseye main'>$(APT_FILE_PATH0)"

update_apt:set_apt_mirror
	sudo apt update

upgrade_apt:update_apt
	sudo apt upgrade -y

setup_environment:
	@echo "Setting up environment..."
	mkdir -p $(TEMP_DIR)
	sudo chmod 777 $(TEMP_DIR)
	sudo apt install -y  gcc cmake

install_python311: setup_environment
	@echo "install python3.11.0 from built binary"
	cd $(TEMP_DIR) &&\
  	if [ -d "$(REPO_NAME)" ]; then \
  		echo "repo is already cloned, skip"; \
  	else \
  		git clone $(PACKAGES_REPO); \
  	fi &&\
  	if [ -d "Python-3.11.0" ]; then \
      		echo "Already unpacked"; \
	else \
		cat $(REPO_NAME)/*gz* | tar -xvzf - ; \
	fi &&\
	cd Python-3.11.0 &&\
	sudo make install

install_python: setup_environment
	@echo "Checking for Python $(PYTHON_VERSION) installation..."
	if ! python3 --version 2>&1 | grep -qF $(PYTHON_VERSION); then \
		echo "Python $(PYTHON_VERSION) not found, installing dependencies..."; \
  		echo "removing clean_deprecated_python3";\
  		sudo apt -y remove python3; \
		sudo apt install -y build-essential libffi-dev libssl-dev openssl; \
		cd $(TEMP_DIR); \
		if [ ! -f "$(TAR_FILE)" ]; then \
			echo "Tarball not found, downloading Python-$(PYTHON_VERSION).tar.xz..."; \
			wget $(PYTHON_DOWNLOAD_URL); \
		else \
			echo "Tarball Python-$(PYTHON_VERSION).tar.xz already downloaded."; \
		fi && \
		tar -xf $(TAR_FILE) && \
		cd Python-$(PYTHON_VERSION) && \
		./configure --enable-optimizations --enable-shared && \
		make -j4 && \
		sudo make install; \
	else \
		echo "Python $(PYTHON_VERSION) is already installed."; \
	fi
set_py_mirror:install_python
	@echo "Setting Python mirror..."

	pip$(SIMPLIFIED_PY_VERSION) config set global.index-url $(PYPI_INDEX) && \
	pip$(SIMPLIFIED_PY_VERSION) install --upgrade pip
setup_pdm: set_py_mirror
	@echo "Setting up pdm..."
	pip$(SIMPLIFIED_PY_VERSION) install pdm --verbose
	pdm config pypi.url $(PYPI_INDEX)

check_modules: install_python
	@echo "Checking Python modules..."
	@[ -z "$(python$(SIMPLIFIED_PY_VERSION) -c 'import ssl' 2>&1)" ] || (echo "ssl module installed." && exit 0) || (echo "ssl module not found." && make install_python)
	@[ -z "$(python$(SIMPLIFIED_PY_VERSION) -c 'import ctypes' 2>&1)" ] || (echo "ctypes module installed." && exit 0) || (echo "ctypes module not found." && make install_python)

install_wiringpi:
	@command -v gpio || (echo "Installing WiringPi..." && \
	cd $(TEMP_DIR) && \
	rm -f wiringpi-latest.deb && \
	wget https://project-downloads.drogon.net/wiringpi-latest.deb && \
	sudo dpkg -i wiringpi-latest.deb)

config_hardware: install_wiringpi
	@echo "Configuring hardware..."
	sudo raspi-config nonint do_fan 0 18 60
	sudo raspi-config nonint do_i2c 0
	sudo raspi-config nonint do_spi 0
	sudo raspi-config nonint do_rgpio 0
	sudo apt-get install -y libtinfo-dev raspberrypi-kernel-headers libpigpiod-if2-1 pigpiod
	@if ! systemctl is-enabled pigpiod >/dev/null 2>&1; then \
		sudo systemctl enable pigpiod && sudo pigpiod && echo "pigpiod enabled on startup"; \
	else \
		echo "pigpiod already enabled on startup"; \
	fi

clean:
	@echo "Cleaning up..."
	rm -rf $(TEMP_DIR)




install_kazu_using_built_packages: install_utils setup_pdm
	@echo "Checking for existing kazu directory..."
	cd && \
	if [ -d "kazu" ]; then \
		echo "Directory 'kazu' already exists. Skipping clone step."; \
	else \
		echo "Cloning kazu..."; \
		git clone $(KAZU_REPO); \
	fi 	&& \
	cd kazu && \
	pdm add  $(CV_URL) $(NP_URL) && \
	pdm install -v && \
	pdm build && \
	pip$(SIMPLIFIED_PY_VERSION) install dist/*whl

install_kazu: install_utils setup_pdm
	@echo "Checking for existing kazu directory..."
	cd && \
	if [ -d "kazu" ]; then \
		echo "Directory 'kazu' already exists. Skipping clone step."; \
	else \
		echo "Cloning kazu..."; \
		git clone $(KAZU_REPO); \
	fi 	&& \
	cd kazu && \
	git stash && \
	pdm install -v && \
	pdm build && \
	pip$(SIMPLIFIED_PY_VERSION) install dist/*whl



overclock:
	$(call check-and-append-string,$(CONFIG_FILE),$(ARM_FREQ))
	$(call check-and-append-string,$(CONFIG_FILE),$(OVER_VOLTAGE))
	$(call check-and-append-string,$(CONFIG_FILE),$(CORE_FREQ))
	$(call check-and-append-string,$(CONFIG_FILE),"avoid_warnings=1")
	@echo "注意：如果超频设置更改后必须要重启后才会生效！"

enable_32bit:
	$(call check-and-append-string,$(CONFIG_FILE),$(ARM_64BIT))
	@echo "注意：如果切换为32bit运行模式后必须要重启后才会生效！若要执行install_kazu这是必须要完成的！"

bench:install_utils
	sysbench cpu --cpu-max-prime=10000 --threads=4 run

	echo "Usually, the Event per Second  is around 460~560"


install_utils: upgrade_apt
	# 检查并安装htop
	if ! command -v htop &> /dev/null; then \
		echo "Installing htop..."; \
		sudo apt install -y htop; \
	else \
		echo "htop is already installed."; \
	fi

	# 检查并安装git
	if ! command -v git &> /dev/null; then \
		echo "Installing git..."; \
		sudo apt install -y git; \
	else \
		echo "git is already installed."; \
	fi

	# 检查并安装fish shell
	if ! command -v fish &> /dev/null; then \
		echo "Installing fish..."; \
		sudo apt install -y fish; \
	else \
		echo "fish is already installed."; \
	fi

	# 检查并安装vim
	if ! command -v vim &> /dev/null; then \
		echo "Installing vim..."; \
		sudo apt install -y vim; \
	else \
		echo "vim is already installed."; \
	fi

	# 检查并安装sysbench
	if ! command -v sysbench &> /dev/null; then \
		echo "Installing sysbench..."; \
		sudo apt install -y sysbench; \
	else \
		echo "sysbench is already installed."; \
	fi
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
	@echo "overclock: overclock settings $(ARM_FREQ)| $(OVER_VOLTAGE)| $(CORE_FREQ)"
	@echo "enable_32bit: change the system kernel to 32-bits, which is required to install kazu"
	@echo "install_python311: install python3.11.0 from built binary, it only works on bullseye"
	@echo "install_kazu: install kazu from the git repo"
	@echo "install_kazu_using_built_packages: install kazu from the git repo and use pre-built packages"