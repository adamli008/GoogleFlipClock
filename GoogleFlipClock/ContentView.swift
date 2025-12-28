import SwiftUI
import Combine
import Foundation

// MARK: - Models

struct ThemeModel {
    var id: String; var name: String
    var backgroundColor: Color; var foregroundColor: Color
    var cardColor: Color; var dividerColor: Color; var shadowRadius: CGFloat
    static let classic = ThemeModel(
        id: "classic", name: "Classic Black",
        backgroundColor: .black, foregroundColor: .white,
        cardColor: Color(white: 0.15), dividerColor: .black, shadowRadius: 5
    )
}

enum ClockMode: String, CaseIterable { case clock, timer, countdown }

class ModeManager: ObservableObject {
    static let shared = ModeManager()
    @Published var currentMode: ClockMode = .clock
    private init() {}
}

class TimeManager: ObservableObject {
    static let shared = TimeManager()
    @Published var currentDate = Date()
    private var timer: AnyCancellable?
    private init() { start() }
    func start() {
        timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
            .sink { [weak self] d in self?.currentDate = d }
    }
}

// MARK: - ViewModels

class ClockViewModel: ObservableObject {
    @Published var hours: [Int] = [0, 0]; @Published var minutes: [Int] = [0, 0]; @Published var seconds: [Int] = [0, 0]
    @Published var dateString: String = ""; @Published var weekdayString: String = ""; @Published var is24Hour: Bool = true
    private var cancel = Set<AnyCancellable>()
    init() {
        TimeManager.shared.$currentDate.receive(on: RunLoop.main)
            .sink { [weak self] d in self?.update(d) }.store(in: &cancel)
    }
    private func update(_ d: Date) {
        let cal = Calendar.current
        var h = cal.component(.hour, from: d); let m = cal.component(.minute, from: d); let s = cal.component(.second, from: d)
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy . MM . dd"; dateString = fmt.string(from: d)
        let wfmt = DateFormatter(); wfmt.locale = Locale(identifier: "zh_CN"); wfmt.dateFormat = "EEEE"; weekdayString = wfmt.string(from: d)
        if !is24Hour { h = h % 12; if h == 0 { h = 12 } }
        hours = [h / 10, h % 10]; minutes = [m / 10, m % 10]; seconds = [s / 10, s % 10]
    }
}

class TimerViewModel: ObservableObject {
    @Published var hours: [Int] = [0, 0]; @Published var minutes: [Int] = [0, 0]; @Published var seconds: [Int] = [0, 0]
    @Published var isRunning: Bool = false
    private var elapsed: Int = 0; private var timer: AnyCancellable?
    func toggle() { if isRunning { stop() } else { start() } }
    func start() {
        isRunning = true
        timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
            .sink { [weak self] _ in self?.elapsed += 1; self?.update() }
    }
    func stop() { isRunning = false; timer?.cancel() }
    func reset() { stop(); elapsed = 0; update() }
    private func update() {
        let h = elapsed / 3600; let m = (elapsed % 3600) / 60; let s = elapsed % 60
        hours = [h / 10, h % 10]; minutes = [m / 10, m % 10]; seconds = [s / 10, s % 10]
    }
}

class CountdownViewModel: ObservableObject {
    @Published var minutes: [Int] = [1, 0]; @Published var seconds: [Int] = [0, 0]; @Published var isRunning: Bool = false
    private var total: Int = 600; private var timer: AnyCancellable?
    func toggle() { if isRunning { stop() } else { start() } }
    func start() {
        guard total > 0 else { return }; isRunning = true
        timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                if self.total > 0 { self.total -= 1; self.update() } else { self.stop() }
            }
    }
    func stop() { isRunning = false; timer?.cancel() }
    func reset(to mins: Int = 10) { stop(); total = mins * 60; update() }
    private func update() {
        let m = total / 60; let s = total % 60
        minutes = [m / 10, m % 10]; seconds = [s / 10, s % 10]
    }
}

// MARK: - Components

struct HalfCardShape: Shape {
    let isTop: Bool
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let hh = rect.height / 2.0; let g: CGFloat = 0.5
        if isTop { path.addRect(CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: hh - g)) }
        else { path.addRect(CGRect(x: rect.minX, y: rect.minY + hh + g, width: rect.width, height: hh - g)) }
        return path
    }
}

