import CHarper
import Darwin

public struct Harper {
    /// Returns the version of the underlying harper-core library
    public static func version() -> String {
        guard let cstr = harper_version() else { return "<nil>" }
        defer { free(UnsafeMutableRawPointer(mutating: cstr)) }
        return String(cString: cstr)
    }

    public static func hello() -> String {
        return "Hello, World!"
    }

    public class Document {
        private var ptr: OpaquePointer?

        public init?(text: String) {
            let cstr = text.utf8CString
            ptr = cstr.withUnsafeBufferPointer {
                harper_create_document($0.baseAddress)
            }
            if ptr == nil { return nil }
        }

        deinit {
            if let ptr = ptr {
                harper_free_document(ptr)
            }
        }

        public func getText() -> String? {
            guard let ptr = ptr else { return nil }
            guard let cstr = harper_get_document_text(ptr) else { return nil }
            defer { free(cstr) }
            return String(cString: cstr)
        }

        public func getTokenCount() -> Int {
            guard let ptr = ptr else { return 0 }
            return Int(harper_get_token_count(ptr))
        }

        public func getLints(lintGroup: LintGroup) -> [Lint] {
            var count: Int32 = 0
            guard let lintsPtr = harper_get_lints(ptr, lintGroup.ptr, &count), count > 0 else {
                return []
            }
            var result: [Lint] = []
            let buffer = UnsafeBufferPointer(start: lintsPtr, count: Int(count))
            for lintPtr in buffer {
                if let lintPtr = lintPtr {
                    result.append(Lint(ptr: lintPtr))
                }
            }
            return result
        }
    }

    public class LintGroup {
        var ptr: OpaquePointer?
        public init?() {
            ptr = harper_create_lint_group()
            if ptr == nil { return nil }
        }
        deinit {
            if let ptr = ptr {
                harper_free_lint_group(ptr)
            }
        }
    }

    public class Lint {
        var ptr: OpaquePointer?
        init(ptr: OpaquePointer?) { self.ptr = ptr }
        deinit {
            if let ptr = ptr {
                harper_free_lint(ptr)
            }
        }
        public func message() -> String? {
            guard let ptr = ptr else { return nil }
            guard let cstr = harper_get_lint_message(ptr) else { return nil }
            defer { free(UnsafeMutableRawPointer(mutating: cstr)) }
            return String(cString: cstr)
        }
        public func startAndEnd() -> (Int64, Int64) {
            guard let ptr = ptr else { return (-1, -1) }
            var start: Int64 = -1
            var end: Int64 = -1
            harper_get_lint_start_and_end(ptr, &start, &end)
            return (start, end)
        }

        /// Returns the problematic text fragment for this lint, or nil if unavailable.
        ///
        /// Note: In Swift, slicing a String (e.g., `docText[sIdx..<eIdx]`) produces a `Substring`,
        /// which is a view into the original String's storage (zero-copy, efficient).
        /// However, holding onto a Substring keeps the entire original String alive in memory.
        /// By converting the Substring to a new String (`String(...)`), we create an owned copy,
        /// which is safer for API boundaries and avoids accidental memory retention.
        /// Returning `String?` (an optional String) is idiomatic for cases where the result
        /// may be absent due to invalid indices or missing document text.
        ///
        /// See also: https://developer.apple.com/documentation/swift/substring
        public func textFragment(from document: Harper.Document) -> String? {
            let (start, end) = self.startAndEnd()
            guard start >= 0, end >= start else { return nil }
            guard let docText = document.getText() else { return nil }
            // Convert Int64 to String.Index safely
            guard
                let startIdx = docText.utf16.index(
                    docText.utf16.startIndex, offsetBy: Int(start),
                    limitedBy: docText.utf16.endIndex),
                let endIdx = docText.utf16.index(
                    docText.utf16.startIndex, offsetBy: Int(end), limitedBy: docText.utf16.endIndex),
                let sIdx = String.Index(startIdx, within: docText),
                let eIdx = String.Index(endIdx, within: docText)
            else { return nil }
            return String(docText[sIdx..<eIdx])
        }

        public func suggestionCount() -> Int {
            guard let ptr = ptr else { return 0 }
            return Int(harper_get_lint_suggestion_count(ptr))
        }

        public func suggestionText(at index: Int) -> String? {
            guard let ptr = ptr else { return nil }
            guard let cstr = harper_get_lint_suggestion_text(ptr, Int32(index)) else { return nil }
            defer { free(UnsafeMutableRawPointer(mutating: cstr)) }
            return String(cString: cstr)
        }
    }
}
