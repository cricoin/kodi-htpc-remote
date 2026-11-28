# 故障排查与加固 / Troubleshooting & hardening

真实使用中遇到过的问题、根因和本仓库里的对应处理。

## 1. 根分区被日志写满，桌面卡死 / Root disk filled by logs

**现象**：锁屏解不开、键盘鼠标没反应；重启后 Jellyfin 拒绝启动
（`/var/lib/jellyfin/data has insufficient free space ... Required: 2GiB`），Kodi 无法播放。

**根因**：GNOME Shell 42 长时间运行后进入 GJS 死循环，每秒数千行地写
`Attempting to run a JS callback during garbage collection ... The offending callback was SourceFunc()`，
一天之内把 `/var/log/syslog` 写到 27 GB。GNOME 每次锁屏都会停用扩展、解锁时再启用；
这套方案里“闲置锁屏 + 遥控器免密解锁”每天循环很多次，Ubuntu 默认扩展
（ubuntu-dock、ding 桌面图标、appindicators）反复启停，最终留下失效的定时器，触发这个循环。
同类案例：dash-to-dock #1121、pop-shell #1803。

**处理（`install.sh` 已包含）**：

- 停用 HTPC 用不到的三个扩展：
  ```bash
  gsettings set org.gnome.shell disabled-extensions \
    "['ubuntu-dock@ubuntu.com', 'ding@rastersoft.com', 'ubuntu-appindicators@ubuntu.com']"
  ```
- `rsyslog/10-drop-gnome-shell-gc-spam.conf`：丢弃这类刷屏行，正常日志不受影响。
- logrotate：rsyslog 加 `maxsize 200M`，`logrotate.timer` 改为每小时检查一次。
- `bin/htpc-disk-guard` + `htpc-disk-guard.timer`：每 5 分钟检查一次，根分区低于 3 GB 时，
  截断超过 500 MB 的日志（末尾 5000 行保留到 /tmp 备查）并清理 journal。

**已经满了怎么救急**：
```bash
sudo tail -n 200000 /var/log/syslog > /tmp/syslog_tail.txt   # 先留证据（/tmp 最好是独立分区）
sudo truncate -s 0 /var/log/syslog
sudo systemctl reset-failed jellyfin && sudo systemctl start jellyfin
```
不必重启整机。

## 2. 遥控器先没反应、过后一次性冲出很多次 / Delayed then bursty keys

**现象**：连按“下”前两次没反应，第三次一下子跳很多格；按住音量减，音量瞬间降到 0。

**根因**：
- 遥控器空闲后自己断开；再次按键时，BLE 重连偶尔失败几次（HCI `0x3e Connection Failed to be
  Established`），几秒后才连上，遥控器会把期间缓存的按键一次性补发。
- 按住某个键时，如果“松开”报文在 BLE 链路上延迟，内核或 X 的自动重复会一直触发，
  于是音量瞬间降到 0。

**处理（`htpc-remote` 已包含）**：
- 忽略内核自动重复，由守护进程自己生成**慢速且有上限**的重复：
  方向键 0.4 s 后每 0.15 s 一次、最长 8 s；左右快进 0.5 s 后每 0.25 s 一次、最长 30 s；
  音量 0.4 s 后每 0.2 s 一次、最长 4 s。
- 去抖：距离上一次按键边沿不到 35 ms 的按下直接丢弃，不补发积压。
- 其余按键都在按下时立刻发送一次完整的按下和松开，不会出现“卡住一直按着”的状态。

重连失败本身通常和蓝牙芯片固件或无线信号有关，只能缩短影响，不能完全消除。

## 3. 按音量键时弹出屏幕键盘 / On-screen keyboard pops up

GNOME 辅助功能里的屏幕键盘被打开了，关闭它：
```bash
gsettings set org.gnome.desktop.a11y.applications screen-keyboard-enabled false
```

## 4. YouTube 每 7 天要重新登录 / YouTube login expires every 7 days

Google 对“测试中（Testing）”状态的 OAuth 应用只签发 **7 天有效**的刷新令牌，
到期后插件会报 `invalid_grant: Token has been expired or revoked`。
在 Google Cloud 控制台把该应用的发布状态改为 **正式版（In production）**，再重新登录一次即可。
参见 Google 文档 *OAuth 2.0 → Refresh token expiration*。
