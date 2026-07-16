// LoopFollow
// BGChartView.swift

import Charts
import SwiftUI

/// Shared generator for the light tick emitted when a scrub lands on a new
/// anchor. File-scoped so it stays prepared across ticks instead of being
/// re-created per body evaluation.
private let scrubHaptic = UISelectionFeedbackGenerator()

private enum BGChartConfig {
    /// Tightest pinch-in zoom.
    static let minVisibleSeconds: TimeInterval = 15 * 60
    /// Widest pinch-out zoom.
    static let maxVisibleSeconds: TimeInterval = 24 * 3600
    /// Double-tap cycles the visible window through these presets.
    static let zoomPresets: [TimeInterval] = [3600, 3 * 3600, 6 * 3600, 12 * 3600, 24 * 3600]
    /// Anchor of the geometric grid pinch commits quantize to.
    static let zoomGridBaseSeconds: TimeInterval = 3600
    /// Geometric grid for pinch commits (~4 % per step). Every committed zoom
    /// step re-lays the canvas, so this bounds a halving of the visible window
    /// to roughly 18 re-layouts instead of hundreds.
    static let zoomStepRatio: Double = 1.04
    /// Live pinch previews as a transform; once the stretch drifts past this
    /// ratio a crisp re-layout is committed mid-gesture, bounding distortion.
    static let pinchCommitScaleDrift: Double = 1.25
    /// Render window extends this many visible-windows beyond each visible edge.
    static let renderWindowPadFactor = 1.5
    /// Re-anchor when a visible edge gets within this fraction of a
    /// visible-window of the render window's edge.
    static let renderWindowMarginFactor = 0.5
    /// How far (pt) a one-finger touch may travel and still count as a
    /// stationary press-to-inspect; beyond this the touch becomes a pan.
    static let inspectMovementTolerance: CGFloat = 10
    /// How long (s) a one-finger touch must rest before inspect latches.
    static let inspectHoldDelay: TimeInterval = 0.2
    /// How close the visible window's trailing edge must sit to "now" before
    /// we treat the user as "at the latest data" and resume auto-following.
    static let followEdgeTolerance: TimeInterval = 90
    /// While following, "now" sits at this fraction of the visible window,
    /// leaving room on the right for predictions/cone.
    static let followNowFraction = 0.7
    /// How long after the last navigation in history before a data tick pulls
    /// the chart back to "now".
    static let autoFollowPause: TimeInterval = 5 * 60
    /// Max distance between the scrub date and an anchor for it to be selected.
    static let selectionTolerance: TimeInterval = 20 * 60
    /// Half-width (pt) of the scrub capture band: treatments whose symbol is
    /// within this screen distance of the finger join the pill alongside the
    /// (ever-present) nearest BG reading.
    static let scrubCaptureRadius: CGFloat = 22
    /// Time cap on the capture band, so wide zooms — where a finger-width
    /// covers hours — don't sweep far-away treatments into the pill.
    static let scrubCaptureMaxSeconds: TimeInterval = 5 * 60
    /// Screen-space radius (pt) within which a tap selects a mark.
    static let tapHitRadius: CGFloat = 30
}

/// Small y-domain headroom keeps the top axis label readable instead of
/// pinning it to the chart edge.
private func chartYDomainUpperBound(_ maxBG: Double) -> Double {
    let clampedMax = max(maxBG, 1)
    let topPadding = max(clampedMax * 0.02, 1)
    return clampedMax + topPadding
}

struct BGChartView: View {
    enum Config {
        case small
        case main
    }

    let model: BGChartModel
    let config: Config

    var body: some View {
        if config == .small {
            SmallBGChart(model: model, interaction: model.interaction)
        } else {
            MainBGChart(model: model, interaction: model.interaction)
        }
    }
}

// MARK: - Main chart shell (gestures, transforms, overlays)

/// The interactive BG chart.
///
/// Rendering/interaction strategy: the chart content is
/// laid out ONCE per (data, zoom) change onto a wide fixed-width canvas
/// covering a render window around the visible viewport. Panning translates
/// that canvas with a pure `.offset` transform — the canvas is an Equatable
/// child whose stored properties exclude the pan position, so SwiftUI skips
/// its body during pans and momentum. Zoom is a pure-SwiftUI MagnifyGesture
/// whose live preview is a `.scaleEffect(x:)` stretch anchored under the
/// pinch centroid, committed on a geometric zoom grid. A one-finger press
/// held stationary latches into inspect mode and scrubs a selection that is
/// rendered by a shell overlay (never re-laying the canvas). Double-tap
/// cycles zoom presets. No `.chartScrollableAxes`, no UIKit gesture hacks.
private struct MainBGChart: View {
    @ObservedObject var model: BGChartModel
    @ObservedObject var interaction: BGChartInteraction

    @State private var didInitialize = false

    /// Rendered slice of the domain. The canvas covers only this window
    /// (visible ± `renderWindowPadFactor` viewports), bounding canvas width
    /// and per-layout cost no matter how long the data domain grows.
    @State private var renderWindowStart = Date()
    @State private var renderWindowEnd = Date().addingTimeInterval(3600)

    /// Plot area of the static axis overlay, in shell coordinates. The
    /// selection overlay uses it for its value-to-pixel maps.
    @State private var plotFrame: CGRect = .zero

    /// Measured size of the visible selection pill (see PillSizePreferenceKey).
    @State private var pillSize: CGSize = .zero

    // Pinch state: live preview stretch plus the anchor captured at pinch
    // start so the zoom stays anchored under the pinch centroid.
    @State private var pinchScale: CGFloat = 1
    @State private var pinchAnchor: (
        visibleAtStart: TimeInterval,
        anchorDate: Date,
        anchorFraction: CGFloat
    )?

    /// Leading edge captured when a one-finger drag transitions into panning.
    @State private var panBaseline: Date?

    /// Date under the user's finger while inspecting, else nil.
    @State private var selection: Date?

    /// Anchor selected by tapping a mark; sticky until the user taps empty
    /// space, taps another mark, or starts a pan/zoom/inspect.
    @State private var tapped: SelectionAnchor?

    /// True once a held press has engaged inspect; from then on finger
    /// movement scrubs the selection instead of panning, until the finger lifts.
    @State private var isInspectLatched = false

    /// Most recent finger location, so the hold timer can place the selection
    /// even if the finger produced no further events after touch-down.
    @State private var lastTouchLocation: CGPoint?

    /// Armed at touch-down; fires after `inspectHoldDelay` and latches inspect
    /// if the touch is still down and stationary. A timer is required because
    /// DragGesture only reports *changes* — a perfectly still finger generates
    /// no events after touch-down.
    @State private var inspectHoldTask: Task<Void, Never>?
    @State private var touchDownTime: Date?

    /// Drives post-flick deceleration; cancelled by any new touch.
    @State private var momentumTask: Task<Void, Never>?

    /// Anchor date of the last haptic tick, so scrub jitter doesn't re-fire it.
    @State private var lastHapticAnchorDate: Date?

    /// While the user is (or recently was) navigating history, auto-return to
    /// "now" is paused until this instant. Refreshed by every scroll movement
    /// away from the live edge, cleared on return to it.
    @State private var autoFollowPausedUntil: Date?

    private var timeZoneForAxis: TimeZone {
        if Storage.shared.graphTimeZoneEnabled.value,
           let tz = TimeZone(identifier: Storage.shared.graphTimeZoneIdentifier.value)
        {
            return tz
        }
        return .current
    }

