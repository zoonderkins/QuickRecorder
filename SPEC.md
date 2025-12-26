# QuickRecorder 技術規格文件

**版本：** 1.0
**最後更新：** 2025-10-23
**目標平台：** macOS 12.3+

---

## 1. 系統架構

### 1.1 整體架構圖

```
┌─────────────────────────────────────────────────────────┐
│                    QuickRecorderApp                      │
│                   (SwiftUI App Entry)                    │
└────────────┬────────────────────────────┬────────────────┘
             │                            │
    ┌────────▼────────┐          ┌───────▼────────┐
    │   AppDelegate   │          │  View Models   │
    │  (Coordinator)  │          │   (UI Layer)   │
    └────────┬────────┘          └────────────────┘
             │
    ┌────────▼────────────────────────────────────┐
    │         Recording Engine Layer              │
    ├─────────────────┬───────────────────────────┤
    │ RecordEngine    │ SCContext  │ AVContext    │
    │ (Main Logic)    │ (State)    │ (Camera/iOS) │
    └─────────────────┴────────────┴──────────────┘
             │
    ┌────────▼────────────────────────────────────┐
    │           macOS Frameworks                  │
    ├─────────────────┬───────────────────────────┤
    │ ScreenCaptureKit│ AVFoundation│VideoToolbox │
    └─────────────────┴─────────────┴─────────────┘
```

### 1.2 主要模組職責

#### 1.2.1 QuickRecorderApp.swift
- **角色：** 應用程式生命週期管理
- **職責：**
  - 初始化 Sparkle 自動更新器
  - 管理 DocumentGroup（.qma 檔案類型）
  - 設定視窗配置

#### 1.2.2 AppDelegate
- **角色：** 全域協調器
- **職責：**
  - 啟動時權限檢查 (`applicationWillFinishLaunching`)
  - 註冊全域鍵盤快捷鍵 (KeyboardShortcuts)
  - 管理浮動視窗（滑鼠游標、放大鏡、相機覆蓋）
  - 全域滑鼠監控 (`NSEvent.addGlobalMonitorForEvents`)
  - SCStream 委派實作
  - 狀態列管理

#### 1.2.3 RecordEngine.swift
- **角色：** 錄製邏輯實作
- **職責：**
  - `prepRecord()`：初始化錄製參數
  - 建構 `SCContentFilter`（包含/排除規則）
  - 設定 `SCStreamConfiguration`（解析度、幀率、編解碼器）
  - 音訊錄製設定（系統音訊、麥克風）
  - 處理簡報者覆蓋事件
  - 實作 `stream(_:didOutputSampleBuffer:of:)` 處理幀資料

#### 1.2.4 SCContext.swift
- **角色：** 狀態管理與工具函式
- **職責：**
  - 維護錄製狀態（isPaused、startTime、filePath）
  - 管理 AVAssetWriter 和輸入串流
  - 檔案路徑生成與管理
  - 權限請求介面
  - 音訊軌道混合 (`mixAudioTracks`)
  - 暫停/繼續時間戳調整 (`adjustTime`)
  - 裝置枚舉（顯示器、視窗、應用程式、相機）

#### 1.2.5 AVContext.swift
- **角色：** AVFoundation 整合
- **職責：**
  - 相機覆蓋模式（macOS 12/13 後備方案）
  - iDevice 錄製（透過 AVCaptureSession）
  - AVCaptureMovieFileOutput 管理

---

## 2. 錄製類型與實作

### 2.1 支援的錄製類型

| StreamType        | 描述                 | Filter 類型                        |
|-------------------|----------------------|------------------------------------|
| `.screen`         | 全螢幕錄製           | `SCContentFilter(display:excludingApplications:exceptingWindows:)` |
| `.window`         | 單一視窗             | `SCContentFilter(desktopIndependentWindow:)` |
| `.windows`        | 多視窗               | `SCContentFilter(display:including:)` |
| `.application`    | 應用程式所有視窗     | `SCContentFilter(display:including:exceptingWindows:)` |
| `.screenarea`     | 螢幕區域             | 使用 `conf.sourceRect` 裁切 |
| `.systemaudio`    | 僅系統音訊           | 空 filter，僅音訊輸出 |
| `.idevice`        | iOS/iPadOS 裝置      | AVCaptureSession (非 SCStream) |
| `.camera`         | 相機覆蓋預覽         | AVCaptureSession |

