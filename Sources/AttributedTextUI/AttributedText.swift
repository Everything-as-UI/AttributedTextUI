import DocumentUI
import CommonUI
import CoreUI
import Foundation

@_exported import struct CoreUI.Group
@_exported import struct DocumentUI.ForEach
@_exported import struct DocumentUI.NullDocument

public typealias AttributedTextBuilder = TextDocumentBuilder

#if canImport(UIKit)
import class UIKit.UIImage
import class UIKit.NSTextAttachment
import class UIKit.NSMutableParagraphStyle
public typealias Image = UIImage
#elseif canImport(AppKit)
import class AppKit.NSImage
import class AppKit.NSTextAttachment
import class AppKit.NSTextAttachmentCell
import class AppKit.NSMutableParagraphStyle
public typealias Image = NSImage
#endif

public typealias StringAttributesContainer = [NSAttributedString.Key: Any]
public struct AttributedContent {
    var nestedContent: [NestedContent] = []
    var attributes: StringAttributesContainer = [:]

    enum NestedContent {
        case string(String)
        case attributedString(AttributedContent)
        #if canImport(UIKit) || canImport(AppKit)
        case image(Image)
        #endif
    }
}

public struct DefaultTextInterpolation<Document>: ViewInterpolationProtocol where Document: AttributedText {
    public typealias ModifyContent = Document.TextBody.AttributedTextInterpolation.ModifyContent
    var base: Document.TextBody.AttributedTextInterpolation
    @_spi(AttributedText)
    public init(_ document: Document) {
        self.base = Document.TextBody.AttributedTextInterpolation(document.textBody)
    }
    @_spi(AttributedText)
    public mutating func modify<M>(_ modifier: M) where M : ViewModifier, ModifyContent == M.Modifiable {
        base.modify(modifier)
    }
    @_spi(AttributedText)
    public mutating func build() -> Document.TextBody.AttributedTextInterpolation.Result {
        base.build()
    }
}

@_typeEraser(AnyAttributedText)
public protocol AttributedText {
    associatedtype AttributedTextInterpolation: ViewInterpolationProtocol = DefaultTextInterpolation<Self> where AttributedTextInterpolation.View == Self, AttributedTextInterpolation.Result == AttributedContent
    associatedtype TextBody: AttributedText
    @AttributedTextBuilder var textBody: TextBody { get }
}
protocol AttributedTextInterpolationProtocol: ViewInterpolationProtocol where View: AttributedText {
    var document: View { get }
    var modifyContent: ModifyContent { get set }
}
extension AttributedTextInterpolationProtocol {
    public mutating func modify<M>(_ modifier: M) where M : ViewModifier, ModifyContent == M.Modifiable {
        modifier.modify(content: &modifyContent)
    }
}
extension AttributedTextInterpolationProtocol
where View.TextBody.AttributedTextInterpolation.Result == AttributedContent,
      ModifyContent == StringAttributesContainer {
    mutating func _build() -> AttributedContent { build() }
    mutating func build() -> AttributedContent {
        var base = View.TextBody.AttributedTextInterpolation(document.textBody)
        return AttributedContent(nestedContent: [.attributedString(base.build())], attributes: modifyContent)
    }
}

extension Never: AttributedText {}

