//
//  ClipboardItem.swift
//  Crenelle
//
//  A single plain-text clipboard capture. Created 2026-10-10 by Ian L.
//

import Foundation

struct ClipboardItem: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    let text: String
    let date: Date

    init(id: UUID = UUID(), text: String, date: Date = .now) {
        self.id = id
        self.text = text
        self.date = date
    }

    /// Single-line preview for the list row. Collapses whitespace so a copied
    /// paragraph does not blow the row height out.
    var preview: String {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .split(whereSeparator: \.isNewline)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespaces)
            ?? text
    }

    private enum CodingKeys: String, CodingKey {
        case id, text, date
    }
}
