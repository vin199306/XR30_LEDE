#!/bin/bash
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)
#
# Copyright (c) 2019-2024 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

# Modify default IP
sed -i 's/192.168.1.1/192.168.2.1/g' package/base-files/files/bin/config_generate

# Modify default theme
# sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile

# Modify hostname
#sed -i 's/OpenWrt/P3TERX-Router/g' package/base-files/files/bin/config_generate

# Set root password (from workflow inputs, default: root/password)
SSH_USER="${SSH_USER:-root}"
SSH_PASSWORD="${SSH_PASSWORD:-password}"
HASH="$(openssl passwd -6 "$SSH_PASSWORD")"
SHADOW_DIR="package/base-files/files/etc"
SHADOW="${SHADOW_DIR}/shadow"
mkdir -p "$SHADOW_DIR"
if [ -f "$SHADOW" ]; then
    if grep -q '^root:' "$SHADOW"; then
        sed -i "s|^root:[^:]*:|root:${HASH}:|" "$SHADOW"
    else
        echo "root:${HASH}:19000:0:99999:7:::" >> "$SHADOW"
    fi
else
    cat > "$SHADOW" <<EOF
root:${HASH}:19000:0:99999:7:::
daemon:*:19000:0:99999:7:::
ftp:*:19000:0:99999:7:::
network:*:19000:0:99999:7:::
nobody:*:19000:0:99999:7:::
EOF
    chmod 600 "$SHADOW"
fi
echo "已设置 root 密码 (哈希前缀: ${HASH:0:20}...)"
