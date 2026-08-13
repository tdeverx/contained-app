import Foundation

private final class CoreLocalizationBundleToken: NSObject {}

public extension Core {
    enum Localization {
        private static let resourceBundle: Bundle? = {
            let bundleName = "ContainedCore_ContainedCore.bundle"
            let hosts = [Bundle.main, Bundle(for: CoreLocalizationBundleToken.self)]
                + Bundle.allBundles
                + Bundle.allFrameworks
            let candidates: [URL?] = hosts.flatMap { host -> [URL?] in
                [
                    host.resourceURL?.appendingPathComponent(bundleName),
                    host.bundleURL.appendingPathComponent(bundleName),
                    host.bundleURL.deletingLastPathComponent().appendingPathComponent(bundleName),
                ]
            }
            return candidates.compactMap { $0 }.lazy.compactMap(Bundle.init(url:)).first
        }()

        public struct Entry: Sendable, Hashable {
            public var key: String
            public var defaultValue: String
            public var table: String

            public init(key: String, defaultValue: String, table: String = "Localizable") {
                self.key = key
                self.defaultValue = defaultValue
                self.table = table
            }
        }

        public typealias Resolver = @Sendable (Entry) -> String?

        public static func string(_ key: String,
                                  defaultValue: String,
                                  table: String = "Localizable",
                                  resolver: Resolver? = nil) -> String {
            let entry = Entry(key: key, defaultValue: defaultValue, table: table)
            if let resolved = resolver?(entry) { return resolved }
            guard let resourceBundle else { return defaultValue }
            let localized = resourceBundle.localizedString(forKey: key, value: defaultValue, table: table)
            return localized == key ? defaultValue : localized
        }
    }
}

public extension Core.Schema.FieldDescriptor {
    func localizedLabel(resolver: Core.Localization.Resolver? = nil) -> String {
        Core.Localization.string(labelKey, defaultValue: defaultLabel, resolver: resolver)
    }

    func localizedTip(for runtimeKind: Core.Runtime.Kind,
                      resolver: Core.Localization.Resolver? = nil) -> String? {
        tip(for: runtimeKind)?.localizedText(resolver: resolver)
    }
}

public extension Core.Schema.ValueOption {
    func localizedLabel(resolver: Core.Localization.Resolver? = nil) -> String {
        Core.Localization.string(labelKey, defaultValue: defaultLabel, resolver: resolver)
    }
}

public extension Core.Schema.FieldTipRef {
    func localizedText(resolver: Core.Localization.Resolver? = nil) -> String {
        Core.Localization.string(key, defaultValue: defaultText, resolver: resolver)
    }
}

public extension Core.Schema.FieldSupport {
    func localizedDisabledReason(resolver: Core.Localization.Resolver? = nil) -> String? {
        guard let defaultDisabledReason else { return nil }
        return Core.Localization.string(disabledReasonKey ?? "schema.disabled.unsupported",
                                        defaultValue: defaultDisabledReason,
                                        resolver: resolver)
    }
}

public extension Core.Schema.ValidationIssue {
    func localizedMessage(resolver: Core.Localization.Resolver? = nil) -> String {
        Core.Localization.string(messageKey, defaultValue: defaultMessage, resolver: resolver)
    }
}

public extension Core.Runtime.UnsupportedCapability {
    func localizedFallbackDescription(resolver: Core.Localization.Resolver? = nil) -> String {
        Core.Localization.string("runtime.capability.unsupported",
                                 defaultValue: "This runtime does not support the requested capability.",
                                 resolver: resolver)
    }
}
