//
//  UsersControllerTests.swift
//  ApiCoreTests
//
//  Created by Ondrej Rafaj on 28/02/2018.
//

import Foundation
import XCTest
@testable import ApiCore
import Vapor
import VaporTestTools
import FluentTestTools
import ApiCoreTestTools
import MailCore
import MailCoreTestTools


class UsersControllerTests: XCTestCase, UsersTestCase, LinuxTests {
    
    var app: Application!
    
    var adminTeam: Team!
    var user1: CoreUser!
    var user2: CoreUser!
    
    // MARK: Linux
    
    static let allTests: [(String, Any)] = [
        ("testLinuxTests", testLinuxTests),
        ("testGetUsers", testGetUsers),
        ("testRegisterUser", testRegisterUser),
        ("testSearchUsersWithoutParams", testSearchUsersWithoutParams)
    ]
    
    func testLinuxTests() {
        doTestLinuxTestsAreOk()
    }
    
    // MARK: Setup
    
    override func setUp() {
        super.setUp()
        
        app = Application.testable.newApiCoreTestApp()
        
        setupUsers()
    }
    
    // MARK: Tests
    
    func testGetUsers() {
        let req = HTTPRequest.testable.get(uri: "/users", authorizedUser: user1, on: app)
        let r = app.testable.response(to: req)
        
        r.response.testable.debug()
        
        XCTAssertTrue(r.response.testable.has(statusCode: .ok), "Wrong status code")
        XCTAssertTrue(r.response.testable.has(contentType: "application/json; charset=utf-8"), "Missing content type")
        
        let users = r.response.testable.content(as: [CoreUser].self)!
        XCTAssertEqual(users.count, 2, "There should be two users in the database")
        XCTAssertTrue(users.contains(where: { (user) -> Bool in
            return user.id == user1.id && user.id != nil
        }), "Newly created user is not present in the database")
        XCTAssertTrue(users.contains(where: { (user) -> Bool in
            return user.id == user2.id && user.id != nil
        }), "Newly created user is not present in the database")
    }
    
    func testRegisterUser() {
        let post = User.Registration(username: "lemmy", firstname: "Lemmy", lastname: "Kilmister", email: "lemmy@liveui.io", password: "passw0rd")
        let req = try! HTTPRequest.testable.post(uri: "/users", data: post.asJson(), headers: [
            "Content-Type": "application/json; charset=utf-8"
            ]
        )
        let r = app.testable.response(to: req)
        
        r.response.testable.debug()
        
        // Check returned data
        let object = r.response.testable.content(as: User.Display.self)!
        XCTAssertEqual(object.firstname, post.firstname, "Firstname doesn't match")
        XCTAssertEqual(object.lastname, post.lastname, "Lastname doesn't match")
        XCTAssertEqual(object.email, post.email, "Email doesn't match")
        
        // Check it has been actually saved
        let user = app.testable.one(for: User.self, id: object.id!)!
        XCTAssertEqual(user.firstname, post.firstname, "Firstname doesn't match")
        XCTAssertEqual(user.lastname, post.lastname, "Lastname doesn't match")
        XCTAssertEqual(user.email, post.email, "Email doesn't match")
        XCTAssertTrue(post.password.verify(against: user.password!), "Password doesn't match")
        XCTAssertEqual(user.disabled, false, "Disabled should be false")
        XCTAssertEqual(user.su, false, "SU should be false")
        
        // Test email has been sent (on a mock email client ... obviously)
        let mailer = try! r.request.make(MailerService.self) as! MailerMock
        XCTAssertEqual(mailer.receivedMessage!.from, "admin@apicore", "Email has a wrong sender")
        XCTAssertEqual(mailer.receivedMessage!.to, "lemmy@liveui.io", "Email has a wrong recipient")
        XCTAssertEqual(mailer.receivedMessage!.subject, "Registration", "Email has a wrong subject")
        
        let token = String(mailer.receivedMessage!.text.split(separator: "|")[1])
        
        XCTAssertEqual(mailer.receivedMessage!.text, """
            Hi Lemmy Kilmister
            Please confirm your email lemmy@liveui.io by clicking on this link http://localhost:8080/users/verify?token=\(token)
            Verification code is: |\(token)|
            Boost team
            """, "Email has a wrong text")
        XCTAssertEqual(mailer.receivedMessage!.html, """
            <h1>Hi Lemmy Kilmister</h1>
            <p>Please confirm your email lemmy@liveui.io by clicking on this <a href=\"http://localhost:8080/users/verify?token=\(token)\">link</a></p>
            <p>Verification code is: <strong>\(token)</strong></p>
            <p>Boost team</p>
            """, "Email has a wrong html")
        
        XCTAssertTrue(r.response.testable.has(statusCode: .created), "Wrong status code")
        XCTAssertTrue(r.response.testable.has(contentType: "application/json; charset=utf-8"), "Missing content type")
    }
    
    func testSearchUsersWithoutParams() {
        let req = HTTPRequest.testable.get(uri: "/users/global", authorizedUser: user1, on: app)
        let r = app.testable.response(to: req)
        
        r.response.testable.debug()
        
        XCTAssertTrue(r.response.testable.has(statusCode: .ok), "Wrong status code")
        XCTAssertTrue(r.response.testable.has(contentType: "application/json; charset=utf-8"), "Missing content type")
        
        let users = r.response.testable.content(as: [CoreUser.AllSearch].self)!
        XCTAssertEqual(users.count, 2, "There should be two users in the database")
        XCTAssertEqual(users[0].id, user1.id, "Avatar is not in the correct format")
        XCTAssertEqual(users[0].avatar, "e7e8b7ac59a724a481bec410d0cb44a4", "Avatar hash (MD5 of an email) is not in the correct format")
    }
    
}
