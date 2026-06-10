#!/bin/bash
set -e

IMG="$1"
MNT_DIR="/mnt/istoreos"

sudo mkdir -p "${MNT_DIR}"
LOOP_DEV=$(sudo losetup -f --show "${IMG}")
echo "Loop device: ${LOOP_DEV}"

sudo mount "${LOOP_DEV}" "${MNT_DIR}"

# fstab
sudo tee "${MNT_DIR}/etc/config/fstab" >/dev/null <<'EOF'
config global
        option anon_swap '0'
        option anon_mount '0'
        option auto_swap '0'
        option auto_mount '1'
        option delay_root '5'
        option check_fs '0'

config mount
        option target '/'
        option device '/dev/root'
        option fstype 'ext4'
        option options 'rw,noatime'
EOF

# network
sudo tee "${MNT_DIR}/etc/config/network" >/dev/null <<'EOF'
config interface 'loopback'
        option ifname 'lo'
        option proto 'static'
        option ipaddr '127.0.0.1'
        option netmask '255.0.0.0'

config interface 'lan'
        option ifname 'eth0'
        option proto 'dhcp'
EOF

# rc.local
sudo tee "${MNT_DIR}/etc/rc.local" >/dev/null <<'EOF'
#!/bin/sh
/etc/init.d/wireless stop
/etc/init.d/hostapd stop
/etc/init.d/dnsmasq disable
/etc/init.d/network restart
exit 0
EOF
sudo chmod +x "${MNT_DIR}/etc/rc.local"

# 删除内核模块
sudo rm -rf "${MNT_DIR}/lib/modules"/*

sudo umount "${MNT_DIR}"
sudo losetup -d "${LOOP_DEV}"

echo "Adapt done!"
