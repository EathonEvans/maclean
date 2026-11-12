// generate-assets.swift
// 从 asset 目录的品牌 SVG 生成：
//   1. AppIcon.icns  —— 多尺寸 iconset → iconutil（macOS 应用图标，最稳路线；
//      asset catalog 的单尺寸格式曾在本机 actool 下被静默丢弃，故弃用）
//   2. MenuBarTemplate.imageset —— M 彩带轮廓的黑色 Template 菜单栏图标
// 用法：swift scripts/generate-assets.swift <logo.svg> <输出 xcassets 目录> <icns 输出路径>

import AppKit
import Foundation

// MARK: - SVG 派生

/// 原始 SVG：1200x1200 画布，圆角方形标记位于 (340,80) 尺寸 520x520，字标在其下方。
let markViewBox = "340 80 520 520"

/// 菜单栏模板：仅保留 M 彩带描边路径与四角星光，纯黑以便作为 Template Image 渲染。
let templateSVG = """
<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="420" height="345" viewBox="400 150 420 345">
  <path d="M 450 440 L 555 285" stroke="#000000" stroke-width="82" stroke-linecap="round" stroke-linejoin="round" fill="none"/>
  <path d="M 555 285 L 660 440" stroke="#000000" stroke-width="82" stroke-linecap="round" stroke-linejoin="round" fill="none"/>
  <path d="M 660 440 L 765 285" stroke="#000000" stroke-width="82" stroke-linecap="round" stroke-linejoin="round" fill="none"/>
  <path d="M 760 166 C 763 180 769 186 783 189 C 769 192 763 198 760 212 C 757 198 751 192 737 189 C 751 186 757 180 760 166 Z" fill="#000000"/>
</svg>
"""

/// 把整图 SVG 裁成仅含圆角方形标记的 SVG（不改形状，只改 viewBox）。
func makeMarkSVG(from fullSVG: String) -> String {
    fullSVG
        .replacingOccurrences(of: "width=\"1200\" height=\"1200\" viewBox=\"0 0 1200 1200\"",
                              with: "width=\"520\" height=\"520\" viewBox=\"\(markViewBox)\"")
}

// MARK: - 渲染

func loadSVGImage(_ svgText: String) -> NSImage {
    guard let image = NSImage(data: Data(svgText.utf8)) else {
        fatalError("SVG 解析失败（需要 macOS 11+ 的 AppKit SVG 支持）")
    }
    return image
}

/// 在正方形 PNG 画布中按纵横比居中绘制图片。
func renderPNG(image: NSImage, canvas: CGFloat, contentRatio: CGFloat) -> NSBitmapImageRep {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(canvas), pixelsHigh: Int(canvas),
        bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ) else {
        fatalError("创建位图失败")
    }
    rep.size = NSSize(width: canvas, height: canvas)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let inner = canvas * contentRatio
    let imageSize = image.size
    let scale = min(inner / imageSize.width, inner / imageSize.height)
    let drawSize = NSSize(width: imageSize.width * scale, height: imageSize.height * scale)
    let origin = NSPoint(x: (canvas - drawSize.width) / 2, y: (canvas - drawSize.height) / 2)
    image.draw(in: NSRect(origin: origin, size: drawSize))

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func pngData(_ rep: NSBitmapImageRep) -> Data {
    guard let data = rep.representation(using: .png, properties: [:]) else {
        fatalError("PNG 编码失败")
    }
    return data
}

func write(_ data: Data, to path: String) {
    try! data.write(to: URL(fileURLWithPath: path))
    print("写出 \(path)")
}

// MARK: - 入口

let arguments = CommandLine.arguments
guard arguments.count >= 4 else {
    print("用法：swift generate-assets.swift <logo.svg> <输出 xcassets 目录> <icns 输出路径>")
    exit(2)
}
let svgURL = URL(fileURLWithPath: arguments[1])
let xcassetsURL = URL(fileURLWithPath: arguments[2])
let icnsOutputURL = URL(fileURLWithPath: arguments[3])

let fullSVG = try! String(contentsOf: svgURL, encoding: .utf8)
let markImage = loadSVGImage(makeMarkSVG(from: fullSVG))

// 1. AppIcon.icns：多尺寸 iconset（矢量按各尺寸直出，保证清晰）→ iconutil
let fm = FileManager.default
let iconsetDir = fm.temporaryDirectory.appendingPathComponent("maclean-appicon.iconset")
try? fm.removeItem(at: iconsetDir)
try! fm.createDirectory(at: iconsetDir, withIntermediateDirectories: true)