    var body: some View {
        GeometryReader { geo in
            chart(viewport: geo.size)
        }
        .background(Color(.systemBackground))
    }

    private func chart(viewport: CGSize) -> some View {
        let viewportWidth = max(viewport.width, 1)
        let windowSeconds = max(renderWindowEnd.timeIntervalSince(renderWindowStart), 1)
        let canvasWidth = viewportWidth * CGFloat(windowSeconds / interaction.visibleSeconds)
        // Pixel offset of the canvas for the current leading-edge date.
        // Derived, not stored: re-anchoring the window recomputes it consistently.
        let canvasOffsetX = CGFloat(
            interaction.scrollPosition.timeIntervalSince(renderWindowStart) / windowSeconds
        ) * canvasWidth

        return ZStack(alignment: .topLeading) {
            BGChartCanvas(
                model: model,
                generation: model.generation,
                isSmall: false,
                windowStart: renderWindowStart,
                windowEnd: renderWindowEnd,
                canvasWidth: canvasWidth,
                height: viewport.height,
                visibleSeconds: interaction.visibleSeconds,
                timeZone: timeZoneForAxis
            )
            .equatable()
            .offset(x: -canvasOffsetX)
            .scaleEffect(
                x: pinchScale,
                y: 1,
                anchor: pinchScaleAnchor(viewportWidth: viewportWidth, canvasWidth: canvasWidth)
            )

            // Pinned y-axis labels (BG trailing, basal leading) over the
            // scrolling canvas. The canvas's own y-axis is hidden — its
            // trailing edge sits far off-screen on the wide canvas.
            StaticYAxisOverlay(generation: model.generation, maxBG: model.maxBG, maxBasal: model.maxBasal)
                .equatable()
                .frame(width: viewportWidth, height: viewport.height)
                .allowsHitTesting(false)

            selectionOverlay(viewportWidth: viewportWidth)
                .allowsHitTesting(false)

            overrideBandLabelsOverlay(viewportWidth: viewportWidth)
                .allowsHitTesting(false)

            if !interaction.followLatest {
                jumpToNowButton
            }
        }
        .frame(width: viewportWidth, height: viewport.height, alignment: .topLeading)
        .clipped()
        .contentShape(Rectangle())
        .simultaneousGesture(panAndInspectGesture(viewportWidth: viewportWidth))
        .simultaneousGesture(magnifyGesture(viewportWidth: viewportWidth))
        // Double-tap zooms; a single tap (only recognized once the double-tap
        // window lapses) selects the mark under the finger, or clears the pill.
        .simultaneousGesture(
            TapGesture(count: 2)
                .exclusively(before: SpatialTapGesture())
                .onEnded { value in
                    switch value {
                    case .first:
                        cycleZoomPreset()
                    case let .second(tap):
                        handleTap(at: tap.location, viewportWidth: viewportWidth)
                    }
                }
        )
        .onPreferenceChange(PlotFramePreferenceKey.self) { plotFrame = $0 }
        .onPreferenceChange(PillSizePreferenceKey.self) { pillSize = $0 }
        .onChange(of: interaction.scrollPosition) { _, _ in
            updateRenderWindow()
            updateFollowState()
        }
        .onChange(of: interaction.visibleSeconds) { _, _ in
            updateRenderWindow(force: true)
        }
        .onChange(of: model.now) { _, _ in
            if interaction.followLatest {
                scrollToNow(animated: true)
            } else if let pausedUntil = autoFollowPausedUntil, Date() >= pausedUntil {
                // Idle in history past the pause: the next data tick pulls the
                // chart back to live.
                scrollToNow(animated: true)
            }
            updateRenderWindow()
        }
        .onAppear {
            if !didInitialize {
                didInitialize = true
                scrollToNow(animated: false)
                updateRenderWindow(force: true)
            }
        }
        .onDisappear {
            momentumTask?.cancel()
            inspectHoldTask?.cancel()
        }
    }

    private var jumpToNowButton: some View {
        Button {
            scrollToNow(animated: true)
        } label: {
            Image(systemName: "arrow.right.to.line")
                .font(.footnote.bold())
                .foregroundColor(.primary)
                .padding(8)
                .background(Circle().fill(Color(.secondarySystemBackground)))
                .overlay(Circle().stroke(Color.primary.opacity(0.25), lineWidth: 0.5))
        }
        .padding(.trailing, 44)
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
    }

    // MARK: Render window / follow state

    /// Re-anchors the render window when the visible window nears its edge.
    /// Between re-anchors, panning stays a pure offset transform.
    private func updateRenderWindow(force: Bool = false) {
        let visibleSeconds = interaction.visibleSeconds
        let pad = BGChartConfig.renderWindowPadFactor * visibleSeconds
        let margin = BGChartConfig.renderWindowMarginFactor * visibleSeconds
        let domainStart = model.domainStart
        let domainEnd = max(model.domainEnd, domainStart.addingTimeInterval(1))
        let visibleStart = max(interaction.scrollPosition, domainStart)
        // Before the first rebuild the scroll position can sit entirely outside
        // the (not yet populated) domain; never let the window invert.
        let visibleEnd = max(
            min(interaction.scrollPosition.addingTimeInterval(visibleSeconds), domainEnd),
            visibleStart
        )

        let nearLeft = visibleStart.timeIntervalSince(renderWindowStart) < margin
            && renderWindowStart > domainStart
        let nearRight = renderWindowEnd.timeIntervalSince(visibleEnd) < margin
            && renderWindowEnd < domainEnd
        let uncovered = visibleStart < renderWindowStart || visibleEnd > renderWindowEnd
        guard force || nearLeft || nearRight || uncovered else { return }

        let newStart = max(visibleStart.addingTimeInterval(-pad), domainStart)
        let newEnd = max(
            min(visibleEnd.addingTimeInterval(pad), domainEnd),
            newStart.addingTimeInterval(1)
        )
        guard newStart != renderWindowStart || newEnd != renderWindowEnd else { return }
        renderWindowStart = newStart
        renderWindowEnd = newEnd
    }

    /// Re-arms following only when the visible window's trailing edge has
    /// caught back up to "now"; otherwise the user is in history, and every
    /// movement there refreshes the auto-return pause.
    private func updateFollowState() {
        let trailingEdge = interaction.scrollPosition.addingTimeInterval(interaction.visibleSeconds)
        let follow = trailingEdge >= model.now.addingTimeInterval(-BGChartConfig.followEdgeTolerance)
        autoFollowPausedUntil = follow ? nil : Date().addingTimeInterval(BGChartConfig.autoFollowPause)
        if interaction.followLatest != follow {
            interaction.followLatest = follow
        }
    }

    /// Clamps a proposed leading edge so the visible window never leaves the domain.
    private func clampedLeadingEdge(_ proposed: Date) -> Date {
        // Before the first rebuild the domain is an epoch-0 placeholder;
        // clamping against it would pin the chart to "the beginning of time"
        // and (via the follow observer) disarm auto-following for good.
        guard model.domainEnd > model.domainStart.addingTimeInterval(1) else { return proposed }
        let earliest = model.domainStart
        let latest = model.domainEnd.addingTimeInterval(-interaction.visibleSeconds)
        return min(max(proposed, earliest), max(earliest, latest))
    }

