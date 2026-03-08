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
    @Binding var selectionPageBounds: CGRect?
    @Binding var selectionPageIndex: Int?
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

        pdfView.minScaleFactor = 0.25
        pdfView.maxScaleFactor = 5.0

        applyDisplayMode(displayMode, to: pdfView)
        applyHighlights(to: pdfView)

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.selectionChanged(_:)),
            name: .PDFViewSelectionChanged,
            object: pdfView
        )

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.pageChanged(_:)),
            name: .PDFViewPageChanged,
            object: pdfView
        )

        let tapGesture = NSClickGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePDFClick(_:)))
        tapGesture.buttonMask = 0x1
        pdfView.addGestureRecognizer(tapGesture)

        context.coordinator.pdfView = pdfView
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

        for i in 0..<document.pageCount {
            guard let page = document.page(at: i) else { continue }
            let annotations = page.annotations.filter {
                $0.type == "Highlight" && ($0.userName?.hasPrefix("CelestialPDFs") ?? false)
            }
            annotations.forEach { page.removeAnnotation($0) }
        }

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

    class Coordinator: NSObject, PDFViewDelegate {
        var parent: PDFKitView
        weak var pdfView: PDFView?

        init(_ parent: PDFKitView) {
            self.parent = parent
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        @objc func selectionChanged(_ notification: Notification) {
            guard let pdfView = notification.object as? PDFView,
                  let selection = pdfView.currentSelection,
                  let rawText = selection.string else {
                clearSelectionBindings()
                return
            }

            let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty,
                  let page = selection.pages.first,
                  let document = pdfView.document else {
                clearSelectionBindings()
                return
            }

            let pageIndex = document.index(for: page)
            let pageBounds = selection.bounds(for: page)
            parent.selectedText = text
            parent.selectionPageBounds = pageBounds
            parent.selectionPageIndex = pageIndex
        }

        @objc func pageChanged(_ notification: Notification) {
            guard let pdfView = notification.object as? PDFView,
                  let currentPage = pdfView.currentPage,
                  let document = pdfView.document else { return }
            parent.currentPageIndex = document.index(for: currentPage)
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
            parent.selectionPageBounds = nil
            parent.selectionPageIndex = nil
        }
    }
}
