import SwiftUI
import AppKit

// MARK: - 节点坐标全局偏好键 (实现真正根据模块实际位置动态生成桑基图条带)
struct NodeFramePreferenceKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

extension View {
    func recordSankeyFrame(id: String) -> some View {
        self.background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: NodeFramePreferenceKey.self,
                    value: [id: geo.frame(in: .named("SankeyCanvasSpace"))]
                )
            }
        )
    }
}

// MARK: - 严格基于模块真实物理位置生成的 3 级全流向能量桑基图
struct LivePowerFlowSankey: View {
    @ObservedObject var model: PowerModel
    @Environment(\.colorScheme) private var colorScheme
    
    // 动态捕获的所有卡片绝对坐标
    @State private var nodeFrames: [String: CGRect] = [:]
    
    // 鼠标悬停状态
    @State private var hoveredRibbon: String? = nil
    @State private var copiedRibbon: String? = nil
    
    private var isDark: Bool { colorScheme == .dark }
    
    // 自适应深色/浅色文字与图标高对比度色彩 (深色模式纯净白，浅色模式碳黑)
    private var cardTextColor: Color {
        isDark ? Color.white.opacity(0.95) : Color.black.opacity(0.80)
    }
    
    private var cardStrokeColor: Color {
        isDark ? Color.white.opacity(0.24) : Color.white.opacity(0.75)
    }
    
    // 苹果马卡龙色盘
    private let blueTint = Color(red: 0.60, green: 0.78, blue: 0.98)     // 适配器
    private let mintTint = Color(red: 0.58, green: 0.90, blue: 0.76)     // 电池充入
    private let lavenderTint = Color(red: 0.82, green: 0.76, blue: 0.96) // 电脑整机
    private let amberTint = Color(red: 1.0, green: 0.76, blue: 0.44)    // 电池放电
    private let displayColor = Color(red: 0.35, green: 0.65, blue: 1.0)
    private let socColor = Color(red: 0.78, green: 0.40, blue: 0.92)
    private let usbColor = Color(red: 1.0, green: 0.62, blue: 0.28)
    private let dramColor = Color(red: 0.28, green: 0.78, blue: 0.88)
    private let diskColor = Color(red: 0.35, green: 0.85, blue: 0.65)
    