    /// Positions "now" at `followNowFraction` of the visible window and keeps
    /// following armed. Never yanks the chart out from under an active gesture
    /// or momentum; the next data tick re-anchors as usual.
    private func scrollToNow(animated: Bool) {
        guard pinchAnchor == nil, panBaseline == nil, !isInspectLatched, momentumTask == nil else { return }
        interaction.followLatest = true
        let target = clampedLeadingEdge(
            model.now.addingTimeInterval(-interaction.visibleSeconds * BGChartConfig.followNowFraction)
        )
        // Animate only moves the render window already covers (its padding
        // guarantees a window around the visible edges): the offset transform
        // then interpolates over unchanged canvas content. A longer move
        // re-anchors the window, which would swap the content out from under
        // the in-flight animation — so deep returns snap instead.
        let distance = abs(target.timeIntervalSince(interaction.scrollPosition))
        if animated, distance <= interaction.visibleSeconds {
            withAnimation(.easeInOut(duration: 0.3)) {
                interaction.scrollPosition = target
            }
        } else {
            interaction.scrollPosition = target
        }
    }

    // MARK: Gestures

    private var isPinching: Bool { pinchAnchor != nil }

    /// Converts a horizontal translation (pt) into a time delta within the visible window.
    private func timeDelta(forTranslation dx: CGFloat, viewportWidth: CGFloat) -> TimeInterval {
        TimeInterval(dx / viewportWidth) * interaction.visibleSeconds
    }

