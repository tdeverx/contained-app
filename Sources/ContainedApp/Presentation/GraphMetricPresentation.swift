import ContainedCore

extension GraphMetric {
    var displayName: String {
        switch self {
        case .cpu: return AppText.string("graphMetric.cpu", defaultValue: "CPU")
        case .memory: return AppText.string("graphMetric.memory", defaultValue: "Memory")
        case .netRx: return AppText.string("graphMetric.netRx", defaultValue: "Net In")
        case .netTx: return AppText.string("graphMetric.netTx", defaultValue: "Net Out")
        case .diskRead: return AppText.string("graphMetric.diskRead", defaultValue: "Disk Read")
        case .diskWrite: return AppText.string("graphMetric.diskWrite", defaultValue: "Disk Write")
        }
    }

    var systemImage: String {
        switch self {
        case .cpu: return "cpu"
        case .memory: return "memorychip"
        case .netRx: return "arrow.down.circle"
        case .netTx: return "arrow.up.circle"
        case .diskRead: return "arrow.down.doc"
        case .diskWrite: return "arrow.up.doc"
        }
    }

    func chipCaption(from delta: StatsDelta,
                     snapshot: ContainerSnapshot? = nil,
                     normalization: StatsNormalizationContext = .containerSpecific) -> String {
        switch self {
        case .cpu, .memory:
            return Format.compactPercent(value(from: delta, snapshot: snapshot, normalization: normalization))
        case .netRx: return Format.compactRate(delta.netRxBytesPerSec)
        case .netTx: return Format.compactRate(delta.netTxBytesPerSec)
        case .diskRead: return Format.compactRate(delta.blockReadBytesPerSec)
        case .diskWrite: return Format.compactRate(delta.blockWriteBytesPerSec)
        }
    }

    func caption(from delta: StatsDelta,
                 snapshot: ContainerSnapshot? = nil,
                 normalization: StatsNormalizationContext = .containerSpecific) -> String {
        switch self {
        case .cpu, .memory:
            return Format.compactPercent(value(from: delta, snapshot: snapshot, normalization: normalization))
        case .netRx: return Format.rate(delta.netRxBytesPerSec)
        case .netTx: return Format.rate(delta.netTxBytesPerSec)
        case .diskRead: return Format.rate(delta.blockReadBytesPerSec)
        case .diskWrite: return Format.rate(delta.blockWriteBytesPerSec)
        }
    }
}

extension StatsNormalizationMode {
    var displayName: String {
        switch self {
        case .container: return AppText.string("statsNormalization.container", defaultValue: "Container")
        case .machine: return AppText.string("statsNormalization.machine", defaultValue: "Machine")
        }
    }

    var footnote: String {
        switch self {
        case .container:
            return AppText.string(
                "statsNormalization.container.footnote",
                defaultValue: "CPU and memory are scaled against each container's own configured limits."
            )
        case .machine:
            return AppText.string(
                "statsNormalization.machine.footnote",
                defaultValue: "CPU and memory are scaled against Apple container's machine CPU and memory resources."
            )
        }
    }
}
