#!/usr/bin/env bash
# linux shell script
#################################################
# Please do not make any changes to this file,  #
# change the variables in webui-user.sh instead #
#################################################


# If run from macOS, load defaults from webui-macos-env.sh
# 如果从macOS运行，则从webui-macOS-env.sh加载默认值
if [[ "$OSTYPE" == "darwin"* ]]
then
    # 如果 webui-macos-env.sh 为常规文件
    if [[ -f webui-macos-env.sh ]]
    then
        # Including ./webui-macos-env.sh script file and execute it
        # 包含 ./webui-macos-env.sh 脚本文件并执行
        source ./webui-macos-env.sh
    fi
fi

# Read variables from webui-user.sh
# 从webui-user.sh读取变量
# shellcheck source=/dev/null
if [[ -f webui-user.sh ]]
then
    # Including ./webui-user.sh script file and execute it
    # 包含 ./webui-user.sh 脚本文件并执行
    source ./webui-user.sh
fi

# Set defaults
# Install directory without trailing slash
# 如果 install_dir 变量为空
if [[ -z "${install_dir}" ]]
then
    install_dir="/home/$(whoami)"
fi

# Name of the subdirectory (defaults to stable-diffusion-webui)
# 如果 clone_dir 变量为空
if [[ -z "${clone_dir}" ]]
then
    clone_dir="stable-diffusion-webui"
fi

# python3 executable
# 如果 python_cmd 变量为空
if [[ -z "${python_cmd}" ]]
then
    python_cmd="python3"
fi

# git executable
# 如果 GIT 变量为空
if [[ -z "${GIT}" ]]
then
    export GIT="git"
fi

# python3 venv without trailing slash (defaults to ${install_dir}/${clone_dir}/venv)
# python3 venv，不带尾部斜杠（默认为${install_dir}/${clone_dir}/venu）
# 如果 venv_dir 变量为空
if [[ -z "${venv_dir}" ]]
then
    venv_dir="venv"
fi

# 如果 LAUNCH_SCRIPT 变量为空
if [[ -z "${LAUNCH_SCRIPT}" ]]
then
    LAUNCH_SCRIPT="launch.py"
fi

# this script cannot be run as root by default
can_run_as_root=0

# read any command line flags to the webui.sh script
while getopts "f" flag > /dev/null 2>&1
do
    case ${flag} in
        f) can_run_as_root=1;;
        *) break;;
    esac
done

# Disable sentry logging
export ERROR_REPORTING=FALSE

# Do not reinstall existing pip packages on Debian/Ubuntu
export PIP_IGNORE_INSTALLED=0

# Pretty print
delimiter="################################################################"

# printf:shell 输出命令
printf "\n%s\n" "${delimiter}"
printf "\e[1m\e[32mInstall script for stable-diffusion + Web UI\n"
printf "\e[1m\e[34mTested on Debian 11 (Bullseye)\e[0m"
printf "\n%s\n" "${delimiter}"

# Do not run as root
# 不以root身份运行
if [[ $(id -u) -eq 0 && can_run_as_root -eq 0 ]]
then
    printf "\n%s\n" "${delimiter}"
    printf "\e[1m\e[31mERROR: This script must not be launched as root, aborting...\e[0m"
    printf "\n%s\n" "${delimiter}"
    exit 1
else
    printf "\n%s\n" "${delimiter}"
    printf "Running on \e[1m\e[32m%s\e[0m user" "$(whoami)"
    printf "\n%s\n" "${delimiter}"
fi

# 如果.git 为目录
if [[ -d .git ]]
then
    printf "\n%s\n" "${delimiter}"
    printf "Repo already cloned, using it as install directory"
    printf "\n%s\n" "${delimiter}"
    install_dir="${PWD}/../"
    clone_dir="${PWD##*/}"
fi

# Check prerequisites
# 检查先决条件
# 此处|作为管道，将第一个命令的执行结果作为第二个命令的参数
# grep:查找文件里符合条件的字符串或正则表达式
# 查看显卡的详细信息
gpu_info=$(lspci 2>/dev/null | grep VGA)
# gpu_info输出示例：03:00.0 VGA compatible controller: Advanced Micro Devices, Inc. [AMD/ATI] Navi 23 [Radeon RX 6600/6600 XT/6600M] (rev c1)
# shell case 语句，$gpu_info执行后得到的字符串 为值
case "$gpu_info" in
    *"Navi 1"*|*"Navi 2"*) 
    # 将AMD Navi 10系和20系显卡仿冒成GFX1030，可以在ROCm中正常工作
    export HSA_OVERRIDE_GFX_VERSION=10.3.0
    ;;
    # AMD Renoir 核心核心显卡
    *"Renoir"*) 
    export HSA_OVERRIDE_GFX_VERSION=9.0.0
        printf "\n%s\n" "${delimiter}"
        printf "Experimental support for Renoir: make sure to have at least 4GB of VRAM and 10GB of RAM or enable cpu mode: --use-cpu all --no-half"
        printf "\n%s\n" "${delimiter}"
    ;;
    *) 
    ;;
