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

# system time has to be accurate
date_header=$(/usr/bin/curl -sI https://www.google.com | /usr/bin/grep '^date:' | cut -d' ' -f2-)
if [ -z "$date_header" ]; then
  echo "couldn't retrieve time and date"
  exit 1
fi
/usr/bin/date -s "$date_header"

IMAGE_URL="$(curl -s 'https://www.kali.org/get-kali/' | grep -oP 'https://cdimage.kali.org/kali-202.*?installer-arm64\.iso' | head -n1)"
SHASUM_URL="${IMAGE_URL%/*}/SHA256SUMS"
SIGN_URL="${IMAGE_URL%/*}/SHA256SUMS.gpg"
echo "[+] using image from: $IMAGE_URL"

# download, check integrity and authenticity
curl -C - -LO "$IMAGE_URL"
curl -LO "$SHASUM_URL"
curl -LO "$SIGN_URL"
curl -o KaliARM.pubkey -L "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x827C8569F2518CC677FECA1AED65462EC8D5E4C5"
shasum -c SHA256SUMS --ignore-missing
gpg --import KaliARM.pubkey
gpg --verify SHA256SUMS.gpg SHA256SUMS

cat <<'EOF'
================================================================
MANUAL STEPS REQUIRED:

1. create a "standalone" VM
2. allocate 8G for the root partition
3. use the downloaded kali-linux-*-installer-arm64.iso image
4. install a minimal system without DE and swap partition
5. shutdown VM
6. scp ./kali-minimal.img 'buildVM:/home/user/build_kali/'
7. continue this script

>>> a subshell has been opened to help with these steps
>>> when finished, type 'exit' to resume this script
================================================================
EOF

PS1="(PAUSED: type 'exit' to resume) \w \$ " /bin/bash --norc || true

losetup -D
losetup -fP --show kali-minimal.img

mount /dev/loop0p3 /mnt
mount /dev/loop0p2 /mnt/boot/efi

# boot fallback
echo "vmlinuz root=/dev/vda3 rw initrd=\initrd.img" > /mnt/boot/efi/startup.nsh

# ensure https
sed -i 's|http://http.kali.org/kali|https://http.kali.org|g' /mnt/etc/apt/sources.list

# implant oeminstall script
cp oeminstall /mnt/root/oeminstall
cp dialogrc /mnt/root/dialogrc
chmod +x /mnt/root/oeminstall
echo "cd /root && ./oeminstall" > /mnt/root/.bash_profile
cp /mnt/root/.bash_profile /mnt/root/.zprofile
cat <<EOF > /mnt/etc/issue

*** SETUP SYSTEM ***

Please login as 'root' (no password).
The setup script will start automatically after login.

EOF

# rosetta2
cat <<'EOT' > /mnt/etc/binfmt.d/rosetta2.conf
:rosetta:M::\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x3e\x00:\xff\xff\xff\xff\xff\xfe\xfe\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff:/usr/local/bin/rosetta2/rosetta:CFP
EOT

# update system and clean up
arch-chroot /mnt /usr/bin/bash -c '
passwd -d root
passwd -d user
apt update
apt full-upgrade -y
apt install -y spice-vdagent dialog e2fsprogs dosfstools util-linux console-data
apt clean -y
find /var/log -type f -delete
journalctl --vacuum-time=0s
dd if=/dev/zero of=/zerofill.tmp bs=1M
rm -f /zerofill.tmp
dd if=/dev/zero of=/boot/efi/zerofill.tmp bs=1M conv=fsync status=progress
rm -f /boot/efi/zerofill.tmp
'

cat <<'EOT'
================================================================
IF YOU LIKE TO VERIFY THE CONTENTS OF YOUR IMAGE:

>>> a subshell has been opened and the image is still mounted
>>> when finished, type 'exit' to resume script
================================================================
EOT

PS1="(PAUSED: type 'exit' to resume) \w \$ " /bin/bash --norc || true

umount -R /mnt
losetup -D

# lzfse -encode -i kali-minimal.img -o ../kali-minimal.img.lzfse
xz -vkc --format=lzma -9e kali-minimal.img > ../kali-minimal.img.lzma

# what has been tried:
#
# xz -T0 -k -6 infile
# xz -T0 -k -9e infile
# lzma is very effective but decompression is painfully slow
#
# 7z a -t7z -m0=lzma2 -mx=9 -mfb=64 -md=32m -ms=on outfile infile
# 7z creates files/headers which can't be handled by Apple's Compression Framework
#
