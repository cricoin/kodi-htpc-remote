# 遥控器配对 / Pairing the remote

安装脚本只负责软件；**蓝牙配对需要先手动做一次**。配对后遥控器会记住笔记本，
之后开机自动连接，不用重复配对（换电池也不用）。

> `install.sh` sets up software only. Pair the remote once by hand first; it is remembered
> across reboots and battery changes.

## 一、让遥控器进入配对模式 / Put the remote in pairing mode

小米/红米语音遥控器通常是**同时长按「主页」和「菜单」约 3 秒**，直到指示灯快速闪烁。
不同型号组合键可能不同，以说明书为准。

## 二、用 bluetoothctl 配对 / Pair with bluetoothctl

```bash
bluetoothctl
# 进入交互式提示符后依次输入：
power on
agent on
default-agent
scan on
```

等待列出设备，找到名字像 `Mi Remote` / `XiaoMi Remote` / 一串 MAC 的条目，记下它的 MAC
（形如 `A8:42:A7:05:CF:0E`）。然后：

```bash
scan off
pair A8:42:A7:05:CF:0E      # 换成你的 MAC
trust A8:42:A7:05:CF:0E     # trust 很重要：开机自动重连全靠它
connect A8:42:A7:05:CF:0E
info A8:42:A7:05:CF:0E       # 应看到 Paired: yes / Trusted: yes / Connected: yes
exit
```

确认 `info` 里的三项都是 `yes` 即配对成功。本仓库的 `htpc-remote` 服务靠 USB/BT
的 `厂商:型号 = 2717:32B8` 识别设备，所以不需要把 MAC 写进任何配置。

## 三、确认键码（不同型号可能不同）/ Verify key codes

本项目假设：语音键上报 HID usage `0x7003e`（F5），电源键上报 `0x70066`，
由 `udev/70-xiaomi-bt-remote.hwdb` 重映射成 `space` / `screenlock`。
如果你的遥控器型号不同，用下面命令看看实际 HID usage：

```bash
sudo evtest          # 选中遥控器，逐个按键观察上报的 code
# 或原始 HID：sudo cat /dev/hidrawN | xxd
```

按需修改 hwdb 里的 `KEYBOARD_KEY_xxxxx=...`，然后：

```bash
sudo systemd-hwdb update && sudo udevadm trigger
```

## 四、让蓝牙开机自动开启 / Enable Bluetooth at boot

```bash
sudo systemctl enable --now bluetooth
# /etc/bluetooth/main.conf 里设 AutoEnable=true，确保开机自动打开适配器
```

## 五、（可选）压低连接间隔，减少语音丢帧 / Optional: tighter connection interval

默认 BLE 连接间隔下，长按语音键取回的音频丢帧明显。把间隔压到约 7.5–11.25 ms
可显著改善（见 `docs/voice.md`）。编辑 `/etc/bluetooth/main.conf`：

```ini
[LE]
MinConnectionInterval=6
MaxConnectionInterval=9
```

改完重启蓝牙或重启机器生效。这项只影响语音音频质量，不影响普通按键，默认可不改。

## 常见问题 / Troubleshooting

- **配对上但不自动重连**：确认执行过 `trust <MAC>`，并且 `AutoEnable=true`。
- **第一次按键弹出锁屏而不是解锁**：确认 `udev/71-...libinput.rules` 已安装
  （让桌面不直接读遥控器），以及 `htpc-remote.service` 正在运行。
- **按键没反应**：`systemctl status htpc-remote`，再 `sudo evtest` 看设备是否出现；
  遥控器长时间没反应多半是**电池没电**，换电池即可，无需重新配对。
