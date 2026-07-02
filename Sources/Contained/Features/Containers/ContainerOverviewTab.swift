import SwiftUI
import ContainedDesignSystem
import ContainedCore

/// The Overview tab of the container detail: grouped, read-only configuration (general, resources,
/// ports, mounts, environment, labels).
struct ContainerOverviewTab: View {
    let snapshot: ContainerSnapshot
    private var config: ContainerConfiguration { snapshot.configuration }

    var body: some View {
        ContainerTabScaffold {
            LazyVStack(alignment: .leading, spacing: Tokens.Space.m) {
                section("General") {
                    row("Image", snapshot.image)
                    row("Platform", config.platform.display)
                    if let exec = config.initProcess.executable {
                        row("Command", ([exec] + config.initProcess.arguments).joined(separator: " "))
                    }
                    row("Working dir", config.initProcess.workingDirectory ?? "—")
                }
                section("Resources") {
                    row("CPUs", "\(config.resources.cpus)")
                    row("Memory", Format.bytes(config.resources.memoryInBytes))
                }
                if !config.publishedPorts.isEmpty {
                    section("Ports") {
                        ForEach(config.publishedPorts, id: \.containerPort) { port in
                            row(port.proto?.uppercased() ?? "TCP", "\(port.hostAddress ?? "0.0.0.0"):\(port.display)")
                        }
                    }
                }
                if !config.mounts.isEmpty {
                    section("Mounts") {
                        ForEach(config.mounts, id: \.effectiveDestination) { mount in
                            row(mount.effectiveDestination ?? "—", "\(mount.source ?? "—") (\(mount.type ?? "?"))")
                        }
                    }
                }
                if !config.initProcess.environment.isEmpty {
                    section("Environment") {
                        ForEach(config.initProcess.environment, id: \.self) { env in
                            Text(env).font(.system(.caption, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading).lineLimit(1)
                        }
                    }
                }
                if !config.labels.isEmpty {
                    section("Labels") {
                        ForEach(config.labels.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                            row(key, value)
                        }
                    }
                }
            }
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: @escaping () -> Content) -> some View {
        ContainerTabSection(title: title) {
            content()
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).multilineTextAlignment(.trailing).textSelection(.enabled)
                .font(.system(.body, design: .monospaced))
        }
        .font(.callout)
    }
}