struct FlipCard: View {
    let value: String; let isTop: Bool; let theme: ThemeModel
    var body: some View {
        GeometryReader { geo in
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(isTop ? Color(white: 0.18) : Color(white: 0.15))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 0.5))
                Text(value).font(.system(size: geo.size.height * 0.85, weight: .bold, design: .rounded))
                    .foregroundColor(theme.foregroundColor).frame(maxWidth: .infinity, maxHeight: .infinity)
                HStack {
                    Rectangle().fill(Color.black.opacity(0.5)).frame(width: 3, height: 8)
                    Spacer()
                    Rectangle().fill(Color.black.opacity(0.5)).frame(width: 3, height: 8)
                }.padding(.horizontal, 1)
            }
            .clipShape(HalfCardShape(isTop: isTop))
            .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: isTop ? 1 : -1)
        }
    }
}

struct FlipDigit: View {
    let value: Int; let theme: ThemeModel
    @State private var cur: Int = 0; @State private var nxt: Int = 0
    @State private var rot: Double = 0; @State private var anim: Bool = false
    var body: some View {
        ZStack {
            FlipCard(value: "\(nxt)", isTop: true, theme: theme)
            FlipCard(value: "\(cur)", isTop: false, theme: theme)
            FlipCard(value: "\(cur)", isTop: true, theme: theme)
                .rotation3DEffect(.degrees(rot), axis: (x: CGFloat(1), y: CGFloat(0), z: CGFloat(0)), anchor: .center, perspective: 0.4)
                .zIndex(rot < -90 ? -1.0 : 1.0)
                .opacity(rot < -90 ? 0.0 : 1.0)
            FlipCard(value: "\(nxt)", isTop: false, theme: theme)
                .rotation3DEffect(.degrees(rot + 180), axis: (x: CGFloat(1), y: CGFloat(0), z: CGFloat(0)), anchor: .center, perspective: 0.4)
                .zIndex(rot < -90 ? 1.0 : -1.0)
                .opacity(rot < -90 ? 1.0 : 0.0)
        }
        .aspectRatio(CGFloat(0.7), contentMode: .fit)
        .onAppear { cur = value; nxt = value }
        .onChange(of: value) { newVal in animate(to: newVal) }
    }
    private func animate(to: Int) {
        if anim { nxt = to; return }
        anim = true; nxt = to; rot = 0
        withAnimation(.spring(response: 0.45, dampingFraction: 0.6, blendDuration: 0)) { rot = -180 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { cur = to; rot = 0; anim = false }
    }
}

struct TimeGroup: View {
    let digits: [Int]; let theme: ThemeModel
    var body: some View { HStack(spacing: 8) { ForEach(0..<digits.count, id: \.self) { FlipDigit(value: digits[$0], theme: theme) } } }
}

// MARK: - Views

struct FlipClockView: View {
    @StateObject private var vm = ClockViewModel(); var theme: ThemeModel
    var body: some View {
        GeometryReader { geo in
            let ih = geo.size.height * 0.55
            VStack(spacing: geo.size.height * 0.05) {
                Spacer()
                Text(vm.dateString).font(.system(size: geo.size.height * 0.07, weight: .medium, design: .rounded))
                    .foregroundColor(theme.foregroundColor.opacity(0.6)).tracking(2)
                Text(vm.weekdayString).font(.system(size: geo.size.height * 0.05, weight: .regular, design: .rounded))
                    .foregroundColor(theme.foregroundColor.opacity(0.4)).tracking(1)
                HStack(spacing: geo.size.width * 0.02) {
                    Spacer(); TimeGroup(digits: vm.hours, theme: theme).frame(height: ih)
                    VStack(spacing: ih * 0.15) { Circle().fill(Color.gray).frame(width: ih * 0.08, height: ih * 0.08); Circle().fill(Color.gray).frame(width: ih * 0.08, height: ih * 0.08) }.frame(height: ih)
                    TimeGroup(digits: vm.minutes, theme: theme).frame(height: ih)
                    VStack(spacing: ih * 0.15) { Circle().fill(Color.gray).frame(width: ih * 0.08, height: ih * 0.08); Circle().fill(Color.gray).frame(width: ih * 0.08, height: ih * 0.08) }.frame(height: ih)
                    TimeGroup(digits: vm.seconds, theme: theme).frame(height: ih); Spacer()
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity).background(theme.backgroundColor)
        }
    }
}

struct TimerView: View {
    @StateObject private var vm = TimerViewModel(); var theme: ThemeModel
    var body: some View {
        GeometryReader { geo in
            let ih = geo.size.height * 0.5
            VStack(spacing: geo.size.height * 0.05) {
                HStack(spacing: geo.size.width * 0.02) {
                    TimeGroup(digits: vm.hours, theme: theme).frame(height: ih)
                    VStack(spacing: ih * 0.15) { Circle().fill(Color.gray).frame(width: ih * 0.08, height: ih * 0.08); Circle().fill(Color.gray).frame(width: ih * 0.08, height: ih * 0.08) }.frame(height: ih)
                    TimeGroup(digits: vm.minutes, theme: theme).frame(height: ih)
                    VStack(spacing: ih * 0.15) { Circle().fill(Color.gray).frame(width: ih * 0.08, height: ih * 0.08); Circle().fill(Color.gray).frame(width: ih * 0.08, height: ih * 0.08) }.frame(height: ih)
                    TimeGroup(digits: vm.seconds, theme: theme).frame(height: ih)
                }
                HStack(spacing: 40) {
                    Button(action: vm.reset) { Image(systemName: "arrow.counterclockwise").font(.system(size: geo.size.height * 0.1)) }.buttonStyle(.plain)
                    Button(action: vm.toggle) { Image(systemName: vm.isRunning ? "pause.fill" : "play.fill").font(.system(size: geo.size.height * 0.15)) }.buttonStyle(.plain)
                }.foregroundColor(theme.foregroundColor)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity).background(theme.backgroundColor)
        }
    }
}

struct CountdownView: View {
    @StateObject private var vm = CountdownViewModel(); var theme: ThemeModel
    @State private var custom: String = "10"
    var body: some View {
        GeometryReader { geo in
            let ih = geo.size.height * 0.5
            VStack(spacing: geo.size.height * 0.05) {
                HStack(spacing: geo.size.width * 0.02) {
                    TimeGroup(digits: vm.minutes, theme: theme).frame(height: ih)
                    VStack(spacing: ih * 0.15) { Circle().fill(Color.gray).frame(width: ih * 0.08, height: ih * 0.08); Circle().fill(Color.gray).frame(width: ih * 0.08, height: ih * 0.08) }.frame(height: ih)
                    TimeGroup(digits: vm.seconds, theme: theme).frame(height: ih)
                }
                HStack(spacing: 15) {
                    TextField("Mins", text: $custom).textFieldStyle(.plain).padding(8).background(Color.white.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 8)).frame(width: 60).multilineTextAlignment(.center)
                    Button("Set") { if let m = Int(custom) { vm.reset(to: m) } }.buttonStyle(.bordered)
                    Rectangle().fill(Color.gray.opacity(0.3)).frame(width: 1, height: 20)
                    Button("10m") { vm.reset(to: 10); custom = "10" }
                    Button("25m") { vm.reset(to: 25); custom = "25" }
                }
                HStack(spacing: 40) {
                    Button(action: { if let m = Int(custom) { vm.reset(to: m) } else { vm.reset(to: 10) } }) { Image(systemName: "arrow.counterclockwise").font(.system(size: geo.size.height * 0.1)) }.buttonStyle(.plain)
                    Button(action: vm.toggle) { Image(systemName: vm.isRunning ? "pause.fill" : "play.fill").font(.system(size: geo.size.height * 0.15)) }.buttonStyle(.plain)
                }.foregroundColor(theme.foregroundColor)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity).background(theme.backgroundColor)
        }
    }
}

struct ContentView: View {
    @StateObject private var mm = ModeManager.shared; @State private var theme: ThemeModel = .classic
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            VStack {
                Group {
                    switch mm.currentMode {
                    case .clock: FlipClockView(theme: theme)
                    case .timer: TimerView(theme: theme)
                    case .countdown: CountdownView(theme: theme)
                    }
                }
                .aspectRatio(CGFloat(1.777), contentMode: .fit).clipShape(RoundedRectangle(cornerRadius: 20)).shadow(color: .black.opacity(0.4), radius: 15).padding(20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            VStack {
                Spacer(); HStack(spacing: 20) {
                    ForEach(ClockMode.allCases, id: \.self) { mode in
                        Button(action: { mm.currentMode = mode }) {
                            Text(mode.rawValue.capitalized).padding(.horizontal, 10).padding(.vertical, 5)
                                .background(mm.currentMode == mode ? Color.white.opacity(0.2) : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 5))
                        }.buttonStyle(.plain)
                    }
                }.padding().background(Color.black.opacity(0.4)).clipShape(RoundedRectangle(cornerRadius: 10)).opacity(0.3)
            }.padding(.bottom, 20)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if let window = NSApp.windows.first(where: { $0.canBecomeKey }) {
                    if !window.styleMask.contains(.fullScreen) {
                        window.toggleFullScreen(nil)
                    }
                }
            }
        }
    }
}
