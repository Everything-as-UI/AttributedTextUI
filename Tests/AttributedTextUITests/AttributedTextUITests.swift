import XCTest
import AttributedTextUI

final class AttributedTextUITests: XCTestCase {

    func testExample() {
        print(SwiftArticle().makeContent().consoleString())
    }
}

struct SwiftArticle: AttributedText {
    var textBody: some AttributedText {
        Paragraph {
            "Swift".prefix("\n")
                .attributedText()
                .attribute(.font, value: NSFont.systemFont(ofSize: 48, weight: .semibold))
                .attribute(.foregroundColor, value: NSColor.systemRed)
                .attribute(.underlineStyle, value: NSUnderlineStyle.single)
        }
        Paragraph {
            "The powerful programming language that is also"
            " easy "
                .attribute(.shadow, value: 10)
            "to learn."
        }
        .attribute(.font, value: NSFont.systemFont(ofSize: 32, weight: .medium))
        .attribute(.foregroundColor, value: NSColor.systemBlue)
        .attribute(.backgroundColor, value: NSColor.systemRed)
        Paragraph {
            "Swift is a powerful and intuitive programming language for macOS, iOS, watchOS, tvOS and beyond. Writing Swift code is interactive and fun, the syntax is concise yet expressive, and Swift includes modern features developers love. Swift code is safe by design, yet also produces software that runs lightning-fast."
                .attribute(.foregroundColor, value: NSColor.labelColor)
        }
    }
}
