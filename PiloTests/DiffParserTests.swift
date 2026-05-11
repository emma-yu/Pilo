import XCTest
@testable import Pilo

final class DiffParserTests: XCTestCase {

    func testSimpleAddedLine() {
        let diff = """
        diff --git a/foo.txt b/foo.txt
        index abc123..def456 100644
        --- a/foo.txt
        +++ b/foo.txt
        @@ -0,0 +1,1 @@
        +new line
        """
        let lines = DiffParser.parse(diff)
        XCTAssertEqual(lines.count, 1)
        XCTAssertEqual(lines.first?.filePath, "foo.txt")
        XCTAssertEqual(lines.first?.newLineNumber, 1)
        XCTAssertEqual(lines.first?.content, "new line")
    }

    func testMultipleHunksTrackLineNumbers() {
        let diff = """
        diff --git a/foo.txt b/foo.txt
        --- a/foo.txt
        +++ b/foo.txt
        @@ -0,0 +5,2 @@
        +line A
        +line B
        @@ -0,0 +20,1 @@
        +line C
        """
        let lines = DiffParser.parse(diff)
        XCTAssertEqual(lines.count, 3)
        XCTAssertEqual(lines[0].newLineNumber, 5)
        XCTAssertEqual(lines[1].newLineNumber, 6)
        XCTAssertEqual(lines[2].newLineNumber, 20)
    }

    func testBinaryFileSkipped() {
        let diff = """
        diff --git a/img.png b/img.png
        Binary files a/img.png and b/img.png differ
        """
        let lines = DiffParser.parse(diff)
        XCTAssertTrue(lines.isEmpty, "二进制文件不应产生 DiffLine")
    }

    func testDeletedLineDoesNotIncrementNewLine() {
        let diff = """
        diff --git a/foo.txt b/foo.txt
        --- a/foo.txt
        +++ b/foo.txt
        @@ -1,3 +1,2 @@
         context line
        -deleted line
        +replaced line
        """
        let lines = DiffParser.parse(diff)
        XCTAssertEqual(lines.count, 1)
        XCTAssertEqual(lines[0].content, "replaced line")
        // context 占第 1 行；删除不算；replaced line 第 2 行
        XCTAssertEqual(lines[0].newLineNumber, 2)
    }

    func testMultipleFilesTracked() {
        let diff = """
        diff --git a/a.txt b/a.txt
        --- a/a.txt
        +++ b/a.txt
        @@ -0,0 +1,1 @@
        +alpha
        diff --git a/b.txt b/b.txt
        --- a/b.txt
        +++ b/b.txt
        @@ -0,0 +1,1 @@
        +bravo
        """
        let lines = DiffParser.parse(diff)
        XCTAssertEqual(lines.count, 2)
        XCTAssertEqual(lines[0].filePath, "a.txt")
        XCTAssertEqual(lines[0].content, "alpha")
        XCTAssertEqual(lines[1].filePath, "b.txt")
        XCTAssertEqual(lines[1].content, "bravo")
    }

    func testPathWithSpacesAndSlashes() {
        let diff = """
        diff --git a/src/feature/x.ts b/src/feature/x.ts
        --- a/src/feature/x.ts
        +++ b/src/feature/x.ts
        @@ -0,0 +1,1 @@
        +import foo;
        """
        let lines = DiffParser.parse(diff)
        XCTAssertEqual(lines.first?.filePath, "src/feature/x.ts")
    }
}
