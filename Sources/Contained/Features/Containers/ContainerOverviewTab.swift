import SwiftUI
import ContainedCore

/// The Overview tab of the container detail: grouped, read-only configuration (general, resources,
/// ports, mounts, environment, labels).
struct ContainerOverviewTab: View {
    let snapshot: ContainerSnapshot
    private var config: ContainerConfiguration { snapshot.configuration }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tokens.Space.m) {
                group("General") {
                    row("Image", snapshot.image)
                    row("Platform", config.platform.display)
                    if let exec = config.initProcess.executable {
                        row("Command", ([exec] + config.initProcess.arguments).joined(separator: " "))
                    }
                    row("Working dir", config.initProcess.workingDirectory ?? "—")
                }
                group("Resources") {
                    row("CPUs", "\(config.resources.cpus)")
                    row("Memory", Format.bytes(config.resources.memoryInBytes))
                }
                if !config.publishedPorts.isEmpty {
                    group("Ports") {
                        ForEach(config.publishedPorts, id: \.containerPort) { port in
                            row(port.proto?.uppercased() ?? "TCP", "\(port.hostAddress ?? "0.0.0.0"):\(port.display)")
                        }
                    }
                }
                if !config.mounts.isEmpty {
                    group("Mounts") {
                        ForEach(config.mounts, id: \.effectiveDestination) { mount in
                            row(mount.effectiveDestination ?? "—", "\(mount.source ?? "—") (\(mount.type ?? "?"))")
                        }
                    }
                }
                if !config.initProcess.environment.isEmpty {
                    group("Environment") {
                        ForEach(config.initProcess.environment, id: \.self) { env in
                            Text(env).font(.system(.caption, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading).lineLimit(1)
                        }
                    }
                }
                if !config.labels.isEmpty {
                    group("Labels") {
                        ForEach(config.labels.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                            row(key, value)
                        }
                    }
                }
            }
            .padding(Tokens.Space.l)
        }
        .scrollEdgeEffectStyle(.soft, for: .all)
    }

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Tokens.Space.m)
        .background(.quaternary.opacity(0.10), in: RoundedRectangle(cornerRadius: Tokens.Radius.control, style: .continuous))
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
