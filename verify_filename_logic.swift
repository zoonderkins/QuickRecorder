#!/usr/bin/swift

import Foundation

// 模拟 URL 扩展名删除逻辑
func simulateFileNamingLogic() {
    print("=== 验证三重扩展名文件处理逻辑 ===\n")

    // 模拟场景：remuxAudio && recordMic && recordWinSound
    let basePath = "/Users/edward_oo/Movies/Recording at 2025-10-23 14.30.00"
    let fileEnding = "mp4"

    // 步骤 1: 初始录制文件 (RecordEngine.swift:374)
    let initialFilePath = "\(basePath).\(fileEnding).\(fileEnding).\(fileEnding)"
    print("📹 初始录制文件:")
    print("   路径: \(initialFilePath)")
    print("   说明: AVAssetWriter 直接写入此文件\n")

    // 步骤 2: 第一次 deletingPathExtension (SCContext.swift:718)
    let videoURL = URL(fileURLWithPath: initialFilePath)
    let audioOutputURL = videoURL.deletingPathExtension()
    print("🎵 第一次删除扩展名 (音频临时文件):")
    print("   路径: \(audioOutputURL.path)")
    print("   说明: 用于导出合并的音频轨道\n")

    // 步骤 3: 第二次 deletingPathExtension (SCContext.swift:719)
    let outputURL = audioOutputURL.deletingPathExtension()
    print("✅ 第二次删除扩展名 (最终输出文件):")
    print("   路径: \(outputURL.path)")
    print("   说明: 包含视频轨 + 合并后的音频轨\n")

    // 验证扩展名
    print("=== 扩展名验证 ===")
    print("初始文件扩展名: \(videoURL.pathExtension)")
    print("音频临时文件扩展名: \(audioOutputURL.pathExtension)")
    print("最终输出文件扩展名: \(outputURL.pathExtension)\n")

    // 清理步骤
    print("=== 清理步骤 (SCContext.swift:818-820) ===")
    print("1. 删除: \(videoURL.path)")
    print("2. 删除: \(audioOutputURL.path)")
    print("3. 保留: \(outputURL.path)")
    print("\n✅ 用户最终看到的文件: \(outputURL.lastPathComponent)\n")

    // 测试边界情况
    print("=== 边界情况测试 ===")
    testEdgeCases()
}

func testEdgeCases() {
    let testCases = [
        ("test.mp4.mp4.mp4", "mp4"),
        ("my.video.file.mov.mov.mov", "mov"),
        ("recording 2025-10-23.mp4.mp4.mp4", "mp4")
    ]

    for (filePath, expectedExt) in testCases {
        let url = URL(fileURLWithPath: filePath)
        let step1 = url.deletingPathExtension()
        let step2 = step1.deletingPathExtension()

        print("\n测试: \(filePath)")
        print("  → \(step1.lastPathComponent)")
        print("  → \(step2.lastPathComponent)")
        print("  最终扩展名: \(step2.pathExtension) (期望: \(expectedExt))")

        if step2.pathExtension == expectedExt {
            print("  ✅ 通过")
        } else {
            print("  ❌ 失败")
        }
    }
}

// 执行验证
simulateFileNamingLogic()
