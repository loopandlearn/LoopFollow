// Wrong header on purpose to make swiftformat --lint fail.

import Foundation

struct LintTestThrowaway {
        let value: Int

        func describe() -> String {
                return  "value=\(value)"
        }
}
