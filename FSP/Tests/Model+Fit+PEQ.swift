import Testing
import Metal
import Foundation
@testable import FSP

@Suite
struct ModelPEQFitTestCases {
    @Test(arguments: [[1.0, 1.0, 1.0], [0.0, 2.0, 0.0]])
    func weightedMagnitudeLoss(weight: [Double]) throws {
        let queue = try #require(MTLCreateSystemDefaultDevice()?.makeCommandQueue())
        let response = [1.2, 1.5, 0.8]
        var loss: Float?
        let fitted = Model.fit(response: response,
                               frequency: [0.1, 0.2, 0.3],
                               weight: weight,
                               initial: [(ω: 0.25, Q: 1.0, A: 1.0)],
                               update: (ω: 0, Q: 0, A: 0, r: 0),
                               queue: queue,
                               epoch: (major: 1, minor: 0)) { _, buffers in
            loss = buffers[0].contents().load(as: Float.self)
        }
        // A = 1 gives unity response; zero learning rates preserve it.
        let expected = zip(response, weight).reduce(0.0) {
            $0 + $1.1 * ($1.0 - log($1.0) - 1)
        }
        #expect(abs(Double(try #require(loss)) - expected) < 1e-5)
        #expect(fitted.count == 1)
        #expect(abs(fitted[0].ω - 0.25) < 1e-6)
        #expect(abs(fitted[0].Q - 1) < 1e-6)
        #expect(abs(fitted[0].A - 1) < 1e-6)
    }
}
