import Foundation

extension Core.Compose.Parser {
    static func preservedFields(_ body: [String: Any], service: String) -> [Core.Field.Path: Core.Schema.Value] {
        var fields: [Core.Field.Path: Core.Schema.Value] = [:]
        putStringList(&fields, .networkExtraHosts, body["extra_hosts"])
        putString(&fields, .networkHostname, body["hostname"])
        putString(&fields, .networkDomainName, body["domainname"])
        putString(&fields, .networkMacAddress, body["mac_address"])
        putStringList(&fields, .networkExpose, body["expose"])
        putString(&fields, .imagePullPolicy, body["pull_policy"])
        putStringOrBoolList(&fields, .processAttachStreams, body["attach"])
        putLogging(&fields, body["logging"])
        putStringList(&fields, .metadataLabelFiles, body["label_file"])
        putString(&fields, .lifecycleStopSignal, body["stop_signal"])
        putString(&fields, .lifecycleStopGracePeriod, body["stop_grace_period"])
        putStringList(&fields, .devices, body["devices"])
        putString(&fields, .gpus, body["gpus"])
        putStringList(&fields, .processSupplementalGroups, body["group_add"])
        putBool(&fields, .securityPrivileged, body["privileged"])
        putStringList(&fields, .securityOptions, body["security_opt"])
        putKeyValues(&fields, .kernelSysctls, body["sysctls"])
        putString(&fields, .namespaceCgroup, body["cgroup"])
        putString(&fields, .namespaceUser, body["userns_mode"])
        putString(&fields, .namespacePID, body["pid"])
        putString(&fields, .namespaceIPC, body["ipc"])
        putString(&fields, .namespaceUTS, body["uts"])
        putString(&fields, .resourcesCPUShares, body["cpu_shares"])
        putString(&fields, .resourcesCPUQuota, body["cpu_quota"])
        putString(&fields, .resourcesCPUPeriod, body["cpu_period"])
        putString(&fields, .resourcesCPUSet, body["cpuset"])
        putString(&fields, .resourcesCPURealtimeRuntime, body["cpu_rt_runtime"])
        putString(&fields, .resourcesCPURealtimePeriod, body["cpu_rt_period"])
        putString(&fields, .resourcesMemoryReservation, body["mem_reservation"])
        putString(&fields, .resourcesMemorySwapLimit, body["memswap_limit"])
        putString(&fields, .resourcesMemorySwappiness, body["mem_swappiness"])
        putBool(&fields, .resourcesOOMKillDisable, body["oom_kill_disable"])
        putString(&fields, .resourcesOOMScoreAdjust, body["oom_score_adj"])
        putString(&fields, .resourcesBlockIO, body["blkio_config"].map(stringify))
        putKeyValues(&fields, .storageOptions, body["storage_opt"])
        putStringList(&fields, .storageVolumesFrom, body["volumes_from"])
        putStringList(&fields, .composeSecrets, body["secrets"])
        putStringList(&fields, .composeConfigs, body["configs"])
        putStringList(&fields, .composeProfiles, body["profiles"])
        putString(&fields, .composeDeploy, body["deploy"].map(stringify))
        putString(&fields, .composeScale, body["scale"])
        putStringList(&fields, .composeLinks, body["links"])
        let dependencies = dependencies(body["depends_on"])
        if !dependencies.isEmpty {
            fields[.composeDependsOn] = .stringList(dependencies.map { "\($0.service)=\($0.condition.rawValue)" })
        }
        putString(&fields, .composeProvider, body["provider"].map(stringify))
        putStringList(&fields, .composeModels, body["models"])
        putBool(&fields, .composeUseAPISocket, body["use_api_socket"])
        return fields
    }

    private static func putString(_ fields: inout [Core.Field.Path: Core.Schema.Value],
                                  _ path: Core.Field.Path,
                                  _ value: Any?) {
        guard let string = stringValue(value), !string.isEmpty else { return }
        fields[path] = .string(string)
    }

    private static func putBool(_ fields: inout [Core.Field.Path: Core.Schema.Value],
                                _ path: Core.Field.Path,
                                _ value: Any?) {
        guard let bool = value as? Bool else { return }
        fields[path] = .bool(bool)
    }

    private static func putStringList(_ fields: inout [Core.Field.Path: Core.Schema.Value],
                                      _ path: Core.Field.Path,
                                      _ value: Any?) {
        let values: [String]
        if let scalar = stringValue(value) {
            values = [scalar]
        } else if let list = value as? [Any] {
            values = list.map(stringify).filter { !$0.isEmpty }
        } else if let map = value as? [String: Any] {
            values = map.keys.sorted().map { key in
                let rendered = stringify(map[key])
                return rendered.isEmpty ? key : "\(key)=\(rendered)"
            }
        } else {
            values = []
        }
        guard !values.isEmpty else { return }
        fields[path] = .stringList(values)
    }

    private static func putStringOrBoolList(_ fields: inout [Core.Field.Path: Core.Schema.Value],
                                            _ path: Core.Field.Path,
                                            _ value: Any?) {
        if let bool = value as? Bool {
            fields[path] = .stringList([String(bool)])
            return
        }
        putStringList(&fields, path, value)
    }

    private static func putKeyValues(_ fields: inout [Core.Field.Path: Core.Schema.Value],
                                     _ path: Core.Field.Path,
                                     _ value: Any?) {
        let values = keyValues(value).compactMap { entry -> Core.Container.KeyValue? in
            guard let eq = entry.firstIndex(of: "=") else { return nil }
            return Core.Container.KeyValue(key: String(entry[..<eq]),
                                           value: String(entry[entry.index(after: eq)...]))
        }
        guard !values.isEmpty else { return }
        fields[path] = .keyValueList(values)
    }

    private static func putLogging(_ fields: inout [Core.Field.Path: Core.Schema.Value],
                                   _ value: Any?) {
        guard let map = value as? [String: Any] else { return }
        putString(&fields, .loggingDriver, map["driver"])
        putKeyValues(&fields, .loggingOptions, map["options"])
    }
}
