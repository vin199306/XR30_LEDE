# XR30 ImmortalWrt 固件 (云编译)

针对 **CMCC XR30 (MT7981B, aarch64, NAND, U-Boot mod)** 设备的 ImmortalWrt 25.12 固件云编译配置，专为 **go2rtc NVR 录像** 场景优化。

## 设备信息

| 项目 | 说明 |
|------|------|
| 目标设备 | `cmcc_xr30-nand-mtkuboot` |
| 平台 | MediaTek Filogic (MT7981B) |
| 架构 | aarch64 (ARMv8) |
| 内核 | Linux 6.12 |
| 根文件系统 | SquashFS (支持恢复出厂) |
| rootfs 分区 | 160MB |

## 云编译使用

### 触发方式

1. **手动触发**：Actions 页 → `Build OpenWrt` → `Run workflow`
2. **自动触发**：`update-checker.yml` 检测上游更新时通过 `repository_dispatch` 触发

### 手动触发可选参数

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `firmware_type` | `all` | 固件类型：`all` / `sysupgrade` / `factory` / `initramfs` |
| `ssh_user` | `root` | SSH 登录用户名 |
| `ssh_password` | `password` | SSH 登录密码（编译时动态生成哈希写入 shadow） |

### 产物

| 类型 | 文件 | 用途 |
|------|------|------|
| sysupgrade | `*-squashfs-sysupgrade.bin` | 正常升级 |
| factory | `*-squashfs-factory.bin` | 从原厂固件刷入 |
| initramfs | `*-initramfs-kernel.bin` | 内存加载测试（不写 flash） |
| 校验 | `sha256sums` | 所有 bin 的 SHA256 校验值 |

- **Artifact**：`OpenWrt_firmware_<设备>_<时间戳>`，按 `firmware_type` 过滤
- **Release**：标签 `YYYY.MM.DD-HHMM`，仅保留最新 3 个

## 固件特性

### 核心 NVR 录像支持

| 包 | 作用 |
|----|------|
| `go2rtc` | 流媒体网关，RTSP/RTMP 接入与转码 |
| `irqbalance` | 中断负载均衡，多路并发录制时分散 CPU 中断 |
| `rsync` | 增量同步录像文件到 NAS/备份机 |
| `f2fs-tools` / `mkf2fs` / `f2fsck` | F2FS 文件系统工具，闪存存储优化 |
| `fdisk` / `cfdisk` | 分区工具 |
| `e2fsprogs` / `ntfs3-mount` | ext4/NTFS 文件系统支持 |

### USB 存储支持

| 包 | 作用 |
|----|------|
| `kmod-usb3` / `kmod-usb-xhci-mtk` | USB 3.0 + MTK XHCI 驱动 |
| `kmod-usb-storage` / `kmod-usb-storage-uas` | USB 存储 + UAS 协议（提速） |
| `automount` / `block-mount` / `fstools` | 自动挂载框架 |
| `kmod-fs-exfat` / `kmod-fs-ext4` / `kmod-fs-f2fs` / `kmod-fs-ntfs3` / `kmod-fs-vfat` | 多文件系统内核支持 |

### 运维必备包

| 包 | 作用 |
|----|------|
| `smartmontools` | 硬盘 SMART 健康监测，预警坏道 |
| `logrotate` | 日志轮转，防止日志写满 NAND |
| `haveged` | 用户态熵源，保 HTTPS/WebRTC 握手 |
| `hdparm` | 硬盘参数/休眠控制 |
| `hd-idle` + `luci-app-hd-idle` | 磁盘空闲自动停转，省电延寿 |
| `kmod-hwmon-core` + `kmod-hwmon-drivetemp` | 硬盘温度传感器 |
| `conntrack` | 连接跟踪表 CLI，排查 RTSP 长连接 |
| `iperf3` | 带宽测试 |
| `lsblk` | 块设备列表 |

### 硬件加速

| 包 | 作用 |
|----|------|
| `kmod-mediatek_hnat` / `hnat-detect` | MTK 硬件 NAT 加速 |
| `luci-app-turboacc-mtk` | MTK 硬件加速管理页 |
| `kmod-nft-offload` | nftables 硬件流卸载 |
| `kmod-crypto-hw-safexcel` / `eip197-mini-firmware` | MTK EIP197 硬件加密引擎 |
| `kmod-warp` / `kmod-conninfra` | MTK WARP 网络加速框架 |

### Web 管理

| 包 | 作用 |
|----|------|
| `nginx-ssl` + `nginx-mod-luci` | Nginx Web 服务器（替代 uhttpd） |
| `luci` + `luci-mod-admin-full` | LuCI 完整管理界面 |
| `luci-theme-argon` | Argon 主题 |
| `luci-app-package-manager` | apk 包管理器界面 |

### 网络与防火墙

| 包 | 作用 |
|----|------|
| `firewall4` / `nftables-json` | firewall4 (nftables) 防火墙 |
| `dnsmasq-full` | DNS+DHCP（含 DNSSEC/DHCPv6） |
| `kmod-tcp-bbr` | BBR 拥塞控制 |
| `odhcp6c` / `odhcpd-ipv6only` | IPv6 DHCP 客户端/服务端 |
| `wpad` | WiFi WPA3 认证 |

