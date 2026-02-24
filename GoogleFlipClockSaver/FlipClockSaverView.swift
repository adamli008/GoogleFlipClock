import AppKit
import Foundation
import ScreenSaver

/**
 * 屏保主视图：纯 AppKit 渲染，避免在部分机器上出现 SwiftUI 渲染调试红条。
 * 使用 30fps 帧驱动数字翻页动画，视觉尽量贴近 Mac 主程序版本。
 */
final class FlipClockSaverView: ScreenSaverView {

    private let clockCanvas = FlipClockCanvasView()

    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        animationTimeInterval = 1.0 / 30.0
        clockCanvas.frame = bounds
        clockCanvas.autoresizingMask = [.width, .height]
        addSubview(clockCanvas)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func animateOneFrame() {
        super.animateOneFrame()
        clockCanvas.tickFrame()
    }
}

/**
 * 纯 AppKit 时钟画布：绘制日期、星期与翻页数字，并在秒变化时触发翻页动画。
 */
private final class FlipClockCanvasView: NSView {

    /** 单个数字位的翻页状态。 */
    private struct DigitFlipState {
        var current: Int
        var next: Int
        var progress: CGFloat
        var isAnimating: Bool
        var startTime: TimeInterval
    }

    private var currentDate = Date()
    private var lastSecond = -1
    private let animationDuration: TimeInterval = 0.52
    private var digits: [DigitFlipState] = Array(
        repeating: DigitFlipState(current: 0, next: 0, progress: 0, isAnimating: false, startTime: 0),
        count: 6
    )

    private let versionBadgeText = FlipClockCanvasView.makeVersionBadgeText()

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        let initial = Self.makeDigits(from: currentDate)
        for i in 0 ..< 6 {
            digits[i] = DigitFlipState(current: initial[i], next: initial[i], progress: 0, isAnimating: false, startTime: 0)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        drawBackground()
        drawDateAndWeekday()
        drawClockCards()
        drawVersionBadge()
    }

    /// 每帧更新：检测秒变化触发翻页，并推进动画进度。
    func tickFrame() {
        let now = Date()
        currentDate = now
        let second = Calendar.current.component(.second, from: now)
        if lastSecond == -1 {
            lastSecond = second
        } else if second != lastSecond {
            lastSecond = second
            let newDigits = Self.makeDigits(from: now)
            startFlipIfNeeded(newDigits: newDigits, now: now.timeIntervalSinceReferenceDate)
        }
        updateAnimationProgress(now: now.timeIntervalSinceReferenceDate)
        needsDisplay = true
    }

    private func drawBackground() {
        NSColor.black.setFill()
        bounds.fill()
    }

    private func drawDateAndWeekday() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy . MM . dd"
        let dateText = dateFormatter.string(from: currentDate)

        let weekdayFormatter = DateFormatter()
        weekdayFormatter.locale = Locale(identifier: "zh_CN")
        weekdayFormatter.dateFormat = "EEEE"
        let weekdayText = weekdayFormatter.string(from: currentDate)

        let dateFont = roundedFont(size: max(18, bounds.height * 0.065), weight: .medium)
        let weekdayFont = roundedFont(size: max(14, bounds.height * 0.045), weight: .regular)

        let dateAttrs: [NSAttributedString.Key: Any] = [
            .font: dateFont,
            .foregroundColor: NSColor.white.withAlphaComponent(0.65),
            .kern: 2.0
        ]
        let weekdayAttrs: [NSAttributedString.Key: Any] = [
            .font: weekdayFont,
            .foregroundColor: NSColor.white.withAlphaComponent(0.45),
            .kern: 1.0
        ]

        let dateSize = dateText.size(withAttributes: dateAttrs)
        let weekdaySize = weekdayText.size(withAttributes: weekdayAttrs)

        let dateX = (bounds.width - dateSize.width) * 0.5
        let weekdayX = (bounds.width - weekdaySize.width) * 0.5
        let dateY = bounds.height * 0.12
        let weekdayY = dateY + dateSize.height + 10