extension _ModifiedDocument: AttributedText where Content: AttributedText, Modifier: ViewModifier, Content.AttributedTextInterpolation.ModifyContent == Modifier.Modifiable {
    public var textBody: Never { fatalError()}
    @_spi(AttributedText)
    public struct AttributedTextInterpolation: ViewInterpolationProtocol {
        public typealias View = _ModifiedDocument<Content, Modifier>
        public typealias ModifyContent = Content.AttributedTextInterpolation.ModifyContent
        var base: Content.AttributedTextInterpolation
        public init(_ document: _ModifiedDocument<Content, Modifier>) {
            self.base = Content.AttributedTextInterpolation(document.content)
            self.base.modify(document.modifier)
        }
        public mutating func modify<M>(_ modifier: M) where M : ViewModifier, ModifyContent == M.Modifiable {
            base.modify(modifier)
        }
        public mutating func build() -> Content.AttributedTextInterpolation.Result {
            base.build()
        }
    }
}
extension AttributedText {
    public func modifier<T>(_ modifier: T) -> _ModifiedDocument<Self, T> where T: ViewModifier, T.Modifiable == AttributedTextInterpolation.ModifyContent {
        _ModifiedDocument(self, modifier: modifier)
    }
}
extension _ConditionalDocument: AttributedText
where TrueContent: AttributedText, FalseContent: AttributedText,
      TrueContent.AttributedTextInterpolation.ModifyContent == FalseContent.AttributedTextInterpolation.ModifyContent {
    public var textBody: Never { fatalError() }
    @_spi(AttributedText)
    public struct AttributedTextInterpolation: ViewInterpolationProtocol {
        public typealias ModifyContent = TrueContent.AttributedTextInterpolation.ModifyContent
        public typealias View = _ConditionalDocument<TrueContent, FalseContent>
        enum Condition {
            case first(TrueContent.AttributedTextInterpolation)
            case second(FalseContent.AttributedTextInterpolation)
        }
        var base: Condition
        public init(_ document: _ConditionalDocument<TrueContent, FalseContent>) {
            switch document.condition {
            case .first(let first): self.base = .first(TrueContent.AttributedTextInterpolation(first))
            case .second(let second): self.base = .second(FalseContent.AttributedTextInterpolation(second))
            }
        }
        public mutating func modify<M>(_ modifier: M) where M : ViewModifier, ModifyContent == M.Modifiable {
            switch base {
            case .first(var trueContent):
                trueContent.modify(modifier)
                self.base = .first(trueContent)
            case .second(var falseContent):
                falseContent.modify(modifier)
                self.base = .second(falseContent)
            }
        }
        public func build() -> AttributedContent {
            switch base {
            case .first(var trueContent): return trueContent.build()
            case .second(var falseContent): return falseContent.build()
            }
        }
    }
}

@_spi(AttributedText)
extension Optional: AttributedText where Wrapped: AttributedText {
    public var textBody: Never { fatalError() }
    public struct AttributedTextInterpolation: ViewInterpolationProtocol {
        public typealias View = Optional<Wrapped>
        public typealias ModifyContent = Wrapped.AttributedTextInterpolation.ModifyContent
        var base: Wrapped.AttributedTextInterpolation?
        public init(_ document: Optional<Wrapped>) {
            self.base = document.map(Wrapped.AttributedTextInterpolation.init)
        }
        public mutating func modify<M>(_ modifier: M) where M : ViewModifier, ModifyContent == M.Modifiable {
            base?.modify(modifier)
        }
        public mutating func build() -> AttributedContent {
            base?.build() ?? AttributedContent()
        }
    }
}

extension NullDocument: AttributedText {}
extension String: AttributedText {
    @_spi(AttributedText)
    public struct AttributedTextInterpolation: ViewInterpolationProtocol {
        public typealias ModifyContent = StringAttributesContainer
        let document: String
        var attributes: StringAttributesContainer
        public init(_ document: String) {
            self.document = document
            self.attributes = StringAttributesContainer()
        }
        public mutating func modify<M>(_ modifier: M) where M : ViewModifier, ModifyContent == M.Modifiable {
            modifier.modify(content: &attributes)
        }
        public mutating func build() -> AttributedContent {
            AttributedContent(nestedContent: [.string(document)], attributes: attributes)
        }
    }
}

