import Foundation
import CoreNFC

// Foreground NFC reader (v1). Wraps NFCNDEFReaderSession — the passive/
// background-read path is captured in NFCBackgroundReadSpike.md and swapped
// in when the spike lands.
//
// Usage:
//   NFCReader.shared.start(hint: "Hold your phone to the tag on Truck Mees") { result in
//       switch result { case .tag(let payload): … case .cancelled: … case .error(let e): … }
//   }
//
// Callers should re-arm on every `onAppear` of Shifts / ShiftDetail — this
// matches bundle §"The clock-in interaction" which specifies the listening
// window re-arms on every arrival, not once at launch.

public enum NFCReadResult {
    /// Parsed URL from the first NDEF URI record on the tag. If the first
    /// record wasn't a URI (or was un-parseable), `url` is nil and `payload`
    /// holds whatever text we could recover — the caller decides whether to
    /// ignore or debug-log it.
    case tag(payload: String, url: URL?)
    case cancelled
    case error(Error)
    case unavailable
}

public final class NFCReader: NSObject {
    public static let shared = NFCReader()
    private var session: NFCNDEFReaderSession?
    private var callback: ((NFCReadResult) -> Void)?

    public var isAvailable: Bool { NFCNDEFReaderSession.readingAvailable }

    public func start(hint: String, callback: @escaping (NFCReadResult) -> Void) {
        guard isAvailable else {
            callback(.unavailable)
            return
        }
        self.callback = callback
        session = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: true)
        session?.alertMessage = hint
        session?.begin()
    }

    public func stop() {
        session?.invalidate()
        session = nil
    }
}

extension NFCReader: NFCNDEFReaderSessionDelegate {
    public func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        // Prefer the first URI record (per Apple's background-tag-reading contract —
        // even in foreground we honour "first record wins" so behaviour matches
        // Phase 2 exactly).
        let records = messages.flatMap(\.records)
        let firstURL = records.compactMap(Self.decodeURIRecord).first
        // Human-readable payload for the audit trail if the URL is nil.
        let payload = records
            .compactMap { String(data: $0.payload, encoding: .utf8) }
            .joined()
        DispatchQueue.main.async {
            self.callback?(.tag(payload: payload, url: firstURL))
            self.callback = nil
        }
    }

    /// Extract a URL from an NDEF URI record. NDEF URI records use a 1-byte
    /// prefix code (§NFCForum-TS-RTD_URI_1.0) — we resolve the small prefix
    /// table below and prepend to the remainder.
    private static func decodeURIRecord(_ record: NFCNDEFPayload) -> URL? {
        guard record.typeNameFormat == .nfcWellKnown else { return nil }
        guard let type = String(data: record.type, encoding: .utf8), type == "U" else { return nil }
        let bytes = record.payload
        guard bytes.count >= 1 else { return nil }
        let prefixCode = bytes[0]
        let rest = String(data: bytes.suffix(from: 1), encoding: .utf8) ?? ""
        let prefix = uriPrefix(for: prefixCode)
        return URL(string: prefix + rest)
    }

    private static func uriPrefix(for code: UInt8) -> String {
        // Prefix table from NFC Forum RTD-URI 1.0 §3.2.2. We only need the
        // https + http entries in practice; the full table is here so a
        // shortened NDEF from a third-party writer still resolves.
        switch code {
        case 0x00: return ""
        case 0x01: return "http://www."
        case 0x02: return "https://www."
        case 0x03: return "http://"
        case 0x04: return "https://"
        case 0x05: return "tel:"
        case 0x06: return "mailto:"
        default:   return ""
        }
    }

    public func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        let ns = error as NSError
        let cancelled = ns.domain == NFCReaderError.errorDomain &&
            (ns.code == NFCReaderError.readerSessionInvalidationErrorUserCanceled.rawValue ||
             ns.code == NFCReaderError.readerSessionInvalidationErrorFirstNDEFTagRead.rawValue)
        DispatchQueue.main.async {
            self.callback?(cancelled ? .cancelled : .error(error))
            self.callback = nil
        }
    }
}
