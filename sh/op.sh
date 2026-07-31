#!/bin/bash

set -x

# kenrel Vermagic
sed -ie 's/^\(.\).*vermagic$/\1cp $(TOPDIR)\/.vermagic $(LINUX_DIR)\/.vermagic/' include/kernel-defaults.mk
grep HASH target/linux/generic/kernel-6.12 | awk -F'HASH-' '{print $2}' | awk '{print $1}' | md5sum | awk '{print $1}' > .vermagic

git clone -b packages --depth 1 --single-branch https://github.com/shiyu1314/openwrt-feeds package/xd
git clone -b porxy --depth 1 --single-branch https://github.com/shiyu1314/openwrt-feeds package/porxy

rm -rf feeds/luci/applications/{luci-app-dockerman,luci-app-samba4,luci-app-aria2,luci-app-diskman}
rm -rf feeds/packages/net/{samba4,v2ray-geodata,mosdns,sing-box,aria2,ariang,adguardhome}

# drop attendedsysupgrade
sed -i '/luci-app-attendedsysupgrade/d' \
    feeds/luci/collections/luci-nginx/Makefile \
    feeds/luci/collections/luci-ssl-openssl/Makefile \
    feeds/luci/collections/luci-ssl/Makefile \
    feeds/luci/collections/luci/Makefile
    
sed -i 's/+uhttpd /+luci-nginx /g' feeds/luci/collections/luci/Makefile
sed -i 's/+uhttpd-mod-ubus //' feeds/luci/collections/luci/Makefile
sed -i 's/+uhttpd /+luci-nginx /g' feeds/luci/collections/luci-light/Makefile
sed -i "s/+luci /+luci-nginx /g" feeds/luci/collections/luci-ssl-openssl/Makefile
sed -i "s/+luci /+luci-nginx /g" feeds/luci/collections/luci-ssl/Makefile
sed -i 's/+uhttpd +uhttpd-mod-ubus /+luci-nginx /g' feeds/packages/net/wg-installer/Makefile
sed -i '/uhttpd-mod-ubus/d' feeds/luci/collections/luci-light/Makefile
sed -i 's/+luci-nginx \\$/+luci-nginx/' feeds/luci/collections/luci-light/Makefile

pushd feeds/luci || exit 1
for patch in *.patch; do
    [ -f "$patch" ] || continue
    
    echo "Applying $patch ..."
    patch -p1 --no-backup-if-mismatch < "$patch" || {
        echo "ERROR: Failed to apply $patch"
        popd
        exit 1
    }
done
popd

for patch in *.patch; do
    [ -f "$patch" ] || continue

    echo "Applying $patch ..."
    patch -p1 --no-backup-if-mismatch < "$patch" || {
        echo "ERROR: Failed to apply $patch"
        exit 1
    }
done

# USB 3.0 optimization for external USB drives
# 1. elevator=bfq: BFQ scheduler for fair IO latency (config: CONFIG_KERNEL_MQ_IOSCHED_BFQ)
# 2. usbcore.autosuspend=-1: disable USB autosuspend, prevent U盘间歇性无响应
for dts in target/linux/mediatek/dts/mt7981-cmcc-xr30-*.dts; do
    [ -f "$dts" ] || continue
    sed -i 's/\(bootargs = "[^"]*\)"/\1 elevator=bfq usbcore.autosuspend=-1/' "$dts"
    echo "Patched bootargs in $dts"
done

# usb-storage quirks: force UAS for Kioxia TransMemory (vid=30de pid=6544)
# usb-storage is a module (=m), so quirk goes in /etc/modules.d, not bootargs
mkdir -p files/etc/modules.d
cat > files/etc/modules.d/usb-storage <<'EOF'
# Force UAS driver for known USB drives (u flag = IGNORE_DEVICE in usb-storage)
usb-storage quirks=30de:6544:u
EOF

# 只编译 sysupgrade.bin, 跳过 initramfs/kernel/rootfs 等产物, 加快编译速度
# 1. 给 cmcc_xr30-nand 添加 IMAGES := sysupgrade.bin
# 2. 移除 KERNEL_INITRAMFS 定义 (避免编译 initramfs 镜像)
filogic_mk="target/linux/mediatek/image/filogic.mk"
awk '
  /^define Device\/cmcc_xr30-nand$/ { in_dev=1 }
  in_dev && /^  IMAGES :=/ { has_images=1 }
  in_dev && /^  IMAGE\/sysupgrade\.bin :=/ && !has_images {
    print "  IMAGES := sysupgrade.bin"
    has_images=1
  }
  in_dev && /^  KERNEL_INITRAMFS / { skip=1; next }
  skip && /\\$/ { next }
  skip { skip=0; next }
  { print }
  /^endef$/ && in_dev { in_dev=0 }
