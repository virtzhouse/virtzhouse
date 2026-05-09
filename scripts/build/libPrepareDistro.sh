#! /bin/bash

prepareDistro() {
    [[ $# -ne 3 ]] && { echo "${FUNCNAME[0]} expects 3 arguments" ; exit 1; }
    local target="$1"
    local distro="$2"
    local extras="$3"

    case "$distro" in
        kali)
            prepareKali "$target" "$extras"
            ;;
        arch)
            prepareArch "$target" "$extras"
            ;;
        manjaro)
            prepareManjaro "$target" "$extras"
            ;;
    esac
}

prepareKali() {
    [[ $# -ne 2 ]] && { echo "${FUNCNAME[0]} expects 2 arguments" ; exit 1; }
    local target="$1"
    local extras="$2"
    local packages="kali-archive-keyring,kali-linux-core,kali-defaults,ca-certificates,linux-image-arm64,systemd,systemd-boot,base-files,network-manager,iproute2,netbase,openssh-server,e2fsprogs,dosfstools,spice-vdagent,dialog,zsh,zsh-autosuggestions,zsh-syntax-highlighting,vim,nano,less,ripgrep,tree,debianutils,util-linux,auditd,locales,kbd,keyboard-configuration,console-data,console-setup,libnss-myhostname"
    
    if [[ -n "$extras" ]]; then
        packages="$packages,$extras"
    fi
    
    mmdebstrap \
        --skip=check/empty \
        --keyring=./kali/kali-archive-keyring.gpg \
        --include=$packages \
        kali-rolling \
        "$target" \
        "deb https://http.kali.org kali-rolling main contrib non-free"
    
    echo 'kali' > "$target/etc/hostname"
    echo 'kali' > "$target/etc/kernel/entry-token"
    echo 'root=/dev/vda2 rw' > "$target/etc/kernel/cmdline"
}

prepareArch() {
    [[ $# -ne 2 ]] && { echo "${FUNCNAME[0]} expects 2 arguments" ; exit 1; }
    local target="$1"
    local extras="$2"
    local packages="archlinux-keyring archlinuxarm-keyring base linux openssh networkmanager e2fsprogs dosfstools spice-vdagent dialog zsh grml-zsh-config nano less ripgrep which"
    
    if [[ -n "$extras" ]]; then
        packages="$packages $extras"
    fi
    
    pacstrap -C ./arch/archlinux.conf "$target" $packages
    
    echo 'arch' > "$target/etc/hostname"
    sed -i 's/^#IgnorePkg =/IgnorePkg = linux-firmware/' "$target/etc/pacman.conf"
    echo 'Server = https://de3.mirror.archlinuxarm.org/$arch/$repo' > "$target/etc/pacman.d/mirrorlist"
}

prepareManjaro() {
    [[ $# -ne 2 ]] && { echo "${FUNCNAME[0]} expects 2 arguments" ; exit 1; }
    local target="$1"
    local extras="$2"
    local packages="archlinux-keyring archlinuxarm-keyring manjaro-keyring manjaro-arm-keyring base linux openssh networkmanager e2fsprogs dosfstools spice-vdagent dialog zsh grml-zsh-config nano less ripgrep which"
    
    if [[ -n "$extras" ]]; then
        packages="$packages $extras"
    fi
    
    pacstrap -C ./manjaro/manjaro.conf "$target" $packages

    echo 'manjaro' > "$target/etc/hostname"
    sed -i 's/^#IgnorePkg =/IgnorePkg = linux-firmware/' "$target/etc/pacman.conf"
}
