import Foundation
import Testing
@testable import ContainedCore

@Suite("Runtime descriptor contracts")
struct RuntimeDescriptorTests {
    @Test func defaultRegistryKeepsDockerDormant() {
        #expect(Core.Runtime.builtInModules.map(\.descriptor.kind) == [.appleContainer])
        #expect(Core.Runtime.supportedDescriptors.map(\.kind) == [.appleContainer])
        #expect(Core.Runtime.descriptor(for: .appleContainer) == .appleContainer)
        #expect(Core.Runtime.descriptor(for: .docker) == nil)
    }

    @Test func openRuntimeKindsCanAdvertiseCapabilities() throws {
        let descriptor = Core.Runtime.Descriptor(
            kind: Core.Runtime.Kind(rawValue: "future-runtime"),
            displayName: "Future runtime",
            executableName: "future",
            capabilities: [.containers, .composeImport]
        )

        #expect(descriptor.supports(.containers))
        #expect(descriptor.supports(.composeImport))
        #expect(!descriptor.supports(.imageBuild))
        try descriptor.require(.containers)
    }

    @Test func unsupportedCapabilityIsDisplayNeutralPackageError() {
        let error = Core.Runtime.UnsupportedCapability(
            kind: .docker,
            capability: .imageBuild
        )

        #expect(error.packageName == "ContainedCore")
        #expect(error.packageErrorCode == "unsupportedRuntimeCapability")
        #expect(error.packageErrorContext["kind"] == Core.Runtime.Kind.docker.rawValue)
        #expect(error.packageErrorContext["capability"] == String(Core.Runtime.Capability.imageBuild.rawValue))
    }

    @Test func defaultCoreSwitchPlanIsDisplayNeutral() throws {
        let runtime = UnavailableRuntime(
            descriptor: Core.Runtime.Descriptor(
                kind: Core.Runtime.Kind(rawValue: "future-runtime"),
                displayName: "Future runtime",
                executableName: "future",
                capabilities: [.containers]
            )
        )

        let plan = try runtime.coreSwitchPlan(for: "web", to: .appleContainer)

        #expect(!plan.isAvailable)
        #expect(plan.unavailableReason == .exportImportUnsupported)
        #expect(plan.context["source"] == "future-runtime")
        #expect(plan.context["target"] == Core.Runtime.Kind.appleContainer.rawValue)
    }