    var body: some View {
        ZStack {
            // 背景液态玻璃大底盘
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            blueTint.opacity(0.18),
                            lavenderTint.opacity(0.20)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    VisualEffectBlur(material: .popover, blendingMode: .withinWindow)
                        .opacity(0.3)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                stops: [
                                    .init(color: .white.opacity(0.65), location: 0.0),
                                    .init(color: .white.opacity(0.20), location: 0.4),
                                    .init(color: .clear, location: 0.8),
                                    .init(color: .white.opacity(0.12), location: 1.0)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
            
            // 核心 1: 底层动态桑基图条带层 (100% 根据模块实际测量坐标生成，严丝合缝)
            sankeyRibbonsLayer
                .allowsHitTesting(false)
            
            // 核心 2: 上层三栏真实模块视图
            HStack(alignment: .center, spacing: 32) {
                // === 第一列: 电源输入端 ===
                sourceColumn
                
                // === 第二列: 中间中转分配端 (上电池，下电脑) ===
                distributionColumn
                
                // === 第三列: 右侧硬件细分端 (显示器、SoC、内存、硬盘，过滤 0 功耗设备) ===
                hardwareSubsystemColumn
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
        }
        .coordinateSpace(name: "SankeyCanvasSpace")
        .onPreferenceChange(NodeFramePreferenceKey.self) { frames in
            // 仅在卡片绝对坐标真实发生位移时才更新 @State，杜绝每秒引发无意义的二次全树重排与重绘
            if self.nodeFrames != frames {
                self.nodeFrames = frames
            }
        }
    }
    
    // =========================================================================
    // MARK: - 第一列: 供电源模块 (Plug / Battery)
    // =========================================================================
    private var sourceCardHeight: CGFloat {
        let hasUsb = hasUsbOut
        let isChargingBat = model.isExternalConnected && model.isCharging
        if isChargingBat && hasUsb {
            return 128
        } else if isChargingBat {
            return 102
        } else if hasUsb {
            return 99
        } else {
            return 64
        }
    }
    
    private var batteryIconName: String {
        let p = model.batteryPercent
        if p >= 90 { return "battery.100" }
        if p >= 75 { return "battery.75" }
        if p >= 50 { return "battery.50" }
        if p >= 25 { return "battery.25" }
        return "battery.0"
    }

    private var sourceColumn: some View {
        VStack {
            if model.isExternalConnected {
                // 适配器供电
                let bg = isDark ? Color(red: 0.20, green: 0.36, blue: 0.58).opacity(0.80) : blueTint.opacity(0.70)
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(bg)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(cardStrokeColor, lineWidth: 0.9)
                        )
                    
                    VStack(spacing: 4) {
                        Image(systemName: "powerplug.fill")
                            .font(.system(size: sourceCardHeight > 80 ? 17 : 15, weight: .semibold))
                            .foregroundColor(cardTextColor)
                        Text(String(format: "%.1fW", model.adapterWatts))
                            .font(.system(size: 10.5, weight: .bold, design: .rounded))
                            .foregroundColor(cardTextColor)
                    }
                }
                .frame(width: 54, height: sourceCardHeight)
                .shadow(color: Color.black.opacity(isDark ? 0.20 : 0.04), radius: 3, y: 1.5)
                .recordSankeyFrame(id: "source")
                .pointingHand()
                .help(model.adapterRatedWatts > 0 ? "电源适配器实时输入: \(String(format: "%.1fW", model.adapterWatts))\n(充电器握手额定规格: \(Int(model.adapterRatedWatts))W PD)" : "电源适配器实时输入: \(String(format: "%.1fW", model.adapterWatts))")
            } else {
                // 纯电池放电: 显示当前电池电量对应的电池图标，精准体现电池输出
                let bg = isDark ? Color(red: 0.58, green: 0.35, blue: 0.16).opacity(0.80) : amberTint.opacity(0.70)
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(bg)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(cardStrokeColor, lineWidth: 0.9)
                        )
                    
                    VStack(spacing: 4) {
                        Image(systemName: batteryIconName)
                            .font(.system(size: sourceCardHeight > 80 ? 18 : 16, weight: .semibold))
                            .foregroundColor(cardTextColor)
                        Text(String(format: "%.1fW", abs(model.batteryWatts)))
                            .font(.system(size: 10.5, weight: .bold, design: .rounded))
                            .foregroundColor(cardTextColor)
                    }
                }
                .frame(width: 54, height: sourceCardHeight)
                .shadow(color: Color.black.opacity(isDark ? 0.20 : 0.04), radius: 3, y: 1.5)
                .recordSankeyFrame(id: "source")
                .pointingHand()
                .help("电池输出供电: \(String(format: "%.1fW", abs(model.batteryWatts)))\n(当前剩余电量: \(model.batteryPercent)%)")
            }
        }
    }
    
    // =========================================================================
    // MARK: - 第二列: 中间中转分配端 (上电池，中电脑，下USB外供)
    // =========================================================================
    private var hasUsbOut: Bool {
        model.subsystem.usbOutWatts > 0.01
    }
    
    private var laptopInternalWatts: Double {
        model.systemWatts
    }
    
    private var distributionColumn: some View {
        VStack(spacing: hasUsbOut ? 7 : 10) {
            // 上模块: 电池 (严格仅在真实处于充电流入状态时才展示，一旦不充电或80%暂缓彻底隐藏，保持能量流极简纯净)
            if model.isExternalConnected && model.isCharging {
                let batBg = isDark ? Color(red: 0.16, green: 0.45, blue: 0.35).opacity(0.80) : mintTint.opacity(0.72)
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(batBg)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(cardStrokeColor, lineWidth: 0.8)
                        )
                    
                    VStack(spacing: 2) {
                        Image(systemName: "battery.100percent.bolt")
                            .font(.system(size: hasUsbOut ? 12 : 13, weight: .semibold))
                            .foregroundColor(cardTextColor)
                        Text(String(format: "+%.1fW", model.batteryWatts))
                            .font(.system(size: hasUsbOut ? 8.8 : 9.5, weight: .bold, design: .rounded))
                            .foregroundColor(cardTextColor)
                    }
                }
                .frame(width: 56, height: hasUsbOut ? 36 : 42)
                .recordSankeyFrame(id: "battery")
                .pointingHand()
                .help("充入电池: \(String(format: "%.1fW", model.batteryWatts))")
            }
            
            // 中模块: 电脑系统硬件负载 (扣除 USB 外供部分，展现电脑自身的真正硬件功耗)
            let lapBg = isDark ? Color(red: 0.36, green: 0.28, blue: 0.54).opacity(0.80) : lavenderTint.opacity(0.75)
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(lapBg)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(cardStrokeColor, lineWidth: 0.8)
                    )
                
                VStack(spacing: 2) {
                    Image(systemName: "laptopcomputer")
                        .font(.system(size: hasUsbOut ? 12.5 : 14, weight: .semibold))
                        .foregroundColor(cardTextColor)
                    Text(String(format: "%.1fW", laptopInternalWatts))
                        .font(.system(size: hasUsbOut ? 9.2 : 10, weight: .bold, design: .rounded))
                        .foregroundColor(cardTextColor)
                }
            }
            .frame(width: 56, height: (model.isExternalConnected && model.isCharging) ? (hasUsbOut ? 42 : 50) : (hasUsbOut ? 50 : 64))
            .recordSankeyFrame(id: "laptop")
            .pointingHand()
            .help("电脑自身硬件功耗: \(String(format: "%.2fW", laptopInternalWatts))\n(严格对应内部组件显示器、SoC芯片、统一内存与固态硬盘的物理功耗)")
            
            // 下模块: USB-C 外供受电节点 (与电脑耗电同级呈现，毕竟不是电脑在耗电)
            if hasUsbOut {
                let usbBg = isDark ? Color(red: 0.55, green: 0.32, blue: 0.14).opacity(0.80) : usbColor.opacity(0.75)
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(usbBg)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(cardStrokeColor, lineWidth: 0.8)
                        )
                    
                    VStack(spacing: 2) {
                        Image(systemName: "cable.connector.horizontal")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundColor(cardTextColor)
                        Text(String(format: "%.1fW", model.subsystem.usbOutWatts))
                            .font(.system(size: 9.2, weight: .bold, design: .rounded))
                            .foregroundColor(cardTextColor)
                    }
                }
                .frame(width: 56, height: (model.isExternalConnected && model.isCharging) ? 36 : 42)
                .recordSankeyFrame(id: "usb_out")
                .pointingHand()
                .help("USB-C 外部反向供电: \(String(format: "%.2fW", model.subsystem.usbOutWatts))\n(检测到 \(model.subsystem.attachedUsbPorts) 个外接设备正在受电，由电源/电池输出给外部设备，非电脑自身能耗)")
            }
        }
    }
    
    // =========================================================================
    // MARK: - 第三列: 真实硬件传感器细分卡片 (全为真机读取，自动过滤 0 功耗设备)
    // =========================================================================
    private var hardwareSubsystemColumn: some View {
        VStack(spacing: 6) {
            // 1. 显示器背光 (直接来自 AppleARMBacklight 硬件寄存器)
            if model.subsystem.displayWatts > 0.01 {
                hardwareItemCard(
                    id: "sub_display",
                    name: "显示器背光",
                    info: "\(model.subsystem.brightnessPercent)% 亮度 · \(Int(model.subsystem.brightnessNits)) nits",
                    watts: model.subsystem.displayWatts,
                    icon: "display",
                    color: displayColor,
                    tooltip: "显示器物理总功耗: \(String(format: "%.2f W", model.subsystem.displayWatts))\n(来自 AppleARMBacklight 硬件寄存器: 亮度 \(model.subsystem.brightnessPercent)% · 流明 \(Int(model.subsystem.brightnessNits)) nits · T-CON 面板基准 0.65W + LED 背光 \(String(format: "%.2fW", max(0.0, model.subsystem.displayWatts - 0.65))))"
                )
            }
            
            // 2. SoC 芯片 (直接来自 Apple Silicon Energy Model 硬件电表)
            if model.subsystem.socWatts > 0.01 {
                hardwareItemCard(
                    id: "sub_soc",
                    name: "SoC 芯片",
                    info: String(format: "CPU %.2fW · GPU %.2fW", model.subsystem.cpuWatts, model.subsystem.gpuWatts),
                    watts: model.subsystem.socWatts,
                    icon: "cpu",
                    color: socColor,
                    tooltip: "SoC 芯片总功耗: \(String(format: "%.2f W", model.subsystem.socWatts))\n(来自 Apple Silicon Energy Model 内核通道: CPU \(String(format: "%.2fW", model.subsystem.cpuWatts)) · GPU \(String(format: "%.2fW", model.subsystem.gpuWatts)) · ANE \(String(format: "%.2fW", model.subsystem.aneWatts)) · CPU负载 \(String(format: "%.0f%%", model.subsystem.cpuUsagePercent)))"
                )
            }
            
            // 3. 统一内存 (直接来自 Apple DRAM Energy Model 硬件电表)
            if model.subsystem.dramWatts > 0.01 {
                hardwareItemCard(
                    id: "sub_dram",
                    name: "统一内存",
                    info: "DRAM 硬件遥测",
                    watts: model.subsystem.dramWatts,
                    icon: "memorychip",
                    color: dramColor,
                    tooltip: "统一内存 DRAM 功耗: \(String(format: "%.2f W", model.subsystem.dramWatts))\n(来自 Apple Silicon 内存控制器硬件电表通道)"
                )
            }
            
            // 5. 固态硬盘 (直接来自 IOBlockStorageDriver 硬件吞吐)
            if model.subsystem.diskWatts > 0.01 {
                let totalMBs = model.subsystem.diskReadMBs + model.subsystem.diskWriteMBs
                let infoStr = totalMBs > 0.1 ? String(format: "读写 %.1f MB/s", totalMBs) : "NVMe PCIe 待机"
                hardwareItemCard(
                    id: "sub_disk",
                    name: "固态硬盘",
                    info: infoStr,
                    watts: model.subsystem.diskWatts,
                    icon: "internaldrive",
                    color: diskColor,
                    tooltip: "NVMe 固态硬盘实时功耗: \(String(format: "%.2f W", model.subsystem.diskWatts))\n(来自 IOBlockStorageDriver 读: \(String(format: "%.1f MB/s", model.subsystem.diskReadMBs)) · 写: \(String(format: "%.1f MB/s", model.subsystem.diskWriteMBs)))"
                )
            }
        }
        .frame(width: 154)
    }
    
    private func hardwareItemCard(id: String, name: String, info: String, watts: Double, icon: String, color: Color, tooltip: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 14)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.primary.opacity(0.85))
                Text(info)
                    .font(.system(size: 8.2, weight: .regular, design: .monospaced))
                    .foregroundColor(.secondary.opacity(0.75))
            }
            
            Spacer()
            
            Text(String(format: "%.2f W", watts))
                .font(.system(size: 10.5, weight: .bold, design: .rounded))
                .foregroundColor(.primary.opacity(0.85))
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4.5)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.primary.opacity(0.09), lineWidth: 0.8)
                )
        )
        .recordSankeyFrame(id: id)
        .pointingHand()
        .help(tooltip)
    }
    
    // =========================================================================
    // MARK: - 动态桑基图条带生成引擎 (以模块实际物理 Frame 为基准，严格对齐直边，消除圆角接缝瑕疵)
    // =========================================================================
    private var sankeyRibbonsLayer: some View {
        Canvas { context, size in
            guard let srcRect = nodeFrames["source"],
                  let laptopRect = nodeFrames["laptop"] else { return }
            
            let batRect = nodeFrames["battery"]
            let usbRect = nodeFrames["usb_out"]
            let hasUsb = (model.subsystem.usbOutWatts > 0.01) && (usbRect != nil)
            let mainStrokeColor = isDark ? Color.white.opacity(0.24) : Color.white.opacity(0.45)
            
            // 模块圆角为 10，上下安全直边严格在 minY + 9.5 到 maxY - 9.5
            let srcFlatTop = srcRect.minY + 9.5
            let srcFlatBottom = srcRect.maxY - 9.5
            let lapFlatTop = laptopRect.minY + 9.5
            let lapFlatBottom = laptopRect.maxY - 9.5
            let gap: CGFloat = 2.0
            
            // --- 第一级: 电源输入与分配 ---
            if model.state == .hybrid, let batRect = batRect {
                // 混合供电模式: 适配器(蓝) + 电池(橙协助) 同时注入电脑硬件(紫)
                let totalIn = max(1.0, model.adapterWatts + abs(model.batteryWatts))
                let batFraction = min(0.65, max(0.25, abs(model.batteryWatts) / totalIn))
                
                let lapAvailH = max(10.0, lapFlatBottom - lapFlatTop)
                let batH = (lapAvailH - gap) * CGFloat(batFraction)
                
                // 上路: 电池 -> 电脑
                let batEndY0 = lapFlatTop
                let batEndY1 = batEndY0 + batH
                drawSankeyRibbon(
                    context: context,
                    x0: batRect.maxX - 0.5,
                    y0Top: batRect.minY + 9.5,
                    y0Bottom: batRect.maxY - 9.5,
                    x1: laptopRect.minX + 0.5,
                    y1Top: batEndY0,
                    y1Bottom: batEndY1,
                    colors: [amberTint.opacity(0.65), lavenderTint.opacity(0.65)],
                    strokeColor: mainStrokeColor,
                    lineWidth: 0.65
                )
                
                // 下路: 适配器 -> 电脑
                let adpEndY0 = batEndY1 + gap
                let adpEndY1 = lapFlatBottom
                drawSankeyRibbon(
                    context: context,
                    x0: srcRect.maxX - 0.5,
                    y0Top: srcFlatTop,
                    y0Bottom: srcFlatBottom,
                    x1: laptopRect.minX + 0.5,
                    y1Top: adpEndY0,
                    y1Bottom: adpEndY1,
                    colors: [blueTint.opacity(0.65), lavenderTint.opacity(0.65)],
                    strokeColor: mainStrokeColor,
                    lineWidth: 0.65
                )
                
            } else if model.isExternalConnected && model.isCharging, let batRect = batRect {
                // 正常充电模式: 适配器向 电池充入、电脑硬件 (及 USB外供) 分流
                let totalSrcW = max(1.0, model.adapterWatts)
                let usbW = hasUsb ? model.subsystem.usbOutWatts : 0.0
                let batW = model.batteryWatts
                let srcAvailH = max(16.0, srcFlatBottom - srcFlatTop)
                
                if hasUsb, let usbRect = usbRect {
                    // 三路并进: 电池、电脑、USB外供
                    let netH = srcAvailH - (gap * 2)
                    let rBat = max(0.18, min(0.60, batW / totalSrcW))
                    let rUsb = max(0.12, min(0.35, usbW / totalSrcW))
                    let hBat = netH * CGFloat(rBat)
                    let hUsb = netH * CGFloat(rUsb)
                    let hLap = max(4.0, netH - hBat - hUsb)
                    
                    // 1. 上路: 适配器 -> 电池 (顶边与电池卡片顶边完全水平对齐)
                    let yBat0 = srcFlatTop
                    let yBat1 = yBat0 + hBat
                    drawSankeyRibbon(
                        context: context,
                        x0: srcRect.maxX - 0.5,
                        y0Top: yBat0,
                        y0Bottom: yBat1,
                        x1: batRect.minX + 0.5,
                        y1Top: batRect.minY + 9.5,
                        y1Bottom: batRect.maxY - 9.5,
                        colors: [blueTint.opacity(0.60), mintTint.opacity(0.60)],
                        strokeColor: mainStrokeColor,
                        lineWidth: 0.65
                    )
                    
                    // 2. 中路: 适配器 -> 电脑硬件
                    let yLap0 = yBat1 + gap
                    let yLap1 = yLap0 + hLap
                    drawSankeyRibbon(
                        context: context,
                        x0: srcRect.maxX - 0.5,
                        y0Top: yLap0,
                        y0Bottom: yLap1,
                        x1: laptopRect.minX + 0.5,
                        y1Top: laptopRect.minY + 9.5,
                        y1Bottom: laptopRect.maxY - 9.5,
                        colors: [blueTint.opacity(0.60), lavenderTint.opacity(0.60)],
                        strokeColor: mainStrokeColor,
                        lineWidth: 0.65
                    )
                    
                    // 3. 下路: 适配器 -> USB外供 (底边与USB卡片底边完全水平对齐)
                    let yUsb0 = yLap1 + gap
                    let yUsb1 = srcFlatBottom
                    drawSankeyRibbon(
                        context: context,
                        x0: srcRect.maxX - 0.5,
                        y0Top: yUsb0,
                        y0Bottom: yUsb1,
                        x1: usbRect.minX + 0.5,
                        y1Top: usbRect.minY + 9.5,
                        y1Bottom: usbRect.maxY - 9.5,
                        colors: [blueTint.opacity(0.60), usbColor.opacity(0.60)],
                        strokeColor: mainStrokeColor,
                        lineWidth: 0.65
                    )
                } else {
                    // 两路输出: 电池、电脑硬件 (上下完全占满模块直边高度)
                    let netH = srcAvailH - gap
                    let batRatio = max(0.20, min(0.70, batW / totalSrcW))
                    let hBat = netH * CGFloat(batRatio)
                    
                    let srcBatY0 = srcFlatTop
                    let srcBatY1 = srcBatY0 + hBat
                    drawSankeyRibbon(
                        context: context,
                        x0: srcRect.maxX - 0.5,
                        y0Top: srcBatY0,
                        y0Bottom: srcBatY1,
                        x1: batRect.minX + 0.5,
                        y1Top: batRect.minY + 9.5,
                        y1Bottom: batRect.maxY - 9.5,
                        colors: [blueTint.opacity(0.60), mintTint.opacity(0.60)],
                        strokeColor: mainStrokeColor,
                        lineWidth: 0.65
                    )
                    
                    let srcSysY0 = srcBatY1 + gap
                    let srcSysY1 = srcFlatBottom
                    drawSankeyRibbon(
                        context: context,
                        x0: srcRect.maxX - 0.5,
                        y0Top: srcSysY0,
                        y0Bottom: srcSysY1,
                        x1: laptopRect.minX + 0.5,
                        y1Top: laptopRect.minY + 9.5,
                        y1Bottom: laptopRect.maxY - 9.5,
                        colors: [blueTint.opacity(0.60), lavenderTint.opacity(0.60)],
                        strokeColor: mainStrokeColor,
                        lineWidth: 0.65
                    )
                }
            } else if !model.isExternalConnected {
                // 纯电池放电模式: 电池(橙) -> 电脑硬件(紫) (及 USB外供)
                if hasUsb, let usbRect = usbRect {
                    let totalPwr = max(0.5, model.systemWatts)
                    let usbW = model.subsystem.usbOutWatts
                    let lapW = max(0.2, totalPwr - usbW)
                    let lapRatio = max(0.25, min(0.75, lapW / totalPwr))
                    
                    let srcH = srcFlatBottom - srcFlatTop
                    let hLap = (srcH - gap) * CGFloat(lapRatio)
                    
                    // 上路: 电池 -> 电脑硬件 (顶边与电脑卡片顶边完全水平对齐)
                    let lapY0 = srcFlatTop
                    let lapY1 = lapY0 + hLap
                    drawSankeyRibbon(
                        context: context,
                        x0: srcRect.maxX - 0.5,
                        y0Top: lapY0,
                        y0Bottom: lapY1,
                        x1: laptopRect.minX + 0.5,
                        y1Top: lapFlatTop,
                        y1Bottom: lapFlatBottom,
                        colors: [amberTint.opacity(0.60), lavenderTint.opacity(0.60)],
                        strokeColor: mainStrokeColor,
                        lineWidth: 0.65
                    )
                    
                    // 下路: 电池 -> USB外供 (底边与USB卡片底边完全水平对齐)
                    let usbY0 = lapY1 + gap
                    let usbY1 = srcFlatBottom
                    drawSankeyRibbon(
                        context: context,
                        x0: srcRect.maxX - 0.5,
                        y0Top: usbY0,
                        y0Bottom: usbY1,
                        x1: usbRect.minX + 0.5,
                        y1Top: usbRect.minY + 9.5,
                        y1Bottom: usbRect.maxY - 9.5,
                        colors: [amberTint.opacity(0.60), usbColor.opacity(0.60)],
                        strokeColor: mainStrokeColor,
                        lineWidth: 0.65
                    )
                } else {
                    // 纯电池单路直供电脑: 模块尺寸一致，呈现完美的完全水平矩形能量流
                    drawSankeyRibbon(
                        context: context,
                        x0: srcRect.maxX - 0.5,
                        y0Top: srcFlatTop,
                        y0Bottom: srcFlatBottom,
                        x1: laptopRect.minX + 0.5,
                        y1Top: lapFlatTop,
                        y1Bottom: lapFlatBottom,
                        colors: [amberTint.opacity(0.60), lavenderTint.opacity(0.60)],
                        strokeColor: mainStrokeColor,
                        lineWidth: 0.65
                    )
                }
            } else {
                // 适配器旁路直通模式: 适配器(蓝) -> 电脑硬件(紫) (及 USB外供)
                if hasUsb, let usbRect = usbRect {
                    let totalW = max(1.0, model.adapterWatts)
                    let usbW = model.subsystem.usbOutWatts
                    let lapW = max(0.5, totalW - usbW)
                    let rLap = max(0.25, min(0.75, lapW / totalW))
                    
                    let srcH = srcFlatBottom - srcFlatTop
                    let hLap = (srcH - gap) * CGFloat(rLap)
                    
                    // 上路: 适配器 -> 电脑硬件 (顶边完全水平直通电脑卡片顶边)
                    let yLap0 = srcFlatTop
                    let yLap1 = yLap0 + hLap
                    drawSankeyRibbon(
                        context: context,
                        x0: srcRect.maxX - 0.5,
                        y0Top: yLap0,
                        y0Bottom: yLap1,
                        x1: laptopRect.minX + 0.5,
                        y1Top: lapFlatTop,
                        y1Bottom: lapFlatBottom,
                        colors: [blueTint.opacity(0.60), lavenderTint.opacity(0.60)],
                        strokeColor: mainStrokeColor,
                        lineWidth: 0.65
                    )
                    
                    // 下路: 适配器 -> USB外供 (底边完全水平直通USB卡片底边)
                    let yUsb0 = yLap1 + gap
                    let yUsb1 = srcFlatBottom
                    drawSankeyRibbon(
                        context: context,
                        x0: srcRect.maxX - 0.5,
                        y0Top: yUsb0,
                        y0Bottom: yUsb1,
                        x1: usbRect.minX + 0.5,
                        y1Top: usbRect.minY + 9.5,
                        y1Bottom: usbRect.maxY - 9.5,
                        colors: [blueTint.opacity(0.60), usbColor.opacity(0.60)],
                        strokeColor: mainStrokeColor,
                        lineWidth: 0.65
                    )
                } else {
                    // 无外供且不充电（旁路直通/80%暂缓）：电池卡片隐藏，电脑卡片高度与适配器对齐，能量流呈完全水平直线直供电脑
                    drawSankeyRibbon(
                        context: context,
                        x0: srcRect.maxX - 0.5,
                        y0Top: srcFlatTop,
                        y0Bottom: srcFlatBottom,
                        x1: laptopRect.minX + 0.5,
                        y1Top: lapFlatTop,
                        y1Bottom: lapFlatBottom,
                        colors: [blueTint.opacity(0.60), lavenderTint.opacity(0.60)],
                        strokeColor: mainStrokeColor,
                        lineWidth: 0.65
                    )
                }
            }
            
            // --- 第二级: 电脑硬件 -> 各活跃内部子系统 (仅电脑本体组件，不再混杂外接设备) ---
            var activeSubsystems: [(id: String, watts: Double, color: Color)] = []
            if model.subsystem.displayWatts > 0.01 { activeSubsystems.append(("sub_display", model.subsystem.displayWatts, displayColor)) }
            if model.subsystem.socWatts > 0.01 { activeSubsystems.append(("sub_soc", model.subsystem.socWatts, socColor)) }
            if model.subsystem.dramWatts > 0.01 { activeSubsystems.append(("sub_dram", model.subsystem.dramWatts, dramColor)) }
            if model.subsystem.diskWatts > 0.01 { activeSubsystems.append(("sub_disk", model.subsystem.diskWatts, diskColor)) }
            
            let count = activeSubsystems.count
            if count > 0 {
                let totalSubWatts = max(0.1, activeSubsystems.reduce(0.0) { $0 + $1.watts })
                let lapExitTop = laptopRect.minY + 9.5
                let lapExitBottom = laptopRect.maxY - 9.5
                let availH = max(10.0, lapExitBottom - lapExitTop)
                let spacing: CGFloat = 1.2
                let totalSpacing = CGFloat(count - 1) * spacing
                let ribbonAvailH = max(6.0, availH - totalSpacing)
                
                // 1. 权重归一化计算每个流向带在电脑右侧边缘的精确厚度
                let rawWeights = activeSubsystems.map { max(0.08, $0.watts / totalSubWatts) }
                let weightSum = max(0.1, rawWeights.reduce(0.0, +))
                let heights = rawWeights.map { ($0 / weightSum) * ribbonAvailH }
                
                // 2. 依次平铺流向带，严格无缝对接
                var currentLaptopY = lapExitTop
                let subStrokeColor = isDark ? Color.white.opacity(0.18) : Color.white.opacity(0.38)
                
                for (idx, sub) in activeSubsystems.enumerated() {
                    guard let targetRect = nodeFrames[sub.id] else { continue }
                    
                    let h = max(3.0, heights[idx])
                    let startY0 = currentLaptopY
                    let startY1 = min(lapExitBottom, startY0 + h)
                    currentLaptopY = startY1 + spacing
                    
                    // 目标端：精准对齐子系统卡片的左边界和上下高度 (严格在直边区域内，避开圆角)
                    let endY0 = targetRect.minY + 7.5
                    let endY1 = targetRect.maxY - 7.5
                    
                    drawSankeyRibbon(
                        context: context,
                        x0: laptopRect.maxX - 0.5,
                        y0Top: startY0,
                        y0Bottom: startY1,
                        x1: targetRect.minX + 0.5,
                        y1Top: endY0,
                        y1Bottom: endY1,
                        colors: [lavenderTint.opacity(0.65), sub.color.opacity(0.65)],
                        strokeColor: subStrokeColor,
                        lineWidth: 0.5
                    )
                }
            }
        }
    }
    
    // =========================================================================
    // MARK: - 精确平滑三次贝塞尔条带绘制引擎 (上下边界水平平滑切入，无垂直侧边封闭线，彻底消除圆角接缝瑕疵)
    // =========================================================================
    private func drawSankeyRibbon(
        context: GraphicsContext,
        x0: CGFloat, y0Top: CGFloat, y0Bottom: CGFloat,
        x1: CGFloat, y1Top: CGFloat, y1Bottom: CGFloat,
        colors: [Color],
        strokeColor: Color,
        lineWidth: CGFloat = 0.6
    ) {
        // 使用 0.38 比例因子确保贝塞尔控制点在水平方向严格单调不交叠，杜绝自交或反向弯折扭曲
        let dx = max(8, (x1 - x0) * 0.38)
        
        // 1. 构造闭合几何图形用于填充渐变
        var fillPath = Path()
        fillPath.move(to: CGPoint(x: x0, y: y0Top))
        fillPath.addCurve(
            to: CGPoint(x: x1, y: y1Top),
            control1: CGPoint(x: x0 + dx, y: y0Top),
            control2: CGPoint(x: x1 - dx, y: y1Top)
        )
        fillPath.addLine(to: CGPoint(x: x1, y: y1Bottom))
        fillPath.addCurve(
            to: CGPoint(x: x0, y: y0Bottom),
            control1: CGPoint(x: x1 - dx, y: y1Bottom),
            control2: CGPoint(x: x0 + dx, y: y0Bottom)
        )
        fillPath.closeSubpath()
        
        let grad = Gradient(colors: colors)
        context.fill(
            fillPath,
            with: .linearGradient(
                grad,
                startPoint: CGPoint(x: x0, y: (y0Top + y0Bottom) / 2),
                endPoint: CGPoint(x: x1, y: (y1Top + y1Bottom) / 2)
            )
        )
        
        // 2. 仅描绘上下两条流向边界曲线 (严格同向从 x0 到 x1 构造，杜绝倒置控制点)
        var topBorder = Path()
        topBorder.move(to: CGPoint(x: x0, y: y0Top))
        topBorder.addCurve(
            to: CGPoint(x: x1, y: y1Top),
            control1: CGPoint(x: x0 + dx, y: y0Top),
            control2: CGPoint(x: x1 - dx, y: y1Top)
        )
        context.stroke(topBorder, with: .color(strokeColor), lineWidth: lineWidth)
        
        var bottomBorder = Path()
        bottomBorder.move(to: CGPoint(x: x0, y: y0Bottom))
        bottomBorder.addCurve(
            to: CGPoint(x: x1, y: y1Bottom),
            control1: CGPoint(x: x0 + dx, y: y0Bottom),
            control2: CGPoint(x: x1 - dx, y: y1Bottom)
        )
        context.stroke(bottomBorder, with: .color(strokeColor), lineWidth: lineWidth)
    }
}
