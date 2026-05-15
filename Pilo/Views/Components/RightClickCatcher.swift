import SwiftUI
import AppKit

/// 右键拦截桥——NSView 接 rightMouseDown，让 SwiftUI 可以绕开系统 NSMenu chrome
/// 弹自定义邮局风菜单（[[PostalContextMenu]]）。
///
/// **用法**：`.background(RightClickCatcher { isMenuOpen = true })`，配合
/// `.popover(isPresented: $isMenuOpen) { PostalContextMenu(items: ...) }` 使用。
///
/// **关键 trick**：`hitTest` 仅在当前 NSEvent 是 `rightMouseDown` 时认领自己，
/// 其它情况返回 nil 让事件穿透——这样左键被前面的 SwiftUI Button 正常抓走，
/// 右键被 NSView 截获，互不干扰。
struct RightClickCatcher: NSViewRepresentable {
    let onRightClick: () -> Void

    final class HitView: NSView {
        var callback: () -> Void = {}
        override func rightMouseDown(with event: NSEvent) {
            callback()
        }
        override func hitTest(_ point: NSPoint) -> NSView? {
            if let event = NSApp.currentEvent, event.type == .rightMouseDown {
                return self
            }
            return nil
        }
    }

    func makeNSView(context: Context) -> HitView {
        let view = HitView()
        view.callback = onRightClick
        return view
    }

    func updateNSView(_ nsView: HitView, context: Context) {
        nsView.callback = onRightClick
    }
}
