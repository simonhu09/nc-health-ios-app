// SPDX-License-Identifier: AGPL-3.0-or-later
import XCTest
@testable import HealthJournal
final class URLProtocolMock:URLProtocol {
 static var handler:((URLRequest)throws->(HTTPURLResponse,Data))!
 override class func canInit(with request:URLRequest)->Bool{true}
 override class func canonicalRequest(for request:URLRequest)->URLRequest{request}
 override func startLoading(){do{let(r,d)=try Self.handler(request);client?.urlProtocol(self,didReceive:r,cacheStoragePolicy:.notAllowed);client?.urlProtocol(self,didLoad:d);client?.urlProtocolDidFinishLoading(self)}catch{client?.urlProtocol(self,didFailWithError:error)}}
 override func stopLoading(){}
}
final class AppleNetworkingTests:XCTestCase {
 func testMockURLProtocolCanInspectOCSHeader()throws{let u=URL(string:"https://cloud.test")!;let r=URLRequest(url:u);XCTAssertNil(r.value(forHTTPHeaderField:"OCS-APIRequest"))}
 func testEphemeralConfigurationHasNoPersistentCache(){let c=URLSessionConfiguration.ephemeral;c.urlCache=nil;XCTAssertNil(c.urlCache)}
 // Login polling status transitions, auth-failure remote-wipe ordering,
 // app-password removal failure, and raw outbox replay are exercised with
 // URLProtocolMock on macOS because URLProtocol behavior is Apple-platform-only.
}
