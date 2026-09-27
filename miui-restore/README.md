# 刷回官方 MIUI —— 刷机方案

## 目标

| 项 | 值 |
|---|---|
| ROM | MIUI 9.6.2.0 稳定版（中国版，Android 5.1.1），latte 最后一个线刷包 |
| 文件 | `latte_images_V9.6.2.0.LACCNFD_20180702.0000.00_5.1_cn_6f8e742f80.tgz`（1,076,439,956 字节） |
| 来源 | 小米官方 CDN：`https://cdnorg.d.miui.com/V9.6.2.0.LACCNFD/<文件名>` |
| MD5 | `6f8e742f80357e695135637b77137abc`（与文件名里的 `6f8e742f80` 一致） |
| 浏览器（默认） | **Bromite 95.0.4638.79 x86**（Chromium 内核）。Chrome/Chromium 95 是支持 Android 5.x 的最后一个版本，从 96 起要求 Android 6。minSdk 21，签名证书 SHA-256 `e1ee5cd0…0c3b9504`（Bromite 官方） |
| 浏览器（备用） | Firefox 143.0.4 x86：Gecko 内核，最后一个支持 Android 5–7 和 32 位 x86 的版本。部分 three.js 或特效网页显示不正常，所以改用 Bromite |

镜像和 APK 的 SHA-256 在 `SHA256SUMS.rom`、`SHA256SUMS.apks` 里。`rom/`、`apks/`、`logs/` 已经加进 `.gitignore`。

## 下载资源

下载的文件不进 git，需要时按下面的链接重新下载：

```bash
cd miui-restore
mkdir -p rom apks
curl -fL -o rom/latte_images_V9.6.2.0.LACCNFD_20180702.0000.00_5.1_cn_6f8e742f80.tgz \
  https://cdnorg.d.miui.com/V9.6.2.0.LACCNFD/latte_images_V9.6.2.0.LACCNFD_20180702.0000.00_5.1_cn_6f8e742f80.tgz
curl -fL -o apks/bromite-95.0.4638.79-x86_ChromePublic.apk \
  https://github.com/bromite/bromite/releases/download/95.0.4638.79/x86_ChromePublic.apk
curl -fL -o apks/fenix-143.0.4.multi.android-x86.apk \
  https://archive.mozilla.org/pub/fenix/releases/143.0.4/android/fenix-143.0.4-android-x86/fenix-143.0.4.multi.android-x86.apk
(cd apks && sha256sum -c ../SHA256SUMS.apks)
```

| 资源 | 链接 | 校验 |
|---|---|---|
| MIUI 线刷包 | https://cdnorg.d.miui.com/V9.6.2.0.LACCNFD/latte_images_V9.6.2.0.LACCNFD_20180702.0000.00_5.1_cn_6f8e742f80.tgz（`bigota.d.miui.com` 返回 403，`bn.d.miui.com` 也可用） | MD5 `6f8e742f80357e695135637b77137abc` |
| Bromite 95.0.4638.79 x86 | https://github.com/bromite/bromite/releases/download/95.0.4638.79/x86_ChromePublic.apk | SHA-256 见 `SHA256SUMS.apks`；签名证书 SHA-256 `e1ee5cd076d7b0dc84cb2b45fb78b86df2eb39a3b6c56ba3dc292a5e0c3b9504` |
| Firefox 143.0.4 x86（备用） | https://archive.mozilla.org/pub/fenix/releases/143.0.4/android/fenix-143.0.4-android-x86/fenix-143.0.4.multi.android-x86.apk | SHA-256 见 `SHA256SUMS.apks`；签名证书 SHA-256 `a78b62a5…2ea319b04`（Mozilla Release Engineering） |
| 版本列表 | https://xiaomirom.com/en/rom/mipad-2-latte-china-fastboot-recovery-rom/ | — |

线刷包只需保留 `.tgz`；`flash-miui.sh` 发现没有解压目录时会自动解压。

## 刷写内容（与官方 `flash_all.sh` 相同）

1. `flash bootloader`：ESP/UEFI 引导分区。**这是唯一有风险的一步，中途断开可能导致开不了机**，出问题时可以用 DNX 模式救回。
2. `format cache`
3. `flash data userdata.img`：**会清空平板上的 Xubuntu 根文件系统**
4. `flash system system.img`（1.8 GB，最耗时）
5. `flash boot boot.img`
6. `flash recovery recovery.img`
7. `reboot`

