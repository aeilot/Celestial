//
//  DictionaryService.swift
//  CelestialPDFs
//
//  Created by CelestialPDFs on 3/4/26.
//

import Foundation
import AppKit

enum DictionaryService {
    /// Look up a word using macOS Dictionary.app
    static func lookUp(_ word: String) {
        let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: "dict://\(encoded)") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Get a definition using DCSCopyTextDefinition (if available)
    static func definition(for word: String) -> String? {
        let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines) as NSString
        let range = CFRangeMake(0, trimmed.length)
        if let definition = DCSCopyTextDefinition(nil, trimmed, range) {
            return definition.takeRetainedValue() as String
        }
        return nil
    }
}
