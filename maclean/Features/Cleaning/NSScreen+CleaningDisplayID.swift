import AppKit
import CoreGraphics
import Foundation

extension NSScreen {
    /// 对应的 CGDirectDisplayID（开发文档 §4.2：用 displayID 作身份，不用数组下标）
    var cleaningDisplayID: CGDirectDisplayID? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }
}
