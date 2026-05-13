# Pilo 音效资产

v1 用 macOS 系统内置音占位（`Blow` / `Glass` / `Submarine` / `Pop`）。要换成真 postal 音：

## 把 `.caf` 文件丢这里

文件名必须**精确匹配** `PiloSounds` enum 的 `rawValue`：

| 文件名 | 触发场景 | 推荐音色 |
|---|---|---|
| `pushSuccess.caf` | 推送成功 | 信件起飞 / 邮戳印章 |
| `letterArrived.caf` | 每日 18:00 信件投递 | 鸽子轻咕一声 |
| `updateArrived.caf` | 「新版已发车」推送 | 邮局柜台铃叮 |
| `waxSealCrack.caf` | 打开 release/update 蜡封信 | 蜡封碎裂 |

`SoundPlayer` 启动时先在 bundle 找 `.caf`，找不到才 fallback 到系统音。

## 推荐音源（CC0 / 免费商用）

- [Pixabay Sound Effects](https://pixabay.com/sound-effects/) —— 完全免费、无需署名、商用 OK（搜 "pigeon coo" / "envelope whoosh" / "wax seal" / "shop bell"）
- [Freesound.org](https://freesound.org/) —— 需注册；过滤 CC0
- [Mixkit](https://mixkit.co/free-sound-effects/) —— Mixkit License（免费商用，无需署名）

## 文件规格建议

- 格式：`.caf`（Apple 原生，无损，体积小）—— 也接受 `.m4a` / `.aiff` 但需改 PiloSounds.loadSound 的 extension
- 时长：**0.2 - 0.6 秒**（再长会打断用户节奏）
- 采样率：44.1 kHz / 48 kHz
- 单声道（mono）—— 比 stereo 体积小一半，听感无差
- 峰值音量：建议 -6 dB 留 headroom，避免某些 Mac 上爆音

## 转换命令

```bash
# 把任意音频文件转 .caf
afconvert input.mp3 -d ima4 -f caff output.caf

# 或者用 ffmpeg
ffmpeg -i input.mp3 -c:a pcm_s16le -ac 1 output.caf
```

## 测试

放好文件后：
1. `xcodegen && xcodebuild build`
2. Pilo Settings → 通用 → 「邮局音效」打开 —— 会立刻播一次 `letterArrived` 预览
3. 跑各场景（推送 / 等到 18:00 / 用 dummy updates.json 触发 update push）听效果
