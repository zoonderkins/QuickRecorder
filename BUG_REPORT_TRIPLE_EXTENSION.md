# Bug 報告：三重副檔名問題 (.mp4.mp4.mp4)

**問題編號：** #001
**嚴重程度：** 中等
**狀態：** 已定位
**發現日期：** 2025-10-23

---

## 問題描述

當使用者選擇 MP4 格式，並且同時啟用以下三個設定時：
- `recordMic = true`（錄製麥克風）
- `recordWinSound = true`（錄製系統音訊）
- `remuxAudio = true`（將麥克風錄製到主音軌）

錄製完成後會產生奇怪的檔案名稱，例如：
```
Recording at 2024-04-16 14.30.00.mp4.mp4.mp4
```

## 根本原因分析

### 原因 1：刻意的三重副檔名設計

**位置：** `RecordEngine.swift:373-377`

```swift
if remuxAudio && recordMic && recordWinSound {
    SCContext.filePath = "\(SCContext.getFilePath()).\(fileEnding).\(fileEnding).\(fileEnding)"
} else {
    SCContext.filePath = "\(SCContext.getFilePath()).\(fileEnding)"
}
```

**設計意圖分析：**
這是**刻意的設計**，而非 bug。三重副檔名用作臨時檔案標記：

1. `getFilePath()` 返回基礎路徑：`"Recording at 2024-04-16 14.30.00"`
2. 第一個 `.mp4`：實際錄製的影片檔案（包含影片軌 + 2 個音訊軌）
3. 第二個 `.mp4`：標記需要進行音訊混合處理
4. 第三個 `.mp4`：標記最終輸出格式

**流程：**
```
初始錄製 → Recording.mp4.mp4.mp4
    ↓
mixAudioTracks() 處理
    ↓
最終輸出 → Recording.mp4
```

### 原因 2：檔案名稱操作邏輯

**位置：** `SCContext.swift:714-839` (`mixAudioTracks` 函式)

```swift
static func mixAudioTracks(videoURL: URL, completion: @escaping (Result<URL, Error>) -> Void) {
    let asset = AVAsset(url: videoURL)  // 輸入：Recording.mp4.mp4.mp4
    let audioOutputURL = videoURL.deletingPathExtension()  // → Recording.mp4.mp4
    let outputURL = audioOutputURL.deletingPathExtension() // → Recording.mp4
    // ...
}
```

**步驟拆解：**
1. **輸入檔案：** `Recording at 2024-04-16 14.30.00.mp4.mp4.mp4`
2. **第一次 deletingPathExtension()：** → `Recording at 2024-04-16 14.30.00.mp4.mp4`
   - 用於儲存純音訊合併結果（臨時檔）
3. **第二次 deletingPathExtension()：** → `Recording at 2024-04-16 14.30.00.mp4`
   - 最終影片檔案路徑
4. **清理臨時檔：** 刪除 `.mp4.mp4.mp4` 和 `.mp4.mp4`

## 問題所在

雖然設計邏輯是正確的，但存在以下問題：

### 問題 1：使用者可見的奇怪檔案名稱

**影響時機：**
- 錄製過程中，檔案系統顯示 `.mp4.mp4.mp4`
- 如果 `mixAudioTracks()` 失敗，臨時檔不會被清理
- 如果使用者在處理過程中瀏覽資料夾，會看到三個怪檔案

**使用者體驗問題：**
- 困惑：為什麼檔案有三個 .mp4？
- 擔心：是不是程式出錯了？
- 檔案管理：難以識別哪個是最終檔案

### 問題 2：錯誤處理不完整

**潛在失敗點：**

1. **`mixAudioTracks()` 未被呼叫的情況**
   - 條件：`vW.status != .completed`
   - 結果：保留 `.mp4.mp4.mp4` 檔案，不進行清理

2. **音訊匯出失敗**
   ```swift
   case .failed:
       completion(.failure(...))
       // 問題：沒有清理 .mp4.mp4.mp4 原始檔案
   ```

3. **影片匯出失敗**
   ```swift
   case .failed:
       completion(.failure(...))
       // 問題：保留 .mp4.mp4.mp4 和 .mp4.mp4 兩個臨時檔
   ```

### 問題 3：檔案命名不具語義性

**目前設計缺陷：**
- 使用副檔名數量作為狀態標記（隱性設計）
- 無法從檔名判斷處理狀態
- 與一般檔案命名慣例衝突

## 影響範圍

### 受影響的功能
- ✅ 影片錄製（開啟多軌混音時）
- ❌ 純音訊錄製（不受影響，使用 .qma 格式）
- ❌ 單軌錄製（不受影響，直接輸出正確檔名）
- ❌ iDevice 錄製（不受影響，使用 AVOutputClass）

### 受影響的使用情境
- `remuxAudio = true` && `recordMic = true` && `recordWinSound = true`
- 適用於所有影片格式（.mp4 和 .mov）

### 不受影響的情況
- 僅錄製系統音訊（無麥克風）
- 僅錄製麥克風（無系統音訊）
- `remuxAudio = false`（保持雙軌分離）

## 修復計劃

### 方案 A：使用臨時資料夾（建議）

**優點：**
- ✅ 使用者永不看到臨時檔案
- ✅ 易於清理（刪除整個臨時資料夾）
- ✅ 符合 macOS 最佳實踐
- ✅ 不改變現有邏輯流程

**實作步驟：**

