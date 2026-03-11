import SwiftUI
import AppKit

@MainActor
@Observable
final class ScrollSyncManager {

    // MARK: - Scroll view references

    weak var editorScrollView: NSScrollView? {
        didSet {
            guard editorScrollView !== oldValue else { return }
            editorObservation = nil
            if let sv = editorScrollView {
                sv.contentView.postsBoundsChangedNotifications = true
                editorObservation = NotificationCenter.default.addObserver(
                    forName: NSView.boundsDidChangeNotification,
                    object: sv.contentView,
                    queue: .main
                ) { [weak self] _ in
                    // Hop onto the actor so we can safely mutate state.
                    Task { @MainActor [weak self] in self?.editorDidScroll() }
                }
            }
        }
    }

    weak var previewScrollView: NSScrollView? {
        didSet {
            guard previewScrollView !== oldValue else { return }
            previewObservation = nil
            if let sv = previewScrollView {
                sv.contentView.postsBoundsChangedNotifications = true
                previewObservation = NotificationCenter.default.addObserver(
                    forName: NSView.boundsDidChangeNotification,
                    object: sv.contentView,
                    queue: .main
                ) { [weak self] _ in
                    Task { @MainActor [weak self] in self?.previewDidScroll() }
                }
            }
        }
    }

    // MARK: - State

    private var editorObservation: NSObjectProtocol?
    private var previewObservation: NSObjectProtocol?

    /// Counter-based re-entry guard.
    /// Incremented before applying a programmatic scroll, decremented after one
    /// runloop turn — this absorbs the bounce notification AppKit sends back.
    private var syncDepth = 0

    var isEnabled = false {
        didSet {
            if isEnabled && !oldValue {
                // Align preview to editor immediately when split view opens.
                editorDidScroll()
            }
        }
    }

    // MARK: - Scroll handlers

    private func editorDidScroll() {
        guard isEnabled, syncDepth == 0 else { return }
        guard let source = editorScrollView, let target = previewScrollView else { return }
        syncDepth += 1
        apply(percentage: scrollPercentage(of: source), to: target)
        scheduleRelease()
    }

    private func previewDidScroll() {
        guard isEnabled, syncDepth == 0 else { return }
        guard let source = previewScrollView, let target = editorScrollView else { return }
        syncDepth += 1
        apply(percentage: scrollPercentage(of: source), to: target)
        scheduleRelease()
    }

    /// Releases the re-entry guard one runloop turn later, absorbing any
    /// bounce notifications produced by the programmatic scroll.
    private func scheduleRelease() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.syncDepth = max(0, self.syncDepth - 1)
        }
    }

    // MARK: - Core math

    /// Returns the scroll position as a fraction [0, 1].
    private func scrollPercentage(of sv: NSScrollView) -> CGFloat {
        let docH  = sv.documentView?.bounds.height ?? 0
        let viewH = sv.contentView.bounds.height
        let maxY  = max(0, docH - viewH)
        guard maxY > 0 else { return 0 }
        let y = sv.contentView.bounds.minY.clamped(to: 0 ... maxY)
        return y / maxY
    }

    /// Moves `target` to the given fraction without triggering a feedback loop.
    private func apply(percentage: CGFloat, to target: NSScrollView) {
        let docH  = target.documentView?.bounds.height ?? 0
        let viewH = target.contentView.bounds.height
        let maxY  = max(0, docH - viewH)
        guard maxY > 0 else { return }

        let y = (percentage * maxY).clamped(to: 0 ... maxY)
        target.documentView?.scroll(NSPoint(x: 0, y: y))
        target.reflectScrolledClipView(target.contentView)
    }
}

// MARK: - Clamping helper

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - ScrollViewExtractor

/// Place inside a SwiftUI ScrollView's content to obtain the underlying NSScrollView.
/// Uses `enclosingScrollView` which is reliable when the probe is truly inside the clip view.
struct ScrollViewExtractor: NSViewRepresentable {
    var onFound: (NSScrollView) -> Void

    func makeNSView(context: Context) -> ProbeView {
        let probe = ProbeView()
        probe.onFound = onFound
        return probe
    }

    func updateNSView(_ nsView: ProbeView, context: Context) {
        nsView.onFound = onFound
    }

    func makeCoordinator() -> Void { () }

    // MARK: - Probe view

    final class ProbeView: NSView {
        var onFound: ((NSScrollView) -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            findScrollView()
        }

        private func findScrollView() {
            // `enclosingScrollView` walks up the AppKit hierarchy and returns the
            // nearest ancestor NSScrollView — exactly what we want when this view
            // is placed inside a SwiftUI ScrollView's content.
            if let sv = enclosingScrollView {
                onFound?(sv)
            } else {
                // Not yet in the hierarchy; retry after the current layout pass.
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    if let sv = self.enclosingScrollView {
                        self.onFound?(sv)
                    }
                }
            }
        }
    }
}
