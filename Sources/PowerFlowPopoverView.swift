import SwiftUI
import AppKit

// MARK: - 整体弹窗面板 (纯正 Mac 单层原生 Popover 架构，彻底消除双重嵌套边框)
struct PowerFlowPopoverView: View {
    @ObservedObject var model: PowerModel
    
    @State private var isPowerBtnHovered = false
    
    var body: some View {
        VStack(spacing: 11) {
            // --- 顶部状态栏 ---
            HStack(alignment: .center) {
                HStack(spacing: 5) {
                    Image(systemName: "bolt.horizontal.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.orange)
                    Text("POWER FLOW")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .tracking(0.8)
                        .foregroundColor(.primary.opacity(0.82))
                }
                
                Spacer()
                
                // 供电模式胶囊
                HStack(spacing: 4) {
                    Circle()
                        .fill(stateColor)
                        .frame(width: 5.5, height: 5.5)
                        .shadow(color: stateColor.opacity(0.8), radius: 2)
                    Text(model.state.rawValue)
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundColor(stateColor)
                }
                .padding(.horizontal, 7.5)
                .padding(.vertical, 3.5)
                .background(
                    Capsule()
                        .fill(stateColor.opacity(0.12))
                        .overlay(Capsule().stroke(stateColor.opacity(0.25), lineWidth: 0.8))
                )
                .help(stateTooltip)
                
                // 电池电量气泡
                HStack(spacing: 3.5) {
                    Image(systemName: batteryIcon)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundColor(model.isCharging ? .mint : .primary)
                    Text("\(model.batteryPercent)%")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                }
                .foregroundColor(.primary)
                .padding(.horizontal, 7)
                .padding(.vertical, 3.5)
                .background(
                    Capsule()
                        .fill(Color.primary.opacity(0.06))
                        .overlay(Capsule().stroke(Color.primary.opacity(0.12), lineWidth: 0.8))
                )
                .help("当前电池电量: \(model.batteryPercent)%")
            }
            .padding(.horizontal, 2)
            
            // --- 核心：基于实际模块坐标与高度动态生成的 3 级全流向能量桑基图 ---
            LivePowerFlowSankey(model: model)
            
            // --- 底部精炼指标行 ---
            HStack(spacing: 8) {
                // 净流向指标
                HStack(spacing: 4.5) {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(netFlowColor)
                    Text(netFlowText)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 4.5)
                .frame(maxWidth: .infinity)
                .background(Color.primary.opacity(0.04))
                .cornerRadius(7)
                .pointingHand()
                .help("电池实时净功率流向")
                
                // 剩余充满 / 续航时间
                HStack(spacing: 4.5) {
                    Image(systemName: "clock")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.blue)
                    Text(timeText)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 4.5)
                .frame(maxWidth: .infinity)
                .background(Color.primary.opacity(0.04))
                .cornerRadius(7)
                .pointingHand()
                .help(timeTooltip)
            }
            .foregroundColor(.secondary)
            
            Divider()
                .opacity(0.18)
            
            // --- 底部硬件传感器参数与退出 ---
            HStack {
                HStack(spacing: 11) {
                    Label(String(format: "%.1f°C", model.temperature), systemImage: "thermometer.medium")
                    Label("\(model.cycleCount)次循环", systemImage: "arrow.triangle.2.circlepath")
                    Label(String(format: "%.2fV", model.voltage), systemImage: "bolt.shield")
                }
                .font(.system(size: 9.5, weight: .medium))
                .foregroundColor(.secondary.opacity(0.85))
                
                Spacer()
                
                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    Image(systemName: "power")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(isPowerBtnHovered ? .red : .secondary.opacity(0.65))
                        .padding(5)
                        .background(
                            Circle()
                                .fill(isPowerBtnHovered ? Color.red.opacity(0.15) : Color.clear)
                        )
                        .scaleEffect(isPowerBtnHovered ? 1.15 : 1.0)
                        .animation(.spring(response: 0.2), value: isPowerBtnHovered)
                }
                .buttonStyle(.plain)
                .pointingHand()
                .onHover { isPowerBtnHovered = $0 }
                .help("退出 Live Power Flow")
            }
            .padding(.horizontal, 2)
        }
        .padding(13)
        .frame(width: 366)
        // 关键：直接使用原生系统级毛玻璃背景，彻底移除多余的人工 .strokeBorder、.shadow 和 .padding(6)
        .background(
            VisualEffectBlur(material: .popover, blendingMode: .behindWindow)
        )
    }
    
    private var stateColor: Color {
        switch model.state {
        case .charging: return .mint
        case .hybrid: return .orange
        case .bypass: return .cyan
        case .battery: return .orange
        }
    }
    
    private var stateTooltip: String {
        switch model.state {
        case .charging: return "正在使用外部适配器向电池充电"
        case .hybrid: return "当前整机高负荷消耗超过了充电器额定功率，电池正在协助供电"
        case .bypass: return "外接电源直通电脑供电，电池处于待机状态"
        case .battery: return "正在由纯电池放电供电"
        }
    }
    
    private var netFlowColor: Color {
        if model.batteryWatts > 0.05 {
            return .mint
        } else if model.batteryWatts < -0.05 {
            return .orange
        }
        return .secondary
    }
    
    private var netFlowText: String {
        switch model.state {
        case .charging:
            return String(format: "充入: +%.1fW", model.batteryWatts)
        case .hybrid:
            return String(format: "协助: -%.1fW", abs(model.batteryWatts))
        case .bypass:
            return "电源直供 (0.0W)"
        case .battery:
            return String(format: "放电: -%.1fW", abs(model.batteryWatts))
        }
    }
    
    private var timeText: String {
        switch model.state {
        case .charging:
            return formatMinutes(model.timeRemainingMinutes, prefix: "充满")
        case .hybrid:
            return "充电器已拉满"
        case .bypass:
            return "电源已连接"
        case .battery:
            return formatMinutes(model.timeRemainingMinutes, prefix: "续航")
        }
    }
    
    private var timeTooltip: String {
        switch model.state {
        case .charging:
            return "预计充满时间: \(formatMinutes(model.timeRemainingMinutes, prefix: ""))\n(来自系统官方充电功率滑动积分)"
        case .battery:
            let sysTimeStr = model.timeRemainingSystemMins > 0 ? formatMinutes(model.timeRemainingSystemMins, prefix: "") : "计算中..."
            let physTimeStr = formatMinutes(model.timeRemainingMinutes, prefix: "")
            return "实时动态续航: \(physTimeStr)\n(基于当前 \(String(format: "%.1fW", model.systemWatts)) 功耗与当前可用电量实时换算)\n\nmacOS 慢速平滑时间: \(sysTimeStr)\n(苹果系统慢速历史指数移动平均，随负荷变动延迟较大)"
        case .hybrid:
            return "当前高负荷下外部输入不足，电池正在放电协助"
        case .bypass:
            return "外部电源直通电脑硬件供电，电池待机无需充电"
        }
    }
    
    private var batteryIcon: String {
        let p = model.batteryPercent
        if model.isCharging { return "battery.100percent.bolt" }
        if p >= 90 { return "battery.100" }
        if p >= 75 { return "battery.75" }
        if p >= 50 { return "battery.50" }
        if p >= 25 { return "battery.25" }
        return "battery.0"
    }
    
    private func formatMinutes(_ mins: Int, prefix: String) -> String {
        guard mins > 0 && mins < 1000 else { return "计算中..." }
        let h = mins / 60
        let m = mins % 60
        if h > 0 {
            return "\(prefix) \(h)h \(m)m"
        }
        return "\(prefix) \(m)分"
    }
}
