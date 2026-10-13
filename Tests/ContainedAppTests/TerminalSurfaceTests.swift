import Darwin
import Foundation
import SwiftTerm
import Testing
import ContainedCore
@testable import ContainedApp

@Suite("Terminal process bridge", .serialized)
@MainActor
struct TerminalSurfaceTests {
    @Test func inputOutputEnvironmentResizeAndExit() async throws {
        var exits: [Int32?] = []
        let surface = shell("""
            stty -echo
            printf 'ready\r\n'
            IFS= read -r line
            printf 'input:%s\r\nTERM:%s COLORTERM:%s\r\n' "$line" "$TERM" "$COLORTERM"
            stty size
            exit 7
            """) { exits.append($0) }
        let coordinator = surface.makeCoordinator()
        let view = surface.makeTerminalView(coordinator: coordinator)
        defer { TerminalSurface.dismantleNSView(view, coordinator: coordinator) }

        try await waitUntil { text(view).contains("ready") }
        view.resize(cols: 91, rows: 47)
        view.send(data: Array("hello ".utf8)[...])
        view.pasteText("λ\n")
        try await waitUntil { !exits.isEmpty }

        #expect(exits.count == 1)
        #expect(exits.first! == 7)
        #expect(text(view).contains("input:hello λ"))
        #expect(text(view).contains("TERM:xterm-256color COLORTERM:truecolor"))
        #expect(text(view).contains("47 91"))
    }

    @Test func missingExecutableReportsExecFailure() async throws {
        var exits: [Int32?] = []
        let surface = TerminalSurface(invocation: .init(
            executableURL: URL(fileURLWithPath: "/nonexistent/contained-terminal-test"),
            arguments: [])) { exits.append($0) }
        let coordinator = surface.makeCoordinator()
        let view = surface.makeTerminalView(coordinator: coordinator)
        defer { TerminalSurface.dismantleNSView(view, coordinator: coordinator) }

        try await waitUntil { !exits.isEmpty }
        #expect(exits.count == 1)
        #expect(exits.first! == 127)
        #expect(view.process.shellPid == 0)
    }

    @Test func ptyLaunchFailureEndsSession() {
        var exits: [Int32?] = []
        let coordinator = TerminalSurface.Coordinator { exits.append($0) }
        let view = LocalProcessTerminalView(frame: .zero)
        view.processDelegate = coordinator
        defer { TerminalSurface.dismantleNSView(view, coordinator: coordinator) }

        // Fork/channel failures are distinct from exec failure (exit 127).
        view.processFailedToStart(view.process, error: .forkFailed(EAGAIN))
        #expect(exits.count == 1)
        #expect(exits.first! == nil)
        #expect(text(view).contains("Process launch failed:"))
    }

    @Test func disconnectReapsStubbornChildAndReconnectStartsFreshSession() async throws {
        var staleExits = 0
        let surface = shell("trap '' HUP TERM; printf 'ready\r\n'; read line") { _ in staleExits += 1 }
        let coordinator = surface.makeCoordinator()
        var view: LocalProcessTerminalView? = surface.makeTerminalView(coordinator: coordinator)
        let pid = try #require(view?.process.shellPid)
        #expect(pid > 0)
        try await waitUntil { text(view!).contains("ready") }

        weak let releasedView = view
        TerminalSurface.dismantleNSView(view!, coordinator: coordinator)
        view = nil
        try await waitUntil { releasedView == nil && kill(pid, 0) == -1 && errno == ESRCH }
        #expect(staleExits == 0)

        var exits: [Int32?] = []
        let replacement = shell("printf 'reconnected\r\n'; exit 0") { exits.append($0) }
        let replacementCoordinator = replacement.makeCoordinator()
        let replacementView = replacement.makeTerminalView(coordinator: replacementCoordinator)
        defer { TerminalSurface.dismantleNSView(replacementView, coordinator: replacementCoordinator) }
        try await waitUntil { !exits.isEmpty }
        #expect(exits.count == 1)
        #expect(exits.first! == 0)
        #expect(text(replacementView).contains("reconnected"))
        #expect(staleExits == 0)
    }

    @Test func controlCInterruptsForegroundProcess() async throws {
        var exits: [Int32?] = []
        let surface = shell("stty -echo; exec /bin/cat") { exits.append($0) }
        let coordinator = surface.makeCoordinator()
        let view = surface.makeTerminalView(coordinator: coordinator)
        defer { TerminalSurface.dismantleNSView(view, coordinator: coordinator) }
        view.send(data: Array("cat-ready\n".utf8)[...])
        try await waitUntil { text(view).contains("cat-ready") }
        view.send(data: [3])
        try await waitUntil { !exits.isEmpty }
        #expect(exits.count == 1)
        #expect(exits.first! == nil)
    }

    private func shell(_ script: String, onExit: @escaping (Int32?) -> Void) -> TerminalSurface {
        TerminalSurface(invocation: Core.Command.Invocation(
            executableURL: URL(fileURLWithPath: "/bin/sh"),
            arguments: ["-c", script]), onExit: onExit)
    }

    private func text(_ view: LocalProcessTerminalView) -> String {
        view.visibleRowsText(0..<view.terminalDimensions.rows).joined(separator: "\n")
    }

    private func waitUntil(_ condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now + .seconds(5)
        while !condition(), ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(condition())
        try #require(condition())
    }
}
