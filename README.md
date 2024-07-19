# setupi
> Auto config the dev env of the pi
---

> **Note**:
> 
> This Makefile were written and tested in env as below
> 
> - Hardware: Raspberry Pi 4B 
> - Operating System: Raspberry Pi OS (Legacy)  Lite ,32-bit
> - Kernel Version: 6.1
> - Debian Version: 11(bullseye)


## Install

Download the script to anywhere you want

1. **Use `curl`**
```bash
curl -O https://raw.githubusercontent.com/Kazu-Kusa/setupi/main/Makefile
```

2. **Use `wget`**
```bash
wget https://raw.githubusercontent.com/Kazu-Kusa/setupi/main/Makefile
```

3. **use `git`**
   
```bash
git clone https://github.com/Kazu-Kusa/setupi.git
```
   get to the cloned repo, and you should find the `Makefile` in `setupi`
```bash
cd setupi
ls
```



## Targets Overview

### all
- **Description**: Default target that triggers the entire setup process or serves as an entry point.

### setup_environment
- **Purpose**: Prepares the environment necessary for installing the project requirements. This might include setting environment variables and creating directories.

### install_python (Python Version: $(PYTHON_VERSION))
- **Function**: Installs the specified version of the Python interpreter, ensuring compatibility with your project's dependencies.

### check_modules
- **Action**: Verifies the correct functioning of required Python modules. Ensures all dependencies are correctly installed and operational.

### install_wiringpi
- **Objective**: Installs WiringPi, a crucial library for GPIO control, enabling features like fan control in your project.

### config_hardware
- **Details**: Configures the hardware settings to optimize system performance and compatibility with your project's needs. This includes activating interfaces like I2C, SPI, and setting appropriate GPIO configurations.

### clean
- **Task**: Removes temporary files and cleans up the workspace, keeping it organized and efficient.

### install_sysbench
- **Explanation**: Installs Sysbench, a popular tool for system performance benchmarking, useful for stress testing and evaluating system capabilities.

### install_fish
- **Purpose**: Installs Fish, a friendly interactive shell that enhances the command-line experience with advanced features and syntax highlighting.

### clone_kazu
- **Action**: Clones the "kazu" repository from GitHub. Presumably, this repository contains source code or additional tools relevant to your project.

### bench
- **Function**: Executes benchmark tests using Sysbench, providing insights into system performance under various loads.

### install_utils
- **Objective**: Installs utility tools and libraries that are not covered by other targets, enhancing the development and runtime environment.

### overclock
- **Details**: Implements overclocking settings to potentially boost system performance. This should be done cautiously to avoid stability issues.

## Usage

To execute a specific target, open a terminal in your project directory and run `make <target_name>`. For example, to set up the Python environment, you would type `make install_python`.

Please ensure you have appropriate permissions (possibly requiring `sudo` for some operations) and review each step for compatibility with your system configuration before proceeding.

To make it simple, you can execute `make all` to trigger the entire setup proces:
```shell

make all
```

You can get help with `help` target:
```shell
make help
```