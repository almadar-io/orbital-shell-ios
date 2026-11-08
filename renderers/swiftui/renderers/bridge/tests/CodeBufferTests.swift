import Foundation
import XCTest
@testable import __APP_MODULE__

final class CodeBufferTests: XCTestCase {
    private func props(_ json: String) -> AnyCodable {
        try! JSONDecoder().decode(AnyCodable.self, from: Data(json.utf8))
    }

    private func model(_ json: String) -> CodeBufferModel { CodeBufferModel(props(json)) }

    func testBufferModeIsOffWithoutACursorObject() {
        XCTAssertFalse(CodeBufferModel.isActive(props(#"{"code":"ab","editable":true}"#)))
        XCTAssertFalse(CodeBufferModel.isActive(props(#"{"code":"ab","cursor":null}"#)))
        XCTAssertTrue(CodeBufferModel.isActive(props(#"{"code":"ab","cursor":{"row":0,"col":0}}"#)))
    }

    func testBlockCaretCoversTheCharacterAtTheCursor() {
        let at = model(#"{"code":"ab\ncde","cursor":{"row":1,"col":2},"caret":"block"}"#)
        XCTAssertEqual(at.caretCharacter, "e")
        XCTAssertEqual(at.cursor, CodeBufferCell(row: 1, col: 2))
        XCTAssertEqual(at.caret, "block")
    }

    func testBarCaretKeepsTheCellBeforeTheCharacter() {
        let at = model(#"{"code":"ab\ncde","cursor":{"row":1,"col":2},"caret":"bar"}"#)
        XCTAssertEqual(at.caret, "bar")
        XCTAssertEqual(at.cursor.col, 2)
    }

    func testCaretAtLineEndIsASpaceWidthCellAfterTheLastCharacter() {
        let at = model(#"{"code":"ab\ncde","cursor":{"row":0,"col":2}}"#)
        XCTAssertNil(at.caretCharacter)
        XCTAssertEqual(at.caret, "block")
        XCTAssertEqual(at.columns, 4)
    }

    func testColumnsCountUnicodeScalars() {
        let at = model(#"{"code":"aé😀","cursor":{"row":0,"col":2}}"#)
        XCTAssertEqual(at.length(0), 3)
        XCTAssertEqual(at.caretCharacter, "\u{1F600}")
    }

    func testLinewiseSelectionPaintsEveryRowFromMinToMax() {
        let at = model(#"{"code":"ab\ncde\nf","cursor":{"row":1,"col":0},"selection":{"fromRow":1,"fromCol":2,"toRow":0,"toCol":0,"linewise":true}}"#)
        XCTAssertEqual(at.selectionSpan(row: 0), 0..<3)
        XCTAssertEqual(at.selectionSpan(row: 1), 0..<4)
        XCTAssertNil(at.selectionSpan(row: 2))
    }

    func testCharwiseSelectionIncludesTheMaxEnd() {
        let at = model(#"{"code":"abcd","cursor":{"row":0,"col":2},"selection":{"fromRow":0,"fromCol":1,"toRow":0,"toCol":2,"linewise":false}}"#)
        XCTAssertEqual(at.selectionSpan(row: 0), 1..<3)
    }

    func testSelectionAnchoredAfterTheCursorPaintsTheSameRange() {
        let at = model(#"{"code":"abcd","cursor":{"row":0,"col":1},"selection":{"fromRow":0,"fromCol":2,"toRow":0,"toCol":1,"linewise":false}}"#)
        XCTAssertEqual(at.selectionSpan(row: 0), 1..<3)
    }

    func testMultiRowCharwiseSelectionRunsToTheLineEndThenFromTheLineStart() {
        let at = model(#"{"code":"abc\ndef","cursor":{"row":1,"col":1},"selection":{"fromRow":0,"fromCol":1,"toRow":1,"toCol":1,"linewise":false}}"#)
        XCTAssertEqual(at.selectionSpan(row: 0), 1..<4)
        XCTAssertEqual(at.selectionSpan(row: 1), 0..<2)
    }

    func testNullSelectionPaintsNothing() {
        let at = model(#"{"code":"abcd","cursor":{"row":0,"col":0},"selection":null}"#)
        XCTAssertNil(at.selection)
        XCTAssertNil(at.selectionSpan(row: 0))
    }

    func testKeywordDecorationColorsTheTextWithTheKeywordToken() {
        let at = model(#"{"code":"fun main","cursor":{"row":0,"col":0},"decorations":[{"id":"k","fromRow":0,"fromCol":0,"toRow":0,"toCol":3,"tone":"keyword"}]}"#)
        XCTAssertEqual(at.runs(row: 0), [CodeBufferRun(text: "fun", foreground: "keyword"), CodeBufferRun(text: " main", foreground: nil)])
        XCTAssertEqual(CodeBufferModel.color("keyword", .fallback), AlmadarTheme.fallback.color.primary)
    }

    func testReviewDecorationPaintsABackgroundNotTheText() {
        let at = model(#"{"code":"abcd","cursor":{"row":0,"col":0},"decorations":[{"id":"r","fromRow":0,"fromCol":1,"toRow":0,"toCol":3,"tone":"review"}]}"#)
        XCTAssertEqual(at.runs(row: 0), [CodeBufferRun(text: "abcd", foreground: nil)])
        let spans = at.backgrounds(row: 0)
        XCTAssertEqual(spans.count, 1)
        XCTAssertEqual(spans[0].range, 1..<3)
        XCTAssertEqual(spans[0].tone, "review")
        XCTAssertNotNil(CodeBufferModel.color("review", .fallback))
    }

    func testUnknownToneAndLaterDecorationsOverEarlierOnes() {
        let at = model(#"{"code":"abcd","cursor":{"row":0,"col":0},"decorations":[{"id":"a","fromRow":0,"fromCol":0,"toRow":0,"toCol":4,"tone":"string"},{"id":"b","fromRow":0,"fromCol":1,"toRow":0,"toCol":2,"tone":"keyword"},{"id":"c","fromRow":0,"fromCol":0,"toRow":0,"toCol":4,"tone":"nope"}]}"#)
        XCTAssertEqual(at.runs(row: 0).map { $0.foreground }, ["string", "keyword", "string"])
        XCTAssertNil(CodeBufferModel.color("nope", .fallback))
    }

    func testDecorationSpanningRowsCoversTheTailThenTheHead() {
        let at = model(#"{"code":"abc\ndef","cursor":{"row":0,"col":0},"decorations":[{"id":"s","fromRow":0,"fromCol":1,"toRow":1,"toCol":2,"tone":"comment"}]}"#)
        XCTAssertEqual(at.runs(row: 0).map { $0.text }, ["a", "bc"])
        XCTAssertEqual(at.runs(row: 1).map { $0.text }, ["de", "f"])
    }

    func testPopoverCarriesTitleSectionsAndBusy() {
        let at = model(#"{"code":"ab","cursor":{"row":0,"col":0},"popover":{"fromRow":0,"fromCol":1,"toRow":0,"toCol":2,"title":"T","sections":[{"heading":"H","lines":["l1","l2"]}],"busy":true}}"#)
        let note = at.popover
        XCTAssertEqual(note?.title, "T")
        XCTAssertEqual(note?.sections.first?.heading, "H")
        XCTAssertEqual(note?.sections.first?.lines, ["l1", "l2"])
        XCTAssertEqual(note?.busy, true)
        XCTAssertNil(model(#"{"code":"ab","cursor":{"row":0,"col":0},"popover":null}"#).popover)
    }

    func testRelativeGutterShowsDistancesAndTheCursorRowsOwnNumber() {
        let at = model(#"{"code":"a\nb\nc\nd\ne","cursor":{"row":2,"col":0},"relativeLineNumbers":true}"#)
        XCTAssertEqual(at.gutter, ["2", "1", "3", "1", "2"])
        XCTAssertEqual(model(#"{"code":"a\nb\nc","cursor":{"row":2,"col":0}}"#).gutter, ["1", "2", "3"])
    }

    func testKeyPayloadCarriesTheWebKeyboardEventFields() {
        let payload = CodeBufferModel.keyPayload(editorId: "ed", key: "a", ctrl: false, alt: false, shift: true, meta: false, repeating: true)
        XCTAssertEqual(payload, props(#"{"editorId":"ed","key":"a","code":"KeyA","ctrl":false,"alt":false,"shift":true,"meta":false,"repeat":true}"#))
        XCTAssertEqual(CodeBufferModel.keyPayload(editorId: "ed", key: "Escape", ctrl: false, alt: false, shift: false, meta: false, repeating: false).dictValue?["code"], .string("Escape"))
    }

    func testPointerPressMapsToACellAndClampsPastTheLineEndAndBelowTheLastLine() {
        let at = model(#"{"code":"ab\ncde","cursor":{"row":0,"col":0}}"#)
        let hit = at.cell(x: 10, y: 20, cellWidth: 8, cellHeight: 16)
        XCTAssertEqual(hit, CodeBufferCell(row: 1, col: 1))
        XCTAssertEqual(CodeBufferModel.cellPayload(editorId: "ed", hit), props(#"{"editorId":"ed","row":1,"col":1}"#))
        XCTAssertEqual(at.cell(x: 400, y: 2, cellWidth: 8, cellHeight: 16), CodeBufferCell(row: 0, col: 2))
        XCTAssertEqual(at.cell(x: 1, y: 900, cellWidth: 8, cellHeight: 16), CodeBufferCell(row: 1, col: 0))
    }

    func testHoverReportsOncePerCellEntered() {
        let first = CodeBufferCell(row: 0, col: 1)
        XCTAssertEqual(CodeBufferModel.hovered(last: nil, now: first), first)
        XCTAssertNil(CodeBufferModel.hovered(last: first, now: first))
        XCTAssertEqual(CodeBufferModel.hovered(last: first, now: CodeBufferCell(row: 0, col: 2)), CodeBufferCell(row: 0, col: 2))
    }
}