不会改动的：分区表（GPT）、IFWI 固件、OEM 变量。之前刷 Linux 时只动过 `boot` 和 `userdata`，所以这套刷写能完全覆盖回去。

## 操作步骤

1. **先备份**：平板上的 Xubuntu 里如果有需要的东西，现在就拷出来，刷机后就没了。
2. 平板充电到 **50% 以上**，用 Type-C 线直连电脑，不要经过 Hub。
3. 关机，按住 **音量上 + 音量下 + 电源**，进入 DNX Fastboot。
4. 预检（只读）：`./miui-restore/flash-miui.sh`
   - 会检查序列号是否为 `A3P4E8A32A64`、`product` 是否为 `latte`，并校验所有镜像。
   - 如果 `product` 不是 `latte`，脚本会提示先执行 `fastboot boot images/loader.efi`。
5. 正式刷写：`./miui-restore/flash-miui.sh --go`，大约 5–10 分钟。任何一步失败都会立即停止。
6. 首次开机需要 5–10 分钟。开机后在设置里连续点"MIUI 版本"打开开发者选项，再打开 **USB 调试**。
7. 可选：消除开机警告。进入 fastboot，运行 `./miui-restore/flash-miui.sh --verified`（可能清空数据，所以放在装应用之前），详见 [`../BOOTLOADER-VERIFIED.md`](../BOOTLOADER-VERIFIED.md)。开机后重新打开 USB 调试。
8. 安装 Bromite、做省电设置、移除预装应用：`./miui-restore/flash-miui.sh --post`

所有输出都记录在 `logs/` 里。

## 省电设置（2026-09-27 已通过 adb 应用）

MIUI 默认值已经比较省电：1 分钟自动锁屏、自动亮度、蓝牙关闭、WiFi 后台扫描关闭，这些没有改。改动如下：

```bash
adb shell settings put secure location_providers_allowed -network
adb shell settings put secure location_providers_allowed -gps
adb shell settings put global window_animation_scale 0
adb shell settings put global transition_animation_scale 0
adb shell settings put global animator_duration_scale 0
adb shell settings put global mobile_data 0
adb shell settings put global wifi_sleep_policy 2                   # 熄屏时 WiFi 不休眠（MIUI 默认值就是 2）
adb shell settings put global wifi_suspend_optimizations_enabled 0  # 关闭 WiFi 驱动的 suspend 省电模式
```

Bromite 的 MIUI 后台策略设为「无限制」（默认是「智能限制后台运行」）。这个设置保存在 powerkeeper 的 provider 里，需要 MIUI 签名权限，adb 没法直接写。所以脚本的做法是：打开设置页 `am start -a miui.intent.action.HIDDEN_APPS_CONFIG_ACTIVITY --es package_name org.bromite.bromite`，用 uiautomator 找到「无限制」按钮并点击，再检查是否已选中。

验证 WiFi 设置是否生效：`adb shell dumpsys wifi | grep -E "mSleepPolicy|mUserWantsSuspendOpt"`，应显示 `2` 和 `false`。

Android 5.1 没有 Doze，所以系统层面的「电池优化白名单」不存在，只有上面这个 MIUI 后台策略需要改。

移除了广告、推广和统计类预装应用（`pm uninstall -k --user 0`）。MIUI 不允许 `pm disable-user`，所以用了卸载。APK 仍保留在 system 分区，恢复出厂设置或重刷后就会回来：

```
com.mi.liveassistant com.yidian.zxpad com.xiaomi.padshop com.xiaomi.jr
com.miui.klo.bugreport com.duokan.hdreader com.miui.analytics
com.miui.systemAdSolution com.miui.video com.miui.player com.miui.fm
com.xiaomi.gamecenter.pad com.xiaomi.gamecenter.sdk.service com.xiaomi.mitunes
com.miui.translation.kingsoft com.miui.translation.youdao
com.miui.translationservice com.android.email com.miui.bugreport com.android.midrive
```

保留未动的：`com.xiaomi.xmsf`（推送）、`com.miui.powerkeeper` 和 `com.miui.powercenter`（MIUI 自带的省电管理）、`com.intel.thermal`（温控）。

