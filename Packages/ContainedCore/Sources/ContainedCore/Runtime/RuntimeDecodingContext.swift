import Foundation

extension CodingUserInfoKey {
    static let coreRuntimeKind = CodingUserInfoKey(rawValue: "com.contained.core.runtimeKind")!
}

extension Decoder {
    var coreRuntimeKindContext: Core.Runtime.Kind? {
        userInfo[.coreRuntimeKind] as? Core.Runtime.Kind
    }
}
