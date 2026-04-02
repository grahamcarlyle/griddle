import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @ObservedObject var configStore: ConfigStore
    var hotkeyManager: HotkeyManager

    @State private var newCols = 3
    @State private var newRows = 2
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                Text("Griddle")
                    .font(.headline)
                    .padding(.top, 4)

                // MARK: - Layout Section
                GroupBox("Layout") {
                    VStack(alignment: .leading, spacing: 8) {
                        LabeledContent("Default") {
                            Picker("", selection: Binding(
                                get: { configStore.config.activeLayoutID },
                                set: { id in
                                    configStore.setActiveLayout(id: id)
                                    hotkeyManager.update(config: configStore.config)
                                }
                            )) {
                                ForEach(configStore.config.layouts) { layout in
                                    Text(layout.name).tag(layout.id)
                                }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                        }

                        screenLayoutRows

                        DisclosureGroup("Add / Remove") {
                            HStack(spacing: 8) {
                                Stepper("Cols: \(newCols)", value: $newCols, in: 1...6)
                                Stepper("Rows: \(newRows)", value: $newRows, in: 1...4)
                            }
                            .font(.caption)

                            HStack {
                                Button("Add \(newCols)×\(newRows)") {
                                    let id = "\(newCols)x\(newRows)_\(Int(Date().timeIntervalSince1970))"
                                    let layout = GridLayout.uniform(id: id, name: "\(newCols)×\(newRows)", columns: newCols, rows: newRows)
                                    configStore.addLayout(layout)
                                    configStore.setActiveLayout(id: id)
                                    hotkeyManager.update(config: configStore.config)
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)

                                if configStore.config.layouts.count > 1 {
                                    Button("Remove", role: .destructive) {
                                        configStore.removeLayout(id: configStore.config.activeLayoutID)
                                        hotkeyManager.update(config: configStore.config)
                                    }
                                    .controlSize(.small)
                                }
                            }
                        }
                        .font(.caption)
                    }
                }

                // MARK: - Grid Preview
                if let layout = configStore.activeLayout {
                    GridPreviewView(
                        layout: layout,
                        keyLabels: HotkeyManager.keyLabels(for: configStore.config.keyStyle, columns: layout.columns, rows: layout.rows)
                    )
                    .frame(height: 100)
                }

                // MARK: - Hotkeys Section
                GroupBox("Hotkeys") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            ForEach(["ctrl", "alt", "cmd", "shift"], id: \.self) { key in
                                Toggle(key, isOn: Binding(
                                    get: { configStore.config.modifier.keys.contains(key) },
                                    set: { isOn in
                                        var keys = configStore.config.modifier.keys
                                        if isOn { keys.append(key) } else { keys.removeAll(where: { $0 == key }) }
                                        configStore.config.modifier.keys = keys
                                        hotkeyManager.update(config: configStore.config)
                                    }
                                ))
                                .toggleStyle(.button)
                                .controlSize(.small)
                            }
                        }

                        LabeledContent("Keys") {
                            Picker("", selection: Binding(
                                get: { configStore.config.keyStyle },
                                set: { style in
                                    configStore.config.keyStyle = style
                                    hotkeyManager.update(config: configStore.config)
                                }
                            )) {
                                Text("Spatial (Q/W/E)").tag(KeyStyle.spatial)
                                Text("Numbers (1–9)").tag(KeyStyle.numbers)
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                        }

                        LabeledContent("Theme") {
                            Picker("", selection: Binding(
                                get: { configStore.config.hudTheme },
                                set: { theme in
                                    configStore.config.hudTheme = theme
                                }
                            )) {
                                Text("System").tag(HUDTheme.system)
                                Text("Green").tag(HUDTheme.green)
                                Text("High Contrast").tag(HUDTheme.highContrast)
                                Text("Purple").tag(HUDTheme.purple)
                                Text("Orange").tag(HUDTheme.orange)
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                        }

                        Text("Tap modifiers to show grid, or hold modifier + key for instant move")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                // MARK: - Footer
                Spacer()

                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in
                        do {
                            if newValue {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            NSLog("Griddle: Failed to update launch-at-login: \(error)")
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }

                HStack {
                    Spacer()
                    Button("Quit Griddle") {
                        NSApplication.shared.terminate(nil)
                    }
                }
            }
            .padding()
            .frame(width: 320)
    }

    // MARK: - Per-Screen Rows

    @ViewBuilder
    private var screenLayoutRows: some View {
        let screens = NSScreen.screens
        if screens.count > 1 {
            ForEach(screens, id: \.self) { screen in
                let key = GriddleConfig.screenKey(for: screen)
                LabeledContent(screen.localizedName) {
                    Picker("", selection: Binding(
                        get: {
                            configStore.config.screenLayouts[key] ?? ""
                        },
                        set: { id in
                            if id.isEmpty {
                                configStore.removeScreenLayout(screen: screen)
                            } else {
                                configStore.setScreenLayout(screen: screen, layoutID: id)
                            }
                            hotkeyManager.update(config: configStore.config)
                        }
                    )) {
                        Text("Default").tag("")
                        ForEach(configStore.config.layouts) { layout in
                            Text(layout.name).tag(layout.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
            }
        }
    }
}

// MARK: - Grid preview

struct GridPreviewView: View {
    let layout: GridLayout
    var keyLabels: [String]?

    var body: some View {
        GeometryReader { geo in
            let cellW = geo.size.width / CGFloat(layout.columns)
            let cellH = geo.size.height / CGFloat(layout.rows)

            ZStack {
                ForEach(Array(layout.cells.enumerated()), id: \.offset) { index, cell in
                    let x = CGFloat(cell.col) * cellW
                    let y = CGFloat(cell.row) * cellH
                    let w = cellW * CGFloat(cell.colSpan)
                    let h = cellH * CGFloat(cell.rowSpan)
                    let label = (keyLabels != nil && index < keyLabels!.count) ? keyLabels![index] : "\(index + 1)"

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.accentColor.opacity(0.15))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.accentColor, lineWidth: 1)
                        )
                        .overlay(
                            Text(label)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        )
                        .frame(width: w - 4, height: h - 4)
                        .position(x: x + w / 2, y: y + h / 2)
                }
            }
        }
    }
}