' "$filogic_mk" > "$filogic_mk.tmp" && mv "$filogic_mk.tmp" "$filogic_mk"
echo "Patched filogic.mk: cmcc_xr30-nand IMAGES := sysupgrade.bin only"

# rust
RUST_VERSION=1.95.0
RUST_HASH=62b67230754da642a264ca0cb9fc08820c54e2ed7b3baba0289876d4cdb48c08
sed -ri "s/(PKG_VERSION:=)[^\"]*/\1$RUST_VERSION/;s/(PKG_HASH:=)[^\"]*/\1$RUST_HASH/" feeds/packages/lang/rust/Makefile

# fstools
rm -rf package/system/fstools
git clone https://github.com/sbwml/package_system_fstools -b openwrt-25.12 package/system/fstools
# util-linux
rm -rf package/utils/util-linux
git clone https://github.com/sbwml/package_utils_util-linux -b openwrt-25.12 package/utils/util-linux

# nghttp3
rm -rf feeds/packages/libs/nghttp3
git clone https://github.com/sbwml/package_libs_nghttp3 package/libs/nghttp3

# ngtcp2
rm -rf feeds/packages/libs/ngtcp2
git clone https://github.com/sbwml/package_libs_ngtcp2 package/libs/ngtcp2

# curl - fix passwall `time_pretransfer` check
rm -rf feeds/packages/net/curl
git clone https://github.com/sbwml/feeds_packages_net_curl feeds/packages/net/curl

# nginx - latest version
rm -rf feeds/packages/net/nginx
git clone https://github.com/sbwml/feeds_packages_net_nginx feeds/packages/net/nginx -b openwrt-25.12
sed -i 's/procd_set_param stdout 1/procd_set_param stdout 0/g;s/procd_set_param stderr 1/procd_set_param stderr 0/g' feeds/packages/net/nginx/files/nginx.init

# nginx - ubus
sed -i 's/ubus_parallel_req 2/ubus_parallel_req 6/g' feeds/packages/net/nginx/files-luci-support/60_nginx-luci-support
sed -i '/ubus_parallel_req/a\        ubus_script_timeout 300;' feeds/packages/net/nginx/files-luci-support/60_nginx-luci-support

# nginx-util
sed -i '/\/etc\/nginx\/uci.conf.template/d' feeds/packages/net/nginx-util/Makefile

# uwsgi - fix timeout
sed -i '$a cgi-timeout = 600' feeds/packages/net/uwsgi/files-luci-support/luci-*.ini
sed -i '/limit-as/c\limit-as = 5000' feeds/packages/net/uwsgi/files-luci-support/luci-webui.ini
# disable error log
sed -i "s/procd_set_param stderr 1/procd_set_param stderr 0/g" feeds/packages/net/uwsgi/files/uwsgi.init

# uwsgi - performance
sed -i 's/threads = 1/threads = 2/g' feeds/packages/net/uwsgi/files-luci-support/luci-webui.ini
sed -i 's/processes = 3/processes = 4/g' feeds/packages/net/uwsgi/files-luci-support/luci-webui.ini
sed -i 's/cheaper = 1/cheaper = 2/g' feeds/packages/net/uwsgi/files-luci-support/luci-webui.ini

# rpcd - fix timeout
sed -i 's/option timeout 30/option timeout 60/g' package/system/rpcd/files/rpcd.config
sed -i 's#20) \* 1000#60) \* 1000#g' feeds/luci/modules/luci-base/htdocs/luci-static/resources/rpc.js

# luci-compat - remove extra line breaks from description
sed -i '/<br \/>/d' feeds/luci/modules/luci-compat/luasrc/view/cbi/full_valuefooter.htm


#golang 26.x
rm -rf feeds/packages/lang/golang
git clone https://github.com/sbwml/packages_lang_golang -b 26.x feeds/packages/lang/golang

./scripts/feeds update -a
./scripts/feeds install -a

sed -i 's|/bin/login|/bin/login -f root|g' feeds/packages/utils/ttyd/files/ttyd.config


sed -i "s/%D %V %C/%D %V $(TZ=UTC-8 date +%Y.%m.%d)/" package/base-files/files/etc/openwrt_release
