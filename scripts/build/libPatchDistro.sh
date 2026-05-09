#! /bin/bash

patchRosetta() {
    [[ $# -ne 1 ]] && { echo "${FUNCNAME[0]} expects 1 argument" ; exit 1; }
    local target="$1"
    
    echo 'export GLIBC_TUNABLES=glibc.pthread.rseq=0' > "$target/etc/profile.d/disable-rseq.sh"
}

patchOEM() {
    [[ $# -ne 2 ]] && { echo "${FUNCNAME[0]} expects 2 arguments" ; exit 1; }
    local target="$1"
    local distro="$2"
    
    mkdir -p "$target/root"
    cp "./$distro/oeminstall" "$target/root/oeminstall"
    cp "./$distro/dialogrc" "$target/root/dialogrc"
    echo 'cd /root && ./oeminstall' > "$target/root/.zprofile"
    chmod +x "$target/root/oeminstall"
    
    cat <<'EOT' > "$target/etc/issue"
*** SETUP SYSTEM ***

Please login as 'root' (no password).
The setup script ("oeminstall") should start automatically after login.

EOT
    
}

patchDistro() {
    [[ $# -ne 2 ]] && { echo "${FUNCNAME[0]} expects 2 arguments" ; exit 1; }
    local target="$1"
    local inputArg="$2"
    
    case "$inputArg" in
        cinnamon) patchCinnamon "$target" ;;
        container) patchContainer "$target" ;;
        *) patchSystem "$target" ;;
    esac
}

patchCinnamon() {
    [[ $# -ne 1 ]] && { echo "${FUNCNAME[0]} expects 1 argument" ; exit 1; }
    local target="$1"
    patchSystem "$target"
    
    arch-chroot "$target" /bin/bash <<'EOF'
echo "root:root" | chpasswd
echo "user:user" | chpasswd
systemctl enable lightdm

EOF
}

patchContainer() {
    [[ $# -ne 1 ]] && { echo "${FUNCNAME[0]} expects 1 argument" ; exit 1; }
    local target="$1"
    patchSystem "$target"
    
    arch-chroot "$target" /bin/bash <<'EOF'
mkdir -p /etc/docker
mkdir -p /etc/systemd/system/docker.service.d/
mkdir -p /var/lib/docker
mkdir -p /var/lib/containerd

cat <<'EOT' > /etc/systemd/system/docker.service.d/override.conf
[Unit]
RequiresMountsFor=/usr/local
EOT

systemctl enable docker

EOF
}

patchSystem() {
    [[ $# -ne 1 ]] && { echo "${FUNCNAME[0]} expects 1 argument" ; exit 1; }
    local target="$1"
    arch-chroot "$target" /bin/bash <<'EOF'
# fstab
cat <<'EOT' > /etc/fstab

# <file system> <dir> <type> <options> <dump> <pass>
                                                                     
/dev/disk/by-id/virtio-root-part1           /boot       vfat defaults,fmask=0077,dmask=0077 0 2
/dev/disk/by-id/virtio-root-part2           /           ext4 defaults 0 1

/dev/disk/by-id/virtio-home-part1           /rw         ext4 nofail,defaults 0 2

/rw/home                      /home                none bind,nofail,x-systemd.requires=/rw 0 0
/rw/usrlocal                  /usr/local           none bind,nofail,x-systemd.requires=/rw 0 0
/rw/usrlocal/lib/docker       /var/lib/docker      none bind,nofail,x-systemd.requires=/rw 0 0
/rw/usrlocal/lib/containerd   /var/lib/containerd  none bind,nofail,x-systemd.requires=/rw 0 0

rosetta         /usr/local/bin/rosetta2     virtiofs    ro,nofail 0 0
fileshare       /media/fileshare            virtiofs    rw,nofail 0 0
EOT

# rosetta2
mkdir -p /etc/systemd/system/systemd-binfmt.service.d/
cat <<'EOT' > /etc/systemd/system/systemd-binfmt.service.d/override.conf
[Unit]
RequiresMountsFor=/usr/local/bin/rosetta2
EOT

cat <<'EOT' > /etc/binfmt.d/rosetta2.conf
:rosetta:M::\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x3e\x00:\xff\xff\xff\xff\xff\xfe\xfe\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff:/usr/local/bin/rosetta2/rosetta:CFP
EOT

EOF
}

cleanupSystem() {
    [[ $# -ne 2 ]] && { echo "${FUNCNAME[0]} expects 2 arguments" ; exit 1; }
    local target="$1"
    local distro="$2"
    
    case "$distro" in
        kali) cleanupKali "$target" ;;
        *) cleanupArch "$target" ;;
    esac
}

cleanupArch() {
    [[ $# -ne 1 ]] && { echo "${FUNCNAME[0]} expects 1 arguments" ; exit 1; }
    local target="$1"
    
    arch-chroot "$target" /bin/bash <<'EOF'
# cleanup
systemctl mask systemd-firstboot.service
pacman -Scc --noconfirm
rm -rf /var/cache/pacman/pkg/\*
rm -rf /etc/pacman.d/gnupg
rm -rf /etc/machine-id
find /var/log -type f -delete
journalctl --vacuum-time=1s
dd if=/dev/zero of=/zerofill.tmp bs=1M conv=fsync status=progress
rm -f /zerofill.tmp
dd if=/dev/zero of=/boot/zerofill.tmp bs=1M conv=fsync status=progress
rm -f /boot/zerofill.tmp

EOF
}

cleanupKali() {
    [[ $# -ne 1 ]] && { echo "${FUNCNAME[0]} expects 1 arguments" ; exit 1; }
    local target="$1"

    arch-chroot "$target" /bin/bash <<'EOF'
# cleanup
apt-get clean
apt-get autoremove --purge -y
rm -rf /var/lib/apt/lists/*
rm -rf /var/cache/apt/archives/*

find /var/log -type f -delete
journalctl --vacuum-time=1s
dd if=/dev/zero of=/zerofill.tmp bs=1M conv=fsync status=progress
rm -f /zerofill.tmp
dd if=/dev/zero of=/boot/zerofill.tmp bs=1M conv=fsync status=progress
rm -f /boot/zerofill.tmp

EOF
}