## 固化配置（uci-defaults 脚本）

以下脚本位于 [`files/etc/uci-defaults/`](files/etc/uci-defaults/)，首次启动/重置后自动运行，确保配置持久化：

### zz-wan-access — WAN 口访问规则

确保刷机/重置后可通过 WAN 口远程管理，避免失联：

| 规则 | 协议 | 端口 | 用途 |
|------|------|------|------|
| Allow-WAN-SSH | TCP | 22 | SSH 远程管理 |
| Allow-WAN-HTTP | TCP | 80 | LuCI 管理页 |
| Allow-WAN-HTTPS | TCP | 443 | LuCI HTTPS |
| Allow-WAN-Ping | ICMP (IPv4) | - | 远程诊断 |
| Allow-WAN-Ping6 | ICMP (IPv6) | - | 远程诊断 |

### zz-ssh-enable — dropbear SSH 配置

- 启用 dropbear 服务并设为开机自启
- 监听所有接口（不绑定特定 Interface，移除 deprecated 选项）
- 允许 root 登录 + 密码认证
- 确保刷完固件后 Luci 无法访问时可通过 SSH 排障

### zz-nginx-webserver — Nginx Web 服务器配置

- 禁用 uhttpd，使用 nginx 作为 Web 服务器
- 移除 `restrict_locally` IP 白名单限制（修复 WAN IPv6 访问 LuCI 返回 403）
- 创建 `nginx.conf -> /var/lib/nginx/uci.conf` 符号链接（修复 `nginx -t` 找不到配置文件）

## 自定义脚本

### diy-part1.sh

- 移除 passwall 软件源

### diy-part2.sh

- 修改默认 LAN IP 为 `192.168.2.1`
- 动态设置 root 密码（从 yml 输入参数 `SSH_USER`/`SSH_PASSWORD` 获取，用 `openssl passwd -6` 生成 SHA-512 哈希写入 `/etc/shadow`）

## 已移除的组件

为精简固件、加快编译速度，移除以下不必要组件：

| 类别 | 移除内容 |
|------|---------|
| PPP 拨号 | `ppp` / `ppp-mod-pppoe` / `kmod-ppp*` / `luci-proto-ppp` |
| 代理软件 | `sing-box` / `microsocks` / `chinadns-ng` / `dns2socks` / `ipt2socks` |
| iptables 兼容 | `kmod-ipt-*` / `iptables-mod-*` / `kmod-nft-compat`（firewall4 原生 nftables） |
| 虚拟网卡 | `kmod-dummy` / `kmod-ifb` / `kmod-macvlan` / `kmod-tun` / `kmod-sched-core` |
| OpenSSL 冗余 | SRP/IDEA/SEED/MDC2/WHIRLPOOL/NPN/ERROR_MESSAGES/AFALG_SYNC |
| 陈旧加密 | `arc4` / `des` / `ecb` / `md4` / `sha3` / `kmod-crypto-user` |
| 多余 ATF | `trusted-firmware-a-mt7986/7987/7988-*`（仅保留设备依赖自动拉取的 mt7981） |
| initramfs 镜像 | `CONFIG_TARGET_ROOTFS_INITRAMFS`（调试用，不需要） |

## 工作流文件

| 文件 | 作用 |
|------|------|
| [`.github/workflows/openwrt-builder.yml`](.github/workflows/openwrt-builder.yml) | 主编译工作流 |
| [`.github/workflows/update-checker.yml`](.github/workflows/update-checker.yml) | 上游更新检测 |

### 工作流权限

使用 GitHub 自动提供的 `GITHUB_TOKEN`（无需手动配置 PAT）：

| 权限 | 用途 |
|------|------|
| `contents: write` | 删除/创建 Releases |
| `actions: write` | 删除 workflow 运行记录、触发 repository_dispatch |

## 默认凭据

| 项目 | 值 |
|------|-----|
| LAN IP | `192.168.2.1` |
| SSH 用户 | `root`（或编译时自定义） |
| SSH 密码 | `password`（或编译时自定义） |

> ⚠️ **安全提示**：`password` 是弱密码，建议编译时输入强密码。刷机后请及时通过 `passwd` 修改。

## Credits

- [ImmortalWrt](https://github.com/immortalwrt/immortalwrt)
- [P3TERX/Actions-OpenWrt](https://github.com/P3TERX/Actions-OpenWrt)
- [GitHub Actions](https://github.com/features/actions)
- [softprops/action-gh-release](https://github.com/softprops/action-gh-release)
- [Mattraks/delete-workflow-runs](https://github.com/Mattraks/delete-workflow-runs)
- [dev-drprasad/delete-older-releases](https://github.com/dev-drprasad/delete-older-releases)
- [peter-evans/repository-dispatch](https://github.com/peter-evans/repository-dispatch)

## License

[MIT](LICENSE) © P3TERX