    /// One-finger gesture: movement pans (with momentum on release); a press
    /// held in place latches into inspect, after which dragging scrubs the
    /// selection until the finger lifts. Panning only mutates scrollPosition
    /// (a transform) and scrubbing only the shell overlay, so neither path
    /// re-lays the canvas.
    private func panAndInspectGesture(viewportWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                momentumTask?.cancel()
                momentumTask = nil
                guard !isPinching else {
                    inspectHoldTask?.cancel()
                    if selection != nil { selection = nil }
                    panBaseline = nil
                    touchDownTime = nil
                    isInspectLatched = false
                    return
                }
                lastTouchLocation = value.location
                if touchDownTime == nil {
                    touchDownTime = value.time
                    scheduleInspectHold(viewportWidth: viewportWidth)
                }

                if isInspectLatched {
                    updateSelection(atViewportX: value.location.x, viewportWidth: viewportWidth)
                    return
                }

                let distance = hypot(value.translation.width, value.translation.height)
                if panBaseline == nil, distance < BGChartConfig.inspectMovementTolerance {
                    // Finger is stationary: the hold timer armed at touch-down
                    // will latch inspect if it stays that way.
                } else {
                    // Finger is travelling: pan. The touch can no longer become an inspect.
                    inspectHoldTask?.cancel()
                    if selection != nil { selection = nil }
                    if tapped != nil { tapped = nil }
                    if panBaseline == nil {
                        // Compensate for the distance already travelled inside the
                        // tolerance so the pan engages without a positional jump.
                        panBaseline = interaction.scrollPosition.addingTimeInterval(
                            timeDelta(forTranslation: value.translation.width, viewportWidth: viewportWidth)
                        )
                    }
                    if let baseline = panBaseline {
                        interaction.scrollPosition = clampedLeadingEdge(
                            baseline.addingTimeInterval(
                                -timeDelta(forTranslation: value.translation.width, viewportWidth: viewportWidth)
                            )
                        )
                    }
                }
            }
            .onEnded { value in
                inspectHoldTask?.cancel()
                if selection != nil { selection = nil }
                touchDownTime = nil
                isInspectLatched = false
                lastTouchLocation = nil
                lastHapticAnchorDate = nil
                let wasPanning = panBaseline != nil
                panBaseline = nil
                guard wasPanning, !isPinching else { return }
                // Momentum: initial velocity in seconds of chart time per second.
                let velocity = -timeDelta(forTranslation: value.velocity.width, viewportWidth: viewportWidth)
                startMomentum(velocitySecondsPerSecond: velocity)
            }
    }

    /// Arms the inspect hold: after `inspectHoldDelay`, if the touch is still
    /// down and has neither become a pan nor a pinch, latch into inspect mode
    /// at the finger's last known position — with a haptic so the mode change is felt.
    private func scheduleInspectHold(viewportWidth: CGFloat) {
        inspectHoldTask?.cancel()
        inspectHoldTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(BGChartConfig.inspectHoldDelay * 1_000_000_000))
            guard !Task.isCancelled,
                  touchDownTime != nil,
                  panBaseline == nil,
                  !isPinching,
                  !isInspectLatched
            else { return }

            isInspectLatched = true
            tapped = nil
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            scrubHaptic.prepare()
            if let location = lastTouchLocation {
                updateSelection(atViewportX: location.x, viewportWidth: viewportWidth)
            }
        }
    }

    private func updateSelection(atViewportX x: CGFloat, viewportWidth: CGFloat) {
        let fraction = min(max(x / viewportWidth, 0), 1)
        let date = interaction.scrollPosition.addingTimeInterval(
            interaction.visibleSeconds * TimeInterval(fraction)
        )
        selection = date
        // A featherlight tick whenever the indicator snaps to a different item.
        let captureWindow = scrubCaptureWindow(viewportWidth: viewportWidth)
        if let anchor = selectionAnchor(for: date, captureWindow: captureWindow), anchor.date != lastHapticAnchorDate {
            lastHapticAnchorDate = anchor.date
            scrubHaptic.selectionChanged()
            scrubHaptic.prepare()
        }
    }

    /// Deceleration after a flick. Mutates only scrollPosition (a transform),
    /// so each frame costs a GPU translation — same profile as live panning.
    private func startMomentum(velocitySecondsPerSecond initialVelocity: TimeInterval) {
        let visibleSeconds = interaction.visibleSeconds
        // Ignore tiny flicks.
        guard abs(initialVelocity) > visibleSeconds * 0.05 else { return }
        momentumTask?.cancel()
        momentumTask = Task { @MainActor in
            var velocity = initialVelocity
            var expected = interaction.scrollPosition
            let frameDuration: TimeInterval = 1.0 / 60.0
            while !Task.isCancelled, abs(velocity) > visibleSeconds * 0.02 {
                try? await Task.sleep(nanoseconds: UInt64(frameDuration * 1_000_000_000))
                guard !Task.isCancelled else { break }
                // Someone else (small-chart tap, data snap) moved the chart: yield.
                guard interaction.scrollPosition == expected else { break }
                let next = clampedLeadingEdge(expected.addingTimeInterval(velocity * frameDuration))
                guard next != expected else { break } // hit a domain edge
                interaction.scrollPosition = next
                expected = next
                velocity *= 0.97
            }
            // Every reassignment of momentumTask cancels the old task first, so
            // an uncancelled task is still the current one and may clear the slot;
            // a cancelled one must not (it could clobber its successor).
            if !Task.isCancelled {
                momentumTask = nil
            }
        }
    }

    /// Two-finger pinch drives the zoom continuously, anchored under the pinch
    /// centroid. Zoom changes re-lay the canvas, so commits are quantized to a
    /// geometric grid to bound the number of re-layouts per pinch.
    private func magnifyGesture(viewportWidth _: CGFloat) -> some Gesture {
        MagnifyGesture(minimumScaleDelta: 0.01)
            .onChanged { value in
                momentumTask?.cancel()
                momentumTask = nil
                if pinchAnchor == nil {
                    let fraction = min(max(value.startAnchor.x, 0), 1)
                    pinchAnchor = (
                        visibleAtStart: interaction.visibleSeconds,
                        anchorDate: interaction.scrollPosition.addingTimeInterval(
                            interaction.visibleSeconds * TimeInterval(fraction)
                        ),
                        anchorFraction: fraction
                    )
                    inspectHoldTask?.cancel()
                    if selection != nil { selection = nil }
                    if tapped != nil { tapped = nil }
                    isInspectLatched = false
                }
                guard let pinch = pinchAnchor, value.magnification > 0 else { return }

                // Live pinch previews as a transform: stretch the already-laid-out
                // canvas about the centroid. Pinch out (magnification > 1) narrows
                // the visible window, i.e. zooms in. Once the stretch drifts past
                // the commit threshold, a crisp re-layout is committed mid-gesture
                // and the transform continues from that new baseline.
                let proposed = min(
                    max(
                        pinch.visibleAtStart / TimeInterval(value.magnification),
                        BGChartConfig.minVisibleSeconds
                    ),
                    BGChartConfig.maxVisibleSeconds
                )
                pinchScale = CGFloat(interaction.visibleSeconds / proposed)

                let drift = BGChartConfig.pinchCommitScaleDrift
                if pinchScale > drift || pinchScale < 1 / drift {
                    commitPinchZoom(proposed)
                }
            }
            .onEnded { _ in
                guard pinchAnchor != nil else { return }
                commitPinchZoom(interaction.visibleSeconds / TimeInterval(pinchScale))
                // The commit no-ops when the zoom quantizes back to the current
                // value; the preview must still un-stretch.
                pinchScale = 1
                pinchAnchor = nil
                interaction.persistZoom()
            }
    }

    /// Quantizes to the geometric zoom grid and re-lays the canvas exactly
    /// once: window re-anchor happens in the same transaction.
    private func commitPinchZoom(_ proposed: TimeInterval) {
        guard let pinch = pinchAnchor else { return }
        let ratio = BGChartConfig.zoomStepRatio
        let base = BGChartConfig.zoomGridBaseSeconds
        let step = (log(proposed / base) / log(ratio)).rounded()
        var quantized = base * pow(ratio, step)
        quantized = min(
            max(quantized, BGChartConfig.minVisibleSeconds),
            BGChartConfig.maxVisibleSeconds
        )
        guard quantized != interaction.visibleSeconds else { return }

        interaction.visibleSeconds = quantized
        interaction.scrollPosition = clampedLeadingEdge(
            pinch.anchorDate.addingTimeInterval(-quantized * TimeInterval(pinch.anchorFraction))
        )
        updateRenderWindow(force: true)
        pinchScale = 1
    }

    /// Anchor for the live-pinch stretch: the centroid's layout position on
    /// the canvas, so the content under the fingers stays put on screen.
    private func pinchScaleAnchor(viewportWidth: CGFloat, canvasWidth: CGFloat) -> UnitPoint {
        guard let pinch = pinchAnchor, canvasWidth > 0 else { return .center }
        return UnitPoint(x: pinch.anchorFraction * viewportWidth / canvasWidth, y: 0.5)
    }

    /// Double-tap cycles the zoom presets. Snap, no animation: animating the
    /// zoom would animate canvasWidth, re-laying the canvas every frame.
    private func cycleZoomPreset() {
        let presets = BGChartConfig.zoomPresets
        let current = interaction.visibleSeconds
        let next = presets.first(where: { $0 > current + 1 }) ?? presets[0]
        momentumTask?.cancel()
        momentumTask = nil
        tapped = nil
        let trailing = interaction.scrollPosition.addingTimeInterval(current)
        interaction.visibleSeconds = next
        if interaction.followLatest {
            interaction.scrollPosition = clampedLeadingEdge(
                model.now.addingTimeInterval(-next * BGChartConfig.followNowFraction)
            )
        } else {
            interaction.scrollPosition = clampedLeadingEdge(trailing.addingTimeInterval(-next))
        }
        updateRenderWindow(force: true)
        interaction.persistZoom()
    }

    // MARK: Selection

    private struct SelectionAnchor {
        /// Where the pill/indicator is drawn — a treatment's `drawnDate`, so the
        /// indicator lands on the symbol even when decluttering moved it.
        let date: Date
        let value: Double
        /// One pill entry per item under the selector (see PillLabel).
        let texts: [String]
    }

    /// Feeds every treatment mark to `body` as (drawnDate, value, pillText).
    /// Single source for both the scrub lookup and the tap hit test.
    private func forEachTreatmentAnchor(_ body: (Date, Double, String) -> Void) {
        for group in [model.boluses, model.carbs, model.smbs, model.bgChecks,
                      model.notes, model.suspends, model.resumes, model.sensorStarts]
        {
            for t in group {
                body(t.drawnDate, t.sgv, t.pillText)
            }
        }
    }

    /// Pill entry for a BG reading. Shared by the scrub lookup and the tap hit test.
    private func bgPillText(for point: BGChartModel.BGPoint) -> String {
        "BG\n\(Localizer.toDisplayUnits(String(Int(point.value))))\n\(model.pillTimeString(for: point.date))"
    }

    private func bandPillTexts(at date: Date) -> [String] {
        var texts: [String] = []
        if let band = model.overrides
            .filter({ date >= $0.start && date <= $0.end })
            .max(by: { $0.start < $1.start })
        {
            texts.append(band.pillText)
        }
        if let band = model.tempTargets
            .filter({ date >= $0.start && date <= $0.end })
            .max(by: { $0.start < $1.start })
        {
            texts.append(band.pillText)
        }
        return texts
    }

    /// Band (override / temp target) under the given date+value, if any.
    private func bandAnchor(at date: Date, value: Double) -> SelectionAnchor? {
        for band in model.overrides where date >= band.start && date <= band.end {
            if value >= band.yBottom, value <= band.yTop {
                let midY = (band.yTop + band.yBottom) / 2
                return SelectionAnchor(date: date, value: midY, texts: [band.pillText])
            }
        }
        for band in model.tempTargets where date >= band.start && date <= band.end {
            if value >= band.yBottom, value <= band.yTop {
                let midY = (band.yTop + band.yBottom) / 2
                return SelectionAnchor(date: date, value: midY, texts: [band.pillText])
            }
        }
        return nil
    }

    /// Seconds of chart time covered by `scrubCaptureRadius` at the current
    /// zoom, bounded by `scrubCaptureMaxSeconds`.
    private func scrubCaptureWindow(viewportWidth: CGFloat) -> TimeInterval {
        min(
            BGChartConfig.scrubCaptureMaxSeconds,
            TimeInterval(BGChartConfig.scrubCaptureRadius / viewportWidth) * interaction.visibleSeconds
        )
    }

    /// Scrub lookup (time-only). Collects everything under the finger instead
    /// of picking a single winner: every treatment inside the capture window
    /// joins the pill, and the nearest BG reading always does — so treatments
    /// and glucose readings can never hide one another. The indicator snaps
    /// to the nearest collected item; the pill stacks them all (treatments in
    /// drawn order, BG last).
    private func selectionAnchor(for selected: Date, captureWindow: TimeInterval) -> SelectionAnchor? {
        struct Item {
            let date: Date
            let value: Double
            let text: String
            let distance: TimeInterval
        }

        var captured: [Item] = []
        var nearestTreatment: Item?
        forEachTreatmentAnchor { date, value, text in
            let item = Item(date: date, value: value, text: text, distance: abs(date.timeIntervalSince(selected)))
            if item.distance <= captureWindow {
                captured.append(item)
            }
            if item.distance < (nearestTreatment?.distance ?? .greatestFiniteMagnitude) {
                nearestTreatment = item
            }
        }
        captured.sort { $0.date < $1.date }

        var nearestBG: Item?
        for p in model.bg {
            let d = abs(p.date.timeIntervalSince(selected))
            if d < (nearestBG?.distance ?? .greatestFiniteMagnitude) {
                nearestBG = Item(date: p.date, value: p.value, text: bgPillText(for: p), distance: d)
            }
        }

        var items = captured
        if let nearestBG, nearestBG.distance <= BGChartConfig.selectionTolerance {
            items.append(nearestBG)
        }
        if let primary = items.min(by: { $0.distance < $1.distance }) {
            let texts = items.map(\.text) + bandPillTexts(at: selected)
            return SelectionAnchor(date: primary.date, value: primary.value, texts: texts)
        }

        // Nothing under the finger. Reach for the nearest treatment (data gaps
        // leave treatments without BG neighbors), then for a band (any height)
        // at the scrub time.
        if let nearestTreatment, nearestTreatment.distance <= BGChartConfig.selectionTolerance {
            let texts = [nearestTreatment.text] + bandPillTexts(at: selected)
            return SelectionAnchor(date: nearestTreatment.date, value: nearestTreatment.value, texts: texts)
        }
        for band in model.overrides where selected >= band.start && selected <= band.end {
            let midY = (band.yTop + band.yBottom) / 2
            return SelectionAnchor(date: selected, value: midY, texts: [band.pillText])
        }
        for band in model.tempTargets where selected >= band.start && selected <= band.end {
            let midY = (band.yTop + band.yBottom) / 2
            return SelectionAnchor(date: selected, value: midY, texts: [band.pillText])
        }

        return nil
    }

    /// Tap hit test (screen-space, 2D). Treatments take priority, then BG
    /// points, then the override/temp-target bands under the finger.
    /// Returns nil when the tap lands on nothing — which clears the pill.
    private func tappedAnchor(at location: CGPoint, viewportWidth: CGFloat) -> SelectionAnchor? {
        let radius = BGChartConfig.tapHitRadius
        var best: SelectionAnchor?
        var bestDistance2 = radius * radius

        func consider(_ date: Date, _ value: Double, _ text: String) {
            let dx = xPosition(for: date, viewportWidth: viewportWidth) - location.x
            let dy = yPosition(forValue: value) - location.y
            let d2 = dx * dx + dy * dy
            if d2 <= bestDistance2 {
                bestDistance2 = d2
                best = SelectionAnchor(date: date, value: value, texts: [text])
            }
        }

        forEachTreatmentAnchor(consider)
        if best == nil {
            for p in model.bg {
                consider(p.date, p.value, bgPillText(for: p))
            }
        }
        if best == nil {
            let date = interaction.scrollPosition.addingTimeInterval(
                interaction.visibleSeconds * TimeInterval(location.x / viewportWidth)
            )
            return bandAnchor(at: date, value: value(atY: location.y))
        }
        if let best {
            let texts = best.texts + bandPillTexts(at: best.date)
            return SelectionAnchor(date: best.date, value: best.value, texts: texts)
        }
        return nil
    }

    private func handleTap(at location: CGPoint, viewportWidth: CGFloat) {
        guard plotFrame.height > 0 else { return }
        tapped = tappedAnchor(at: location, viewportWidth: viewportWidth)
    }

    /// The anchor the overlay should show: a live scrub wins over a sticky tap.
    private func activeAnchor(viewportWidth: CGFloat) -> SelectionAnchor? {
        if isInspectLatched, let selected = selection {
            return selectionAnchor(for: selected, captureWindow: scrubCaptureWindow(viewportWidth: viewportWidth))
        }
        return tapped
    }

    // MARK: Value-to-pixel maps (shared by the selection overlay and tap hit test)

    private func xPosition(for date: Date, viewportWidth: CGFloat) -> CGFloat {
        CGFloat(
            date.timeIntervalSince(interaction.scrollPosition) / interaction.visibleSeconds
        ) * viewportWidth
    }

    private func yPosition(forValue value: Double) -> CGFloat {
        let yMax = chartYDomainUpperBound(model.maxBG)
        let clamped = min(max(value, 0), yMax)
        return plotFrame.minY + CGFloat(1 - clamped / yMax) * plotFrame.height
    }

    private func value(atY y: CGFloat) -> Double {
        guard plotFrame.height > 0 else { return 0 }
        let yMax = chartYDomainUpperBound(model.maxBG)
        let fraction = 1 - (y - plotFrame.minY) / plotFrame.height
        return Double(min(max(fraction, 0), 1)) * yMax
    }

    @ViewBuilder
    private func overrideBandLabelsOverlay(viewportWidth: CGFloat) -> some View {
        if plotFrame.height > 0 {
            let visibleStart = interaction.scrollPosition
            let visibleEnd = interaction.scrollPosition.addingTimeInterval(interaction.visibleSeconds)

            ForEach(model.overrides.filter { $0.end >= visibleStart && $0.start <= visibleEnd }) { band in
                let visibleBandStart = max(band.start, visibleStart)
                let visibleBandEnd = min(band.end, visibleEnd)
                let xStart = xPosition(for: visibleBandStart, viewportWidth: viewportWidth)
                let xEnd = xPosition(for: visibleBandEnd, viewportWidth: viewportWidth)
                let bandWidth = max(0, xEnd - xStart)
                let y = yPosition(forValue: (band.yBottom + band.yTop) / 2)

                if bandWidth > 24 {
                    Text(band.label)
                        .font(.caption2)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .padding(.trailing, 10)
                        .frame(width: max(0, bandWidth - 6), alignment: .trailing)
                        .clipped()
                        .position(x: xStart + bandWidth / 2, y: y)
                }
            }
        }
    }

    /// Vertical indicator + pill for the current selection, rendered in the
    /// shell with the same linear maps the canvas uses — neither scrubbing
    /// nor a tapped pill ever re-lays the canvas.
    ///
    /// The pill wraps long texts (notes) at its max width; placement uses the
    /// measured pill size so the pill always sits fully on screen, below the
    /// anchor when there is room and above it otherwise. Wrapping relies on
    /// SwiftUI's word wrapping, which respects the actual font metrics, so
    /// there is no manual line splitting.
    @ViewBuilder
    private func selectionOverlay(viewportWidth: CGFloat) -> some View {
        if plotFrame.height > 0, let anchor = activeAnchor(viewportWidth: viewportWidth) {
            let x = xPosition(for: anchor.date, viewportWidth: viewportWidth)
            if x >= 0, x <= viewportWidth {
                let y = yPosition(forValue: anchor.value)

                Rectangle()
                    .fill(Color.primary.opacity(0.5))
                    .frame(width: 1, height: plotFrame.height)
                    .position(x: x, y: plotFrame.midY)

                // Measured size lags the text by one frame; fall back to a
                // small nominal size until the first measurement lands.
                let pillW = max(pillSize.width, 60)
                let pillH = max(pillSize.height, 28)
                let labelX = min(max(x, pillW / 2 + 4), viewportWidth - pillW / 2 - 4)
                let below = y + 14 + pillH / 2
                let above = y - 14 - pillH / 2
                let fitsBelow = below + pillH / 2 <= plotFrame.maxY - 4
                let labelY = fitsBelow ? below : max(above, plotFrame.minY + pillH / 2 + 4)
                PillLabel(texts: anchor.texts, maxWidth: min(300, viewportWidth - 16))
                    .position(x: labelX, y: labelY)
            }
        }
    }
}

