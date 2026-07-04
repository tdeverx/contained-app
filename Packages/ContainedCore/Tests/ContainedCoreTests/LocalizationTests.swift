import Testing
@testable import ContainedCore

@Suite("Core localization")
struct CoreLocalizationTests {
    @Test func packageResourcesResolveSemanticDefaults() {
        #expect(Core.Localization.string("schema.field.image.reference", defaultValue: "Fallback image") == "Image")
        #expect(Core.Localization.string("runtime.capability.unsupported",
                                         defaultValue: "Fallback unsupported") == "This runtime does not support the requested capability.")
    }

    @Test func missingKeysUseProvidedFallback() {
        #expect(Core.Localization.string("missing.core.key", defaultValue: "Fallback text") == "Fallback text")
    }

    @Test func downstreamResolversCanOverrideOrWrapCoreStrings() throws {
        let definition = Core.Schema.Definition.containerRunEdit(runtimeProfile: DockerRuntimeModule().schemaProfile())
        let image = try #require(definition.descriptor(for: .imageReference))
        let wrapped = image.localizedLabel { entry in
            "[app] \(entry.defaultValue)"
        }

        #expect(wrapped == "[app] Image")
    }

    @Test func schemaSupportReasonsUseCoreLocalization() throws {
        let definition = Core.Schema.Definition.containerRunEdit(runtimeProfile: DockerRuntimeModule().schemaProfile())
        let kernel = try #require(definition.descriptor(for: .kernelPath))
        let reason = kernel.support(for: .docker).localizedDisabledReason()

        #expect(reason == "Known from Apple container or Compose, not executable by Docker.")
    }
}
