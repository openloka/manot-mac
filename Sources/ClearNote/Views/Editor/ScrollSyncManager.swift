import SwiftUI
import AppKit
import OSLog

@MainActor
@Observable
final class ScrollSyncManager {
    weak var editorScrollView: NSScrollView? {
        didSet {
            editorObservation = nil
            if let sv = editorScrollView {
                sv.contentView.postsBoundsChangedNotifications = true
                editorObservation = NotificationCenter.default.addObserver(
                    forName: NSView.boundsDidChangeNotification,
                    object: sv.contentView,
                    queue: .main
                ) { [weak self] _ in
                    Task { @MainActor [weak self] in
                        self?.editorScrolled()
                    }
                }
            }
        }
    }
    
    weak var previewScrollView: NSScrollView? {
        didSet {
            previewObservation = nil
            if let sv = previewScrollView {
                sv.contentView.postsBoundsChangedNotifications = true
                previewObservation = NotificationCenter.default.addObserver(
                    forName: NSView.boundsDidChangeNotification,
                    object: sv.contentView,
                    queue: .main
                ) { [weak self] _ in
                    Task { @MainActor [weak self] in
                        self?.previewScrolled()
                    }
                }
            }
        }
    }
    
    private var editorObservation: NSObjectProtocol?
    private var previewObservation: NSObjectProtocol?
    private var isSyncing = false
    
    var isEnabled = false {
        didSet {
            if isEnabled && !oldValue {
                editorScrolled()
            }
        }
    }
    
    private func editorScrolled() {
        guard isEnabled, !isSyncing, let source = editorScrollView, let target = previewScrollView else { return }
        sync(from: source, to: target)
    }
    
    private func previewScrolled() {
        guard isEnabled, !isSyncing, let source = previewScrollView, let target = editorScrollView else { return }
        sync(from: source, to: target)
    }
    
    private func sync(from source: NSScrollView, to target: NSScrollView) {
        isSyncing = true
        defer { 
            DispatchQueue.main.async { [weak self] in 
                self?.isSyncing = false 
            }
        }
        
        // Use visibleRect to correctly calculate the scroll percentage since clipview bounds can change dynamically.
        let sourceDocHeight = source.documentView?.bounds.height ?? 0
        let sourceHeight = source.contentView.bounds.height
        let targetDocHeight = target.documentView?.bounds.height ?? 0
        let targetHeight = target.contentView.bounds.height
        
        let sourceMaxY = max(0, sourceDocHeight - sourceHeight)
        let targetMaxY = max(0, targetDocHeight - targetHeight)
        
        guard sourceMaxY > 0, targetMaxY > 0 else { return }
        
        let sourceY = min(max(0, source.contentView.bounds.minY), sourceMaxY)
        let percentage = sourceY / sourceMaxY
        
        let targetY = percentage * targetMaxY
        
        target.contentView.bounds.origin.y = targetY
        target.documentView?.scroll(NSPoint(x: target.contentView.bounds.minX, y: targetY))
        target.reflectScrolledClipView(target.contentView)
    }
}

struct ScrollViewExtractor: NSViewRepresentable {
    var onFound: (NSScrollView) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false
        context.coordinator.onFound = onFound
        // Delay to ensure the scroll view is resolved in the view hierarchy
        DispatchQueue.main.async {
            if let scrollView = view.enclosingScrollView {
                context.coordinator.onFound?(scrollView)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onFound = onFound
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        var onFound: ((NSScrollView) -> Void)?
    }
}
