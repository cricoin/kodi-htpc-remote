# 语音键：音频流与未来玩法 / Voice key: audio streaming & future ideas

这只遥控器的语音键不只是一个普通按键。**长按语音键时，遥控器会自己把麦克风音频通过
蓝牙 HID 推流上来**。本项目目前只把语音键当作“播放/暂停”，并抑制长按时产生的杂乱上报；
但底层的音频流是真实可用的，为以后的扩展留了空间。

> The voice key streams microphone audio over Bluetooth HID while held. This project
> currently maps it to play/pause only, but the raw audio stream works and opens the
> door to voice-driven features.

## 技术细节 / How the audio stream works

抓包观察到的结构（具体数值可能因固件而异）：

- 长按语音键时，遥控器通过 **HID report ID 1** 持续上报，每帧 **60 字节**。
- 每帧里是一段 **mSBC**（宽带 SBC）数据：同步字节 `0xAD` 在第 3 个字节，有效载荷约为
  `frame[2:59]`。
- 把这些帧拼成裸码流后，可用 ffmpeg 解码成 16 kHz 单声道 WAV：

  ```bash
  ffmpeg -f sbc -i voice.msbc -ar 16000 -ac 1 voice.wav
  ```

- 丢帧与 **BLE 连接间隔**强相关：默认间隔下丢帧明显；把连接间隔压到约
  **7.5–11.25 ms**（BlueZ `/etc/bluetooth/main.conf` 的 `[LE] MinConnectionInterval` /
  `MaxConnectionInterval`）后，帧到达率可达 ~98%，语音清晰可懂。

> 本仓库不包含抓包/解码脚本，这里只记录原理，便于后来者自行实现。

## 可以做成什么 / Possible extensions

拿到清晰的 16 kHz 音频后，接上一个 ASR（语音识别）就能解锁很多玩法：

- **语音指令控制 Kodi**：如“播放汪汪队第三季”“快进两分钟”“回主页”，
  识别出意图后走 Kodi JSON-RPC。
- **语音问答/聊天**：把音频送到在线或本地的语音助手，用扬声器播报回答
  （类似电视遥控器上的“小爱同学”）。
- **Vibe coding / 语音写代码**：按住说话，转写后交给编码代理执行。
- **Typeless 式语音输入**：在需要输入文字的地方（搜索框等）按住说话直接转写上屏，
  省去用方向键在屏幕键盘上逐字选的麻烦。

### 大致做法 / Sketch

1. 一个常驻进程读取遥控器 `hidraw`，在语音键按下时收集 report ID 1 的帧。
2. 松开后拼帧、用 ffmpeg 解成 WAV。
3. 送入 ASR（本地如 whisper.cpp / sherpa-onnx，或在线 ASR）。
4. 按用途分流：Kodi 控制走 JSON-RPC；问答走助手并用 TTS 播报；输入走 `uinput` 打字。

这些都还没有实现，欢迎有兴趣的人在此基础上扩展。
