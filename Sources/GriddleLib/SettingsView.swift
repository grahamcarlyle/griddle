import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @ObservedObject var configStore: ConfigStore
    var hotkeyManager: HotkeyManager

    @State private var showAddLayout = false
    @State private var newCols = 3
    @State private var newRows = 2
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Griddle")
                .font(.headline)
                .padding(.top, 8)

            activeLayoutPicker

            screenLayoutPickers

            layoutGrid

            Divider()

            modifierPicker

            keyStylePicker

            themePicker

            Divider()

            addLayoutButton

            Spacer()

            launchAtLoginToggle

            quitButton
        }
        .padding()
        .frame(width: 320)
    }

    // MARK: - Subviews

    private var activeLayoutPicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Default Layout")
                .font(.subheadline)
                .foregroundColor(.secondary)
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
    }

    private var screenLayoutPickers: some View {
        VStack(alignment: .leading, spacing: 8) {
            let screens = NSScreen.screens
            if screens.count > 1 {
                Text("Per-Screen Layouts")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                ForEach(screens, id: \.self) { screen in
                    let key = GriddleConfig.screenKey(for: screen)
                    HStack {
                        Text(screen.localizedName)
                            .font(.caption)
                            .lineLimit(1)
                        Spacer()
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
                        .frame(width: 120)
                    }
                }
            }
        }
    }

    private var layoutGrid: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let layout = configStore.activeLayout {
                Text("Grid Preview — \(layout.columns)×\(layout.rows)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                GridPreviewView(
                    layout: layout,
                    keyLabels: HotkeyManager.keyLabels(for: configStore.config.keyStyle, columns: layout.columns, rows: layout.rows)
                )
                    .frame(height: 120)
            }
        }
    }

    private var modifierPicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Modifier Keys")
                .font(.subheadline)
                .foregroundColor(.secondary)
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
                }
            }
            Text("Tap modifiers to show grid overlay, or hold modifier + key for instant move")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var keyStylePicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Key Style")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Picker("", selection: Binding(
                get: { configStore.config.keyStyle },
                set: { style in
                    configStore.config.keyStyle = style
                    hotkeyManager.update(config: configStore.config)
                }
            )) {
                Text("Spatial (Q/W/E, A/S/D, Z/X/C)").tag(KeyStyle.spatial)
                Text("Numbers (1–9)").tag(KeyStyle.numbers)
            }
            .pickerStyle(.menu)
            .labelsHidden()
        }
    }

    private var themePicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("HUD Theme")
                .font(.subheadline)
                .foregroundColor(.secondary)
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
    }

    private var addLayoutButton: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Add Layout")
                .font(.subheadline)
                .foregroundColor(.secondary)
            HStack {
                Stepper("Cols: \(newCols)", value: $newCols, in: 1...6)
                Stepper("Rows: \(newRows)", value: $newRows, in: 1...4)
            }
            Button("Add \(newCols)×\(newRows) Layout") {
                let id = "\(newCols)x\(newRows)_\(Int(Date().timeIntervalSince1970))"
                let layout = GridLayout.uniform(id: id, name: "\(newCols)×\(newRows)", columns: newCols, rows: newRows)
                configStore.addLayout(layout)
                configStore.setActiveLayout(id: id)
                hotkeyManager.update(config: configStore.config)
            }
            .buttonStyle(.borderedProminent)

            if configStore.config.layouts.count > 1 {
                Button("Remove Active Layout", role: .destructive) {
                    configStore.removeLayout(id: configStore.config.activeLayoutID)
                    hotkeyManager.update(config: configStore.config)
                }
            }
        }
    }

    private var launchAtLoginToggle: some View {
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
                    // Revert toggle on failure
                    launchAtLogin = SMAppService.mainApp.status == .enabled
                }
            }
    }

    private var quitButton: some View {
        HStack {
            Spacer()
            Button("Quit Griddle") {
                NSApplication.shared.terminate(nil)
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