// MARK: - Small chart (overview + tap-to-navigate)

private struct SmallBGChart: View {
    @ObservedObject var model: BGChartModel
    @ObservedObject var interaction: BGChartInteraction

    var body: some View {
        GeometryReader { geo in
            let width = max(geo.size.width, 1)
            let domainSeconds = max(model.domainEnd.timeIntervalSince(model.domainStart), 1)

            ZStack(alignment: .topLeading) {
                BGChartCanvas(
                    model: model,
                    generation: model.generation,
                    isSmall: true,
                    windowStart: model.domainStart,
                    windowEnd: model.domainStart.addingTimeInterval(domainSeconds),
                    canvasWidth: width,
                    height: geo.size.height,
                    visibleSeconds: domainSeconds,
                    timeZone: .current
                )
                .equatable()

                viewportBox(width: width, height: geo.size.height, domainSeconds: domainSeconds)
                    .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { value in
                        navigate(toLocalX: value.location.x, width: width, domainSeconds: domainSeconds)
                    }
            )
        }
        .background(Color(.systemBackground))
    }

    /// Box showing where the main chart's visible window currently sits.
    private func viewportBox(width: CGFloat, height: CGFloat, domainSeconds: TimeInterval) -> some View {
        let startFraction = interaction.scrollPosition.timeIntervalSince(model.domainStart) / domainSeconds
        let boxWidth = min(max(2, CGFloat(interaction.visibleSeconds / domainSeconds) * width), width)
        let boxLeft = min(max(CGFloat(startFraction) * width, 0), width - boxWidth)
        return Rectangle()
            .fill(Color.primary.opacity(0.08))
            .overlay(Rectangle().stroke(Color.primary.opacity(0.35), lineWidth: 1))
            .frame(width: boxWidth, height: height)
            .offset(x: boxLeft)
    }

