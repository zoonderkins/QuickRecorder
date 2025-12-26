# CLAUDE.md (繁體中文版)

此檔案為 Claude Code (claude.ai/code) 在此程式碼庫中工作時提供指引。

## 專案概述

QuickRecorder 是一個使用 SwiftUI 建構的輕量級、高效能 macOS 螢幕錄製工具。支援錄製螢幕、視窗、應用程式、行動裝置和系統音訊，具備音訊回送錄製、滑鼠高亮、螢幕放大鏡和 HDR 影片擷取等功能。

**核心技術：**
- SwiftUI 使用者介面
- ScreenCaptureKit (SCStreamKit) 螢幕錄製
- AVFoundation 影片編碼與相機擷取
- VideoToolbox 硬體加速編碼

**系統需求：** macOS 12.3 以上

## 建置指令

由於這是 Xcode 專案，沒有命令列建置腳本，必須透過 Xcode 建置：

1. 在 Xcode 中開啟 `QuickRecorder.xcodeproj`
2. 建置：`Cmd+B`
3. 執行：`Cmd+R`

**注意：** 需要 Xcode（而非僅命令列工具）才能建置此專案。

## 相依套件

此專案使用 Swift Package Manager，包含以下相依套件：

- **Sparkle** (2.6.0+)：自動更新框架
- **KeyboardShortcuts** (2.2.4+)：全域鍵盤快捷鍵處理
- **SwiftLAME**：MP3 編碼支援
- **AECAudioStream**：音訊回音消除 (AEC) 支援
- **MatrixColorSelector**：自訂顏色選擇器 UI

相依套件透過 Xcode 的 Swift Package Manager 整合管理，開啟專案時會自動取得。

## 架構

### 核心元件

**錄製引擎 (`RecordEngine.swift`)：**
- 入口點：`prepRecord(type:screens:windows:applications:fastStart:)`
- 根據錄製類型（螢幕/視窗/應用程式/區域/音訊）設定 `SCContentFilter`
- 設定 `SCStreamConfiguration`，包含解析度、幀率、編解碼器設定
- 管理系統和麥克風的音訊錄製
- 透過 `SCStreamDelegate` 和 `SCStreamOutput` 處理主要錄製迴圈

**螢幕擷取上下文 (`SCContext.swift`)：**
- 錄製會話的集中式狀態管理
- 管理 `SCStream`、`AVAssetWriter` 和音訊引擎
- 關鍵方法：
  - `updateAvailableContent()`：重新整理可用的顯示器/視窗/應用程式
  - `stopRecording()`：清理和檔案完成處理
  - `pauseRecording()`：使用時間戳管理切換暫停/繼續
  - `mixAudioTracks()`：合併獨立的麥克風和系統音訊軌道

**AV 上下文 (`AVContext.swift`)：**
- 簡報者模式的相機覆蓋錄製
- 透過 AVCaptureSession 錄製行動裝置 (iDevice)
- 管理裝置錄製的 `AVCaptureMovieFileOutput`

**應用程式委派 (`QuickRecorderApp.swift`)：**
- SwiftUI 應用程式生命週期管理
- 全域狀態（視窗、權限、設定）
- 鍵盤快捷鍵註冊
- 滑鼠游標和螢幕放大鏡覆蓋
- 使用 Sparkle 更新器進行版本檢查

### 視圖模型 (ViewModel/)

UI 元件按功能組織：
- `ContentView.swift`：主錄製面板
- `SettingsView.swift`：偏好設定/設定 UI
- `StatusBar.swift`：選單列狀態顯示
- `AreaSelector.swift`：區域錄製的範圍選擇
- `ScreenSelector.swift`、`WinSelector.swift`、`AppSelector.swift`：擷取目標選擇器
- `CameraOverlayer.swift`：macOS 12/13 的相機覆蓋視窗
- `QmaPlayer.swift`：多軌音訊 (.qma) 播放器/編輯器
- `VideoEditor.swift`：錄製後修剪介面

### 錄製流程

1. 使用者選擇錄製目標（螢幕/視窗/應用程式/區域）
2. `prepRecord()` 建立 `SCContentFilter`，包含：
   - 包含/排除的視窗和應用程式
   - 背景處理（桌布/純色/透明）
   - 桌面檔案可見性、選單列包含設定
3. `record()` 設定 `SCStreamConfiguration`：
   - 解析度（透過 `highRes` 設定進行 Retina 縮放）
   - 幀率（預設 60fps，可設定）
   - 編解碼器（H.264/H.265/HEVC with Alpha）
   - 音訊設定（取樣率、聲道數）