使用建议：
- 在 Bromite 里把 Guacamole、ttyd、Excalidraw 这些网页"添加到主屏幕"，当应用用。
- WebGL 网页打不开时，打开 `chrome://gpu` 看 WebGL 是否被 GPU 黑名单禁用了；如果是，在 `chrome://flags` 里启用 "Override software rendering list"。

## 出问题怎么办

- **卡在开机 Mi 标志**：重新进 DNX，再运行一次 `--go`。
- **进不了 fastboot**：参考 xiaomi.eu 上的 [仅 DNX 模式救砖](https://xiaomi.eu/community/threads/how-to-unbrick-mi-pad-with-only-dnx-fastboot-mode.36217/)，用 `fastboot boot loader.efi` 进入 fastboot 后重新刷。
- **想回到 Linux**：上级目录里保留了 `mipad2-boot-*.img` 等备份，但 `userdata` 里的根文件系统需要重新写入。

## adb 常开与 WiFi adb

- **开发者选项、USB 调试**：保存在系统设置里（`development_settings_enabled=1`、`adb_enabled=1`），重启后会保持开启，不需要额外处理。
- **WiFi adb**：`./miui-restore/wifi-adb.sh` 用 USB 开启 `adb tcpip 5555` 并连接。**没有 root 时，重启后会失效。**要让它重启后自动开启，得写入 `persist.adb.tcp.port`，但 SELinux 不允许 shell 用户写 `persist.*` 属性：`setprop` 返回 0，实际没有写进去。`service.adb.tcp.port` 能写，但重启后会清空。所以目前的做法是：每次重启后用 USB 连一次，运行这个脚本。
- 真正做到常开需要 root，而 root 需要先把 bootloader 从 verified 切回 unlocked（会清空数据），再刷修改过的 boot 镜像。

## 电池 / 电量计诊断

2026-09-27 发现 BQ27520 电量计记录的满电容量 `CHARGE_FULL` 只有 **70 mAh**，而设计容量是 6190 mAh，导致电量百分比乱跳（72% → 0% 自动关机 → 100%）。循环次数 138 次，健康状态 Good。

- `./miui-restore/battery-log.sh [ip:port]`：通过 WiFi adb 每分钟记录一次状态、电量、电压、电流和 `CHARGE_FULL`，写入 `logs/battery-*.csv`。
### 结论：电池损坏，需要更换（2026-09-27 放电测试）

| 时间 | 状态 | 电量 | 电压 | 电流 |
|---|---|---|---|---|
| 19:21 | 充电中 | 100% | 4.30 V | — |
| 19:22 | 拔掉电源 | 99% | 3.95 V | 482 mA |
| 19:23 | 放电中 | 98% | 3.89 V | 653 mA |
| 19:24 | 放电中 | 96% | 3.84 V | 662 mA |
| 19:25 | 放电中 | 93% | 3.89 V | 498 mA |
| 19:27 起 | 已关机 | — | — | — |

- **拔电后只撑了 4–5 分钟**，一共放出约 40–50 mAh，和电量计记录的 `CHARGE_FULL` 71 mAh 一致。所以电量计没有记错，是电池实际容量只剩设计值的 1% 左右。**校准没有意义。**
- 一拔电源，电压就跌了约 0.35 V，估算内阻约 0.7 Ω（正常为 0.1–0.2 Ω）。关机时显示的电量是 93%、电压 3.89 V，属于负载一大电压就瞬间跌破关机线的突然掉电。
- 循环次数只有 138 次，却衰减成这样，更像是长期亏电存放导致的过放损伤，而不是正常用旧。

处理建议：
1. **先检查电池有没有鼓包**：后盖是否隆起、屏幕是否被顶起、边框缝隙是否变大。有的话，立刻停止充电和使用。
2. **更换电池**：型号 **BM61**（6190 mAh），需要拆开后盖。
3. 换电池之前，把平板当插电设备用，**一定要用墙插充电器（2 A 以上）**。电脑 USB 的输入电流被限制在 900 mA（`INPUT_CUR_LIMIT=900`），负载大的时候，平板还是要从电池取电，一样会突然关机。
4. 换上新电池后，按下面的步骤校准一次电量计，让它重新学习容量：充到 100% 后继续插 2 小时以上 → 拔掉电源，用到自动关机 → 静置 1 小时以上 → 一次性充满。然后用 `battery-log.sh` 检查 `CHARGE_FULL` 是否接近 6190 mAh。
