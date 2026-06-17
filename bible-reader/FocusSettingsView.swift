import SwiftUI
#if os(iOS)
import FamilyControls
#endif

struct FocusSettingsView: View {
    @Environment(FocusCoordinator.self) private var focus

    @State private var isEnabled = false
    @State private var targetMinutes = 20
    @State private var authDenied = false
#if os(iOS)
    @State private var selection = FamilyActivitySelection()
    @State private var showPicker = false
#endif

    var body: some View {
        Form {
            Section {
                Toggle("启用专注锁定", isOn: $isEnabled)
            } footer: {
                Text("未达每日目标前,屏蔽所选 App。需在系统授权「屏幕使用时间」。")
            }

            if isEnabled {
                Section("每日目标") {
                    Stepper("\(targetMinutes) 分钟", value: $targetMinutes, in: 5...180, step: 5)
                }
#if os(iOS)
                Section("屏蔽的 App") {
                    Button("选择要屏蔽的 App") { showPicker = true }
                }
#endif
                Section("今日进度") {
                    let p = focus.todayProgress()
                    ProgressView(
                        value: min(p.seconds, Double(p.target * 60)),
                        total: Double(max(p.target * 60, 1))
                    ) {
                        Text(p.isComplete ? "今日已完成 ✓" : "\(Int(p.seconds / 60)) / \(p.target) 分钟")
                    }
                    Text("连续达标 \(focus.currentStreak()) 天")
                        .foregroundStyle(.secondary)
                }
            }
            if authDenied {
                Section {
                    Text("未获授权,当前仅计时不屏蔽。请在系统「设置 → 屏幕使用时间」中允许本 App。")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("专注锁定")
        .onAppear {
            isEnabled = focus.plan.isEnabled
            targetMinutes = focus.plan.dailyTargetMinutes
#if os(iOS)
            if let data = focus.plan.selectionToken,
               let s = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) {
                selection = s
            }
#endif
        }
        .onChange(of: isEnabled) { _, on in
            Task { await toggleEnabled(on) }
        }
        .onChange(of: targetMinutes) { _, m in
            focus.setTarget(minutes: m)
        }
#if os(iOS)
        .familyActivityPicker(isPresented: $showPicker, selection: $selection)
        .onChange(of: selection) { _, sel in
            focus.setSelection(data: try? JSONEncoder().encode(sel))
        }
#endif
    }

    private func toggleEnabled(_ on: Bool) async {
        if on {
            do {
                try await focus.authorizeAndEnable()
                authDenied = !focus.isAuthorized
            } catch {
                authDenied = true
                focus.setEnabled(false)
                isEnabled = false
            }
        } else {
            focus.setEnabled(false)
            authDenied = false
        }
    }
}