1. **建立臨時檔案路徑**
   ```swift
   // RecordEngine.swift:373
   if remuxAudio && recordMic && recordWinSound {
       let tempDir = FileManager.default.temporaryDirectory
       let uniqueID = UUID().uuidString
       let tempPath = tempDir.appendingPathComponent("QuickRecorder_\(uniqueID)")
       try? FileManager.default.createDirectory(at: tempPath, withIntermediateDirectories: true)

       SCContext.filePath = tempPath.appendingPathComponent("recording.\(fileEnding)").path
       SCContext.finalOutputPath = "\(SCContext.getFilePath()).\(fileEnding)"
   } else {
       SCContext.filePath = "\(SCContext.getFilePath()).\(fileEnding)"
   }
   ```

2. **修改 mixAudioTracks()**
   ```swift
   // SCContext.swift:714
   static func mixAudioTracks(videoURL: URL, finalURL: URL, completion: ...) {
       // ... 處理邏輯 ...

       // 成功後移動到最終位置
       try? FileManager.default.moveItem(at: outputURL, to: finalURL)

       // 清理臨時資料夾
       if let tempDir = videoURL.deletingLastPathComponent() {
           try? FileManager.default.removeItem(at: tempDir)
       }
   }
   ```

3. **更新呼叫點**
   ```swift
   // SCContext.swift:364
   mixAudioTracks(videoURL: filePath.url, finalURL: finalOutputPath.url) { result in
       // ...
   }
   ```

**檔案變更：**
- `RecordEngine.swift`: initVideo() 函式
- `SCContext.swift`: mixAudioTracks() 函式與呼叫點
- `SCContext.swift`: 新增 `finalOutputPath` 靜態變數

**風險評估：** 低
- 現有功能不受影響
- 向後相容（不影響其他錄製模式）

### 方案 B：使用語義化檔案名稱

**優點：**
- ✅ 檔案名稱有意義
- ✅ 易於除錯

**缺點：**
- ❌ 仍會暴露臨時檔案給使用者
- ❌ 需要複雜的檔案名稱解析邏輯

**實作範例：**
```swift
// 不推薦
SCContext.filePath = "\(SCContext.getFilePath())_temp_multitrack.\(fileEnding)"
```

**建議：** 不採用此方案

### 方案 C：使用隱藏檔案（點開頭）

**優點：**
- ✅ 在 Finder 中預設隱藏
- ✅ 保持在同一資料夾

**缺點：**
- ❌ 進階使用者仍可見（顯示隱藏檔案時）
- ❌ 不符合 macOS 臨時檔案慣例

**實作範例：**
```swift
SCContext.filePath = "\(SCContext.getFilePath())/.recording_temp.\(fileEnding)"
```

**建議：** 次要選擇

## 推薦解決方案

**選擇：方案 A（使用臨時資料夾）**

**理由：**
1. 最符合 macOS 平台慣例
2. 完全隔離使用者可見檔案和臨時處理檔案
3. 清理邏輯簡單可靠
4. 修改範圍小，風險低

## 實作檢查清單

- [ ] 修改 `RecordEngine.swift:initVideo()` 建立臨時路徑
- [ ] 在 `SCContext.swift` 新增 `finalOutputPath` 變數
- [ ] 修改 `mixAudioTracks()` 函式簽章，接受 `finalURL` 參數
- [ ] 更新 `mixAudioTracks()` 內部邏輯：
  - [ ] 成功時移動檔案到最終路徑
  - [ ] 失敗時清理臨時資料夾
  - [ ] 取消時清理臨時資料夾
- [ ] 更新 `SCContext.swift:364` 的呼叫點
- [ ] 測試所有錄製模式：
  - [ ] 系統音訊 + 麥克風 + remux
  - [ ] 僅系統音訊
  - [ ] 僅麥克風
  - [ ] 雙軌分離模式
- [ ] 測試錯誤情境：
  - [ ] 錄製中途停止
  - [ ] 磁碟空間不足
  - [ ] 權限不足
- [ ] 驗證臨時檔案清理機制

## 額外建議

### 改進 1：新增進度回報

```swift
static func mixAudioTracks(..., progressHandler: ((Double) -> Void)? = nil) {
    // 在 exportAsynchronously 中定期回報進度
    progressHandler?(0.5)  // 音訊匯出完成 50%
    progressHandler?(1.0)  // 完成
}
```

### 改進 2：新增重試機制

```swift
// 如果第一次混音失敗，自動重試一次
if exportSession.status == .failed {
    if retryCount < 1 {
        retryCount += 1
        // 重試邏輯
    }
}
```

### 改進 3：啟動時清理舊臨時檔案

```swift
// QuickRecorderApp.swift: applicationWillFinishLaunching
func cleanupOldTempFiles() {
    let tempDir = FileManager.default.temporaryDirectory
    let contents = try? FileManager.default.contentsOfDirectory(at: tempDir, ...)
    for item in contents ?? [] {
        if item.lastPathComponent.hasPrefix("QuickRecorder_") {
            try? FileManager.default.removeItem(at: item)
        }
    }
}
```

## 相關文件更新

修復後需更新以下文件：

1. **SPEC.md**
   - 章節 6.2「檔案命名規則」
   - 章節 4.4「多軌混音流程」

2. **CLAUDE.md / CLAUDE_zh-TW.md**
   - 「錄製流程」章節
   - 「多軌音訊」說明

3. **README.md**（如有使用者文件）
   - 說明臨時檔案位置（系統臨時資料夾）

## 總結

這個問題本質上是**設計問題**而非程式錯誤。目前的實作使用三重副檔名作為狀態標記，雖然邏輯上可行，但違反了使用者預期和平台慣例。

**建議採用方案 A**，將臨時處理過程完全移至系統臨時資料夾，既符合 macOS 設計規範，又能提供更好的使用者體驗。

**預估修復時間：** 2-3 小時（包含測試）
**預估測試時間：** 1-2 小時
**風險等級：** 低
