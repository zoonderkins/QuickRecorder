# 更新日誌

## [未發布] - 2024-12-23

### 新增功能

#### 麥克風靜音切換（來自 PR #220）
- 錄影時可切換麥克風靜音/取消靜音
- 在狀態列控制器加入麥克風按鈕
- 支援快捷鍵設定（設定 > Hotkey > Toggle Microphone Mute）
- 靜音時會輸出靜音音訊以保持音軌同步

#### Debug Log 功能
- 在 Help 選單加入「View Debug Log」選項
- 可查看錄影過程的診斷資訊
- Log 檔案位置：`/tmp/qr-debug.log`

### 修復

#### 錄影 Session 狀態追蹤
- 新增 `sessionStarted` 狀態變數追蹤 AVAssetWriter session
- 如果錄影開始後立即停止（尚未收到任何 frame），顯示「Recording Cancelled」通知
- 避免產生無法播放的損壞檔案

### 已知問題

#### Fragmented MP4（已停用）
- `movieFragmentInterval` 功能已停用
- 原因：與 VideoToolbox 編碼器不相容，會導致錯誤 -16341
- 目前錄影如果異常終止（App 崩潰），檔案可能損壞
- 正常停止錄影不受影響

**修改的檔案：**

| 檔案 | 修改內容 |
|------|----------|
| `SCContext.swift` | 新增 `sessionStarted`、`isMicMuted`、`debugLog()` 函數 |
| `RecordEngine.swift` | 麥克風靜音處理、debug log |
| `QuickRecorderApp.swift` | Help 選單加入 Debug Log、麥克風靜音快捷鍵 |
| `SettingsView.swift` | 麥克風靜音快捷鍵設定 UI |
| `StatusBar.swift` | 麥克風靜音按鈕 |
