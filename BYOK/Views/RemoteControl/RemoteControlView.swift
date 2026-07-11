import SwiftUI

struct RemoteControlView: View {
    @StateObject private var viewModel = RemoteControlViewModel()
    @State private var showPair = false

    var body: some View {
        NavigationStack {
            List {
                if viewModel.devices.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "antenna.radiowaves.left.and.right").font(.system(size: 40)).foregroundColor(.secondary)
                        Text("No paired devices").foregroundColor(.secondary)
                    }.frame(maxWidth: .infinity).padding(.vertical, 40)
                }
                ForEach(viewModel.devices) { device in
                    HStack {
                        Image(systemName: "iphone").foregroundColor(.accentTeal)
                        VStack(alignment: .leading) {
                            Text(device.name).fontWeight(.medium)
                            Text(device.platform).font(.caption).foregroundColor(.secondary)
                            if let lastSeen = device.lastSeen { Text("Last seen: \(lastSeen)").font(.caption2).foregroundColor(.secondary) }
                        }
                        Spacer()
                    }
                    .swipeActions(edge: .trailing) { Button(role: .destructive) { Task { await viewModel.removeDevice(id: device.id) } } label: { Label("Unpair", systemImage: "xmark") } }
                }
            }
            .navigationTitle("Remote Control")
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button(action: { showPair = true }) { Image(systemName: "plus") } } }
            .sheet(isPresented: $showPair) { PairDeviceView(viewModel: viewModel) }
            .onAppear { viewModel.loadDevices() }
        }
    }
}

struct PairDeviceView: View {
    @ObservedObject var viewModel: RemoteControlViewModel
    @Environment(\.dismiss) var dismiss
    @State private var name = ""; @State private var platform = "ios"

    var body: some View {
        NavigationStack {
            Form {
                Section("Device Details") { TextField("Device Name", text: $name); Picker("Platform", selection: $platform) { Text("iOS").tag("ios"); Text("Android").tag("android"); Text("Web").tag("web") } }
            }
            .navigationTitle("Pair Device")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Pair") { Task { await viewModel.pairDevice(name: name, platform: platform); dismiss() } }.disabled(name.isEmpty) }
            }
        }
    }
}

#Preview { RemoteControlView().environmentObject(AuthViewModel()).environmentObject(ThemeManager()) }