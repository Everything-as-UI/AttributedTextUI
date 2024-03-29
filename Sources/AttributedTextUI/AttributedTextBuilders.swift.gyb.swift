%{
elements = ['C0', 'C1', 'C2', 'C3', 'C4', 'C5', 'C6', 'C7', 'C8', 'C9', 'C10', 'C11', 'C12', 'C13', 'C14']
}%
///
///  Generated by Swift GYB.
///


extension AttributedTextBuilder {
    % for count in range(2, 11):
    public static func buildBlock<${', '.join(elements[:count])}>(
    ${', '.join(map(lambda x, y: '_ c' + str(x) + ': ' + y, range(0, count), elements[:count]))}
    ) -> TupleText<(${', '.join(elements[:count])})> where ${', '.join(map(lambda x: x + ': AttributedText', elements[:count]))} {
        TupleText {
            % for x in range(0, count):
            ${'var ' + elements[x].lower() + 'i = ' + elements[x] + '.AttributedTextInterpolation(' + elements[x].lower() + '); let ' + elements[x].lower() + 'r = ' + elements[x].lower() + 'i.build()'}
            % end
            return [${', '.join(map(lambda x: '.attributedString(' + elements[x].lower() + 'r)', range(0, count)))}]
        }
    }
    % end
}