### 2.2 Filter 建構邏輯

**排除規則：**
- hideSelf = true：排除 QuickRecorder 自身視窗
- hideCCenter = true：排除控制中心
- hideDesktopFiles = true：排除 Finder 桌面圖示視窗
- 使用者自訂黑名單應用程式

**包含規則：**
- 視窗錄製：選定視窗 + 滑鼠游標視窗（如啟用）
- 應用程式錄製：應用程式視窗 + Dock（如背景為桌布）

**背景處理：**
- `wallpaper`：包含 Dock 的桌布視窗
- `clear`/`black`/`white` 等：設定 `conf.backgroundColor`

---

## 3. 影片編碼規格

### 3.1 編解碼器選擇

```swift
enum Encoder: String {
    case h264  // AVVideoCodecType.h264
    case h265  // AVVideoCodecType.hevc 或 hevcWithAlpha
}
```

**決策邏輯：**
1. 使用者選擇 H.264 時：
   - 檢查 `VTCompressionSession` 是否支援目前解析度
   - 不支援時提示切換至 H.265
2. 使用者選擇 H.265 或啟用 HDR：
   - 使用 HEVC
   - 若 `withAlpha = true` 且非 HDR：使用 `hevcWithAlpha`

### 3.2 解析度與縮放

**Retina 支援：**
```swift
let scale = (highRes == 2) ? pointPixelScale : 1
conf.width = Int(contentRect.width) * scale
conf.height = Int(contentRect.height) * scale
```

- `highRes = 2`：Retina 解析度（2x）
- `highRes = 1`：標準解析度

**macOS 版本差異：**
- macOS 14+：使用 `filter.pointPixelScale`
- macOS 13 以下：使用 `NSScreen.backingScaleFactor`

### 3.3 位元率計算

```swift
let fpsMultiplier = Double(frameRate) / 8
let encoderMultiplier = encoderIsH265 ? 0.5 : 0.9
let resolution = Double(max(600, width)) * Double(max(600, height))
var qualityMultiplier = 1 - (log10(sqrt(resolution) * fpsMultiplier) / 5)

// 根據使用者選擇的品質調整
switch videoQuality {
    case 0.3: qualityMultiplier = max(0.1, qualityMultiplier)
    case 0.7: qualityMultiplier = max(0.4, min(0.6, qualityMultiplier * 3))
    default: qualityMultiplier = 1.0
}

let targetBitrate = resolution * fpsMultiplier * encoderMultiplier * qualityMultiplier * (recordHDR ? 2 : 1)
```

### 3.4 幀率處理

```swift
conf.minimumFrameInterval = CMTime(
    value: 1,
    timescale: audioOnly ? CMTimeScale.max : (frameRate >= 60 ? 0 : CMTimeScale(frameRate))
)
```

- `timescale = 0`：無節流，使用最大支援幀率（60fps+）
- `timescale = frameRate`：限制為指定幀率（<60fps）
- 音訊模式：`CMTimeScale.max`（不限制）

---

## 4. 音訊處理

### 4.1 音訊架構

```
系統音訊 ────┐
             ├──> AVAssetWriter ──> 影片檔案
麥克風 ──────┘   (3個 AVAssetWriterInput)

選項1：合併到主軌 (remuxAudio = true)
選項2：分離軌道 (remuxAudio = false)
```

### 4.2 音訊格式與設定

**支援格式：**
- AAC (M4A)：`kAudioFormatMPEG4AAC`
- ALAC (M4A)：`kAudioFormatAppleLossless`
- FLAC (CAF)：`kAudioFormatFLAC`
- Opus (OGG/CAF)：`kAudioFormatOpus`
- MP3：先編碼為 AAC，後用 SwiftLAME 轉換