    @Test func orchestratorAggregatesAndScopesContainersAcrossRuntimes() async throws {
        let apple = UnavailableRuntime(
            descriptor: .appleContainer,
            containers: [.placeholder(id: "web", image: "nginx:latest", runtimeKind: .appleContainer)]
        )
        let docker = UnavailableRuntime(
            descriptor: .docker,
            containers: [.placeholder(id: "web", image: "nginx:latest", runtimeKind: .docker)]
        )
        let orchestrator = Core.Orchestrator(
            cliURLs: [
                .appleContainer: URL(fileURLWithPath: "/usr/bin/container"),
                .docker: URL(fileURLWithPath: "/usr/local/bin/docker"),
            ],
            runtimes: [
                .appleContainer: apple,
                .docker: docker,
            ] as [Core.Runtime.Kind: any RuntimeClient]
        )

        let snapshots = try await orchestrator.listRuntimeContainers()

        #expect(snapshots.count == 2)
        #expect(Set(snapshots.map { $0.id }) == ["web"])
        #expect(Set(snapshots.map { $0.scopedID }) == [
            "apple-container::web",
            "docker::web",
        ])
        #expect(Set(snapshots.map { $0.runtimeKind }) == [
            Core.Runtime.Kind.appleContainer,
            Core.Runtime.Kind.docker,
        ])
    }

    @Test func orchestratorPreservesPartialInventoryWhenOneRuntimeFails() async throws {
        let apple = UnavailableRuntime(
            descriptor: .appleContainer,
            containers: [.placeholder(id: "apple-web", image: "nginx:latest", runtimeKind: .appleContainer)]
        )
        let docker = UnavailableRuntime(
            descriptor: .docker,
            listError: TestStubError.unused
        )
        let orchestrator = Core.Orchestrator(
            cliURLs: [
                .appleContainer: URL(fileURLWithPath: "/usr/bin/container"),
                .docker: URL(fileURLWithPath: "/usr/local/bin/docker"),
            ],
            runtimes: [
                .appleContainer: apple,
                .docker: docker,
            ] as [Core.Runtime.Kind: any RuntimeClient]
        )

        let inventory = try await orchestrator.containerInventory()
        let snapshots = inventory.items

        #expect(snapshots.map { $0.scopedID } == ["apple-container::apple-web"])
        #expect(inventory.failures.count == 1)
        #expect(inventory.failures.first?.kind == .docker)
        #expect(inventory.successfulRuntimeKinds == [.appleContainer])
    }

    @Test func orchestratorTerminalInvocationRoutesByRuntimeKind() throws {
        let orchestrator = Core.Orchestrator(
            cliURLs: [
                .appleContainer: URL(fileURLWithPath: "/usr/bin/container"),
                .docker: URL(fileURLWithPath: "/usr/local/bin/docker"),
            ],
            runtimes: [
                .appleContainer: UnavailableRuntime(descriptor: .appleContainer),
                .docker: UnavailableRuntime(descriptor: .docker),
            ] as [Core.Runtime.Kind: any RuntimeClient],
            modules: [
                .appleContainer: AppleContainerRuntimeModule(),
                .docker: DockerRuntimeModule(),
            ]
        )

        let docker = try orchestrator.terminalInvocation(containerID: "web",
                                                         shell: "/bin/sh",
                                                         runtimeKind: .docker)
        let apple = try orchestrator.terminalInvocation(containerID: "web",
                                                        shell: "/bin/sh",
                                                        runtimeKind: .appleContainer)

        #expect(docker.executableURL.path == "/usr/local/bin/docker")
        #expect(docker.arguments == DockerCommands.execInteractive("web", shell: "/bin/sh"))
        #expect(apple.executableURL.path == "/usr/bin/container")
        #expect(apple.arguments == ContainerCommands.execInteractive("web", shell: "/bin/sh"))
    }

    @Test func orchestratorDoesNotFabricateUnregisteredDescriptors() {
        let orchestrator = Core.Orchestrator(
            cliURLs: [.appleContainer: URL(fileURLWithPath: "/usr/bin/container")],
            runtimes: [.appleContainer: UnavailableRuntime(descriptor: .appleContainer)] as [Core.Runtime.Kind: any RuntimeClient]
        )

        #expect(orchestrator.descriptor(for: .appleContainer) == .appleContainer)
        #expect(orchestrator.descriptor(for: .docker) == nil)
        #expect(orchestrator.descriptor(for: Core.Runtime.Kind(rawValue: "future-runtime")) == nil)
    }

    @Test func serviceControlRequiresExplicitCapability() async {
        let orchestrator = Core.Orchestrator(
            cliURLs: [.docker: URL(fileURLWithPath: "/usr/local/bin/docker")],
            runtimes: [.docker: UnavailableRuntime(descriptor: .docker)] as [Core.Runtime.Kind: any RuntimeClient]
        )

        await #expect(throws: Core.Runtime.UnsupportedCapability.self) {
            _ = try await orchestrator.performSystemAction(.start, runtimeKind: .docker)
        }
    }

    @Test func recreateSkipsDeleteWhenOriginalIsAlreadyMissing() async throws {
        let runtime = RecordingContainerRuntime(containers: [])
        let orchestrator = Core.Orchestrator(
            cliURLs: [.appleContainer: URL(fileURLWithPath: "/usr/bin/container")],
            runtimes: [.appleContainer: runtime] as [Core.Runtime.Kind: any RuntimeClient]
        )

        let result = try await orchestrator.recreateContainer(originalID: "missing",
                                                              replacement: recreateDocument(),
                                                              rollback: recreateDocument(name: "missing"))

        #expect(result.id == "created")
        #expect(await runtime.deletedIDs.isEmpty)
        #expect(await runtime.createdRequests.count == 1)
    }

    @Test func recreateTreatsRacingDeleteNotFoundAsAlreadyGone() async throws {
        let runtime = RecordingContainerRuntime(
            containers: [.placeholder(id: "gone", image: "nginx:latest", runtimeKind: .appleContainer)],
            deleteError: .nonZeroExit(code: 1,
                                      stderr: "Error: container with ID gone not found",
                                      command: "delete --force gone")
        )
        let orchestrator = Core.Orchestrator(
            cliURLs: [.appleContainer: URL(fileURLWithPath: "/usr/bin/container")],
            runtimes: [.appleContainer: runtime] as [Core.Runtime.Kind: any RuntimeClient]
        )

        let result = try await orchestrator.recreateContainer(originalID: "gone",
                                                              replacement: recreateDocument(),
                                                              rollback: recreateDocument(name: "gone"))

        #expect(result.id == "created")
        #expect(await runtime.deletedIDs == ["gone"])
        #expect(await runtime.createdRequests.count == 1)
    }

    @Test func recreateRestartsRunningOriginalAfterDeleteFailure() async throws {
        let runtime = RecordingContainerRuntime(
            containers: [.placeholder(id: "blocked", image: "nginx:latest", runtimeKind: .appleContainer)],
            deleteError: .nonZeroExit(code: 1,
                                      stderr: "permission denied",
                                      command: "delete --force blocked")
        )
        let orchestrator = Core.Orchestrator(
            cliURLs: [.appleContainer: URL(fileURLWithPath: "/usr/bin/container")],
            runtimes: [.appleContainer: runtime] as [Core.Runtime.Kind: any RuntimeClient]
        )

        do {
            _ = try await orchestrator.recreateContainer(originalID: "blocked",
                                                         replacement: recreateDocument(),
                                                         rollback: recreateDocument(name: "blocked"))
            Issue.record("Expected recreate to fail")
        } catch let error as Core.Container.RecreateFailure {
            #expect(error.phase == .deleteOriginal)
            #expect(error.recovery == .originalRestored)
            #expect(error.primaryFailure.runtimeDetail == "permission denied")
        }
        #expect(await runtime.createdRequests.isEmpty)
        #expect(await runtime.startedIDs == ["blocked"])
        #expect(await runtime.containers.first?.state == .running)
    }

    @Test func recreateDoesNotStartStoppedOriginalAfterDeleteFailure() async throws {
        let runtime = RecordingContainerRuntime(
            containers: [.placeholder(id: "blocked", image: "nginx:latest", state: .stopped, runtimeKind: .appleContainer)],
            deleteError: .nonZeroExit(code: 1, stderr: "permission denied", command: "delete --force blocked"))
        let orchestrator = Core.Orchestrator(cliURLs: [.appleContainer: URL(fileURLWithPath: "/usr/bin/container")],
            runtimes: [.appleContainer: runtime] as [Core.Runtime.Kind: any RuntimeClient])

        do {
            _ = try await orchestrator.recreateContainer(originalID: "blocked", replacement: recreateDocument(),
                                                         rollback: recreateDocument(name: "blocked"))
            Issue.record("Expected delete failure")
        } catch let failure as Core.Container.RecreateFailure {
            #expect(failure.phase == .deleteOriginal)
            #expect(failure.recovery == .notNeeded)
        }
        #expect(await runtime.startedIDs.isEmpty)
        #expect(await runtime.containers.first?.state == .stopped)
    }

    @Test(arguments: [false, true])
    func recreateRetainsRecoveryWhenRestartAfterDeleteFailureFails(commandFails: Bool) async throws {
        let runtime = RecordingContainerRuntime(
            containers: [.placeholder(id: "blocked", image: "nginx:latest", runtimeKind: .appleContainer)],
            deleteError: .nonZeroExit(code: 1, stderr: "permission denied", command: "delete --force blocked"),
            startError: commandFails ? .nonZeroExit(code: 1, stderr: "restart unavailable", command: "start blocked") : nil,
            startState: .stopped)
        let orchestrator = Core.Orchestrator(cliURLs: [.appleContainer: URL(fileURLWithPath: "/usr/bin/container")],
            runtimes: [.appleContainer: runtime] as [Core.Runtime.Kind: any RuntimeClient])

        do {
            _ = try await orchestrator.recreateContainer(originalID: "blocked", replacement: recreateDocument(),
                                                         rollback: recreateDocument(name: "blocked"))
            Issue.record("Expected failed original restart")
        } catch let failure as Core.Container.RecreateFailure {
            #expect(failure.phase == .deleteOriginal)
            #expect(failure.recovery == .restoreFailed)
            #expect(failure.primaryFailure.runtimeDetail == "permission denied")
            #expect(failure.recoveryFailure?.code == (commandFails ? "nonZeroExit" : "recreateReplacementNotRunning"))
        }
        #expect(await runtime.startedIDs == ["blocked"])
        #expect(await runtime.createdRequests.isEmpty)
        #expect(await runtime.containers.first?.state == .stopped)
    }

    @Test func recreateValidatesRollbackBeforeDeletingOriginal() async throws {
        let runtime = RecordingContainerRuntime(
            containers: [.placeholder(id: "web", image: "nginx:latest", runtimeKind: .appleContainer)]
        )
        let orchestrator = Core.Orchestrator(
            cliURLs: [.appleContainer: URL(fileURLWithPath: "/usr/bin/container")],
            runtimes: [.appleContainer: runtime] as [Core.Runtime.Kind: any RuntimeClient]
        )
        var invalidRollback = recreateDocument(name: "web")
        invalidRollback.set(.imageReference, .string(""))

        await #expect(throws: Core.Schema.ValidationError.self) {
            _ = try await orchestrator.recreateContainer(originalID: "web",
                                                         replacement: recreateDocument(),
                                                         rollback: invalidRollback)
        }
        #expect(await runtime.stoppedIDs.isEmpty)
        #expect(await runtime.deletedIDs.isEmpty)
        #expect(await runtime.createdRequests.isEmpty)
    }

    @Test func recreateValidatesReplacementBeforeDeletingOriginal() async throws {
        let runtime = RecordingContainerRuntime(
            containers: [.placeholder(id: "web", image: "nginx:latest", runtimeKind: .appleContainer)]
        )
        let orchestrator = Core.Orchestrator(
            cliURLs: [.appleContainer: URL(fileURLWithPath: "/usr/bin/container")],
            runtimes: [.appleContainer: runtime] as [Core.Runtime.Kind: any RuntimeClient]
        )
        var invalidReplacement = recreateDocument()
        invalidReplacement.set(.imageReference, .string(""))

        await #expect(throws: Core.Schema.ValidationError.self) {
            _ = try await orchestrator.recreateContainer(originalID: "web",
                                                         replacement: invalidReplacement,
                                                         rollback: recreateDocument(name: "web"))
        }
        #expect(await runtime.stoppedIDs.isEmpty)
        #expect(await runtime.deletedIDs.isEmpty)
        #expect(await runtime.createdRequests.isEmpty)
    }

    @Test func recreateRestoresOriginalWhenReplacementCreationFails() async throws {
        let runtime = RecordingContainerRuntime(
            containers: [.placeholder(id: "web", image: "nginx:stable", runtimeKind: .appleContainer)],
            createErrors: [.nonZeroExit(code: 1, stderr: "replacement failed", command: "run replacement")]
        )
        let orchestrator = Core.Orchestrator(
            cliURLs: [.appleContainer: URL(fileURLWithPath: "/usr/bin/container")],
            runtimes: [.appleContainer: runtime] as [Core.Runtime.Kind: any RuntimeClient]
        )

        do {
            _ = try await orchestrator.recreateContainer(originalID: "web",
                                                         replacement: recreateDocument(),
                                                         rollback: recreateDocument(name: "web", image: "nginx:stable"))
            Issue.record("Expected recreate to report the replacement failure")
        } catch let error as Core.Container.RecreateFailure {
            #expect(error.phase == .createReplacement)
            #expect(error.recovery == .originalRestored)
            #expect(error.primaryFailure.runtimeDetail == "replacement failed")
        }
        let requests = await runtime.createdRequests
        #expect(requests.map(\.name) == ["created", "web"])
    }

    @Test func recreateReportsWhenReplacementAndRestorationFail() async throws {
        let runtime = RecordingContainerRuntime(
            containers: [.placeholder(id: "web", image: "nginx:stable", runtimeKind: .appleContainer)],
            createErrors: [
                .nonZeroExit(code: 1, stderr: "replacement failed", command: "run replacement"),
                .nonZeroExit(code: 2, stderr: "restore failed", command: "run original"),
            ]
        )
        let orchestrator = Core.Orchestrator(
            cliURLs: [.appleContainer: URL(fileURLWithPath: "/usr/bin/container")],
            runtimes: [.appleContainer: runtime] as [Core.Runtime.Kind: any RuntimeClient]
        )

        do {
            _ = try await orchestrator.recreateContainer(originalID: "web",
                                                         replacement: recreateDocument(),
                                                         rollback: recreateDocument(name: "web", image: "nginx:stable"))
            Issue.record("Expected recreate and restoration to fail")
        } catch let error as Core.Container.RecreateFailure {
            #expect(error.phase == .restoreOriginal)
            #expect(error.recovery == .restoreFailed)
            #expect(error.primaryFailure.runtimeDetail == "replacement failed")
            #expect(error.recoveryFailure?.runtimeDetail == "restore failed")
            #expect(error.packageErrorContext["phase"] == "restoreOriginal")
            #expect(!error.packageErrorContext.values.contains { $0.contains("failed") })
        }
    }

    @Test func recreateRejectsStaleReplacementImageAndRestoresOriginal() async throws {
        let expected = Core.Image.Resource(
            configuration: Core.Image.Configuration(
                name: "nginx:latest",
                descriptor: Core.Container.Descriptor(digest: "sha256:new", mediaType: nil, size: nil),
                creationDate: nil
            ),
            id: "new",
            runtimeKind: .appleContainer
        )
        let runtime = RecordingContainerRuntime(
            containers: [.placeholder(id: "web", image: "nginx:latest", runtimeKind: .appleContainer)],
            inspectedImages: [expected],
            creationDigests: ["sha256:old", "sha256:new"]
        )
        let orchestrator = Core.Orchestrator(
            cliURLs: [.appleContainer: URL(fileURLWithPath: "/usr/bin/container")],
            runtimes: [.appleContainer: runtime] as [Core.Runtime.Kind: any RuntimeClient]
        )

        do {
            _ = try await orchestrator.recreateContainer(originalID: "web",
                                                         replacement: recreateDocument(),
                                                         rollback: recreateDocument(name: "web"))
            Issue.record("Expected stale replacement verification to fail")
        } catch let error as Core.Container.RecreateFailure {
            #expect(error.phase == .createReplacement)
            #expect(error.recovery == .originalRestored)
            #expect(error.primaryFailure.code == "recreateImageMismatch")
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        #expect(await runtime.deletedIDs == ["web", "created"])
        #expect(await runtime.createdRequests.map(\.name) == ["created", "web"])
    }

    @Test func recreateKeepsOriginalWhenImageInspectionFails() async throws {
        let inspectionError = Core.Command.Error.nonZeroExit(code: 1,
                                                              stderr: "image service unavailable",
                                                              command: "image inspect nginx:latest")
        let runtime = RecordingContainerRuntime(
            containers: [.placeholder(id: "web", image: "nginx:latest", runtimeKind: .appleContainer)],
            inspectError: inspectionError
        )
        let orchestrator = Core.Orchestrator(
            cliURLs: [.appleContainer: URL(fileURLWithPath: "/usr/bin/container")],
            runtimes: [.appleContainer: runtime] as [Core.Runtime.Kind: any RuntimeClient]
        )

        do {
            _ = try await orchestrator.recreateContainer(originalID: "web",
                                                         replacement: recreateDocument(),
                                                         rollback: recreateDocument(name: "web"))
            Issue.record("Expected image inspection to fail")
        } catch let error as Core.Command.Error {
            #expect(error == inspectionError)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        #expect(await runtime.deletedIDs.isEmpty)
        #expect(await runtime.createdRequests.isEmpty)
    }

    @Test func recreateRejectsReplacementThatStopsDuringStartup() async throws {
        let runtime = RecordingContainerRuntime(
            containers: [.placeholder(id: "web", image: "nginx:latest", runtimeKind: .appleContainer)],
            creationStates: [.stopped, .running]
        )
        let orchestrator = Core.Orchestrator(
            cliURLs: [.appleContainer: URL(fileURLWithPath: "/usr/bin/container")],
            runtimes: [.appleContainer: runtime] as [Core.Runtime.Kind: any RuntimeClient]
        )

        do {
            _ = try await orchestrator.recreateContainer(originalID: "web",
                                                         replacement: recreateDocument(),
                                                         rollback: recreateDocument(name: "web"))
            Issue.record("Expected stopped replacement verification to fail")
        } catch let error as Core.Container.RecreateFailure {
            #expect(error.phase == .createReplacement)
            #expect(error.recovery == .originalRestored)
            #expect(error.primaryFailure.code == "recreateReplacementNotRunning")
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    private func recreateDocument(name: String = "created", image: String = "nginx:latest") -> Core.Schema.Document {
        var request = Core.Container.CreateRequest(runtimeKind: .appleContainer)
        request.image = image
        request.name = name
        return Core.Schema.Document.containerCreate(from: request)
    }

    @Test func recreationDoesNotReportStoppedRollbackAsRestored() async throws {
        let runtime = RecordingContainerRuntime(
            containers: [.placeholder(id: "web", image: "nginx:stable", runtimeKind: .appleContainer)],
            createErrors: [.nonZeroExit(code: 1, stderr: "mount failed", command: "run")],
            creationStates: [.stopped])
        let orchestrator = Core.Orchestrator(cliURLs: [.appleContainer: URL(fileURLWithPath: "/usr/bin/container")],
            runtimes: [.appleContainer: runtime] as [Core.Runtime.Kind: any RuntimeClient])
        do {
            _ = try await orchestrator.recreateContainer(originalID: "web", replacement: recreateDocument(), rollback: recreateDocument(name: "web"))
            Issue.record("Expected failed rollback startup")
        } catch let failure as Core.Container.RecreateFailure {
            #expect(failure.recovery == .restoreFailed)
            #expect(failure.primaryFailure.runtimeDetail == "mount failed")
            #expect(failure.recoveryFailure?.code == "recreateReplacementNotRunning")
        }
    }

    @Test func explicitRecoveryNeverDeletesAnExistingContainer() async throws {
        let runtime = RecordingContainerRuntime(containers: [.placeholder(id: "web", image: "nginx:stable", runtimeKind: .appleContainer)])
        let orchestrator = Core.Orchestrator(cliURLs: [.appleContainer: URL(fileURLWithPath: "/usr/bin/container")],
            runtimes: [.appleContainer: runtime] as [Core.Runtime.Kind: any RuntimeClient])
        do {
            _ = try await orchestrator.restoreContainer(recreateDocument(name: "web"), originalWasRunning: true)
            Issue.record("Expected recovery name collision")
        } catch {
            #expect((error as? any Core.Error.PackageError)?.packageErrorCode == "recreateRecoveryNameInUse")
        }
        #expect(await runtime.createdRequests.isEmpty)
        #expect(await runtime.deletedIDs.isEmpty)
        #expect(await runtime.stoppedIDs.isEmpty)
    }

    @Test func explicitRecoveryRequiresVerifiedStartup() async throws {
        let runtime = RecordingContainerRuntime(containers: [], creationStates: [.stopped, .running])
        let orchestrator = Core.Orchestrator(cliURLs: [.appleContainer: URL(fileURLWithPath: "/usr/bin/container")],
            runtimes: [.appleContainer: runtime] as [Core.Runtime.Kind: any RuntimeClient])
        do {
            _ = try await orchestrator.restoreContainer(recreateDocument(name: "web"), originalWasRunning: true)
            Issue.record("Expected stopped restore verification to fail")
        } catch {
            #expect((error as? any Core.Error.PackageError)?.packageErrorCode == "recreateReplacementNotRunning")
        }
        // Failed verification leaves the object for inspection rather than silently deleting it.
        #expect(await runtime.deletedIDs.isEmpty)
        let result = try await orchestrator.restoreContainer(recreateDocument(name: "other"), originalWasRunning: true)
        #expect(result.id == "other")
    }

    @Test func explicitStoppedRecoveryNeverStartsTheWorkload() async throws {
        let runtime = RecordingContainerRuntime(containers: [],
            inspectedImages: [.init(configuration: .init(name: "nginx:stable",
                descriptor: .init(digest: "sha256:original", mediaType: nil, size: nil), creationDate: nil),
                id: "original", runtimeKind: .appleContainer)],
            creationDigests: ["sha256:original"])
        let orchestrator = Core.Orchestrator(cliURLs: [.appleContainer: URL(fileURLWithPath: "/usr/bin/container")],
            runtimes: [.appleContainer: runtime] as [Core.Runtime.Kind: any RuntimeClient])
        let document = recreateDocument(name: "web")

        let result = try await orchestrator.restoreContainer(document, originalWasRunning: false)

        #expect(result.id == "web")
        #expect(await runtime.creationStarts == [false])
        #expect(await runtime.containers.first?.state == .stopped)
        #expect(await runtime.startedIDs.isEmpty)
        #expect(await runtime.stoppedIDs.isEmpty)
        #expect(await runtime.deletedIDs.isEmpty)
        #expect(try orchestrator.previewCreateCommand(for: document, start: false).command.first == "create")
    }

    @Test func stoppedRecoveryRejectsAnUnexpectedlyRunningResult() async throws {
        let runtime = RecordingContainerRuntime(containers: [], creationStates: [.running])
        let orchestrator = Core.Orchestrator(cliURLs: [.appleContainer: URL(fileURLWithPath: "/usr/bin/container")],
            runtimes: [.appleContainer: runtime] as [Core.Runtime.Kind: any RuntimeClient])
        do {
            _ = try await orchestrator.restoreContainer(recreateDocument(name: "web"), originalWasRunning: false)
            Issue.record("Expected stopped-state verification to fail")
        } catch {
            #expect((error as? any Core.Error.PackageError)?.packageErrorCode == "recreateReplacementNotStopped")
        }
        #expect(await runtime.creationStarts == [false])
        #expect(await runtime.deletedIDs.isEmpty)
    }

    @Test func stoppedRecoveryStillVerifiesImageIdentity() async throws {
        let runtime = RecordingContainerRuntime(containers: [],
            inspectedImages: [.init(configuration: .init(name: "nginx:stable",
                descriptor: .init(digest: "sha256:original", mediaType: nil, size: nil), creationDate: nil),
                id: "original", runtimeKind: .appleContainer)],
            creationDigests: ["sha256:wrong"])
        let orchestrator = Core.Orchestrator(cliURLs: [.appleContainer: URL(fileURLWithPath: "/usr/bin/container")],
            runtimes: [.appleContainer: runtime] as [Core.Runtime.Kind: any RuntimeClient])
        do {
            _ = try await orchestrator.restoreContainer(recreateDocument(name: "web"), originalWasRunning: false)
            Issue.record("Expected image verification to fail")
        } catch {
            #expect((error as? any Core.Error.PackageError)?.packageErrorCode == "recreateImageMismatch")
        }
        #expect(await runtime.creationStarts == [false])
        #expect(await runtime.startedIDs.isEmpty)
        #expect(await runtime.deletedIDs.isEmpty)
    }

    @Test func failedReplacementRestoresStoppedOriginalWithoutStartingIt() async throws {
        let seed = Core.Container.Snapshot.placeholder(id: "web", image: "nginx:stable", runtimeKind: .appleContainer)
        let original = Core.Container.Snapshot(configuration: seed.configuration, id: "web",
                                               status: .init(state: .stopped), runtimeKind: .appleContainer)
        let runtime = RecordingContainerRuntime(containers: [original],
            createErrors: [.nonZeroExit(code: 1, stderr: "replacement failed", command: "run replacement")])
        let orchestrator = Core.Orchestrator(cliURLs: [.appleContainer: URL(fileURLWithPath: "/usr/bin/container")],
            runtimes: [.appleContainer: runtime] as [Core.Runtime.Kind: any RuntimeClient])
        do {
            _ = try await orchestrator.recreateContainer(originalID: "web", replacement: recreateDocument(),
                                                         rollback: recreateDocument(name: "web"))
            Issue.record("Expected replacement failure")
        } catch let failure as Core.Container.RecreateFailure {
            #expect(failure.recovery == .originalRestored)
        }
        #expect(await runtime.creationStarts == [true, false])
        #expect(await runtime.containers.first?.state == .stopped)
        #expect(await runtime.startedIDs.isEmpty)
    }
}

private struct UnavailableRuntime: RuntimeClient,
                                   RuntimeContainerClient,
                                   RuntimeSystemStatusClient,
                                   RuntimeDNSClient,
                                   RuntimeKernelClient,
                                   RuntimeExecClient,
                                   RuntimeSystemLogsClient,
                                   RuntimeComposeClient,
                                   RuntimeNetworkClient,
                                   RuntimeVolumeClient,
                                   RuntimeImageClient,
                                   RuntimeRegistryClient,
                                   RuntimeServiceControlClient {
    let descriptor: Core.Runtime.Descriptor
    var containers: [Core.Container.Snapshot] = []
    var listError: TestStubError?

    func listContainers(all: Bool) async throws -> [Core.Container.Snapshot] {
        if let listError { throw listError }
        return containers
    }
    func stats(ids: [String]) async throws -> [Core.Metrics.ContainerStats] { [] }
    func streamStats(ids: [String]) -> AsyncThrowingStream<[Core.Metrics.RuntimeStatsSnapshot], Error> {
        AsyncThrowingStream { $0.finish() }
    }
    func diskUsage() async throws -> Core.System.DiskUsage { throw TestStubError.unused }
    func systemProperties() async throws -> Core.System.Properties { throw TestStubError.unused }
    func dnsDomains() async throws -> [String] { [] }
    func createDNSDomain(_ domain: String) async throws -> Data { throw TestStubError.unused }
    func deleteDNSDomain(_ domain: String) async throws -> Data { throw TestStubError.unused }
    func setRecommendedKernel() async throws -> Data { throw TestStubError.unused }
    func execCapture(_ id: String, _ command: [String]) async throws -> String { "" }
    func copy(source: String, destination: String) async throws -> Data { throw TestStubError.unused }
    func streamSystemLogs(follow: Bool, last: Int?) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { $0.finish() }
    }
    func systemStatus() async throws -> Core.System.Status { throw TestStubError.unused }
    func networks() async throws -> [Core.Network.Resource] { [] }
    func volumes() async throws -> [Core.Volume.Resource] { [] }
    func images() async throws -> [Core.Image.Resource] { [] }
    func inspectImage(_ ref: String) async throws -> [Core.Image.Resource] { [] }
    func streamLogs(id: String, follow: Bool, tail: Int?, boot: Bool) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { $0.finish() }
    }
    func streamPull(_ ref: String, platform: String?) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { $0.finish() }
    }
    func streamBuild(context: String, tag: String?, dockerfile: String?,
                     buildArgs: [String: String], noCache: Bool, ssh: Bool,
                     platform: String?) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { $0.finish() }
    }
    func streamPush(_ ref: String, platform: String?) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { $0.finish() }
    }
    func runContainer(arguments: [String]) async throws -> Data { throw TestStubError.unused }
    func performSystemAction(_ action: Core.Runtime.SystemAction) async throws -> Data { throw TestStubError.unused }
    func registries() async throws -> [Core.Registry.Login] { [] }
    func registryLogin(server: String, username: String, password: String) async throws -> Data { throw TestStubError.unused }
    func registryLogout(server: String) async throws -> Data { throw TestStubError.unused }
    func deleteImages(_ refs: [String]) async throws -> Data { throw TestStubError.unused }
    func tagImage(source: String, target: String) async throws -> Data { throw TestStubError.unused }
    func saveImages(_ refs: [String], to output: String) async throws -> Data { throw TestStubError.unused }
    func loadImages(from input: String) async throws -> Data { throw TestStubError.unused }
    func exportContainer(_ id: String, to output: String) async throws -> Data { throw TestStubError.unused }
    func pruneImages(all: Bool) async throws -> Data { throw TestStubError.unused }
    func start(_ ids: [String]) async throws -> Data { throw TestStubError.unused }
    func stop(_ ids: [String]) async throws -> Data { throw TestStubError.unused }
    func deleteContainers(_ ids: [String], force: Bool) async throws -> Data { throw TestStubError.unused }
    func pruneContainers() async throws -> Data { throw TestStubError.unused }
    func pruneVolumes() async throws -> Data { throw TestStubError.unused }
    func pruneNetworks() async throws -> Data { throw TestStubError.unused }
    func createVolume(name: String, size: String?, labels: [String: String]) async throws -> Data { throw TestStubError.unused }
    func deleteVolumes(_ names: [String]) async throws -> Data { throw TestStubError.unused }
    func createNetwork(name: String, subnet: String?, internalOnly: Bool,
                       labels: [String: String]) async throws -> Data { throw TestStubError.unused }
    func deleteNetworks(_ names: [String]) async throws -> Data { throw TestStubError.unused }
}

