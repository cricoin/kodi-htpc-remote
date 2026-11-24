# YouTube on Kodi（可选）/ YouTube add-on (optional)

`kodi/addons/service.htpc.youtubeview` 是一个很轻量的服务插件：Kodi 会按“文件夹路径”
分别记忆视图，于是每个 YouTube 频道/搜索页都会退回皮肤默认的列表视图。这个服务只在
打开 YouTube 的视频列表时，把视图切成 "Wall"（封面网格），其它页面不受影响。

安装：

```bash
cp -r kodi/addons/service.htpc.youtubeview ~/.kodi/addons/
# 在 Kodi 里：设置 → 插件 → 我的插件 → 服务，启用 "HTPC YouTube 封面视图"
```

## 关于官方 YouTube 插件 / The official add-on

本仓库不包含官方 `plugin.video.youtube`，请从 Kodi 官方插件库安装。两个常见坑：

1. **旧版 Kodi（如 21 nightly）会优先加载系统自带的旧 `requests`**，导致插件报
   `ImportError: cannot import name 'InvalidJSONError'`。
   解决：让 Kodi 优先用它自带的 requests（`htpc-autostart-kodi` 已设置
   `PYTHONPATH=~/.kodi/addons/script.module.requests/lib`），或升级到正式版 Kodi。

2. **部分 nightly 不保存插件用 Python 写入的设置**，导致安装向导反复弹出。
   解决：停掉 Kodi 后直接写 `~/.kodi/userdata/addon_data/plugin.video.youtube/settings.xml`，
   例如把 `kodion.setup_wizard` 设为 `false`、`kodion.setup_wizard.forced_runs` 设为插件要求的时间戳。

要用自己的 API 配额，需在 Google Cloud 建 **“电视和受限输入设备”** 类型的 OAuth 客户端，
再加上一个 API Key，填进插件的 `api_keys.json` 或插件设置页。**不要把这些密钥提交到仓库。**