        dateText.draw(at: NSPoint(x: dateX, y: dateY), withAttributes: dateAttrs)
        weekdayText.draw(at: NSPoint(x: weekdayX, y: weekdayY), withAttributes: weekdayAttrs)
    }

    private func drawClockCards() {
        let digitGap = bounds.width * 0.008

        let cardH = min(bounds.height * 0.46, bounds.width * 0.19)
        let cardW = cardH * 0.70
        let y = bounds.height * 0.38
        let groupW = cardW * 2 + digitGap
        let colonW = max(10.0, cardW * 0.16)

        // 四段间距保持一致：左边距 / 时分间距 / 分秒间距 / 右边距
        let baseGap = max(cardW * 0.28, bounds.width * 0.035)
        let totalW = groupW * 3 + baseGap * 4
        let x0 = (bounds.width - totalW) * 0.5
        var x = x0 + baseGap

        drawDigit(state: digits[0], in: NSRect(x: x, y: y, width: cardW, height: cardH))
        x += cardW + digitGap
        drawDigit(state: digits[1], in: NSRect(x: x, y: y, width: cardW, height: cardH))
        x += cardW
        drawColon(atX: x + (baseGap - colonW) * 0.5, y: y, height: cardH)
        x += baseGap

        drawDigit(state: digits[2], in: NSRect(x: x, y: y, width: cardW, height: cardH))
        x += cardW + digitGap
        drawDigit(state: digits[3], in: NSRect(x: x, y: y, width: cardW, height: cardH))
        x += cardW
        drawColon(atX: x + (baseGap - colonW) * 0.5, y: y, height: cardH)
        x += baseGap

        drawDigit(state: digits[4], in: NSRect(x: x, y: y, width: cardW, height: cardH))
        x += cardW + digitGap
        drawDigit(state: digits[5], in: NSRect(x: x, y: y, width: cardW, height: cardH))
    }

    /**
     * 绘制单个数字卡片：
     * - 静止状态：上下半卡片显示同一数字
     * - 动画状态：上半当前值收起 + 下半目标值展开，形成翻页视觉
     */
    private func drawDigit(state: DigitFlipState, in rect: NSRect) {
        let corner: CGFloat = 10
        let halfH = rect.height * 0.5
        let topRect = NSRect(x: rect.minX, y: rect.minY, width: rect.width, height: halfH - 0.5)
        let bottomRect = NSRect(x: rect.minX, y: rect.midY + 0.5, width: rect.width, height: halfH - 0.5)

        let topPhase: CGFloat = 0.34 // 上半卡更快结束
        let p = max(0, min(1, state.progress))
        let isBottomPhase = state.isAnimating && p >= topPhase

        let topBase = state.isAnimating ? state.next : state.current
        // 到达中点后，底部静态层切到新数字，符合真实翻页观感
        let bottomBase = isBottomPhase ? state.next : state.current

        drawHalf(clipRect: topRect, fullRect: rect, value: topBase, isTop: true)
        drawHalf(clipRect: bottomRect, fullRect: rect, value: bottomBase, isTop: false)
        NSColor.white.withAlphaComponent(0.10).setStroke()
        let border = NSBezierPath(roundedRect: rect, xRadius: corner, yRadius: corner)
        border.lineWidth = 0.6
        border.stroke()
        NSColor.black.withAlphaComponent(0.35).setFill()
        NSRect(x: rect.minX, y: rect.midY - 0.5, width: rect.width, height: 1.0).fill()

        drawHingePins(in: rect)

        guard state.isAnimating else { return }
        let bottomPhase = 1.0 - topPhase

        if p < topPhase {
            let t = max(0, min(1, p / topPhase))
            let q = max(0.04, 1.0 - easeOutCubic(t))
            let h = topRect.height * q
            let animTop = NSRect(x: topRect.minX, y: topRect.maxY - h, width: topRect.width, height: h)
            drawHalf(clipRect: animTop, fullRect: rect, value: state.current, isTop: true)
            NSColor.black.withAlphaComponent(0.18).setFill()
            NSRect(x: animTop.minX, y: animTop.minY, width: animTop.width, height: 1.0).fill()
        } else {
            let t = max(0, min(1, (p - topPhase) / bottomPhase))
            let q = max(0.04, bottomFlipProgressWithBounce(t))
            let h = bottomRect.height * q
            let animBottom = NSRect(x: bottomRect.minX, y: bottomRect.minY, width: bottomRect.width, height: h)
            drawHalf(clipRect: animBottom, fullRect: rect, value: state.next, isTop: false)
            // 下半卡展开时增加翻转边缘阴影，让“展开”动作更明显
            NSColor.black.withAlphaComponent(0.30 * (1.0 - t)).setFill()
            NSRect(x: animBottom.minX, y: animBottom.maxY - 2, width: animBottom.width, height: 2.0).fill()
        }
    }

    /** 绘制卡片半区并裁剪数字文本，确保上下半对齐。 */
    private func drawHalf(clipRect: NSRect, fullRect: NSRect, value: Int, isTop: Bool) {
        let bg = isTop ? NSColor(calibratedWhite: 0.18, alpha: 1) : NSColor(calibratedWhite: 0.15, alpha: 1)
        bg.setFill()
        NSBezierPath(roundedRect: clipRect, xRadius: 8, yRadius: 8).fill()

        let text = "\(value)"
        let font = roundedFont(size: fullRect.height * 0.72, weight: .bold)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white
        ]
        let size = text.size(withAttributes: attrs)
        let tx = fullRect.midX - size.width * 0.5
        let ty = fullRect.midY - size.height * 0.55

        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: clipRect).addClip()
        text.draw(at: NSPoint(x: tx, y: ty), withAttributes: attrs)
        NSGraphicsContext.restoreGraphicsState()
    }

    /** 绘制中线两侧机械卡扣细节，提升与原版一致性。 */
    private func drawHingePins(in rect: NSRect) {
        let pinW: CGFloat = max(2.0, rect.width * 0.035)
        let pinH: CGFloat = max(6.0, rect.height * 0.06)
        let y = rect.midY - pinH * 0.5
        NSColor.black.withAlphaComponent(0.52).setFill()
        NSRect(x: rect.minX + 1, y: y, width: pinW, height: pinH).fill()
        NSRect(x: rect.maxX - pinW - 1, y: y, width: pinW, height: pinH).fill()
    }

    private func drawColon(atX x: CGFloat, y: CGFloat, height: CGFloat) {
        let r = max(2.0, height * 0.03)
        let cx = x + r
        let y1 = y + height * 0.35
        let y2 = y + height * 0.65

        NSColor.gray.setFill()
        NSBezierPath(ovalIn: NSRect(x: cx - r, y: y1 - r, width: r * 2, height: r * 2)).fill()
        NSBezierPath(ovalIn: NSRect(x: cx - r, y: y2 - r, width: r * 2, height: r * 2)).fill()
    }

    /// 在右下角绘制版本角标，便于在不同机器确认加载的屏保版本。
    private func drawVersionBadge() {
        let text = versionBadgeText
        let font = NSFont.monospacedSystemFont(ofSize: max(10, bounds.height * 0.016), weight: .medium)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white.withAlphaComponent(0.9)
        ]
        let textSize = text.size(withAttributes: attrs)
        let padX: CGFloat = 8
        let padY: CGFloat = 4
        let badgeSize = NSSize(width: textSize.width + padX * 2, height: textSize.height + padY * 2)
        let margin: CGFloat = 12

        let badgeRect = NSRect(
            x: bounds.width - badgeSize.width - margin,
            y: bounds.height - badgeSize.height - margin,
            width: badgeSize.width,
            height: badgeSize.height
        )
        drawBadge(text: text, in: badgeRect, attrs: attrs, padX: padX, padY: padY)
    }

    private func drawBadge(
        text: String,
        in rect: NSRect,
        attrs: [NSAttributedString.Key: Any],
        padX: CGFloat,
        padY: CGFloat
    ) {
        NSColor.black.withAlphaComponent(0.72).setFill()
        NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8).fill()
        NSColor.white.withAlphaComponent(0.25).setStroke()
        let border = NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8)
        border.lineWidth = 1
        border.stroke()

        let textRect = NSRect(
            x: rect.minX + padX,
            y: rect.minY + padY,
            width: rect.width - padX * 2,
            height: rect.height - padY * 2
        )
        text.draw(in: textRect, withAttributes: attrs)
    }

    /** 秒变化时，为发生变化的数字位启动翻页。 */
    private func startFlipIfNeeded(newDigits: [Int], now: TimeInterval) {
        for i in 0 ..< 6 {
            if digits[i].current != newDigits[i] {
                digits[i].next = newDigits[i]
                digits[i].progress = 0
                digits[i].isAnimating = true
                digits[i].startTime = now
            }
        }
    }

    /** 推进翻页动画进度并在结束时固化目标值。 */
    private func updateAnimationProgress(now: TimeInterval) {
        for i in 0 ..< 6 where digits[i].isAnimating {
            let t = CGFloat((now - digits[i].startTime) / animationDuration)
            if t >= 1.0 {
                digits[i].progress = 1.0
                digits[i].isAnimating = false
                digits[i].current = digits[i].next
            } else {
                digits[i].progress = max(0, t)
            }
        }
    }

    /** 从当前时间生成 HHMMSS 的 6 位数字数组。 */
    private static func makeDigits(from date: Date) -> [Int] {
        let cal = Calendar.current
        let h = cal.component(.hour, from: date)
        let m = cal.component(.minute, from: date)
        let s = cal.component(.second, from: date)
        return [h / 10, h % 10, m / 10, m % 10, s / 10, s % 10]
    }

    /** 创建圆角系统字体，尽量贴近主程序 rounded 风格。 */
    private func roundedFont(size: CGFloat, weight: NSFont.Weight) -> NSFont {
        let base = NSFont.systemFont(ofSize: size, weight: weight)
        if let roundedDescriptor = base.fontDescriptor.withDesign(.rounded),
           let rounded = NSFont(descriptor: roundedDescriptor, size: size) {
            return rounded
        }
        return base
    }

    /** 上半卡使用：快速结束的缓动。 */
    private func easeOutCubic(_ t: CGFloat) -> CGFloat {
        let u = 1 - t
        return 1 - u * u * u
    }

    /** 下半卡使用：相对平滑、稍慢的缓动。 */
    private func easeInOutQuad(_ t: CGFloat) -> CGFloat {
        if t < 0.5 {
            return 2 * t * t
        }
        return 1 - pow(-2 * t + 2, 2) / 2
    }

    /**
     * 下半卡展开进度（含轻微回弹）：
     * - 前 80% 时间：快速展开到 106%
     * - 后 20% 时间：从 106% 平滑回落到 100%
     */
    private func bottomFlipProgressWithBounce(_ t: CGFloat) -> CGFloat {
        let overshoot: CGFloat = 0.06
        if t < 0.8 {
            let u = t / 0.8
            return easeInOutQuad(u) * (1.0 + overshoot)
        }
        let u = (t - 0.8) / 0.2
        return (1.0 + overshoot) - overshoot * easeOutCubic(u)
    }

    /// 生成角标文本，优先显示 Info.plist 中的版本号与构建号。
    private static func makeVersionBadgeText() -> String {
        let info = Bundle.main.infoDictionary
        let shortVersion = info?["CFBundleShortVersionString"] as? String
        if let shortVersion {
            return "V\(shortVersion)"
        }
        return "V1.2"
    }
}
