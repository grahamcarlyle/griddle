import SwiftUI
import ServiceManagement

public struct SettingsView: View {
    @ObservedObject var configStore: ConfigStore
    var hotkeyManager: HotkeyManager
    var screens: [ScreenInfo]

    public init(configStore: ConfigStore, hotkeyManager: HotkeyManager, screens: [ScreenInfo],
                manageLayoutsExpanded: Bool = false, proportionsExpanded: Bool = false,
                hotkeysExpanded: Bool = false) {
        self.configStore = configStore
        self.hotkeyManager = hotkeyManager
        self.screens = screens
        self._manageLayoutsExpanded = State(initialValue: manageLayoutsExpanded)
        self._proportionsExpanded = State(initialValue: proportionsExpanded)
        self._hotkeysExpanded = State(initialValue: hotkeysExpanded)
    }

    @State private var newCols = 3
    @State private var newRows = 2
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var editingLayoutID: String?
    @State private var editingName: String = ""
    @State private var manageLayoutsExpanded: Bool
    @State private var proportionsExpanded: Bool
    @State private var hotkeysExpanded: Bool

    public var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                Text("Griddle")
                    .font(.headline)
                    .padding(.top, 4)

                // MARK: - Layout Section
                GroupBox(label: Label("Layout", systemImage: "square.grid.2x2").font(.subheadline.bold())) {
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
                                    Text(layout.displayName).tag(layout.id)
                                }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                        }

                        screenLayoutRows

                        DisclosureGroup("Manage Layouts", isExpanded: $manageLayoutsExpanded) {
                            ScrollView {
                                VStack(alignment: .leading, spacing: 4) {
                                    ForEach(configStore.config.layouts) { layout in
                                        HStack(spacing: 6) {
                                            if layout.id == configStore.config.activeLayoutID {
                                                Image(systemName: "checkmark")
                                                    .foregroundColor(.accentColor)
                                                    .frame(width: 12)
                                            } else {
                                                Spacer().frame(width: 12)
                                            }

                                            if editingLayoutID == layout.id {
                                                TextField("Name", text: $editingName, onCommit: {
                                                    let trimmed = editingName.trimmingCharacters(in: .whitespaces)
                                                    if !trimmed.isEmpty {
                                                        configStore.renameLayout(id: layout.id, name: trimmed)
                                                    }
                                                    editingLayoutID = nil
                                                })
                                                .onExitCommand { editingLayoutID = nil }
                                                .textFieldStyle(.roundedBorder)
                                                .frame(maxWidth: 100)
                                            } else {
                                                Text(layout.displayName)

                                                let dims = "\(layout.columns)×\(layout.rows)"
                                                if layout.name != dims && !layout.name.hasPrefix(dims) {
                                                    Text(dims)
                                                        .foregroundColor(.secondary)
                                                }

                                                Button {
                                                    editingName = layout.name
                                                    editingLayoutID = layout.id
                                                } label: {
                                                    Image(systemName: "pencil")
                                                }
                                                .buttonStyle(.plain)
                                                .foregroundColor(.secondary)
                                            }

                                            if isDuplicate(layout) {
                                                Text("duplicate")
                                                    .font(.caption2)
                                                    .foregroundColor(.orange)
                                            }

                                            Spacer()

                                            if configStore.config.layouts.count > 1 {
                                                Button(role: .destructive) {
                                                    configStore.removeLayout(id: layout.id)
                                                    hotkeyManager.update(config: configStore.config)
                                                } label: {
                                                    Image(systemName: "minus.circle")
                                                }
                                                .buttonStyle(.plain)
                                                .foregroundColor(.red.opacity(0.7))
                                            }
                                        }
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            configStore.setActiveLayout(id: layout.id)
                                            hotkeyManager.update(config: configStore.config)
                                        }
                                    }
                                }
                            }
                            .frame(maxHeight: 100)

                            Divider()

                            HStack(spacing: 8) {
                                Stepper("Cols: \(newCols)", value: $newCols, in: 1...6)
                                Stepper("Rows: \(newRows)", value: $newRows, in: 1...4)
                            }

                            Button("Add \(newCols)×\(newRows)") {
                                let id = "\(newCols)x\(newRows)_\(Int(Date().timeIntervalSince1970))"
                                let existingCount = configStore.config.layouts.filter { $0.columns == newCols && $0.rows == newRows }.count
                                let name = existingCount > 0 ? "\(newCols)×\(newRows) (\(existingCount + 1))" : "\(newCols)×\(newRows)"
                                let layout = GridLayout.uniform(id: id, name: name, columns: newCols, rows: newRows)
                                configStore.addLayout(layout)
                                configStore.setActiveLayout(id: id)
                                hotkeyManager.update(config: configStore.config)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                        .font(.caption)
                    }
                }

                // MARK: - Grid Preview
                if let layout = configStore.activeLayout {
                    GridPreviewView(
                        layout: layout,
                        keyLabels: KeyMap.build(for: configStore.config.keyStyle, columns: layout.columns, rows: layout.rows).labels
                    )
                    .frame(height: 100)

                    // MARK: - Proportions
                    DisclosureGroup("Proportions", isExpanded: $proportionsExpanded) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Columns")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            ForEach(0..<layout.columns, id: \.self) { col in
                                let weight = layout.columnWeights?[col] ?? 1.0
                                HStack(spacing: 4) {
                                    Text("C\(col + 1)")
                                        .font(.caption2)
                                        .frame(width: 22, alignment: .leading)
                                    Slider(
                                        value: Binding(
                                            get: { layout.columnWeights?[col] ?? 1.0 },
                                            set: { val in
                                                configStore.setColumnWeight(layoutID: layout.id, index: col, value: val)
                                                hotkeyManager.update(config: configStore.config)
                                            }
                                        ),
                                        in: 0.1...5.0,
                                        step: 0.1
                                    )
                                    Text(String(format: "%.1f", weight))
                                        .font(.caption2)
                                        .frame(width: 24, alignment: .trailing)
                                }
                            }

                            Text("Rows")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            ForEach(0..<layout.rows, id: \.self) { row in
                                let weight = layout.rowWeights?[row] ?? 1.0
                                HStack(spacing: 4) {
                                    Text("R\(row + 1)")
                                        .font(.caption2)
                                        .frame(width: 22, alignment: .leading)
                                    Slider(
                                        value: Binding(
                                            get: { layout.rowWeights?[row] ?? 1.0 },
                                            set: { val in
                                                configStore.setRowWeight(layoutID: layout.id, index: row, value: val)
                                                hotkeyManager.update(config: configStore.config)
                                            }
                                        ),
                                        in: 0.1...5.0,
                                        step: 0.1
                                    )
                                    Text(String(format: "%.1f", weight))
                                        .font(.caption2)
                                        .frame(width: 24, alignment: .trailing)
                                }
                            }

                            HStack {
                                Spacer()
                                Button("Reset to Uniform") {
                                    configStore.resetWeights(layoutID: layout.id)
                                    hotkeyManager.update(config: configStore.config)
                                }
                                .controlSize(.small)
                                .disabled(!layout.hasCustomWeights)
                            }
                        }
                    }
                    .font(.caption)
                }

                // MARK: - Hotkeys Section
                DisclosureGroup(isExpanded: $hotkeysExpanded) {
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

                        LabeledContent("Cycle layout") {
                            Picker("", selection: Binding(
                                get: { configStore.config.cycleKey },
                                set: { key in
                                    configStore.config.cycleKey = key
                                    hotkeyManager.update(config: configStore.config)
                                }
                            )) {
                                ForEach(CycleKey.allCases, id: \.self) { key in
                                    Text(key.displayName).tag(key)
                                }
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
                } label: {
                    Label("Hotkeys", systemImage: "keyboard").font(.subheadline.bold())
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
                    Text(versionLabel)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Quit Griddle") {
                        NSApplication.shared.terminate(nil)
                    }
                }
            }
            .padding()
            .frame(width: 320)
    }

    // MARK: - Version

    private var versionLabel: String {
        if let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String, !v.isEmpty {
            return "v\(v)"
        }
        return "dev"
    }

    // MARK: - Duplicate Detection

    private func isDuplicate(_ layout: GridLayout) -> Bool {
        let colWeights = layout.normalizedColumnWeights()
        let rowWeights = layout.normalizedRowWeights()
        return configStore.config.layouts.contains { other in
            other.id != layout.id
                && other.columns == layout.columns
                && other.rows == layout.rows
                && other.normalizedColumnWeights().elementsEqual(colWeights, by: { abs($0 - $1) < 0.001 })
                && other.normalizedRowWeights().elementsEqual(rowWeights, by: { abs($0 - $1) < 0.001 })
        }
    }

    // MARK: - Per-Screen Rows

    @ViewBuilder
    private var screenLayoutRows: some View {
        if screens.count > 1 {
            ForEach(screens) { screen in
                let screenLayouts = configStore.config.layoutsForScreen(key: screen.id)
                let hasCustomPool = configStore.config.screenLayoutPools[screen.id] != nil

                DisclosureGroup {
                    let useAll = Binding(
                        get: { !hasCustomPool },
                        set: { isOn in
                            if isOn {
                                configStore.clearScreenLayoutPool(screen: screen)
                                configStore.removeScreenLayout(screen: screen)
                            } else {
                                configStore.setScreenLayoutPool(screen: screen, layoutIDs: configStore.config.layouts.map(\.id))
                            }
                            hotkeyManager.update(config: configStore.config)
                        }
                    )
                    Toggle("Use all layouts", isOn: useAll)

                    if hasCustomPool {
                        ForEach(configStore.config.layouts) { layout in
                            Toggle(layout.name, isOn: Binding(
                                get: {
                                    configStore.config.screenLayoutPools[screen.id]?.contains(layout.id) ?? true
                                },
                                set: { isOn in
                                    var pool = configStore.config.screenLayoutPools[screen.id] ?? configStore.config.layouts.map(\.id)
                                    if isOn {
                                        if !pool.contains(layout.id) { pool.append(layout.id) }
                                    } else {
                                        pool.removeAll { $0 == layout.id }
                                    }
                                    if Set(pool) == Set(configStore.config.layouts.map(\.id)) {
                                        configStore.clearScreenLayoutPool(screen: screen)
                                        configStore.removeScreenLayout(screen: screen)
                                    } else if pool.isEmpty {
                                        return
                                    } else {
                                        configStore.setScreenLayoutPool(screen: screen, layoutIDs: pool)
                                        if let current = configStore.config.screenLayouts[screen.id],
                                           !pool.contains(current) {
                                            configStore.setScreenLayout(screen: screen, layoutID: pool.first!)
                                        }
                                    }
                                    hotkeyManager.update(config: configStore.config)
                                }
                            ))
                        }
                    }
                } label: {
                    HStack {
                        Text(screen.localizedName)
                        Spacer()
                        Picker("", selection: Binding(
                            get: {
                                configStore.config.screenLayouts[screen.id] ?? ""
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
                            ForEach(screenLayouts) { layout in
                                Text(layout.displayName).tag(layout.id)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(width: 80)
                    }
                }
                .font(.caption)
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
            let colOffsets = layout.columnOffsets()
            let rowOffsets = layout.rowOffsets()

            ZStack {
                ForEach(Array(layout.cells.enumerated()), id: \.offset) { index, cell in
                    let x = CGFloat(colOffsets[cell.col]) * geo.size.width
                    let y = CGFloat(rowOffsets[cell.row]) * geo.size.height
                    let w = CGFloat(colOffsets[cell.col + cell.colSpan] - colOffsets[cell.col]) * geo.size.width
                    let h = CGFloat(rowOffsets[cell.row + cell.rowSpan] - rowOffsets[cell.row]) * geo.size.height
                    let label = (keyLabels != nil && index < keyLabels!.count) ? keyLabels![index] : "\(index + 1)"

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.accentColor.opacity(0.15))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.accentColor, lineWidth: 1)
                        )
                        .overlay(
                            Text(label)
                                .font(label.count > 2 ? .system(size: 8) : .caption2)
                                .foregroundColor(.secondary)
                        )
                        .frame(width: w - 4, height: h - 4)
                        .position(x: x + w / 2, y: y + h / 2)
                }
            }
        }
    }
}