let iconsetSizes: [(name: String, pixels: Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]
for (name, pixels) in iconsetSizes {
    let rep = renderPNG(image: markImage, canvas: CGFloat(pixels), contentRatio: 0.88)
    try! pngData(rep).write(to: iconsetDir.appendingPathComponent("\(name).png"))
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconsetDir.path, "-o", icnsOutputURL.path]
try! iconutil.run()
iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else {
    fatalError("iconutil 失败：退出码 \(iconutil.terminationStatus)")
}
print("写出 \(icnsOutputURL.path)")

// 2. 菜单栏模板图：18pt（1x/2x/3x），内容占画布 84%
try! fm.createDirectory(at: xcassetsURL, withIntermediateDirectories: true)
write(Data("{\"info\":{\"author\":\"xcode\",\"version\":1}}".utf8),
      to: xcassetsURL.appendingPathComponent("Contents.json").path)

let templateImage = loadSVGImage(templateSVG)
let templateDir = xcassetsURL.appendingPathComponent("MenuBarTemplate.imageset")
try! fm.createDirectory(at: templateDir, withIntermediateDirectories: true)
var imageEntries: [String] = []
for (index, px) in [18.0, 36.0, 54.0].enumerated() {
    let scale = index + 1
    let filename = "menubar-template\(scale == 1 ? "" : "@\(scale)x").png"
    let rep = renderPNG(image: templateImage, canvas: px, contentRatio: 0.84)
    write(pngData(rep), to: templateDir.appendingPathComponent(filename).path)
    imageEntries.append("""
        {
          "filename" : "\(filename)",
          "idiom" : "universal",
          "scale" : "\(scale)x"
        }
        """)
}
let templateJSON = """
{
  "images" : [
\(imageEntries.joined(separator: ",\n"))
  ],
  "info" : { "author" : "xcode", "version" : 1 },
  "properties" : {
    "template-rendering-intent" : "template"
  }
}
"""
write(Data(templateJSON.utf8), to: templateDir.appendingPathComponent("Contents.json").path)

// 3. 菜单项图标：构建时把 SF Symbol 渲染成位图模板 PNG。
//    运行时 NSImage(systemSymbolName:) 赋给 NSMenuItem.image 在本机不渲染，
//    资产目录位图模板（与状态栏图标同路线）则保证显示。
let menuItemIcons: [(asset: String, symbol: String)] = [
    ("MenuItemDisplay", "display"),
    ("MenuItemClean", "sparkles"),
    ("MenuItemSettings", "gearshape"),
    ("MenuItemAbout", "info.circle"),
    ("MenuItemQuit", "power"),
]
for (asset, symbol) in menuItemIcons {
    let imagesetDir = xcassetsURL.appendingPathComponent("\(asset).imageset")
    try! fm.createDirectory(at: imagesetDir, withIntermediateDirectories: true)
    var entries: [String] = []
    for (index, px) in [16.0, 32.0, 48.0].enumerated() {
        let scale = index + 1
        let filename = "\(asset)\(scale == 1 ? "" : "@\(scale)x").png"
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(px), pixelsHigh: Int(px),
            bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        )!
        // 直接绘制符号到位图（rep.size 保持 1x 逻辑尺寸）
        rep.size = NSSize(width: px / CGFloat(scale), height: px / CGFloat(scale))
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        let symbolImage = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 12, weight: .medium))!
        let size = symbolImage!.size
        let logical = px / CGFloat(scale)
        let fit = min(logical / size.width, logical / size.height)
        let drawSize = NSSize(width: size.width * fit, height: size.height * fit)
        symbolImage!.draw(in: NSRect(
            x: (logical - drawSize.width) / 2, y: (logical - drawSize.height) / 2,
            width: drawSize.width, height: drawSize.height
        ))
        NSGraphicsContext.restoreGraphicsState()
        write(pngData(rep), to: imagesetDir.appendingPathComponent(filename).path)
        entries.append("""
            {
              "filename" : "\(filename)",
              "idiom" : "universal",
              "scale" : "\(scale)x"
            }
            """)
    }
    let imagesetJSON = """
    {
      "images" : [
    \(entries.joined(separator: ",\n"))
      ],
      "info" : { "author" : "xcode", "version" : 1 },
      "properties" : {
        "template-rendering-intent" : "template"
      }
    }
    """
    write(Data(imagesetJSON.utf8), to: imagesetDir.appendingPathComponent("Contents.json").path)
}
print("资源生成完成 ✅")
