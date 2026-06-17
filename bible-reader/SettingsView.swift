import SwiftUI

struct SettingsView: View {
    @Environment(ReadingSettings.self) private var settings
    let translationManager: TranslationManager

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
            Section("译本") {
                NavigationLink("译本管理") {
                    TranslationsView(manager: translationManager)
                }
            }
        }
        .navigationTitle("设置")
    }
}