**取樣率：**
- 系統音訊：48000 Hz（固定）
- 麥克風：從裝置取得實際取樣率 (`getSampleRate()`)

**位元率：**
```swift
var bitRate = audioQuality * 1000  // 128k/192k/256k/320k
if sampleRate < 44100 {
    bitRate = min(64000, bitRate / 2)
}
```

### 4.3 麥克風錄製模式

**模式 1：預設裝置（default）**
- 啟用 AEC：使用 `AECAudioStream`
  - 可設定閃避等級（min/mid/max）
  - 即時消除系統音訊回授
- 停用 AEC：使用 `AVAudioEngine.inputNode`

**模式 2：特定裝置（非 default）**
- 使用 `AVCaptureDeviceInput`
- 建立獨立 `AVCaptureSession`
- 透過 `AudioRecorder.shared` 管理

### 4.4 多軌混音流程

**情境：** `recordMic = true && recordWinSound = true && remuxAudio = true`

1. 錄製產生檔案：`output.mov.mov.mov`（三層副檔名）
   - 影片軌：1 軌
   - 音訊軌：2 軌（系統、麥克風）

2. `mixAudioTracks()` 執行步驟：
   ```
   a) 建立 AVMutableComposition，合併兩音訊軌
   b) 匯出純音訊檔案：output.mov.mov
   c) 建立新 composition：影片 + 合併後音訊
   d) 使用 AVAssetExportSession 匯出：output.mov
   e) 刪除臨時檔案
   ```

---

## 5. 特殊功能實作

### 5.1 簡報者覆蓋 (Presenter Overlay)

**支援版本：** macOS 14.2+

**工作原理：**
1. ScreenCaptureKit 提供原生簡報者覆蓋 API
2. 透過 `SCStreamFrameInfo.presenterOverlayContentRect` 偵測狀態
3. 三種狀態：
   - `OFF`：X = .infinity
   - `Small`：X = 0.0
   - `Big`：X ≠ 0 且 ≠ .infinity

**安全機制：**
```swift
if isPresenterON && !isCameraReady { break }  // 跳過幀
```
- `poSafeDelay` 延遲（預設 1 秒）避免擷取轉場動畫
- 狀態變更時重設 `isCameraReady = false`

**後備方案（macOS 12/13）：**
- 使用 `camWindow` 浮動視窗
- 手動放置相機畫面
- 使用 `AVCaptureSession` 預覽

### 5.2 HDR 錄製

**支援版本：** macOS 15+，需要 Swift 6 編譯器

**設定：**
```swift
#if compiler(>=6.0)
if recordHDR {
    if #available(macOS 15, *) {
        conf = SCStreamConfiguration(preset: .captureHDRStreamLocalDisplay)
    }
}
#endif
```

**色彩空間：**
- 使用 `CGColorSpace.itur_2100_PQ`（BT.2100 PQ）
- 不設定 `pixelFormat`（使用預設）
- `queueDepth = 8`（建議 4-8 之間）

**截圖處理：**
```swift
// 曝光補償 +1 EV
ciImage = ciImage.applyingFilter("CIExposureAdjust", parameters: ["inputEV": 1.0])
// 匯出 RGB10 PNG (macOS 14+)
try context.writePNGRepresentation(of: ciImage, to: url, format: .RGB10, colorSpace: colorSpace)
```

### 5.3 滑鼠高亮

**實作層級：** 浮動視窗覆蓋

```swift
// 全域滑鼠監控
mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDown, ...]) { event in
    self.mousePointerReLocation(event: event)
}
```

**視窗設定：**
- `level = .screenSaver`（最高層級）
- `ignoresMouseEvents = true`
- `backgroundColor = .clear`

**繪製：**
- `MousePointerView`：根據事件繪製同心圓動畫
- 視窗跟隨滑鼠座標

### 5.4 螢幕放大鏡

**觸發：** `KeyboardShortcuts.screenMagnifier` 或設定開關

**工作原理：**
1. 使用 `NSImage.createScreenShot()` 擷取全螢幕
2. 裁切滑鼠周圍 134x116 像素區域
3. 在 `ScreenMagnifier` 視圖中放大顯示（3x 縮放）
4. 視窗大小：402x348 像素

