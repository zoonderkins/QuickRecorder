# QuickRecorder 編譯指南

## 快速編譯（命令列）

```bash
# 無需 code signing 的編譯方式
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  -project QuickRecorder.xcodeproj \
  -scheme QuickRecorder \
  -configuration Debug \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  build
```

## 首次設定（權限授權）

```bash
# 1. 重置螢幕錄製權限
tccutil reset ScreenCapture

# 2. 開啟編譯好的 App
open ~/Library/Developer/Xcode/DerivedData/QuickRecorder-*/Build/Products/Debug/QuickRecorder.app

# 3. 授權時點選「允許」（每次 build 只需一次）
```

## 修改程式碼後

```bash
# 1. 重新編譯（不需重置權限）
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  -project QuickRecorder.xcodeproj \
  -scheme QuickRecorder \
  -configuration Debug \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  build

# 2. 執行 App（如果簽名改變可能需要重新授權）
open ~/Library/Developer/Xcode/DerivedData/QuickRecorder-*/Build/Products/Debug/QuickRecorder.app
```

## 安裝到 /Applications（讓 Spotlight 找得到）

```bash
# 複製到 Applications 資料夾
cp -R ~/Library/Developer/Xcode/DerivedData/QuickRecorder-*/Build/Products/Debug/QuickRecorder.app /Applications/QuickRecorder-Dev.app

# 現在可以用 Spotlight 搜尋 "QuickRecorder-Dev" 開啟
```

## 一鍵編譯並安裝腳本

將以下內容存為專案根目錄的 `build.sh`：

```bash
#!/bin/bash
cd "$(dirname "$0")"

echo "🔨 編譯中..."
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  -project QuickRecorder.xcodeproj \
  -scheme QuickRecorder \
  -configuration Debug \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  build 2>&1 | grep -E "(BUILD|error:|warning:)"

if [ $? -eq 0 ]; then
  echo "✅ 編譯成功！"
  echo "📦 安裝到 /Applications..."
  cp -R ~/Library/Developer/Xcode/DerivedData/QuickRecorder-*/Build/Products/Debug/QuickRecorder.app /Applications/QuickRecorder-Dev.app
  echo "🚀 啟動 App..."
  open /Applications/QuickRecorder-Dev.app
else
  echo "❌ 編譯失敗"
fi
```

使用方式：
```bash
chmod +x build.sh
./build.sh
```

## 注意事項

- 每次新編譯可能需要重新授權螢幕錄製權限（macOS 對 ad-hoc 簽名的限制）
- 如需穩定的權限，請在 Xcode 中使用正式的 Apple Developer 憑證
- 此 App 需要 macOS 12.3 或更新版本
