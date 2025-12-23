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
  build 2>&1 | grep -E "(BUILD SUCCEEDED|BUILD FAILED|error:)"

if [ ${PIPESTATUS[0]} -eq 0 ]; then
  echo "✅ 編譯成功！"
  echo "📦 安裝到 /Applications..."
  rm -rf /Applications/QuickRecorder-Dev.app
  cp -R ~/Library/Developer/Xcode/DerivedData/QuickRecorder-*/Build/Products/Debug/QuickRecorder.app /Applications/QuickRecorder-Dev.app
  echo "🚀 啟動 App..."
  echo "📝 Debug Log: /tmp/qr-debug.log (可從 Help 選單開啟)"
  echo "------- App 日誌 -------"
  /Applications/QuickRecorder-Dev.app/Contents/MacOS/QuickRecorder
else
  echo "❌ 編譯失敗"
  exit 1
fi
