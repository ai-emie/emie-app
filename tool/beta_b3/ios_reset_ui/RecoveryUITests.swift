import XCTest

/// Runs only against the separately built Local Debug app on the selected own simulator.
/// Raw activities may include typeText values: keep xcresult private, export redacted evidence.
final class RecoveryUITests: XCTestCase {
    let app = XCUIApplication(bundleIdentifier: "ai.emiso.emie")
    override func setUpWithError() throws { continueAfterFailure = false }
    override func tearDownWithError() throws { snapshot("end-state") }
    func config() throws -> [String: String] {
        let root = try String(contentsOfFile: "/private/tmp/emie_e2e_current", encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: root + "/private/ui-config.json"))) as! [String: Any]
        return json.compactMapValues { $0 as? String }
    }
    func snapshot(_ name: String) {
        let picture = XCTAttachment(screenshot: app.screenshot()); picture.name = name; picture.lifetime = .keepAlways; add(picture)
        let tree = XCTAttachment(string: app.debugDescription); tree.name = name + "-accessibility"; tree.lifetime = .keepAlways; add(tree)
    }
    func text(_ value: String) -> XCUIElement { app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", value)).firstMatch }
    func field(_ label: String) -> XCUIElement { app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label)).firstMatch }
    func logoutIfNeeded() {
        app.activate()
        if app.staticTexts["Profil"].waitForExistence(timeout: 5) {
            app.staticTexts.matching(identifier: "Profil").allElementsBoundByIndex.last!.tap()
            // Existing unlabeled settings icon in the observed app bar; no app behavior patched.
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.89, dy: 0.125)).tap()
            let logout = text("Abmelden")
            XCTAssertTrue(logout.waitForExistence(timeout: 5))
            if !logout.isHittable { app.swipeUp() }
            logout.tap()
        }
        XCTAssertTrue(app.textFields.firstMatch.waitForExistence(timeout: 8))
    }
    func login(_ email: String, _ password: String, name: String) {
        let field = self.field("E-Mail")
        XCTAssertTrue(field.waitForExistence(timeout: 8)); field.tap(); field.typeText(email)
        let secret = self.field("Passwort"); secret.tap(); secret.typeText(password)
        submitLogin()
        XCTAssertTrue(text(name).waitForExistence(timeout: 15)); snapshot("login-" + name)
    }
    func submitLogin() {
        if app.keyboards.buttons["Done"].exists { app.keyboards.buttons["Done"].tap() }
        let button = app.buttons["Einloggen"]
        if !button.isHittable { app.swipeUp() }
        XCTAssertTrue(button.isHittable); button.tap()
    }
    func testI1LoginContinuation() {
        // Continue the already confirmed I1 reset; never resubmit its proof.
        app.activate(); submitLogin()
        XCTAssertTrue(text("E2E A").waitForExistence(timeout: 15)); snapshot("I1-login-A")
    }
    func openAndSubmit(_ c: [String: String], cold: Bool, loss: Bool) {
        if cold { app.terminate(); XCTAssertEqual(app.state, .notRunning) }
        else { app.activate(); XCTAssertEqual(app.state, .runningForeground) }
        if cold { app.open(URL(string: c["url"]!)!) }
        else { XCUIDevice.shared.system.open(URL(string: c["url"]!)!) }
        XCTAssertTrue(field("Neues Passwort").waitForExistence(timeout: 10))
        XCTAssertTrue(field("Passwort bestätigen").exists)
        snapshot(c["scenario"]! + "-form")
        field("Neues Passwort").tap(); field("Neues Passwort").typeText(c["new_password"]!)
        field("Passwort bestätigen").tap(); field("Passwort bestätigen").typeText(c["new_password"]!)
        let submit = app.buttons["Passwort speichern"]
        XCTAssertTrue(submit.isEnabled); submit.tap()
        if loss {
            XCTAssertTrue(text("nicht bestätigt").waitForExistence(timeout: 40))
            XCTAssertFalse(text("Dein Passwort wurde geändert").exists)
            // Observe a bounded no-retry window, while the host checks actual request counts.
            Thread.sleep(forTimeInterval: 5)
            XCTAssertFalse(text("Dein Passwort wurde geändert").exists)
        } else {
            XCTAssertTrue(text("Dein Passwort wurde geändert").waitForExistence(timeout: 20))
            XCTAssertFalse(field("Neues Passwort").exists)
        }
        snapshot(c["scenario"]! + "-result")
    }
    func testLogout() { logoutIfNeeded(); snapshot("logged-out") }
    func testI1Cold() throws {
        let c = try config(); XCTAssertEqual(c["scenario"], "I1")
        XCTAssertTrue(app.textFields.firstMatch.waitForExistence(timeout: 5))
        openAndSubmit(c, cold: true, loss: false)
        XCTAssertTrue(app.buttons["Zurück zum Login"].exists)
        app.buttons["Zurück zum Login"].tap()
        login(c["email"]!, c["new_password"]!, name: "E2E A")
    }
    func testI2Warm() throws {
        let c = try config(); XCTAssertEqual(c["scenario"], "I2")
        openAndSubmit(c, cold: false, loss: false)
        app.buttons["Zurück zur App"].tap(); XCTAssertTrue(text("E2E A").waitForExistence(timeout: 10))
        snapshot("I2-return-A")
    }
    func testLoginB() throws {
        let c = try config(); logoutIfNeeded(); login(c["b_email"]!, c["b_password"]!, name: "E2E B")
    }
    func testI3PreservesB() throws {
        let c = try config(); XCTAssertEqual(c["scenario"], "I3")
        app.activate(); XCTAssertTrue(text("E2E B").waitForExistence(timeout: 10)); snapshot("I3-B-before")
        openAndSubmit(c, cold: false, loss: false)
        app.buttons["Zurück zur App"].tap(); XCTAssertTrue(text("E2E B").waitForExistence(timeout: 10)); snapshot("I3-B-after")
        app.staticTexts.matching(identifier: "Profil").allElementsBoundByIndex.last!.tap(); XCTAssertTrue(text("E2E B").waitForExistence(timeout: 10)); snapshot("I3-B-profile")
        app.staticTexts["Übersicht"].tap()
    }
    func testI4LostConfirmation() throws {
        let c = try config(); XCTAssertEqual(c["scenario"], "I4")
        app.activate(); XCTAssertTrue(text("E2E B").waitForExistence(timeout: 10)); snapshot("I4-B-before")
        openAndSubmit(c, cold: false, loss: true)
        app.buttons["Zurück zur App"].tap(); XCTAssertTrue(text("E2E B").waitForExistence(timeout: 10)); snapshot("I4-B-after")
    }
}
