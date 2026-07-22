import Testing
@testable import ContainedUI

@Suite("Bounded console buffering")
struct BoundedLineBufferTests {
    @Test func bufferEvictsByLineWithoutRenumberingRemainingBlocks() {
        var buffer = UI.Console.BoundedLineBuffer(capacity: 45)
        buffer.append((0..<40).map { "line-\($0)" })
        let firstBlockID = buffer.blocks.first?.id
        let secondBlockInput = (40..<45).map { "line-\($0)" }
        buffer.append(secondBlockInput)
        let secondBlockID = buffer.blocks.last?.id

        buffer.append((45..<55).map { "line-\($0)" })

        #expect(buffer.lineCount == 45)
        #expect(buffer.blocks.first?.id == firstBlockID)
        #expect(buffer.blocks.contains { $0.id == secondBlockID })
        #expect(buffer.copyText.hasPrefix("line-10"))
        #expect(buffer.copyText.hasSuffix("line-54"))
    }

    @Test @MainActor func streamBufferPreservesPartialLinesAndBlankLines() {
        let stream = UI.Console.StreamBuffer(capacity: 20)
        stream.enqueue("hello")
        stream.enqueue(" world\n\nthird")
        stream.finish()

        #expect(stream.output.lineCount == 3)
        #expect(stream.output.copyText == "hello world\n\nthird")
    }

    @Test @MainActor func clearResetsPublishedOutput() {
        let stream = UI.Console.StreamBuffer(capacity: 20)
        stream.enqueue("one\ntwo\n")
        stream.finish()
        stream.clear()

        #expect(stream.output.lineCount == 0)
        #expect(stream.output.blocks.isEmpty)
        #expect(stream.output.copyText.isEmpty)
    }

    @Test @MainActor func unicodeBurstPublishesOnceAndRetainsExactlyCapacity() {
        let stream = UI.Console.StreamBuffer(capacity: 5_000)
        let chunk = (0..<6_000).map { "λ-line-\($0)" }.joined(separator: "\n") + "\n"

        stream.enqueue(chunk)
        stream.finish()

        #expect(stream.publicationCount == 1)
        #expect(stream.output.lineCount == 5_000)
        #expect(stream.output.copyText.hasPrefix("λ-line-1000"))
        #expect(stream.output.copyText.hasSuffix("λ-line-5999"))
        #expect(stream.output.blocks.allSatisfy { $0.lineCount <= 40 })
        #expect(stream.output.blocks.allSatisfy { $0.text.utf8.count <= 8_192 })
    }

    @Test @MainActor func cancellationFlushesTrailingPartialLine() {
        let stream = UI.Console.StreamBuffer(capacity: 20)
        stream.enqueue("complete\npartial")

        stream.cancel()

        #expect(stream.output.copyText == "complete\npartial")
        #expect(stream.output.lineCount == 2)
    }
}