private enum TestStubError: Error {
    case unused
}

private actor RecordingContainerRuntime: RuntimeClient, RuntimeContainerClient, RuntimeImageClient {
    nonisolated let descriptor = Core.Runtime.Descriptor.appleContainer
    var containers: [Core.Container.Snapshot]
    var deleteError: Core.Command.Error?
    var startError: Core.Command.Error?
    var startState: Core.Runtime.Status
    var createErrors: [Core.Command.Error]
    var deletedIDs: [String] = []
    var stoppedIDs: [String] = []
    var startedIDs: [String] = []
    var createdRequests: [Core.Container.CreateRequest] = []
    var creationStarts: [Bool] = []
    var inspectedImages: [Core.Image.Resource]
    var inspectError: Core.Command.Error?
    var creationDigests: [String?]
    var creationStates: [Core.Runtime.Status]

    init(containers: [Core.Container.Snapshot],
         deleteError: Core.Command.Error? = nil,
         startError: Core.Command.Error? = nil,
         startState: Core.Runtime.Status = .running,
         createErrors: [Core.Command.Error] = [],
         inspectedImages: [Core.Image.Resource] = [],
         inspectError: Core.Command.Error? = nil,
         creationDigests: [String?] = [],
         creationStates: [Core.Runtime.Status] = []) {
        self.containers = containers
        self.deleteError = deleteError
        self.startError = startError
        self.startState = startState
        self.createErrors = createErrors
        self.inspectedImages = inspectedImages
        self.inspectError = inspectError
        self.creationDigests = creationDigests
        self.creationStates = creationStates
    }

    func listContainers(all: Bool) async throws -> [Core.Container.Snapshot] { containers }
    func stats(ids: [String]) async throws -> [Core.Metrics.ContainerStats] { [] }
    nonisolated func streamStats(ids: [String]) -> AsyncThrowingStream<[Core.Metrics.RuntimeStatsSnapshot], Error> {
        AsyncThrowingStream { $0.finish() }
    }
    nonisolated func streamLogs(id: String, follow: Bool, tail: Int?, boot: Bool) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { $0.finish() }
    }
    nonisolated func previewCreateCommand(for request: Core.Container.CreateRequest, start: Bool) throws -> Core.Command.Preview {
        Core.Command.Preview(command: [start ? "run" : "create", request.image])
    }
    func createContainer(_ request: Core.Container.CreateRequest, start: Bool) async throws -> Core.Container.CreateResult {
        createdRequests.append(request)
        creationStarts.append(start)
        if !createErrors.isEmpty { throw createErrors.removeFirst() }
        let id = request.name.isEmpty ? "created" : request.name
        let digest = creationDigests.isEmpty ? nil : creationDigests.removeFirst()
        let state = creationStates.isEmpty ? (start ? Core.Runtime.Status.running : .stopped) : creationStates.removeFirst()
        let descriptor = digest.map { Core.Container.Descriptor(digest: $0, mediaType: nil, size: nil) }
        let initProcess = try JSONDecoder().decode(Core.Container.ProcessConfiguration.self,
                                                   from: Data("{}".utf8))
        let configuration = Core.Container.Configuration(
            runtimeKind: .appleContainer,
            id: id,
            image: Core.Container.ImageReference(reference: request.image, descriptor: descriptor),
            initProcess: initProcess
        )
        containers.removeAll { $0.id == id }
        containers.append(Core.Container.Snapshot(
            configuration: configuration,
            id: id,
            status: Core.Container.RuntimeState(state: state),
            runtimeKind: .appleContainer
        ))
        return Core.Container.CreateResult(id: id)
    }
    func runContainer(arguments: [String]) async throws -> Data { Data() }
    func start(_ ids: [String]) async throws -> Data {
        startedIDs.append(contentsOf: ids)
        if let startError { throw startError }
        setState(startState, for: ids)
        return Data()
    }
    func stop(_ ids: [String]) async throws -> Data {
        stoppedIDs.append(contentsOf: ids)
        setState(.stopped, for: ids)
        return Data()
    }
    private func setState(_ state: Core.Runtime.Status, for ids: [String]) {
        containers = containers.map { snapshot in
            guard ids.contains(snapshot.id) else { return snapshot }
            return Core.Container.Snapshot(configuration: snapshot.configuration, id: snapshot.id,
                                           status: .init(state: state), runtimeKind: snapshot.runtimeKind)
        }
    }
    func deleteContainers(_ ids: [String], force: Bool) async throws -> Data {
        deletedIDs.append(contentsOf: ids)
        if let deleteError { throw deleteError }
        containers.removeAll { ids.contains($0.id) }
        return Data()
    }
    func pruneContainers() async throws -> Data { Data() }
    func images() async throws -> [Core.Image.Resource] { inspectedImages }
    func inspectImage(_ ref: String) async throws -> [Core.Image.Resource] {
        if let inspectError { throw inspectError }
        return inspectedImages
    }
    nonisolated func streamPull(_ ref: String, platform: String?) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { $0.finish() }
    }
    nonisolated func streamBuild(context: String, tag: String?, dockerfile: String?,
                                 buildArgs: [String: String], noCache: Bool, ssh: Bool,
                                 platform: String?) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { $0.finish() }
    }
    nonisolated func streamPush(_ ref: String, platform: String?) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { $0.finish() }
    }
    func deleteImages(_ refs: [String]) async throws -> Data { Data() }
    func tagImage(source: String, target: String) async throws -> Data { Data() }
    func saveImages(_ refs: [String], to output: String) async throws -> Data { Data() }
    func loadImages(from input: String) async throws -> Data { Data() }
    func exportContainer(_ id: String, to output: String) async throws -> Data { Data() }
    func pruneImages(all: Bool) async throws -> Data { Data() }
}