### 5.5 暫停/繼續機制

**挑戰：** 保持時間軸連續性

**解決方案：**
```swift
// 恢復時計算時間偏移
if SCContext.isResume {
    var pts = CMSampleBufferGetPresentationTimeStamp(sample)
    let last = SCContext.lastPTS
    let off = CMTimeSubtract(pts, last)
    SCContext.timeOffset = CMTimeAdd(SCContext.timeOffset, off)
}

// 調整每個 sample 的時間戳
if timeOffset.value > 0 {
    sample = adjustTime(sample: sample, by: timeOffset)
}
```

**時間戳調整：**
- 累積所有暫停期間的時間
- 減去累積偏移以保持連續性
- 同時調整 `presentationTimeStamp` 和 `decodeTimeStamp`

---

## 6. 資料格式

### 6.1 .qma 格式（QuickRecorder Multi-Track Audio）

**結構：** 資料夾封裝（bundle）

```
Recording.qma/
├── info.json
├── sys.m4a      # 系統音訊
└── mic.m4a      # 麥克風音訊
```

**info.json 範例：**
```json
{
    "format": "m4a",
    "encoder": "aac",
    "exportMP3": false,
    "sysVol": 1.0,
    "micVol": 1.0
}
```

**用途：**
- 獨立編輯系統音訊和麥克風音量
- 在 `QmaPlayer` 中混音
- 匯出為單一音訊檔案

### 6.2 檔案命名規則

```swift
let dateFormatter = DateFormatter()
dateFormatter.dateFormat = "y-MM-dd HH.mm.ss"
let fileName = saveDirectory + "/Recording at " + dateFormatter.string(from: Date())
```

**擴充套用：**
- 一般影片：`Recording at 2024-04-16 14.30.00.mp4`
- 三軌檔案：`Recording at 2024-04-16 14.30.00.mp4.mp4.mp4`（臨時）
- 截圖：`Capturing at 2024-04-16 14.30.00.png`
- .qma：`Recording at 2024-04-16 14.30.00.qma/`

---

## 7. 權限管理

### 7.1 所需權限

| 權限類型         | Entitlement Key                       | 用途                    |
|------------------|---------------------------------------|-------------------------|
| 螢幕錄製         | N/A (系統偏好設定)                    | ScreenCaptureKit        |
| 麥克風           | `com.apple.security.device.audio-input` | 麥克風錄製            |
| 相機             | `com.apple.security.device.camera`    | 相機覆蓋、iDevice 錄製  |

### 7.2 權限檢查時機

**啟動時檢查：**
```swift
func applicationWillFinishLaunching(_ notification: Notification) {
    scPerm = SCContext.updateAvailableContentSync() != nil
    // ...
}
```

**錄製前檢查：**
```swift
func prepRecord(...) {
    Task { await SCContext.performMicCheck() }
}
```

**處理拒絕：**
- 螢幕錄製拒絕：顯示警告，開啟系統偏好設定
- 麥克風拒絕：自動停用 `recordMic`，顯示提示
- 相機拒絕：回傳失敗，顯示提示

---

## 8. 效能最佳化

### 8.1 幀處理優化

**跳幀機制：**
```swift
if frameQueue.getArray().contains(where: { $0 >= pts }) {
    print("Skip this frame")
    return
}
frameQueue.append(pts)  // FixedLengthArray(maxLength: 20)
```

**準備檢查：**
```swift
if vwInput.isReadyForMoreMediaData {
    vwInput.append(sampleBuffer)
}
```

### 8.2 記憶體管理

**自動釋放池：**
```swift
var nsImage: NSImage? {
    return autoreleasepool {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(self) else { return nil }
        // ...
    }
}
```

**檔案關閉：**
```swift
audioFile = nil  // 觸發 AVAudioFile 關閉
```

### 8.3 背景執行

**防止休眠：**
```swift
if preventSleep {
    SleepPreventer.shared.preventSleep(reason: "Screen recording in progress")
}
```

