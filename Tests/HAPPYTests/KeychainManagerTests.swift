import XCTest
@testable import HAPPY

final class KeychainManagerTests: XCTestCase {
    private var testServiceName: String!
    private var keychain: KeychainManager!

    override func setUp() {
        super.setUp()
        testServiceName = "com.happy.test.keychain.\(UUID().uuidString)"
        keychain = KeychainManager(serviceName: testServiceName)
    }

    override func tearDown() {
        keychain.deleteAll()
        keychain = nil
        testServiceName = nil
        super.tearDown()
    }

    func testSaveAndRetrieveItem() {
        let key = "gemini_api_key"
        let secret = "AIzaSyTestSecretKey_12345"

        let saveSuccess = keychain.save(key: key, value: secret)
        XCTAssertTrue(saveSuccess, "Saving to Keychain should succeed")

        let retrieved = keychain.get(key: key)
        XCTAssertEqual(retrieved, secret, "Retrieved secret should match saved value")
    }

    func testUpdateExistingItem() {
        let key = "test_update_key"
        keychain.save(key: key, value: "initial_value")
        XCTAssertEqual(keychain.get(key: key), "initial_value")

        // Overwrite
        let updateSuccess = keychain.save(key: key, value: "updated_value")
        XCTAssertTrue(updateSuccess, "Updating existing item in Keychain should succeed")
        XCTAssertEqual(keychain.get(key: key), "updated_value")
    }

    func testGetNonExistentItemReturnsNil() {
        let missing = keychain.get(key: "non_existent_key_\(UUID().uuidString)")
        XCTAssertNil(missing, "Querying non-existent key should return nil")
    }

    func testDeleteItem() {
        let key = "delete_me"
        keychain.save(key: key, value: "temp")
        XCTAssertNotNil(keychain.get(key: key))

        let deleteSuccess = keychain.delete(key: key)
        XCTAssertTrue(deleteSuccess, "Deleting key should succeed")
        XCTAssertNil(keychain.get(key: key), "Key should no longer exist after deletion")
    }

    func testDeleteAllAndCleanUp() {
        let key1 = "key_one"
        let key2 = "key_two"
        keychain.save(key: key1, value: "value1")
        keychain.save(key: key2, value: "value2")

        XCTAssertEqual(keychain.get(key: key1), "value1")
        XCTAssertEqual(keychain.get(key: key2), "value2")

        let deleteAllSuccess = keychain.deleteAll()
        XCTAssertTrue(deleteAllSuccess)

        XCTAssertNil(keychain.get(key: key1))
        XCTAssertNil(keychain.get(key: key2))
    }
}
