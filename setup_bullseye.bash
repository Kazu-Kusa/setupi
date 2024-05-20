#!/bin/sh

# apt source

APT_FILE_PATH="/etc/apt/sources.list"



sudo sh -c "echo 'deb https://mirrors.tuna.tsinghua.edu.cn/raspbian/raspbian/ bullseye main non-free contrib rpi' > $APT_FILE_PATH"
sudo sh -c "echo 'deb-src https://mirrors.tuna.tsinghua.edu.cn/raspbian/raspbian/ bullseye main non-free contrib rpi' >> $APT_FILE_PATH"
#sudo sh -c "echo 'deb https://mirrors.tuna.tsinghua.edu.cn/debian bookworm-updates main contrib non-free-firmware' >> $APT_FILE_PATH"



sudo apt update
sudo apt upgrade -y

WORK_ROOT=$(pwd)
echo $WORK_ROOT

PYTHON_VERSION="3.11.0"  # 要判断的Python版本

# 初始化临时目录，并设定任何人可读写
TEMP_DIR_PATH="$WORK_ROOT/temp"
mkdir $TEMP_DIR_PATH || True
sudo chmod 777 $TEMP_DIR_PATH



sudo apt install -y -q git gcc cmake

function installPython() {
    # install python compile dep
    sudo apt install -y build-essential libffi-dev libssl-dev openssl
    # install python
    cd $TEMP_DIR_PATH || exit
    echo "下载Python-$PYTHON_VERSION, at https://mirrors.huaweicloud.com/python/$PYTHON_VERSION/Python-$PYTHON_VERSION.tar.xz"
    wget https://mirrors.huaweicloud.com/python/$PYTHON_VERSION/Python-$PYTHON_VERSION.tar.xz
    tar -xf Python-$PYTHON_VERSION.tar.xz
    cd Python-$PYTHON_VERSION || exit
    ./configure --enable-optimizations
    make -j4
    sudo make install
    # update pip
    pip3 config set global.index-url https://pypi.mirrors.ustc.edu.cn/simple
    pip3 install --upgrade pip setuptools wheel pdm
    pdm config pypi.url https://pypi.tuna.tsinghua.edu.cn/simple
}

# 函数：检查模块是否存在
# 参数：模块名
# 返回值：0表示模块已安装，1表示模块未安装
check_module() {
    python3 -c "import $1" 2>/dev/null
    return $?
}

function check_python_modules() {
    if python3 --version 2>&1 | grep -qF "$PYTHON_VERSION"; then
        echo "Python $PYTHON_VERSION 已安装."
        # 调用示例
        if check_module "ssl"; then
            echo "ssl模块已安装"
        else
            echo "ssl模块未安装"
            installPython
        fi

        if check_module "ctypes"; then
            echo "ctypes模块已安装"
        else
            echo "ctypes模块未安装"
            installPython
        fi

    else
        echo "Python $PYTHON_VERSION 未安装."
        installPython
    fi
}




function install_wiringpi() {
    if command -v gpio; then
        echo "wiringpi 已经安装"
    else
        echo "下载并安装wiringpi中"
        cd $TEMP_DIR_PATH || exit
        rm wiringpi-latest.deb
        wget https://project-downloads.drogon.net/wiringpi-latest.deb
        sudo dpkg -i wiringpi-latest.deb
    fi
}





function check_and_append_string() {
    file_path="$1"
    string_to_append="$2"

    if grep -q "$string_to_append" "$file_path"; then
        echo "String '$2' already exists in the file '$1',do nothing."
    else
        echo "$string_to_append" >> "$file_path"
        echo "String '$2' appended to the file '$1'."
    fi
}

function config_hardware() {

    config_file="/boot/config.txt"
    # raspi-config
    sudo raspi-config nonint do_i2c 0  # 激活I2C
    sudo raspi-config nonint do_fan 0  # 激活风扇
    sudo sed -i 's/gpiopin=14/gpiopin=18/' $config_file
    sudo sed -i 's/temp=80000/temp=60000/' $config_file  # 设置风扇GPIO和激活温度为60℃
    # open SPI
    sudo raspi-config nonint do_spi 0
    # -------------------------------
    # 超频配置
    # -------------------------------
    arm_freq="arm_freq=2000"#CPU频率，默认1800Mhz，可用范围<=2147Mhz（当然，越高越不稳定）
    over_voltage="over_voltage=10"#电压偏移，默认0，可用范围<=10*10^-2V
    core_freq="core_freq=750"#核心频率，默认500Mhz，可用范围<=750Mhz
    arm_64bit="arm_64bit=0" #32bit还是64bit，必须是32bit，不然没法使用博创的32位的so库

    echo "-超频配置参数-"
    echo "ARM主频设置为'$arm_freq'Mhz，默认1500Mhz，推荐范围<=2147Mhz"
    check_and_append_string "$config_file" "$arm_freq"
    echo "核心电压偏移设置为'$over_voltage'*10^-2V，默认0，推荐范围<=10*10^-2V"
    check_and_append_string "$config_file" "$over_voltage"
    echo "核心频率设置为'$core_freq'Mhz，默认500Mhz，推荐范围<=750Mhz"
    check_and_append_string "$config_file" "$core_freq"
    echo "确认系统为32bit"
    check_and_append_string "$config_file" "$arm_64bit"

    check_and_append_string "$config_file" "avoid_warnings=1"
    echo "注意如果超频设置更改后必须要重启后才会生效"

    sudo apt-get install -y -q libtinfo-dev raspberrypi-kernel-headers libpigpiod-if2-1 pigpiod

    if ! systemctl is-enabled pigpiod >/dev/null 2>&1; then
      # 设置pigpiod开机自启
      sudo systemctl enable pigpiod
      sudo pigpiod
      echo "已设置pigpiod开机自启"
    else
      echo "pigpiod已设置开机自启"
    fi
}



# 调用函数
check_python_modules
install_wiringpi
config_hardware



sudo chmod -R 777 $TEMP_DIR_PATH
OPENCV_LIB="export LD_PRELOAD=/usr/lib/arm-linux-gnueabihf/libatomic.so.1"
sh -c "echo $OPENCV_LIB >> /etc/profile"