---

## 9. 錯誤處理

### 9.1 錄製錯誤

**SCStream 錯誤：**
```swift
func stream(_ stream: SCStream, didStopWithError error: Error) {
    // 可能原因：視窗關閉、使用者從 Sonoma UI 停止
    DispatchQueue.main.async {
        SCContext.stopRecording()
    }
}
```

**AVAssetWriter 錯誤：**
```swift
vW.finishWriting {
    if vW.status != .completed {
        showNotification(title: "Failed to save file", body: "\(vW.error?.localizedDescription ?? "Unknown Error")")
    }
}
```

### 9.2 編解碼器不支援

**H.264 硬體編碼檢查：**
```swift
let status = VTCompressionSessionCreate(
    width: width, height: height,
    codecType: kCMVideoCodecType_H264,
    encoderSpecification: [kVTVideoEncoderSpecification_RequireHardwareAcceleratedVideoEncoder: true],
    ...
)
if status != noErr {
    // 顯示警告，建議切換至 H.265
}
```

---

## 10. 測試建議

### 10.1 關鍵測試場景

1. **多顯示器環境**
   - 在不同 DPI 顯示器間切換
   - 跨顯示器視窗錄製

2. **長時間錄製**
   - 測試 2+ 小時錄製
   - 監控記憶體使用

3. **暫停/繼續**
   - 多次暫停後時間軸正確性
   - 音訊同步檢查

4. **特殊解析度**
   - 超寬螢幕 (21:9)
   - 垂直螢幕 (9:16)
   - 4K/5K 顯示器

5. **音訊邊界案例**
   - 僅系統音訊
   - 僅麥克風
   - 雙軌混音

### 10.2 版本相容性測試

- macOS 12.3：基礎功能（無系統音訊）
- macOS 13：系統音訊
- macOS 14：簡報者覆蓋、選單列包含
- macOS 15：HDR 錄製

---

## 11. 已知限制與未來改進

### 11.1 目前限制

1. **H.264 解析度限制**
   - 某些解析度無法使用硬體編碼
   - 軟體編碼 CPU 使用率高

2. **macOS 12 功能限制**
   - 無系統音訊擷取
   - 無預覽視窗

3. **非沙盒應用程式**
   - 無法發布至 App Store
   - 需要手動分發

### 11.2 潛在改進方向

1. **效能**
   - 使用 Metal 進行影片後處理
   - 更智慧的位元率調整

2. **功能**
   - 自訂浮水印
   - 即時標註工具
   - 多語言旁白錄製

3. **相容性**
   - 支援更多匯出格式（WebM、AV1）
   - 雲端儲存整合

---

## 12. 開發指南

### 12.1 新增錄製類型

1. 在 `StreamType` enum 新增類型
2. 在 `prepRecord()` 新增 case 處理
3. 實作 `SCContentFilter` 建構邏輯
4. 更新 UI 選擇器（`ViewModel/` 中對應檔案）
5. 測試所有 macOS 版本

### 12.2 新增音訊格式

1. 在 `AudioFormat` enum 新增格式
2. 在 `updateAudioSettings()` 新增格式設定
3. 更新 `prepareAudioRecording()` 檔案副檔名邏輯
4. 如需轉換，在 `stopRecording()` 新增處理
5. 更新 `SettingsView` UI

### 12.3 程式碼風格

- 使用 `@AppStorage` 進行設定持久化
- 全域狀態放在 `SCContext` 靜態屬性
- UI 相關放在 `ViewModel/`
- 工具函式放在 `Supports/`
- 本地化字串使用 `.local` 擴充套件

### 12.4 版本相容性模式

```swift
// 執行時檢查
if isMacOS14 { /* ... */ }

// 編譯時檢查
#if compiler(>=6.0)
// Swift 6+ 程式碼
#endif

// API 可用性
if #available(macOS 14.0, *) {
    // 使用新 API
} else {
    // 後備實作
}
```

---

**文件版本歷史：**
- 1.0 (2025-10-23)：初始版本，基於程式碼庫分析
