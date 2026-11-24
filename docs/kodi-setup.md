# Kodi 适老化设置 / Kodi setup

这些步骤需要在 Kodi 里手动做一次（或用你自己的配置管理同步）。

## 键位 / Keymap

把 `kodi/keymaps/remote.xml` 复制到 Kodi 用户目录：

```bash
cp kodi/keymaps/remote.xml ~/.kodi/userdata/keymaps/
```

在 Kodi 里执行 `Action(reloadkeymaps)` 或重启 Kodi 生效。该键位的设计原则是**每个键只做一件事、没有长按**：

| 按键 | 浏览菜单 | 播放中 |
|------|----------|--------|
| 方向键 | 移动 | 左右=±10 秒（按住连续快退/快进），上下=无 |
| OK | 打开/播放 | 暂停/继续 |
| 返回 | 上一级 | 停止并回到列表 |
| 主页 | 回主页 | — |
| 菜单 | 右键菜单 | 播放控制条（字幕/音轨） |
| 语音键 | 播放/暂停 | 播放/暂停 |

> 注意：Kodi 的 keymap 一旦给某个键设了 `mod="longpress"`，按住时就不会自动重复。连续快退/快进因此改由 `htpc-remote` 守护进程每 0.25 秒补一次按键实现。

## 推荐的播放设置 / Recommended settings

- 固定快进步长：`videoplayer.seeksteps = [-10, 10]`，`videoplayer.seekdelay = 0`
- 看一半自动续播、不弹窗：`myvideos.selectaction = 继续播放 (2)`
- 关闭自动播放下一集（如用 Up Next 插件则禁用它）

这些可在 设置 → 播放器 里改，或用 `Settings.SetSettingValue` 通过 JSON-RPC 设置。

## 列表显示封面 / Thumbnail views

把 `videonavtvshows / videonavseasons / videonavepisodes / videonavtitles`
的视图设成皮肤的 "Wall"（Estuary 为 ID 500，`guisettings.xml` 里的 `viewmode` 值为 `131572`）。
插件（如 YouTube）的页面请一起安装 `service.htpc.youtubeview` 服务，见下。
