import SwiftUI

struct SettingsView: View {
    @Environment(ReadingSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section("字体大小") {
                Slider(value: $settings.fontSize, in: 12...32, step: 1)
                Text("示例经文 \(Int(settings.fontSize))pt")
                    .font(.system(size: settings.fontSize))
            }
            Section("外观") {
                Picker("主题", selection: $settings.colorScheme) {
                    ForEach(AppColorScheme.allCases) { scheme in
                        Text(scheme.label).tag(scheme)
                    }
                }
            }
        }
        .navigationTitle("设置")
    }
}
