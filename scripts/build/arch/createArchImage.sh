#! /bin/bash

set -Eo pipefail

if [ "$(id -u)" -ne 0 ]; then
  if command -v sudo >/dev/null 2>&1; then
    exec sudo -E -- "${BASH_SOURCE[0]}" "$@"
  else
    printf 'Error: This script must be run as root and sudo is not available.\n' >&2
    exit 1
  fi
fi

onerr() {
  local rc=${?}
  local lineno=${BASH_LINENO[0]:-?}
  local cmd=${BASH_COMMAND:-'unknown'}
  umount -R /mnt
  losetup -D
  printf 'Error: %s\nLine: %s\nExit code: %s\n' "$cmd" "$lineno" "$rc" >&2
  exit "$rc"
}

trap 'onerr' ERR

# get accurate system time
date_header=$(/usr/bin/curl -sI https://www.google.com | /usr/bin/grep '^date:' | cut -d' ' -f2-)
if [ -z "$date_header" ]; then
  echo "couldn't retrieve time and date"
  exit 1
fi
/usr/bin/date -s "$date_header"

# create image and partitions
touch arch-minimal.img
truncate -s 4G arch-minimal.img

losetup -D
losetup -fP --show arch-minimal.img
parted /dev/loop0 mklabel gpt
parted /dev/loop0 mkpart primary fat32 1MiB 512MiB
parted /dev/loop0 mkpart primary ext4 512MiB 100%
parted /dev/loop0 set 1 boot on
parted /dev/loop0 set 1 esp on
mkfs.vfat -F32 /dev/loop0p1
mkfs.ext4 /dev/loop0p2
mount /dev/loop0p2 /mnt
mkdir /mnt/boot
mount /dev/loop0p1 /mnt/boot

pacstrap -C ./archlinux.conf -K /mnt \
                base archlinux-keyring archlinuxarm-keyring \
                linux dhcpcd openssh e2fsprogs dosfstools spice-vdagent \
                dialog zsh grml-zsh-config nano less ripgrep which

cp ./oeminstall /mnt/root/oeminstall
cp ./dialogrc /mnt/root/dialogrc
echo 'cd /root && ./oeminstall' > /mnt/root/.zprofile
chmod +x /mnt/root/oeminstall

#
# enter chroot
#
arch-chroot /mnt /bin/bash <<'EOF'
# pacman + https mirror
pacman-key --init
pacman-key --populate archlinux archlinuxarm
echo 'Server = https://de3.mirror.archlinuxarm.org/$arch/$repo' > /etc/pacman.d/mirrorlist
pacman -Syu

# boot loader
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

# network
systemctl enable systemd-networkd
systemctl enable systemd-resolved
systemctl enable dhcpcd

# fstab
cat <<'EOT' > /etc/fstab

# <file system> <dir> <type> <options> <dump> <pass>
                                                                     
/dev/disk/by-id/virtio-root-part1           /boot       vfat defaults 0 2
/dev/disk/by-id/virtio-root-part2           /           ext4 defaults 0 1

/dev/disk/by-id/virtio-home-part1           /rw         ext4 nofail,defaults 0 2
/rw/home                                    /home       none bind,nofail 0 0
/rw/usrlocal                                /usr/local  none bind,nofail 0 0

rosetta         /usr/local/bin/rosetta2     virtiofs    ro,nofail 0 0
fileshare       /media/fileshare            virtiofs    rw,nofail 0 0
EOT

# rosetta2
cat <<'EOT' > /etc/binfmt.d/rosetta2.conf
:rosetta:M::\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x3e\x00:\xff\xff\xff\xff\xff\xfe\xfe\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff:/usr/local/bin/rosetta2/rosetta:CFP
EOT

# uid 0
chsh -s /usr/bin/zsh
passwd -d root
cat <<'EOT' > /etc/issue

*** SETUP SYSTEM ***

Please login as 'root' (no password).
The setup script ("oeminstall") should start automatically after login.

EOT

# uid 1000
useradd -m -G wheel,video,audio,storage,power -s /usr/bin/zsh user
passwd -d user

# cleanup
systemctl mask systemd-firstboot.service
pacman -Scc --noconfirm
rm -rf /var/cache/pacman/pkg/\*
rm -rf /etc/pacman.d/gnupg
rm -rf /etc/machine-id
find /var/log -type f -delete
journalctl --vacuum-time=0s
dd if=/dev/zero of=/zerofill.tmp bs=1M conv=fsync status=progress
rm -f /zerofill.tmp
dd if=/dev/zero of=/boot/zerofill.tmp bs=1M conv=fsync status=progress
rm -f /boot/zerofill.tmp

EOF
#
# leave chroot
#

cat <<'EOT'
================================================================
IF YOU LIKE TO VERIFY THE CONTENTS OF YOUR IMAGE:

>>> a subshell has been opened and the image is still mounted
>>> when finished, type 'exit' to resume this script
================================================================
EOT

PS1="(type 'exit' to resume script) \w \$ " /bin/bash --norc || true

umount -R /mnt
losetup -D

# lzfse -encode -i arch-minimal.img -o ../arch-minimal.img.lzfse
xz -vkc --format=lzma -9e arch-minimal.img > ../arch-minimal.img.lzma
