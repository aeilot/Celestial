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
    @Binding var selectionBounds: CGRect?
    @Binding var selectionPageIndex: Int?
    var highlights: [BookHighlight]
    var displayMode: PDFDisplayMode = .autoScale

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

        context.coordinator.pdfView = pdfView
        return pdfView
    }

    func updateNSView(_ pdfView: PDFView, context: Context) {
        if pdfView.document !== document {
            pdfView.document = document
        }
        applyDisplayMode(displayMode, to: pdfView)
        applyHighlights(to: pdfView)
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
                $0.type == "Highlight" && $0.userName == "CelestialPDFs"
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
            annotation.color = NSColor.yellow.withAlphaComponent(0.4)
            annotation.userName = "CelestialPDFs"
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

        init(_ parent: PDFKitView) {
            self.parent = parent
        }

        @objc func selectionChanged(_ notification: Notification) {
            guard let pdfView = notification.object as? PDFView,
                  let selection = pdfView.currentSelection,
                  let text = selection.string, !text.isEmpty else {
                parent.selectedText = ""
                parent.selectionBounds = nil
                parent.selectionPageIndex = nil
                return
            }
            parent.selectedText = text

            // Get selection bounds for floating toolbar
            if let page = selection.pages.first {
                let pageBounds = selection.bounds(for: page)
                // Convert page coordinates to PDFView coordinates
                let viewRect = pdfView.convert(pageBounds, from: page)

                // Convert from PDFView's document coordinate space
                // to the visible viewport (SwiftUI overlay space)
                let visibleRect = pdfView.documentView?.visibleRect ?? pdfView.bounds
                let viewHeight = pdfView.bounds.height

                // Adjust for scroll position and flip Y axis (AppKit → SwiftUI)
                let relativeX = viewRect.origin.x - visibleRect.origin.x
                let relativeY = viewRect.origin.y - visibleRect.origin.y
                let flippedY = viewHeight - relativeY - viewRect.height

                parent.selectionBounds = CGRect(
                    x: relativeX,
                    y: flippedY,
                    width: viewRect.width,
                    height: viewRect.height
                )

                if let doc = pdfView.document {
                    parent.selectionPageIndex = doc.index(for: page)
                }
            }
        }

        @objc func pageChanged(_ notification: Notification) {
            guard let pdfView = notification.object as? PDFView,
                  let currentPage = pdfView.currentPage,
                  let document = pdfView.document else { return }
            let index = document.index(for: currentPage)
            parent.currentPageIndex = index
        }
    }
}