    /// Maps a tap x to a time and recenters the main chart on it (clamped to
    /// the data window). Following re-arms automatically via the main chart's
    /// scroll observer if the user lands back at the latest data.
    private func navigate(toLocalX x: CGFloat, width: CGFloat, domainSeconds: TimeInterval) {
        let fraction = min(max(x / width, 0), 1)
        let date = model.domainStart.addingTimeInterval(domainSeconds * TimeInterval(fraction))
        let length = interaction.visibleSeconds
        var target = date.addingTimeInterval(-length / 2)
        let minStart = model.domainStart
        let maxStart = model.domainEnd.addingTimeInterval(-length)
        if maxStart > minStart {
            target = min(max(target, minStart), maxStart)
        }
        // Same rule as the main chart's scrollToNow: only nearby targets (still
        // inside the render window) animate cleanly; long jumps snap.
        if abs(target.timeIntervalSince(interaction.scrollPosition)) <= interaction.visibleSeconds {
            withAnimation(.easeInOut(duration: 0.3)) {
                interaction.scrollPosition = target
            }
        } else {
            interaction.scrollPosition = target
        }
    }
}

// MARK: - Canvas (laid out once per data / zoom change; translated while panning)

/// The chart content, laid out over the render window at fixed width. Stored
/// properties deliberately exclude the pan position, and the explicit
/// Equatable conformance below compares only cheap metadata (`generation`
/// stands in for the data arrays) — so SwiftUI provably skips this body
/// during panning and momentum.
private struct BGChartCanvas: View, Equatable {
    let model: BGChartModel // plain reference on purpose: updates arrive via `generation`
    let generation: Int
    let isSmall: Bool
    let windowStart: Date
    let windowEnd: Date
    let canvasWidth: CGFloat
    let height: CGFloat
    let visibleSeconds: TimeInterval
    let timeZone: TimeZone

    static func == (lhs: BGChartCanvas, rhs: BGChartCanvas) -> Bool {
        lhs.generation == rhs.generation &&
            lhs.isSmall == rhs.isSmall &&
            lhs.windowStart == rhs.windowStart &&
            lhs.windowEnd == rhs.windowEnd &&
            lhs.canvasWidth == rhs.canvasWidth &&
            lhs.height == rhs.height &&
            lhs.visibleSeconds == rhs.visibleSeconds &&
            lhs.timeZone == rhs.timeZone
    }

    private var basalScale: Double {
        guard model.maxBasal > 0 else { return 0 }
        return model.maxBG / model.maxBasal
    }

