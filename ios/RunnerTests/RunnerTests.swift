import Flutter
import UIKit
import XCTest
import Security
@testable import Runner

final class RunnerTests: XCTestCase {
  func testSyntheticKeychainRoundTrip() {
    let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: "emie.synthetic.native.tests",
      kSecAttrAccount as String: UUID().uuidString]
    defer { SecItemDelete(query as CFDictionary) }
    var write = query
    write[kSecValueData as String] = Data("synthetic-only".utf8)
    XCTAssertEqual(SecItemAdd(write as CFDictionary, nil), errSecSuccess)
    var read = query
    read[kSecReturnData as String] = true
    var result: CFTypeRef?
    XCTAssertEqual(SecItemCopyMatching(read as CFDictionary, &result), errSecSuccess)
    XCTAssertEqual(result as? Data, Data("synthetic-only".utf8))
  }
  let proof = "synthetic_only_proof_1234567890"
  func testColdDeliveryOnceAndWarmDelivery() {
    let ingress = RecoveryIngress(origin: "https://recovery.example.invalid")
    let url = URL(string: "https://recovery.example.invalid/reset-password?token=\(proof)")!
    XCTAssertTrue(ingress.accept(url))
    XCTAssertEqual(ingress.takeInitial(), url.absoluteString)
    XCTAssertNil(ingress.takeInitial())
    var delivered: [String] = []
    ingress.send = { delivered.append($0) }
    XCTAssertTrue(ingress.accept(url))
    XCTAssertEqual(delivered, [url.absoluteString])
    XCTAssertNil(ingress.takeInitial())
  }
  func testExpiredPendingAndSingleSlot() {
    let ingress = RecoveryIngress(origin: "https://recovery.example.invalid")
    var clock: TimeInterval = 1
    ingress.now = { clock }
    XCTAssertTrue(ingress.accept(URL(string: "https://recovery.example.invalid/reset-password?token=first")!))
    XCTAssertTrue(ingress.accept(URL(string: "https://recovery.example.invalid/reset-password?token=second")!))
    clock = 62
    XCTAssertNil(ingress.takeInitial())
  }
  func testUnrelatedPluginsAndOriginsAreNotConsumed() {
    let ingress = RecoveryIngress(origin: "https://recovery.example.invalid")
    for raw in ["com.googleusercontent.apps.example:/oauth", "https://other.example.invalid/reset-password", "https://recovery.example.invalid/other", "http://recovery.example.invalid/reset-password", "https://recovery.example.invalid:444/reset-password", "emie-local-recovery://recover/reset-password"] {
      XCTAssertFalse(ingress.accept(URL(string: raw)!))
    }
    XCTAssertNil(ingress.takeInitial())
  }
  func testOversizeNeutralAndUnconfirmedOriginDisabled() {
    let ingress = RecoveryIngress(origin: "https://recovery.example.invalid")
    XCTAssertTrue(ingress.accept(URL(string: "https://recovery.example.invalid/reset-password?token=" + String(repeating: "x", count: 4100))!))
    XCTAssertEqual(ingress.takeInitial(), "/reset-password")
    XCTAssertFalse(RecoveryIngress(origin: "").accept(URL(string: "https://recovery.example.invalid/reset-password")!))
  }
  func testLocalDeliveryMappingAndMalformedEnvelope() {
    let ingress = RecoveryIngress(origin: "", localPort: 8010)
    XCTAssertTrue(ingress.accept(URL(string: "emie-local-recovery://recover/reset-password?token=\(proof)")!))
    XCTAssertEqual(ingress.takeInitial(), "http://127.0.0.1:8010/reset-password?token=\(proof)")
    XCTAssertEqual(ingress.payload(URL(string: "emie-local-recovery://user@recover/reset-password?token=\(proof)")!), "/reset-password")
    XCTAssertEqual(ingress.payload(URL(string: "emie-local-recovery://recover:8010/reset-password?token=\(proof)")!), "/reset-password")
  }
}