esac

# grep -q:
# $gpu_info输出是否包含 AMD 并且 TORCH_COMMAND变量为空
if echo "$gpu_info" | grep -q "AMD" && [[ -z "${TORCH_COMMAND}" ]]
then
    # pytorch 1.13.1 for linux pip python ROCm 5.2 强制安装
    # export TORCH_COMMAND="pip install torch==1.13.1+rocm5.2 torchvision==0.14.1+rocm5.2 --extra-index-url https://download.pytorch.org/whl/rocm5.2 --upgrade --force-reinstall"
    
    # pytorch 1.13.1 for linux pip3 python ROCm 5.2
    # export TORCH_COMMAND="pip3 install torch torchvision torchaudio --extra-index-url"

    # pytorch 2.0.0 for linux pip3 python ROCm 5.4.2
    export TORCH_COMMAND="pip install torch --index-url https://download.pytorch.org/whl/rocm5.4.2"

     # pytorch 2.0.0 for linux pip python ROCm 5.4.2
    # export TORCH_COMMAND="pip install torch torchvision --extra-index-url https://download.pytorch.org/whl/rocm5.2"

fi  

for preq in "${GIT}" "${python_cmd}"
do
    if ! hash "${preq}" &>/dev/null
    then
        printf "\n%s\n" "${delimiter}"
        printf "\e[1m\e[31mERROR: %s is not installed, aborting...\e[0m" "${preq}"
        printf "\n%s\n" "${delimiter}"
        exit 1
    fi
done

if ! "${python_cmd}" -c "import venv" &>/dev/null
then
    printf "\n%s\n" "${delimiter}"
    printf "\e[1m\e[31mERROR: python3-venv is not installed, aborting...\e[0m"
    printf "\n%s\n" "${delimiter}"
    exit 1
fi

cd "${install_dir}"/ || { printf "\e[1m\e[31mERROR: Can't cd to %s/, aborting...\e[0m" "${install_dir}"; exit 1; }
if [[ -d "${clone_dir}" ]]
then
    cd "${clone_dir}"/ || { printf "\e[1m\e[31mERROR: Can't cd to %s/%s/, aborting...\e[0m" "${install_dir}" "${clone_dir}"; exit 1; }
else
    printf "\n%s\n" "${delimiter}"
    printf "Clone stable-diffusion-webui"
    printf "\n%s\n" "${delimiter}"
    "${GIT}" clone https://github.com/AUTOMATIC1111/stable-diffusion-webui.git "${clone_dir}"
    cd "${clone_dir}"/ || { printf "\e[1m\e[31mERROR: Can't cd to %s/%s/, aborting...\e[0m" "${install_dir}" "${clone_dir}"; exit 1; }
fi

printf "\n%s\n" "${delimiter}"
printf "Create and activate python venv"
printf "\n%s\n" "${delimiter}"
cd "${install_dir}"/"${clone_dir}"/ || { printf "\e[1m\e[31mERROR: Can't cd to %s/%s/, aborting...\e[0m" "${install_dir}" "${clone_dir}"; exit 1; }
if [[ ! -d "${venv_dir}" ]]
then
    "${python_cmd}" -m venv "${venv_dir}"
    first_launch=1
fi
# shellcheck source=/dev/null
if [[ -f "${venv_dir}"/bin/activate ]]
then
    source "${venv_dir}"/bin/activate
else
    printf "\n%s\n" "${delimiter}"
    printf "\e[1m\e[31mERROR: Cannot activate python venv, aborting...\e[0m"
    printf "\n%s\n" "${delimiter}"
    exit 1
fi

if [[ ! -z "${ACCELERATE}" ]] && [ ${ACCELERATE}="True" ] && [ -x "$(command -v accelerate)" ]
then
    printf "\n%s\n" "${delimiter}"
    printf "Accelerating launch.py..."
    printf "\n%s\n" "${delimiter}"
    exec accelerate launch --num_cpu_threads_per_process=6 "${LAUNCH_SCRIPT}" "$@"
else
    printf "\n%s\n" "${delimiter}"
    printf "Launching launch.py..."
    printf "\n%s\n" "${delimiter}"      
    exec "${python_cmd}" "${LAUNCH_SCRIPT}" "$@"
fi
