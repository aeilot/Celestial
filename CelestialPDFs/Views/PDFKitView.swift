//
//  PDFKitView.swift
//  CelestialPDFs
//
//  Created by CelestialPDFs on 3/4/26.
//

import SwiftUI
import PDFKit

struct PDFKitView: NSViewRepresentable {
    let document: PDFDocument?
    @Binding var selectedText: String
    @Binding var currentPageIndex: Int
    @Binding var selectionOverlayBounds: CGRect?
    @Binding var selectionPageBounds: CGRect?
    @Binding var selectionPageIndex: Int?
    @Binding var selectionAnchor: ReaderSelectionAnchor?
    @Binding var jumpToPageIndex: Int?
    var highlights: [BookHighlight]
    var displayMode: PDFDisplayMode = .autoScale
    var onHighlightAnnotationTapped: ((UUID, CGRect) -> Void)? = nil
    var onBackgroundTapped: (() -> Void)? = nil

    enum PDFDisplayMode {
        case fitWidth, fitPage, autoScale
    }

    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.document = document
        pdfView.delegate = context.coordinator

        // Enable zoom
        pdfView.minScaleFactor = 0.25
        pdfView.maxScaleFactor = 5.0

        // Apply display mode
        applyDisplayMode(displayMode, to: pdfView)

        // Apply existing highlights
        applyHighlights(to: pdfView)