    var body: some View {
        let chart = Chart {
            bgBandMarks
            basalMarks
            scheduledBasalMarks
            coneMarks
            yesterdayMarks
            bgLineMarks
            bgPointsMark
            predictionLineMark
            if !isSmall {
                predictionVariantMarks
            }
            treatmentMarks
            if !isSmall {
                ruleMarks
            }
        }
        .chartXScale(domain: windowStart ... windowEnd)
        .chartYScale(domain: 0 ... chartYDomainUpperBound(model.maxBG))
        .chartLegend(.hidden)
        .chartYAxis(.hidden)

        return Group {
            if isSmall {
                chart.chartXAxis(.hidden)
            } else {
                chart.chartXAxis {
                    AxisMarks(values: xAxisMarkDates()) { value in
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                xAxisLabel(for: date)
                            }
                        }
                    }
                }
            }
        }
        .frame(width: canvasWidth, height: height)
    }

    // MARK: Windowing

    // The mark series sliced to the render window: marks outside it clip
    // invisibly but still cost layout, so an unfiltered re-layout does several
    // times the work for nothing.

    private func windowed<T>(_ items: [T], date: (T) -> Date) -> [T] {
        items.filter { item in
            let d = date(item)
            return d >= windowStart && d <= windowEnd
        }
    }

    /// For line/area series: like `windowed`, but keeps one point beyond each
    /// edge so segments crossing (or spanning) the window survive. Assumes
    /// ascending dates.
    private func windowedLine<T>(_ items: [T], date: (T) -> Date) -> [T] {
        guard items.count > 1 else { return items }
        let firstInside = items.firstIndex { date($0) >= windowStart } ?? items.count
        let firstBeyond = items.firstIndex { date($0) > windowEnd } ?? items.count - 1
        let lo = max(firstInside - 1, 0)
        let hi = min(firstBeyond, items.count - 1)
        guard lo <= hi else { return [] }
        return Array(items[lo ... hi])
    }

    // MARK: X axis

    /// Grid/label stride ladder for the current zoom level.
    private var xAxisStrideSeconds: TimeInterval {
        let visibleHours = visibleSeconds / 3600
        if visibleHours <= 2 { return 1800 }
        if visibleHours <= 6 { return 3600 }
        if visibleHours <= 12 { return 2 * 3600 }
        return 4 * 3600
    }

    /// Axis mark dates anchored to local midnight (in the configured graph
    /// time zone), unlike `.stride(by: .hour)`, which anchors to the domain start.
    private func xAxisMarkDates() -> [Date] {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let stride = xAxisStrideSeconds
        var mark = cal.startOfDay(for: windowStart)
        var marks: [Date] = []
        while mark <= windowEnd {
            if mark >= windowStart {
                marks.append(mark)
            }
            mark = mark.addingTimeInterval(stride)
        }
        return marks
    }

    /// Midnight ticks carry the day ("Tue 7") so panned-back history stays
    /// unambiguous; other ticks show the hour (plus minutes at sub-hour strides).
    private func xAxisLabel(for date: Date) -> some View {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let comps = cal.dateComponents([.hour, .minute], from: date)
        return Group {
            if comps.hour == 0, comps.minute == 0 {
                Text(date, format: .dateTime.weekday(.abbreviated).day())
            } else if xAxisStrideSeconds < 3600 {
                Text(date, format: .dateTime.hour().minute())
            } else {
                Text(date, format: .dateTime.hour())
            }
        }
        .font(.footnote)
        .environment(\.timeZone, timeZone)
    }

    // MARK: Marks

    @ChartContentBuilder
    private var bgBandMarks: some ChartContent {
        ForEach(model.overrides.filter { $0.end >= windowStart && $0.start <= windowEnd }) { band in
            RectangleMark(
                xStart: .value("start", band.start),
                xEnd: .value("end", band.end),
                yStart: .value("yBottom", band.yBottom),
                yEnd: .value("yTop", band.yTop)
            )
            .foregroundStyle(model.overrideColor.opacity(0.6))
        }

        ForEach(model.tempTargets.filter { $0.end >= windowStart && $0.start <= windowEnd }) { band in
            RectangleMark(
                xStart: .value("start", band.start),
                xEnd: .value("end", band.end),
                yStart: .value("yBottom", band.yBottom),
                yEnd: .value("yTop", band.yTop)
            )
            .foregroundStyle(model.tempTargetColor.opacity(0.5))
        }
    }

    @ChartContentBuilder
    private var basalMarks: some ChartContent {
        ForEach(model.basal.filter { $0.end >= windowStart && $0.start <= windowEnd }) { step in
            RectangleMark(
                xStart: .value("start", step.start),
                xEnd: .value("end", step.end),
                yStart: .value("yBottom", 0.0),
                yEnd: .value("rate", step.rate * basalScale)
            )
            .foregroundStyle(.blue.opacity(0.35))
        }
    }

    @ChartContentBuilder
    private var scheduledBasalMarks: some ChartContent {
        ForEach(windowedLine(model.basalScheduled) { $0.date }) { pt in
            LineMark(
                x: .value("time", pt.date),
                y: .value("rate", pt.rate * basalScale),
                series: .value("series", "basalScheduled")
            )
            .lineStyle(StrokeStyle(lineWidth: 2, dash: [10, 5]))
            .foregroundStyle(Color.blue.opacity(0.8))
        }
    }

    @ChartContentBuilder
    private var coneMarks: some ChartContent {
        ForEach(windowedLine(model.cone) { $0.date }) { pt in
            AreaMark(
                x: .value("time", pt.date),
                yStart: .value("yMin", pt.yMin),
                yEnd: .value("yMax", pt.yMax)
            )
            // Same fill as Trio's cone.
            .foregroundStyle(Color(.systemBlue).opacity(0.4))
            .interpolationMethod(.monotone)
        }
    }

    @ChartContentBuilder
    private var yesterdayMarks: some ChartContent {
        ForEach(windowedLine(model.yesterday) { $0.date }) { pt in
            LineMark(
                x: .value("time", pt.date),
                y: .value("bg", pt.value),
                series: .value("series", "yesterday")
            )
            .foregroundStyle(Color(.systemGray).opacity(0.4))
            .lineStyle(StrokeStyle(lineWidth: 1.5))
            .interpolationMethod(.linear)
        }
    }

    @ChartContentBuilder
    private var bgLineMarks: some ChartContent {
        if model.showLines {
            ForEach(model.bgRuns) { run in
                if let first = run.points.first, let last = run.points.last,
                   last.date >= windowStart, first.date <= windowEnd
                {
                    ForEach(windowedLine(run.points) { $0.date }) { pt in
                        LineMark(
                            x: .value("time", pt.date),
                            y: .value("bg", pt.value),
                            series: .value("series", "bg-\(run.id)")
                        )
                        .foregroundStyle(run.color)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                        .interpolationMethod(.linear)
                    }
                }
            }
        }
    }

    @ChartContentBuilder
    private var bgPointsMark: some ChartContent {
        if model.showDots {
            ForEach(windowed(model.bg) { $0.date }) { pt in
                PointMark(
                    x: .value("time", pt.date),
                    y: .value("bg", pt.value)
                )
                .symbolSize(isSmall ? 14 : 30)
                .foregroundStyle(pt.color)
            }
        }
    }

    @ChartContentBuilder
    private var predictionLineMark: some ChartContent {
        ForEach(windowedLine(model.prediction) { $0.date }) { pt in
            LineMark(
                x: .value("time", pt.date),
                y: .value("bg", pt.value),
                series: .value("series", "prediction")
            )
            .foregroundStyle(.purple)
            .lineStyle(StrokeStyle(lineWidth: 2))
        }
    }

    @ChartContentBuilder
    private var predictionVariantMarks: some ChartContent {
        ForEach(windowedLine(model.ztPrediction) { $0.date }) { pt in
            LineMark(
                x: .value("time", pt.date),
                y: .value("bg", pt.value),
                series: .value("series", "zt")
            )
            .foregroundStyle(Color(.systemGray))
            .lineStyle(StrokeStyle(lineWidth: 2))
        }

        ForEach(windowedLine(model.iobPrediction) { $0.date }) { pt in
            LineMark(
                x: .value("time", pt.date),
                y: .value("bg", pt.value),
                series: .value("series", "iob")
            )
            .foregroundStyle(Color(.systemBlue))
            .lineStyle(StrokeStyle(lineWidth: 2))
        }

        ForEach(windowedLine(model.cobPrediction) { $0.date }) { pt in
            LineMark(
                x: .value("time", pt.date),
                y: .value("bg", pt.value),
                series: .value("series", "cob")
            )
            .foregroundStyle(Color(.systemOrange))
            .lineStyle(StrokeStyle(lineWidth: 2))
        }

        ForEach(windowedLine(model.uamPrediction) { $0.date }) { pt in
            LineMark(
                x: .value("time", pt.date),
                y: .value("bg", pt.value),
                series: .value("series", "uam")
            )
            .foregroundStyle(Color(.systemPink))
            .lineStyle(StrokeStyle(lineWidth: 2))
        }
    }

    @ChartContentBuilder
    private var treatmentMarks: some ChartContent {
        ForEach(windowed(model.boluses) { $0.drawnDate }) { pt in
            PointMark(
                x: .value("time", pt.drawnDate),
                y: .value("sgv", pt.sgv)
            )
            .symbolSize(isSmall ? 24 : 64)
            .foregroundStyle(Color.blue.opacity(0.75))
            .annotation(position: .top, alignment: .center) {
                if !isSmall, Storage.shared.showValues.value {
                    Text(pt.label).font(.caption2).foregroundColor(.primary)
                }
            }
        }

        ForEach(windowed(model.carbs) { $0.drawnDate }) { pt in
            PointMark(
                x: .value("time", pt.drawnDate),
                y: .value("sgv", pt.sgv)
            )
            .symbolSize(isSmall ? 24 : 64)
            .foregroundStyle(Color.orange.opacity(0.75))
            .annotation(position: .top, alignment: .center) {
                if !isSmall, Storage.shared.showValues.value {
                    Text(pt.label).font(.caption2).foregroundColor(.primary)
                }
            }
        }

        ForEach(windowed(model.smbs) { $0.drawnDate }) { pt in
            PointMark(
                x: .value("time", pt.drawnDate),
                y: .value("sgv", pt.sgv)
            )
            .symbol(DownwardTriangle())
            .symbolSize(isSmall ? 28 : 64)
            .foregroundStyle(Color.blue.opacity(0.75))
            .annotation(position: .top, alignment: .center) {
                if !isSmall, Storage.shared.showValues.value {
                    Text(pt.label).font(.caption2).foregroundColor(.primary)
                }
            }
        }

        ForEach(windowed(model.bgChecks) { $0.drawnDate }) { pt in
            PointMark(
                x: .value("time", pt.drawnDate),
                y: .value("sgv", pt.sgv)
            )
            .symbolSize(isSmall ? 22 : 54)
            .foregroundStyle(Color.red.opacity(0.75))
        }

        ForEach(windowed(model.suspends) { $0.drawnDate }) { pt in
            PointMark(
                x: .value("time", pt.drawnDate),
                y: .value("sgv", pt.sgv)
            )
            .symbol(.square)
            .symbolSize(isSmall ? 22 : 54)
            .foregroundStyle(Color.teal.opacity(0.75))
        }

        ForEach(windowed(model.resumes) { $0.drawnDate }) { pt in
            PointMark(
                x: .value("time", pt.drawnDate),
                y: .value("sgv", pt.sgv)
            )
            .symbol(.square)
            .symbolSize(isSmall ? 22 : 54)
            .foregroundStyle(Color.teal.opacity(0.5))
        }

        ForEach(windowed(model.sensorStarts) { $0.drawnDate }) { pt in
            PointMark(
                x: .value("time", pt.drawnDate),
                y: .value("sgv", pt.sgv)
            )
            .symbol(.cross)
            .symbolSize(isSmall ? 22 : 54)
            .foregroundStyle(Color.indigo.opacity(0.75))
        }

        ForEach(windowed(model.notes) { $0.drawnDate }) { pt in
            PointMark(
                x: .value("time", pt.drawnDate),
                y: .value("sgv", pt.sgv)
            )
            .symbolSize(isSmall ? 22 : 54)
            .foregroundStyle(Color.gray.opacity(0.75))
        }
    }

    @ChartContentBuilder
    private var ruleMarks: some ChartContent {
        RuleMark(y: .value("low", model.lowLine))
            .lineStyle(StrokeStyle(lineWidth: 2))
            .foregroundStyle(Color.red.opacity(0.5))

        RuleMark(y: .value("high", model.highLine))
            .lineStyle(StrokeStyle(lineWidth: 2))
            .foregroundStyle(Color.yellow.opacity(0.5))

        if model.now >= windowStart, model.now <= windowEnd {
            RuleMark(x: .value("now", model.now))
                .lineStyle(StrokeStyle(lineWidth: 1))
                .foregroundStyle(Color.gray.opacity(0.6))
        }

        if model.show30Min, let d = model.thirtyMinMark, d >= windowStart, d <= windowEnd {
            RuleMark(x: .value("30m", d))
                .lineStyle(StrokeStyle(lineWidth: 0.5))
                .foregroundStyle(Color.blue.opacity(0.7))
        }
        if model.show90Min, let d = model.ninetyMinMark, d >= windowStart, d <= windowEnd {
            RuleMark(x: .value("90m", d))
                .lineStyle(StrokeStyle(lineWidth: 0.5))
                .foregroundStyle(Color.orange.opacity(0.7))
        }
        if model.showDIA {
            ForEach(model.diaMarkers.filter { $0 >= windowStart && $0 <= windowEnd }, id: \.self) { d in
                RuleMark(x: .value("dia", d))
                    .lineStyle(StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
                    .foregroundStyle(Color.gray.opacity(0.5))
            }
        }
        if model.showMidnight {
            ForEach(model.midnightMarkers.filter { $0 >= windowStart && $0 <= windowEnd }, id: \.self) { d in
                RuleMark(x: .value("midnight", d))
                    .lineStyle(StrokeStyle(lineWidth: 0.5, dash: [5, 3]))
                    .foregroundStyle(Color.teal.opacity(0.6))
            }
        }
    }
}