#if canImport(UIKit) || canImport(AppKit)
@_spi(AttributedText)
extension Image: AttributedText {
    public var textBody: Never { fatalError() }
    public struct AttributedTextInterpolation: ViewInterpolationProtocol {
        public typealias View = Image
        public typealias ModifyContent = StringAttributesContainer
        let document: Image
        var attributes: StringAttributesContainer = StringAttributesContainer()
        public init(_ document: Image) {
            self.document = document
        }
        public mutating func modify<M>(_ modifier: M) where M : ViewModifier, ModifyContent == M.Modifiable {
            modifier.modify(content: &attributes)
        }
        public func build() -> AttributedContent {
            AttributedContent(nestedContent: [.image(document)], attributes: attributes)
        }
    }
}
#endif

public struct AnyAttributedText: AttributedText {
    let interpolation: AnyInterpolation<StringAttributesContainer, AttributedContent>
    public init<T>(_ document: T) where T: AttributedText, T.AttributedTextInterpolation.ModifyContent == StringAttributesContainer {
        self.interpolation = AnyInterpolation(T.AttributedTextInterpolation(document))
    }
    public init<T>(_ document: T) where T: AttributedText {
        self.init(AttributedTextProxy(_body: document))
    }
    public init<T>(erasing document: T) where T: AttributedText {
        self.init(document)
    }
    public var textBody: Never { fatalError() }
    @_spi(AttributedText)
    public struct AttributedTextInterpolation: ViewInterpolationProtocol {
        public typealias ModifyContent = StringAttributesContainer
        let document: AnyAttributedText
        public init(_ document: AnyAttributedText) {
            self.document = document
        }
        public mutating func modify<M>(_ modifier: M) where M : ViewModifier, ModifyContent == M.Modifiable {
            document.interpolation.modify(modifier)
        }
        public func build() -> AttributedContent { document.interpolation.build() }
    }
}

public struct TupleText<T>: AttributedText {
    let build: () -> [AttributedContent.NestedContent]
    public var textBody: Never { fatalError() }
    @_spi(AttributedText)
    public struct AttributedTextInterpolation: ViewInterpolationProtocol {
        public typealias View = TupleText<T>
        public typealias ModifyContent = StringAttributesContainer
        let document: TupleText<T>
        var attributes: StringAttributesContainer
        public init(_ document: TupleText<T>) {
            self.document = document
            self.attributes = StringAttributesContainer()
        }
        public mutating func modify<M>(_ modifier: M) where M : ViewModifier, ModifyContent == M.Modifiable {
            modifier.modify(content: &attributes)
        }
        public mutating func build() -> AttributedContent {
            AttributedContent(nestedContent: document.build(), attributes: attributes)
        }
    }
}

///

extension Group: AttributedText where Content: AttributedText {
    public var textBody: some AttributedText { body }
}
extension ForEach: AttributedText where Content: AttributedText {
    public var textBody: Never { fatalError() }
    @_spi(AttributedText)
    public struct AttributedTextInterpolation: ViewInterpolationProtocol {
        public typealias View = ForEach<Data, Content>
        public typealias ModifyContent = StringAttributesContainer
        let document: View
        var attributes: StringAttributesContainer
        public init(_ document: ForEach<Data, Content>) {
            self.document = document
            self.attributes = StringAttributesContainer()
        }
        public mutating func modify<M>(_ modifier: M) where M : ViewModifier, ModifyContent == M.Modifiable {
            modifier.modify(content: &attributes)
        }
        public mutating func build() -> Content.AttributedTextInterpolation.Result {
            var result = AttributedContent(attributes: attributes)
            for element in document.data {
                var interpolation = Content.AttributedTextInterpolation(document.content(element))
                result.nestedContent.append(.attributedString(interpolation.build()))
            }
            return result
        }
    }
}

///

