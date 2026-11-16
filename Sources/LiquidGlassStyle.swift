import SwiftUI
import AppKit

// MARK: - 窗口透明化注入器 (解开 macOS 默认不透明窗口限制，实现真正物理透光的桌面毛玻璃)
struct WindowAccessor: NSViewRepresentable {
    var onWindow: (NSWindow) -> Void
    
    func makeNSView(context: Context) -> NSView {
        let view = WindowHookView()
        view.onWindow = onWindow
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
}

private class WindowHookView: NSView {
    var onWindow: ((NSWindow) -> Void)?
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let window = self.window {
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = true
            onWindow?(window)
        }
    }
}

// MARK: - 原生 macOS 系统级毛玻璃 (真正对桌面背景进行物理透射和高斯模糊)
struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .popover
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    var state: NSVisualEffectView.State = .active

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = state
    }
}

// MARK: - 100% 绝对生效的系统级鼠标手型光标注入器 (AppKit 原生 CursorRect，杜绝丢帧与失效)
struct PointingHandCursorView: NSViewRepresentable {
    func makeNSView(context: Context) -> PointingHandNSView {
        let view = PointingHandNSView()
        return view
    }
    
    func updateNSView(_ nsView: PointingHandNSView, context: Context) {
        nsView.window?.invalidateCursorRects(for: nsView)
    }
}

class PointingHandNSView: NSView {
    override func resetCursorRects() {
        discardCursorRects()
        addCursorRect(bounds, cursor: .pointingHand)
    }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.invalidateCursorRects(for: self)
    }
    
    // 允许事件穿透到底层 SwiftUI 按钮与手势
    override func hitTest(_ point: NSPoint) -> NSView? {
        return nil
    }
}

// MARK: - 鼠标手型修饰器 (双保险机制：原生 CursorRect + onHover 即时响应)
struct PointingHandModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .overlay(PointingHandCursorView())
            .onHover { inside in
                if inside {
                    NSCursor.pointingHand.set()
                } else {
                    NSCursor.arrow.set()
                }
            }
    }
}

extension View {
    func pointingHand() -> some View {
        self.modifier(PointingHandModifier())
    }
}

// MARK: - 苹果官方级别 真实液态玻璃 (Apple Liquid Glass) 质感修饰器
struct AppleLiquidGlassModifier: ViewModifier {
    var cornerRadius: CGFloat
    var isHovered: Bool
    var tintColor: Color
    
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    VisualEffectBlur(material: .hudWindow, blendingMode: .withinWindow)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    tintColor.opacity(isHovered ? 0.45 : 0.32),
                                    tintColor.opacity(isHovered ? 0.28 : 0.18)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                stops: [
                                    .init(color: .white.opacity(isHovered ? 0.85 : 0.60), location: 0.0),
                                    .init(color: .white.opacity(isHovered ? 0.40 : 0.22), location: 0.35),
                                    .init(color: .white.opacity(0.05), location: 0.7),
                                    .init(color: .black.opacity(0.08), location: 1.0)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: isHovered ? 1.2 : 0.9
                        )
                }
            )
            .shadow(
                color: Color.black.opacity(isHovered ? 0.16 : 0.08),
                radius: isHovered ? 8 : 4,
                x: 0,
                y: isHovered ? 4 : 2
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.72), value: isHovered)
    }
}

extension View {
    func appleLiquidGlass(cornerRadius: CGFloat = 13, isHovered: Bool = false, tint: Color = .white) -> some View {
        self.modifier(AppleLiquidGlassModifier(cornerRadius: cornerRadius, isHovered: isHovered, tintColor: tint))
    }
}
