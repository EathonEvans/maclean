import AppKit
import CoreGraphics
import Foundation

extension NSScreen {
    /// 对应的 CGDirectDisplayID（AppKit 与 CoreGraphics 坐标/标识统一，文档 §4.8）
    var macleanDisplayID: CGDirectDisplayID? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }
}
