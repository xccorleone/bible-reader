import Testing
import Foundation
@testable import bible_reader

struct ReadingTimerTests {
    /// Mutable fake clock; the closure captures `t` by reference.
    final class Clock { var t = Date(timeIntervalSince1970: 0) }

    @Test func accruesOnlyWhileRunning() {
        let clock = Clock()
        let timer = ReadingTimer(now: { clock.t })
        clock.t += 10                       // not running yet → ignored
        timer.resume()
        clock.t += 30
        timer.pause()
        clock.t += 100                      // paused → ignored
        #expect(timer.drain() == 30)
        #expect(timer.drain() == 0)         // drained
    }

    @Test func drainKeepsRunningSegmentGoing() {
        let clock = Clock()
        let timer = ReadingTimer(now: { clock.t })
        timer.resume()
        clock.t += 5
        #expect(timer.drain() == 5)
        clock.t += 7
        #expect(timer.drain() == 7)         // segment continued across drains
    }

    @Test func resumeIsIdempotentAndTracksIsRunning() {
        let clock = Clock()
        let timer = ReadingTimer(now: { clock.t })
        #expect(timer.isRunning == false)
        timer.resume(); clock.t += 4
        timer.resume()                      // no-op, must not reset start
        clock.t += 6
        timer.pause()
        #expect(timer.isRunning == false)
        #expect(timer.drain() == 10)
    }
}
