confirm() {
    # call with a prompt string or use a default
    read -r -p "${1:-Is everything okay? [y/N]} " response
    case "$response" in
        [yY][eE][sS]|[yY]) 
            return 0
            ;;
        *)
            rm -r ~/linux-5.14.9
            exit 1
            ;;
    esac
}

# pre-setup
dir=$(pwd)
echo 'Current dir: ' $dir
sudo apt update && sudo apt upgrade -y
sudo apt install build-essential libncurses-dev libssl-dev libelf-dev bison flex vim ccache -y

# download kernel
cd ~
wget https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-5.14.9.tar.xz
tar Jxvf linux-5.14.9.tar.xz
echo 'Kernel file should have been downloaded and extracted successfully.'
confirm
rm linux-5.14.9.tar.xz

# write source code for new syscall
cd ~/linux-5.14.9
mkdir get_code_segment
cd get_code_segment
cp $dir/get_code_segment.c ./get_code_segment.c
echo 'obj-y := get_code_segment.o' >> Makefile
echo 'Source code for new syscall should have been created successfully.'
confirm

# edit config
cd ~/linux-5.14.9
## add get_code_segment/ to core-y
vim Makefile
echo 'Directory of source code for new syscall should have been added.'
confirm
## add  448 common  get_code_segment    sys_get_code_segment
vim ~/linux-5.14.9/arch/x86/entry/syscalls/syscall_64.tbl
echo 'Info of new syscall should have been added.'
confirm
## append asmlinkage long sys_get_code_segment(pid_t current_pid, void *__user user_code_segment);
vim ~/linux-5.14.9/include/linux/syscalls.h
echo 'Header of new syscall should have been appended.'
confirm

# compile
make clean
make menuconfig
echo 'Config should have been made successfully.'
confirm
## clear content in CONFIG_SYSTEM_TRUSTED_KEYS and SYSTEM_REVOCATION_KEYS
vim ~/linux-5.14.9/.config
echo 'Content in CONFIG_SYSTEM_TRUSTED_KEYS and SYSTEM_REVOCATION_KEYS should have been cleared.'
confirm
make -j$(nproc) CC='ccache gcc'
echo 'Kernel should have been made successfully.'
confirm
make modules -j$(nproc) CC='ccache gcc'
echo 'Kernel modules should have been made successfully.'
confirm

# install
sudo make modules_install
echo 'Kernel modules should have been made successfully.'
confirm
sudo make install
echo 'Kernel should have been installed successfully.'
confirm

# modify grub settings and restart
## comment out these two:
## GRUB_TIMEOUT_STYLE=hidden
## GRUB_TIMEOUT=0
sudo vim /etc/default/grub
echo 'GRUB settings should have been modified.'
confirm
sudo update-grub
reboot