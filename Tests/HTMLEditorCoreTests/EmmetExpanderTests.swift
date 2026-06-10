import XCTest
@testable import HTMLEditorCore

final class EmmetExpanderTests: XCTestCase {

    private func expand(_ s: String) -> String? { EmmetExpander.expand(s) }

    func testSingleElement() {
        XCTAssertEqual(expand("div"), "<div></div>")
    }

    func testVoidElementHasNoClose() {
        XCTAssertEqual(expand("br"), "<br>")
        XCTAssertEqual(expand("img"), "<img>")
    }

    func testClassOnlyDefaultsToDiv() {
        XCTAssertEqual(expand(".box"), #"<div class="box"></div>"#)
    }

    func testIdOnlyDefaultsToDiv() {
        XCTAssertEqual(expand("#main"), #"<div id="main"></div>"#)
    }

    func testMultipleClassesAndId() {
        XCTAssertEqual(expand("a.btn.lg#go"),
                       #"<a id="go" class="btn lg"></a>"#)
    }

    func testAttributesAndText() {
        XCTAssertEqual(expand(##"a[href="#" target=_blank]{Click}"##),
                       ##"<a href="#" target="_blank">Click</a>"##)
    }

    func testBareAttributeWithoutValue() {
        XCTAssertEqual(expand("input[disabled]"), "<input disabled>")
    }

    func testChild() {
        XCTAssertEqual(expand("ul>li"), """
        <ul>
          <li></li>
        </ul>
        """)
    }

    func testSiblings() {
        XCTAssertEqual(expand("p+p+p"), """
        <p></p>
        <p></p>
        <p></p>
        """)
    }

    func testMultiplication() {
        XCTAssertEqual(expand("ul>li*3"), """
        <ul>
          <li></li>
          <li></li>
          <li></li>
        </ul>
        """)
    }

    func testNumberingInClass() {
        XCTAssertEqual(expand("ul>li.item$*3"), """
        <ul>
          <li class="item1"></li>
          <li class="item2"></li>
          <li class="item3"></li>
        </ul>
        """)
    }

    func testZeroPaddedNumbering() {
        XCTAssertEqual(expand("li.item$$*2"), """
        <li class="item01"></li>
        <li class="item02"></li>
        """)
    }

    func testLoneNumberingBecomesOne() {
        XCTAssertEqual(expand("li.item$"), #"<li class="item1"></li>"#)
    }

    func testGroupingWithMultiplication() {
        XCTAssertEqual(expand("(li>a)*2"), """
        <li>
          <a></a>
        </li>
        <li>
          <a></a>
        </li>
        """)
    }

    func testGroupNumbering() {
        XCTAssertEqual(expand("(li.row$)*2"), """
        <li class="row1"></li>
        <li class="row2"></li>
        """)
    }

    func testNestedChildSiblingMix() {
        // a descends to b and c as siblings
        XCTAssertEqual(expand("a>b+c"), """
        <a>
          <b></b>
          <c></c>
        </a>
        """)
    }

    func testTextOnlyIsRaw() {
        XCTAssertEqual(expand("{hello world}"), "hello world")
    }

    func testElementWithText() {
        XCTAssertEqual(expand("p{Hi there}"), "<p>Hi there</p>")
    }

    func testRejectsLeadingAngleBracket() {
        XCTAssertNil(expand("<div>"))
    }

    func testRejectsTrailingGarbage() {
        XCTAssertNil(expand("div@@"))
    }

    func testRejectsEmpty() {
        XCTAssertNil(expand("   "))
    }

    func testRealisticLayout() {
        XCTAssertEqual(expand("nav>ul>li*2>a"), """
        <nav>
          <ul>
            <li>
              <a></a>
            </li>
            <li>
              <a></a>
            </li>
          </ul>
        </nav>
        """)
    }
}
