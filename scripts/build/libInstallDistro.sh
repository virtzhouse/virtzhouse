#! /bin/bash

installDistro() {
    [[ $# -ne 2 ]] && { echo "${FUNCNAME[0]} expects 2 arguments" ; exit 1; }
    local target="$1"
    local distro="$2"

    case "$distro" in
        kali)
            installKali "$target"
            ;;
        arch)
            installArch "$target"
            ;;
        manjaro)
            installManjaro "$target"
            ;;
    esac
}

installKali() {
    [[ $# -ne 1 ]] && { echo "${FUNCNAME[0]} expects 1 argument" ; exit 1; }
    local target="$1"
    arch-chroot "$target" /bin/bash <<'EOF'
# basic config
bootctl install --path=/boot --no-variables
echo "timeout 1" >> /boot/loader/loader.conf
echo "default kali-*" >> /boot/loader/loader.conf
KVER=$(basename /boot/vmlinuz-*)
KVER=${KVER#vmlinuz-}
kernel-install -v add "$KVER" "/boot/vmlinuz-$KVER"

# apt
sed -i 's|http://|https://|g' /etc/apt/sources.list
apt update
apt full-upgrade -y
apt autoremove -y
apt clean

# services
systemctl enable auditd
systemctl enable NetworkManager
systemctl enable systemd-binfmt

# uid 0
chsh -s /usr/bin/zsh
passwd -d root

# uid 1000
useradd -m -G wheel,video,audio,storage,power -s /usr/bin/zsh user
passwd -d user

EOF
}

installArch() {
    [[ $# -ne 1 ]] && { echo "${FUNCNAME[0]} expects 1 argument" ; exit 1; }
    local target="$1"
    arch-chroot "$target" /bin/bash <<'EOF'
# basic config
bootctl install --path=/boot --no-variables
mkdir -p /boot/EFI/BOOT
mkdir -p /boot/loader/entries

cat <<'EOT' > /boot/loader/loader.conf
timeout 0
editor no
console-mode keep
random-seed-mode off
default arch.conf
EOT

cat <<'EOT' > /boot/loader/entries/arch.conf
title   Arch ARM
linux   /Image
initrd  /initramfs-linux.img
options root=/dev/vda2 rw
EOT

cat <<'EOT' > /boot/startup.nsh
Image root=/dev/vda2 rw initrd=\initramfs-linux.img
EOT

# services
systemctl enable auditd
systemctl enable NetworkManager
systemctl enable systemd-binfmt

# pacman
pacman-key --init
pacman-key --populate archlinux archlinuxarm
pacman -Syu --noconfirm --disable-sandbox

# uid 0
chsh -s /usr/bin/zsh
passwd -d root

# uid 1000
useradd -m -G wheel,video,audio,storage,power -s /usr/bin/zsh user
passwd -d user

EOF
}

installManjaro() {
    [[ $# -ne 1 ]] && { echo "${FUNCNAME[0]} expects 1 argument" ; exit 1; }
    local target="$1"
    arch-chroot "$target" /bin/bash <<'EOF'
# basic config
bootctl install --path=/boot --no-variables
mkdir -p /boot/EFI/BOOT
mkdir -p /boot/loader/entries

cat <<'EOT' > /boot/loader/loader.conf
timeout 0
editor no
console-mode keep
random-seed-mode off
default manjaro.conf
EOT

cat <<'EOT' > /boot/loader/entries/manjaro.conf
title   Manjaro ARM
linux   /Image
initrd  /initramfs-linux.img
options root=/dev/vda2 rw
EOT

cat <<'EOT' > /boot/startup.nsh
Image root=/dev/vda2 rw initrd=\initramfs-linux.img
EOT

# services
systemctl enable auditd
systemctl enable NetworkManager
systemctl enable systemd-binfmt

# pacman
pacman-key --init
pacman-key --populate archlinux archlinuxarm manjaro manjaro-arm
pacman-mirrors --fasttrack 15 -aP https
pacman -Syu --noconfirm --disable-sandbox

# uid 0
chsh -s /usr/bin/zsh
passwd -d root

# uid 1000
useradd -m -G wheel,video,audio,storage,power -s /usr/bin/zsh user
passwd -d user

EOF
}

# cat <<'EOT' > /etc/systemd/network/20-ethernet.network
# [Match]
# Name=en*
# Name=eth*
# [Network]
# DHCP=yes
# EOT
#
# ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
