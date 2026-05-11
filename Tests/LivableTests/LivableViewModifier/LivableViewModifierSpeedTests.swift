import Foundation
import Testing
@testable import Livable

@Test func speedAdjustmentDoesNotMoveShaderTimeBackward() {
    let start = Date(timeIntervalSinceReferenceDate: 0)
    let changeDate = start.addingTimeInterval(10)

    let beforeChange = LivableViewModifier.shaderTime(at: changeDate, phaseAnchor: 0, phaseAnchorDate: start, speed: 3)
    let afterChange = LivableViewModifier.shaderTime(
        at: changeDate,
        phaseAnchor: beforeChange,
        phaseAnchorDate: changeDate,
        speed: 0.25
    )

    #expect(beforeChange == 30)
    #expect(afterChange == beforeChange)
}

@Test func speedAdjustmentPreservesShaderUniformsAtChangeInstant() {
    let start = Date(timeIntervalSinceReferenceDate: 0)
    let changeDate = start.addingTimeInterval(8)

    let beforeChangeTime = LivableViewModifier.shaderTime(
        at: changeDate,
        phaseAnchor: 0,
        phaseAnchorDate: start,
        speed: 1
    )
    let beforeChangeState = ShaderUniforms.build(time: beforeChangeTime)

    let afterChangeTime = LivableViewModifier.shaderTime(
        at: changeDate,
        phaseAnchor: beforeChangeTime,
        phaseAnchorDate: changeDate,
        speed: 0.1
    )
    let afterChangeState = ShaderUniforms.build(time: afterChangeTime)

    #expect(afterChangeTime == beforeChangeTime)
    #expect(afterChangeState == beforeChangeState)
}

@Test func negativeSpeedFreezesAtCurrentShaderTime() {
    let start = Date(timeIntervalSinceReferenceDate: 0)

    let freezeStart = start.addingTimeInterval(5)
    let freezeTime = LivableViewModifier.shaderTime(at: freezeStart, phaseAnchor: 0, phaseAnchorDate: start, speed: 1)
    let laterTime = LivableViewModifier.shaderTime(
        at: start.addingTimeInterval(20),
        phaseAnchor: freezeTime,
        phaseAnchorDate: freezeStart,
        speed: -1
    )

    #expect(freezeTime == 5)
    #expect(laterTime == freezeTime)
}