// MARK: - Pinned y-axis overlay

/// Renders only the y-axes — BG values trailing, basal rates leading — at a
/// fixed position over the scrolling canvas, plus a phantom x-axis label that
/// reserves exactly the height of the canvas's hour labels so both plots end
/// at the same y. Also reports its plot frame so the shell's selection
/// overlay shares the same value-to-pixel mapping.
private struct StaticYAxisOverlay: View, Equatable {
    let generation: Int
    let maxBG: Double
    let maxBasal: Double

    private var basalScale: Double {
        guard maxBasal > 0 else { return 0 }
        return maxBG / maxBasal
    }

    private var leadingBasalTicks: [Double] {
        guard basalScale > 0 else { return [] }
        let ticks = stride(from: 0.0, through: maxBasal, by: max(0.5, maxBasal / 4))
            .map { $0 * basalScale }
        return Array(ticks)
    }

    var body: some View {
        Chart {
            // Invisible content at the domain corners so the scales resolve
            // and the plot (and with it the axes) materializes.
            PointMark(x: .value("edge", 0.0), y: .value("min", 0.0))
                .opacity(0)
            PointMark(x: .value("edge", 1.0), y: .value("max", maxBG))
                .opacity(0)
        }
        .chartXScale(domain: 0 ... 1)
        .chartYScale(domain: 0 ... chartYDomainUpperBound(maxBG))
        .chartLegend(.hidden)
        .chartXAxis {
            AxisMarks(values: [0.5]) { _ in
                AxisValueLabel {
                    Text("00").font(.footnote).foregroundStyle(.clear)
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing) { value in
                AxisTick()
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(Localizer.toDisplayUnits(String(v)))
                    }
                }
            }
            AxisMarks(position: .leading, values: leadingBasalTicks) { value in
                AxisTick()
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        let rate = basalScale > 0 ? v / basalScale : 0
                        Text(String(format: "%.1fU", rate))
                    }
                }
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geo in
                Color.clear.preference(
                    key: PlotFramePreferenceKey.self,
                    value: proxy.plotFrame.map { geo[$0] } ?? .zero
                )
            }
        }
    }
}

private struct PlotFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

/// Rendered size of the visible selection pill, reported so the shell can
/// clamp its position using the real (wrapped) dimensions.
private struct PillSizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

// MARK: - Shared pieces

private struct DownwardTriangle: ChartSymbolShape {
    var perceptualUnitRect: CGRect { CGRect(x: 0, y: 0, width: 1, height: 1) }

    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

private struct PillLabel: View {
    /// One entry per selected item. A lone entry keeps its multi-line layout;
    /// several stack as compact one-line-per-item rows so the pill stays
    /// readable over a busy cluster.
    let texts: [String]
    let maxWidth: CGFloat

    var body: some View {
        content
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.primary, lineWidth: 0.5)
                    )
            )
            .background(
                GeometryReader { geo in
                    Color.clear.preference(key: PillSizePreferenceKey.self, value: geo.size)
                }
            )
            // Transparent flexible container: it caps the width the text can
            // wrap to, while the visible pill above still hugs its content.
            .frame(maxWidth: maxWidth)
    }

    @ViewBuilder
    private var content: some View {
        if texts.count == 1 {
            // Bound pathological texts; a note this long is better read in
            // Nightscout than on a chart pill.
            entry(texts[0], lineLimit: 10)
        } else {
            VStack(spacing: 3) {
                ForEach(texts.indices, id: \.self) { index in
                    if index > 0 {
                        // Fixed-width hairline: a Divider would greedily
                        // stretch the hugging pill to its max width.
                        Rectangle()
                            .fill(Color.primary.opacity(0.25))
                            .frame(width: 46, height: 0.5)
                    }
                    // Stacked items collapse to "Bolus 2.5U 14:32" rows.
                    entry(texts[index].replacingOccurrences(of: "\n", with: " "), lineLimit: 4)
                }
            }
        }
    }

    private func entry(_ text: String, lineLimit: Int) -> some View {
        Text(text)
            .font(.caption2)
            .foregroundColor(.primary)
            .multilineTextAlignment(.center)
            .lineLimit(lineLimit)
    }
}