extension AttributedText {
    public func makeContent() -> AttributedContent {
        var interpolator = AttributedTextInterpolation(self)
        return interpolator.build()
    }
}
extension AttributedContent {
    public func nsAttributedString() -> NSAttributedString {
        let aString = NSMutableAttributedString()
        aString.append(self)
        return aString
    }
    @available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
    public func attributedString() -> AttributedString {
        var aString = AttributedString()
        aString.append(self)
        return aString
    }
    public func consoleString() -> String {
        var aString = String()
        aString.append(self)
        return aString
    }
}
extension String {
    public mutating func append(_ aContent: AttributedContent, inheritAttrs: StringAttributesContainer = [:]) {
        guard aContent.nestedContent.count > 0 else { return }
        append(aContent.attributes)
        let parentAttrs = inheritAttrs.merging(aContent.attributes, uniquingKeysWith: { _, new in new })
        for (i, nested) in aContent.nestedContent.enumerated() {
            switch nested {
            case .string(let str): append(str)
            case .attributedString(let aStr):
                append(aStr, inheritAttrs: parentAttrs)
                if i < aContent.nestedContent.count {
                    append(parentAttrs)
                }
            case .image: continue
            }
        }
        append("\\u{1b}[0m")
    }
    mutating func append(_ attrs: StringAttributesContainer) {
        for (key, _) in attrs {
            switch key {
            case .backgroundColor: append("\\u{1b}[41m")
            case .foregroundColor: append("\\u{1b}[33m")
            case .underlineStyle: append("\\u{1b}[4m")
            case .strikethroughStyle: append("\\u{1b}[9m")
            case .font: append("\\u{1b}[1m")
            case .textEffect: append("\\u{1b}[5m")
            case .shadow: append("\\u{1b}[2m")
            default: continue
            }
        }
    }
}
extension NSMutableAttributedString {
    public func append(_ aContent: AttributedContent) {
        let location = mutableString.length
        for nested in aContent.nestedContent {
            switch nested {
            case .string(let str): append(NSAttributedString(string: str))
            case .attributedString(let aStr): append(aStr)
                #if canImport(UIKit) || canImport(AppKit)
            case .image(let img):
                let attachment = NSTextAttachment()
                #if os(macOS)
                let attachmentCell: NSTextAttachmentCell = NSTextAttachmentCell(imageCell: img)
                attachment.attachmentCell = attachmentCell
                #else
                attachment.image = img
                #endif
                append(NSAttributedString(attachment: attachment))
                #endif
            }
        }
        addAttributes(aContent.attributes, range: NSRange(location: location, length: mutableString.length - location))
    }
}
@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedString {
    public mutating func append(_ aContent: AttributedContent) {
        let location = endIndex
        for nested in aContent.nestedContent {
            switch nested {
            case .string(let str): append(AttributedString(stringLiteral: str))
            case .attributedString(let aStr): append(aStr)
                #if canImport(UIKit) || canImport(AppKit)
            case .image(let img): // not working in SwiftUI
                let attachment = NSTextAttachment()
                #if os(macOS)
                let attachmentCell: NSTextAttachmentCell = NSTextAttachmentCell(imageCell: img)
                attachment.attachmentCell = attachmentCell
                #else
                attachment.image = img
                #endif
                append(AttributedString(NSAttributedString(attachment: attachment)))
                #endif
            }
        }
        self[location ..< endIndex].mergeAttributes(AttributeContainer(aContent.attributes), mergePolicy: .keepNew)
    }
}

///

public struct AttributedTextProxy<Body>: AttributedText where Body: AttributedText {
    let _body: Body
    public var textBody: Body { _body }
    @_spi(AttributedText)
    public struct AttributedTextInterpolation: AttributedTextInterpolationProtocol {
        public typealias ModifyContent = StringAttributesContainer
        public typealias Result = AttributedContent
        let document: AttributedTextProxy<Body>
        var modifyContent: StringAttributesContainer
        public init(_ document: AttributedTextProxy<Body>) {
            self.document = document
            self.modifyContent = StringAttributesContainer()
        }
        public mutating func build() -> AttributedContent { _build() }
    }
}