4. `SCStream` 啟動，將幀委派給 `stream(_:didOutputSampleBuffer:of:)`
5. 影片幀 → `AVAssetWriterInput` (vwInput)
6. 系統音訊 → `AVAssetWriterInput` (awInput)
7. 麥克風 → 獨立的 `AVAssetWriterInput` (micInput)
8. 停止時：完成寫入器、選擇性混合音訊軌道、顯示預覽

### 特殊功能

**簡報者覆蓋 (macOS 14+)：**
- 使用 ScreenCaptureKit 的內建簡報者覆蓋 API
- 透過 `presenterOverlayContentRect` 附件偵測覆蓋狀態變更
- 實作安全延遲 (`poSafeDelay`) 以避免擷取轉場幀

**音訊回音消除：**
- 透過 `AECAudioStream` 函式庫提供選用的 AEC
- 處理麥克風輸入以移除系統音訊干擾
- 可設定的閃避等級（最小/中等/最大）

**HDR 錄製 (macOS 15+)：**
- 使用 `SCStreamConfiguration.captureHDRStreamLocalDisplay` 預設
- 在 BT.2100 PQ 色彩空間中擷取
- 匯出螢幕截圖時使用 +1 EV 調整以獲得正確亮度

**多軌音訊 (.qma)：**
- 用於獨立系統/麥克風音訊軌道的自訂封裝格式
- 包含 `info.json`，含有格式中繼資料和音量設定
- 允許在 `QmaPlayer` 中獨立混音

**暫停/繼續：**
- 跨暫停期間追蹤累積時間偏移 (`timeOffset`)
- 透過 `adjustTime(sample:by:)` 調整 CMTime 時間戳以保持連續性

## 重要檔案路徑

- **主要原始碼：** `QuickRecorder/`
  - 核心：`QuickRecorderApp.swift`、`RecordEngine.swift`、`SCContext.swift`、`AVContext.swift`
  - 視圖：`ViewModel/*.swift`
  - 工具程式：`Supports/*.swift`
- **權限設定：** `QuickRecorder/QuickRecorder.entitlements`（相機、麥克風存取）
- **本地化：** `Base.lproj/`、`zh-Hans.lproj/`、`zh-Hant.lproj/`、`it.lproj/`
- **資源：** `QuickRecorder/Assets.xcassets/`

## 常用設定 (@AppStorage 鍵值)

設定透過 `@AppStorage` 包裝器儲存在 UserDefaults 中：
- `encoder`：影片編解碼器 (h264/h265)
- `videoFormat`：容器格式 (mp4/mov)
- `audioFormat`：音訊編解碼器 (aac/alac/flac/opus/mp3)
- `frameRate`：錄製幀率（預設：60）
- `videoQuality`：品質倍數 (0.3/0.7/1.0)
- `highRes`：Retina 縮放（2 = retina，1 = 非 retina）
- `recordWinSound`：擷取系統音訊
- `recordMic`：擷取麥克風
- `remuxAudio`：將麥克風+系統合併為單一軌道
- `highlightMouse`：顯示滑鼠高亮覆蓋
- `showMouse`：在錄製中包含游標
- `background`：視窗錄製背景（桌布/透明/純色）
- `saveDirectory`：輸出資料夾路徑

## macOS 版本處理

程式碼庫針對多個 macOS 版本，使用條件編譯：
- `isMacOS12`、`isMacOS14`、`isMacOS15`：全域版本旗標
- `@available(macOS 14.0, *)`：簡報者覆蓋、`filter.pointPixelScale`
- `@available(macOS 15, *)`：HDR 錄製預設
- `#if compiler(>=6.0)`：Swift 6 特定功能

新增功能時，請檢查版本可用性並為舊版 macOS 提供後備方案。

## 權限

QuickRecorder 需要多項系統權限：
- **螢幕錄製**：ScreenCaptureKit 的主要權限（首次執行時請求）
- **麥克風**：啟用 `recordMic` 時需要
- **相機**：相機覆蓋或裝置錄製時需要

權限檢查位於 `SCContext.swift`：
- `requestPermissions()`：螢幕錄製（拒絕時顯示警告）
- `performMicCheck()`：麥克風（非同步檢查）
- `requestCameraPermission()`：相機存取

## 已知限制

- 非沙盒應用程式（無計畫發布至 App Store）
- H.264 硬體編碼器有解析度限制（不支援時會提示切換至 H.265）
- macOS 12 不支援：系統音訊擷取 (`recordWinSound`)、預覽視窗
- 某些功能（簡報者覆蓋、HDR）需要較新的 macOS 版本
