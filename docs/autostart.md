# 开机免密自启与电源策略 / Autostart & power policy

目标：通电即进入 Kodi，闲置后锁屏息屏，遥控器任意键免密唤醒，且永不休眠。

## 自动登录 / Auto-login (GDM)

`/etc/gdm3/custom.conf`：

```ini
[daemon]
AutomaticLoginEnable=True
AutomaticLogin=你的用户名
```

其他显示管理器（LightDM/SDDM）用各自的自动登录配置。

## 启动 Kodi / Launch Kodi

`install.sh` 会在 `~/.config/autostart/kodi.desktop` 放一个自启动项，执行
`~/.local/bin/htpc-autostart-kodi`。该脚本是一个守护循环：Kodi 退出后几秒内自动重开，
所以即使误选“退出”也会自动恢复。

## 闲置锁屏 + 息屏 / Idle lock & screen off

GNOME（用 `gsettings`，以桌面用户执行）：

```bash
gsettings set org.gnome.desktop.session idle-delay 'uint32 60'      # 60 秒后息屏
gsettings set org.gnome.desktop.screensaver lock-enabled true
gsettings set org.gnome.desktop.screensaver lock-delay 'uint32 0'
```

## 永不休眠 / Never sleep

```bash
sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
# 合盖不休眠（笔记本）：/etc/systemd/logind.conf
#   HandleLidSwitch=ignore
#   HandleLidSwitchExternalPower=ignore
```

把电源键也交给我们处理（见 udev hwdb：power -> KEY_SCREENLOCK），
这样按电源键是锁屏而不是系统挂起。

## 唤醒无密码 / Password-less wake

锁屏时按遥控器任意键，`htpc-remote` 会调用 `htpc-power-key`：
`xset dpms force on` → `loginctl unlock-session` → 回到 Kodi。
整个过程不需要输入密码，符合长辈对“电视开关机”的预期。

> 安全提示：这套设计假设机器在家庭内网、物理可信环境中使用。它刻意做到任意键免密解锁，
> 不适合对安全性有要求的场景。