        // Observe selection changes
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.selectionChanged(_:)),
            name: .PDFViewSelectionChanged,
            object: pdfView
        )

        // Observe page changes
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.pageChanged(_:)),
            name: .PDFViewPageChanged,
            object: pdfView
        )
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.geometryChanged(_:)),
            name: .PDFViewScaleChanged,
            object: pdfView
        )

        let tapGesture = NSClickGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePDFClick(_:)))
        tapGesture.buttonMask = 0x1
        pdfView.addGestureRecognizer(tapGesture)

        context.coordinator.pdfView = pdfView
        context.coordinator.observeScrollBounds(of: pdfView)
        return pdfView
    }

    func updateNSView(_ pdfView: PDFView, context: Context) {
        if pdfView.document !== document {
            pdfView.document = document
        }
        applyDisplayMode(displayMode, to: pdfView)
        applyHighlights(to: pdfView)
        if let targetIndex = jumpToPageIndex,
           let document = pdfView.document,
           targetIndex >= 0,
           targetIndex < document.pageCount,
           let page = document.page(at: targetIndex) {
            pdfView.go(to: page)
            jumpToPageIndex = nil
        }
        if selectedText.isEmpty, pdfView.currentSelection != nil {
            pdfView.clearSelection()
            context.coordinator.clearSelectionBindings()
        }
        context.coordinator.observeScrollBounds(of: pdfView)
    }

    private func applyDisplayMode(_ mode: PDFDisplayMode, to pdfView: PDFView) {
        switch mode {
        case .fitWidth:
            pdfView.autoScales = false
            if let page = pdfView.currentPage {
                let pageWidth = page.bounds(for: .mediaBox).width
                let viewWidth = pdfView.bounds.width
                pdfView.scaleFactor = viewWidth / pageWidth
            }
        case .fitPage:
            pdfView.autoScales = false
            if let page = pdfView.currentPage {
                let pageHeight = page.bounds(for: .mediaBox).height
                let viewHeight = pdfView.bounds.height
                pdfView.scaleFactor = viewHeight / pageHeight
            }
        case .autoScale:
            pdfView.autoScales = true
        }
    }

    private func applyHighlights(to pdfView: PDFView) {
        guard let document = pdfView.document else { return }

        // Remove existing highlight annotations
        for i in 0..<document.pageCount {
            guard let page = document.page(at: i) else { continue }
            let annotations = page.annotations.filter {
                $0.type == "Highlight" && ($0.userName?.hasPrefix("CelestialPDFs") ?? false)
            }
            annotations.forEach { page.removeAnnotation($0) }
        }

        // Add saved highlights
        for highlight in highlights {
            guard highlight.pageIndex < document.pageCount,
                  let page = document.page(at: highlight.pageIndex) else { continue }

            let annotation = PDFAnnotation(
                bounds: highlight.bounds,
                forType: .highlight,
                withProperties: nil
            )
            annotation.color = NSColor.fromHighlightHex(highlight.colorHex).withAlphaComponent(0.4)
            annotation.userName = "CelestialPDFs:\(highlight.id.uuidString)"
            annotation.contents = highlight.id.uuidString
            page.addAnnotation(annotation)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Zoom Control

    static func zoomIn(pdfView: PDFView) {
        if pdfView.canZoomIn {
            pdfView.zoomIn(nil)
        }
    }

    static func zoomOut(pdfView: PDFView) {
        if pdfView.canZoomOut {
            pdfView.zoomOut(nil)
        }
    }

    static func zoomToFit(pdfView: PDFView) {
        pdfView.autoScales = true
    }

    class Coordinator: NSObject, PDFViewDelegate {
        var parent: PDFKitView
        weak var pdfView: PDFView?
        weak var observedClipView: NSClipView?

        init(_ parent: PDFKitView) {
            self.parent = parent
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        func observeScrollBounds(of pdfView: PDFView) {
            DispatchQueue.main.async { [weak self, weak pdfView] in
                guard let self, let pdfView else { return }
                guard let clipView = pdfView.enclosingScrollView?.contentView else { return }
                if self.observedClipView === clipView { return }

                if let observedClipView = self.observedClipView {
                    NotificationCenter.default.removeObserver(
                        self,
                        name: NSView.boundsDidChangeNotification,
                        object: observedClipView
                    )
                }
                self.observedClipView = clipView
                clipView.postsBoundsChangedNotifications = true
                NotificationCenter.default.addObserver(
                    self,
                    selector: #selector(Coordinator.scrollBoundsChanged(_:)),
                    name: NSView.boundsDidChangeNotification,
                    object: clipView
                )
            }
        }

        @objc func selectionChanged(_ notification: Notification) {
            guard let pdfView = notification.object as? PDFView,
                  let selection = pdfView.currentSelection,
                  let rawText = selection.string else {
                parent.selectedText = ""
                parent.selectionOverlayBounds = nil
                parent.selectionPageBounds = nil
                parent.selectionPageIndex = nil
                parent.selectionAnchor = nil
                return
            }

            let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty,
                  let page = selection.pages.first,
                  let document = pdfView.document else {
                parent.selectedText = ""
                parent.selectionOverlayBounds = nil
                parent.selectionPageBounds = nil
                parent.selectionPageIndex = nil
                parent.selectionAnchor = nil
                return
            }

            let pageIndex = document.index(for: page)
            let pageBounds = selection.bounds(for: page)
            let firstLineBounds = firstLineBounds(for: selection, on: page) ?? pageBounds
            let anchor = ReaderSelectionAnchor(pageIndex: pageIndex, firstLinePageBounds: firstLineBounds)

            parent.selectedText = text
            parent.selectionPageBounds = pageBounds
            parent.selectionPageIndex = pageIndex
            parent.selectionAnchor = anchor
            parent.selectionOverlayBounds = projectAnchor(anchor, in: pdfView)
        }

        @objc func pageChanged(_ notification: Notification) {
            guard let pdfView = notification.object as? PDFView,
                  let currentPage = pdfView.currentPage,
                  let document = pdfView.document else { return }
            let index = document.index(for: currentPage)
            parent.currentPageIndex = index
            refreshProjectedAnchor(in: pdfView)
        }

        @objc func geometryChanged(_ notification: Notification) {
            guard let pdfView = notification.object as? PDFView else { return }
            refreshProjectedAnchor(in: pdfView)
        }

        @objc func scrollBoundsChanged(_ notification: Notification) {
            guard let pdfView else { return }
            refreshProjectedAnchor(in: pdfView)
        }

        @objc func handlePDFClick(_ gesture: NSClickGestureRecognizer) {
            guard let pdfView = gesture.view as? PDFView else { return }
            let pointInView = gesture.location(in: pdfView)
            guard let page = pdfView.page(for: pointInView, nearest: true) else { return }
            let pointInPage = pdfView.convert(pointInView, to: page)

            guard let annotation = page.annotation(at: pointInPage),
                  annotation.type == "Highlight",
                  let userName = annotation.userName,
                  userName.hasPrefix("CelestialPDFs") else {
                pdfView.clearSelection()
                clearSelectionBindings()
                parent.onBackgroundTapped?()
                return
            }

            let idText = annotation.contents ?? userName.replacingOccurrences(of: "CelestialPDFs:", with: "")
            guard let highlightID = UUID(uuidString: idText) else { return }
            let overlayRect = pdfView.convert(annotation.bounds, from: page)
            parent.onHighlightAnnotationTapped?(highlightID, overlayRect)
        }

        func clearSelectionBindings() {
            parent.selectedText = ""
            parent.selectionOverlayBounds = nil
            parent.selectionPageBounds = nil
            parent.selectionPageIndex = nil
            parent.selectionAnchor = nil
        }

        private func refreshProjectedAnchor(in pdfView: PDFView) {
            guard let anchor = parent.selectionAnchor else { return }
            parent.selectionOverlayBounds = projectAnchor(anchor, in: pdfView)
        }

        private func projectAnchor(_ anchor: ReaderSelectionAnchor, in pdfView: PDFView) -> CGRect? {
            guard let document = pdfView.document,
                  anchor.pageIndex >= 0,
                  anchor.pageIndex < document.pageCount,
                  let page = document.page(at: anchor.pageIndex) else {
                parent.selectionAnchor = nil
                parent.selectionOverlayBounds = nil
                return nil
            }
            let overlay = pdfView.convert(anchor.firstLinePageBounds, from: page)
            guard overlay.width > 0, overlay.height > 0 else { return nil }
            return overlay
        }

        private func firstLineBounds(for selection: PDFSelection, on page: PDFPage) -> CGRect? {
            let lineSelections = selection.selectionsByLine()
            if let firstLine = lineSelections.first(where: { line in
                line.pages.contains(where: { $0 === page })
            }) {
                let bounds = firstLine.bounds(for: page)
                if bounds.width > 0 && bounds.height > 0 {
                    return bounds
                }
            }
            let fallback = selection.bounds(for: page)
            return (fallback.width > 0 && fallback.height > 0) ? fallback : nil
        }
    }
}