public struct TextDocumentProxy<Body>: AttributedText where Body: TextDocument {
    let _body: Body
    init(_body: Body) { self._body = _body }
    public var textBody: Never { fatalError() }
    @_spi(AttributedText)
    public struct AttributedTextInterpolation: ViewInterpolationProtocol {
        public typealias View = TextDocumentProxy<Body>
        public typealias ModifyContent = StringAttributesContainer
        let document: View
        var attributes: StringAttributesContainer
        public init(_ document: TextDocumentProxy<Body>) {
            self.document = document
            self.attributes = StringAttributesContainer()
        }
        public mutating func modify<M>(_ modifier: M) where M : ViewModifier, ModifyContent == M.Modifiable {
            modifier.modify(content: &attributes)
        }
        public func build() -> AttributedContent {
            var base = Body.DocumentInterpolation(document._body)
            return AttributedContent(nestedContent: [.string(base.build())], attributes: attributes)
        }
    }
}
extension TextDocument {
    public func attributedText() -> TextDocumentProxy<Self> { TextDocumentProxy(_body: self) }
    public func modifier<M>(_ modifier: M) -> _ModifiedDocument<TextDocumentProxy<Self>, M> where M: ViewModifier, M.Modifiable == StringAttributesContainer {
        _ModifiedDocument(TextDocumentProxy(_body: self), modifier: modifier)
    }
}

///

public struct AttributeModifier: ViewModifier {
    let key: NSAttributedString.Key
    let value: Any
    public init(_ key: NSAttributedString.Key, value: Any) {
        self.key = key
        self.value = value
    }
    public func modify(content: inout StringAttributesContainer) {
        content[key] = value
    }
}
extension AttributedText {
    public func attribute(_ key: NSAttributedString.Key, value: Any) -> _ModifiedDocument<Self, AttributeModifier> {
        _ModifiedDocument(self, modifier: AttributeModifier(key, value: value))
    }
}

#if canImport(UIKit) || canImport(AppKit)
public struct Paragraph<Content>: AttributedText where Content: AttributedText {
    let content: () -> Content
    public init(@AttributedTextBuilder content: @escaping () -> Content) {
        self.content = content
    }
    public var textBody: some AttributedText { content() }
    @_spi(AttributedText)
    public struct AttributedTextInterpolation: ViewInterpolationProtocol {
        public typealias View = Paragraph<Content>
        public typealias ModifyContent = NSMutableParagraphStyle
        var document: View
        var style: NSMutableParagraphStyle
        public init(_ document: Paragraph<Content>) {
            self.document = document
            self.style = NSMutableParagraphStyle()
        }
        public mutating func modify<M>(_ modifier: M) where M : ViewModifier, ModifyContent == M.Modifiable {
            modifier.modify(content: &style)
        }
        public mutating func build() -> AttributedContent {
            var interpolation = Content.AttributedTextInterpolation(document.content())
            var content = interpolation.build()
            content.nestedContent.append(.string("\n"))
            content.attributes[.paragraphStyle] = style
            return content
        }
    }
}
public struct ParagraphModifier: ViewModifier {
    let _modify: (NSMutableParagraphStyle) -> Void
    public init(_ modify: @escaping (NSMutableParagraphStyle) -> Void) {
        self._modify = modify
    }
    public func modify(content: inout NSMutableParagraphStyle) {
        _modify(content)
    }
}
#endif

extension AttributedText where AttributedTextInterpolation.ModifyContent == NSMutableParagraphStyle {
    public func modifier<M>(_ modifier: M) -> _ModifiedDocument<AttributedTextProxy<Self>, M> where M: ViewModifier, M.Modifiable == StringAttributesContainer {
        _ModifiedDocument(AttributedTextProxy(_body: self), modifier: modifier)
    }
    public func attribute(_ key: NSAttributedString.Key, value: Any) -> _ModifiedDocument<AttributedTextProxy<Self>, AttributeModifier> {
        _ModifiedDocument(AttributedTextProxy(_body: self), modifier: AttributeModifier(key, value: value))
    }
}
