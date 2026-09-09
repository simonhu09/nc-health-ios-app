// SPDX-License-Identifier: AGPL-3.0-or-later
import XCTest
@testable import HealthCore
final class HealthCoreTests: XCTestCase {
 func testAPIEndpointBasePath() throws { XCTAssertEqual(try APIEndpoint.configuration.url(on: .init(server: "https://cloud.test")).path, "/ocs/v2.php/apps/health/api/v2/configuration") }
 func testAPIEndpointEncodesDate() throws { XCTAssertTrue(try APIEndpoint.dailyNote("2026-09-09").url(on: .init(server: "https://cloud.test")).absoluteString.hasSuffix("daily-notes/2026-09-09")) }
 func testAPIEndpointQuery() throws { XCTAssertTrue(try APIEndpoint.dailyValues("2026-09-09").url(on: .init(server: "https://cloud.test")).query!.contains("date=2026-09-09")) }
 func testAPIEndpointMetricsQuery() throws { XCTAssertTrue(try APIEndpoint.statistics(period: .thisMonth, metrics: ["mood","stress"]).url(on: .init(server: "https://cloud.test")).query!.contains("metrics=mood,stress")) }
 func testCapabilitiesUsesOCSRoot() throws { XCTAssertEqual(try APIEndpoint.capabilities.url(on: .init(server: "https://cloud.test/nextcloud")).path, "/nextcloud/ocs/v2.php/cloud/capabilities") }
 func testOCSDecodesData() throws { let d=Data(#"{"ocs":{"meta":{"status":"ok","statuscode":100},"data":{"date":"2026-01-01","content":"x","createdAt":null,"updatedAt":null}}}"#.utf8); XCTAssertEqual(try JSONDecoder.health.decode(OCSResponse<DailyNote>.self, from:d).ocs.data.content,"x") }
 func testOCSFailureDetected() throws { let meta=OCSMeta(status:"failure",statuscode:404,message:"No"); XCTAssertThrowsError(try meta.validate()) }
 func testUnitConverterKgToPounds() throws { XCTAssertEqual(try UnitConverter.convert(1, from:"kg", to:"lb"),2.2046226218,accuracy:0.0001) }
 func testUnitConverterCelsius() throws { XCTAssertEqual(try UnitConverter.convert(0, from:"celsius",to:"fahrenheit"),32) }
 func testUnitConverterGlucose() throws { XCTAssertEqual(try UnitConverter.convert(1,from:"mmol_l",to:"mg_dl"),18.0182,accuracy:0.001) }
 func testUnitConverterPressure() throws { XCTAssertEqual(try UnitConverter.convert(1,from:"kpa",to:"mmhg"),7.50062,accuracy:0.001) }
 func testValidationRejectsHTTP() { XCTAssertThrowsError(try ServerConfiguration(server:"http://cloud.test")) }
 func testValidationAcceptsHTTPS() { XCTAssertNoThrow(try ServerConfiguration(server:"https://cloud.test/nextcloud/")) }
 func testValidationRejectsBlankLogin() { XCTAssertThrowsError(try Credentials(login:" ", appPassword:"x")) }
 func testFallbackHasTwentyMetrics() { XCTAssertEqual(MetricDefinition.fallback.count,20) }
 func testEntryValidationScale() { XCTAssertThrowsError(try InputValidator.validate(value:6, metric:.init(key:"mood",category:.journal,valueType:.scale,minimum:1,maximum:5))) }
 func testRejectsUserInfo() { XCTAssertThrowsError(try ServerConfiguration(server:"https://user:pass@cloud.test")) }
 func testRejectsQuery() { XCTAssertThrowsError(try ServerConfiguration(server:"https://cloud.test?q=x")) }
 func testRejectsFragment() { XCTAssertThrowsError(try ServerConfiguration(server:"https://cloud.test/#x")) }
 func testAcceptsCustomHTTPSPort() { XCTAssertNoThrow(try ServerConfiguration(server:"https://cloud.test:8443")) }
 func testEntryFilters() throws { let u=try APIEndpoint.entries(.init(metricKey:"mood",from:"2026-01-01T00:00:00Z",to:"2026-01-02T00:00:00Z",cursor:nil,limit:20)).url(on:.init(server:"https://cloud.test")); XCTAssertTrue(u.absoluteString.contains("metricKey=mood")) }
 func testMeasurementFilters() throws { let u=try APIEndpoint.measurements(from:"2026-01-01",to:"2026-01-02").url(on:.init(server:"https://cloud.test")); XCTAssertNotNil(u.query) }
 func testGoalProgressFilters() throws { let u=try APIEndpoint.goalProgress(period:.week,date:"2026-01-02").url(on:.init(server:"https://cloud.test")); XCTAssertTrue(u.absoluteString.contains("period=week")) }
 func testStatisticsPeriodsAreExact() { XCTAssertTrue(StatisticsPeriod.allCases.contains(.last30Days)); XCTAssertFalse(StatisticsPeriod.allCases.map(\.rawValue).contains("month")) }
 func testOutboxSerializationPreservesOperationId() throws { let x=OutboxOperation(endpoint:"entries",method:.post,body:Data("{}".utf8));let y=try JSONDecoder().decode(OutboxOperation.self,from:JSONEncoder().encode(x));XCTAssertEqual(x.operationId,y.operationId) }
 func testOutboxUUIDIsVersionFour() { let x=OutboxOperation(endpoint:"entries",method:.post,body:Data());XCTAssertEqual((x.operationId.uuid.6 >> 4),4) }
 func testCapabilitiesVersionsAreStrings() throws {let d=Data(#"{"apiVersions":["2"],"features":[],"metrics":null,"goalTargets":null}"#.utf8);XCTAssertEqual(try JSONDecoder().decode(HealthCapabilities.self,from:d).apiVersions,["2"])}
 func testLocalDateIsFixed() { var calendar=Calendar(identifier:.gregorian);calendar.timeZone=TimeZone(secondsFromGMT:0)!;let date=calendar.date(from:DateComponents(year:2026,month:9,day:9))!;XCTAssertEqual(LocalDate.string(from:date,timeZone:calendar.timeZone),"2026-09-09") }
 func testLocalDayRangeIsHalfOpen() throws { let calendar=Calendar(identifier:.gregorian);let range=LocalDayRange(date:Date(timeIntervalSince1970:0),calendar:calendar);XCTAssertEqual(range.end.timeIntervalSince(range.start),86400) }
 func testFormEncodingEscapesToken() { XCTAssertEqual(FormEncoding.field("token",value:"a+b &c"),"token=a%2Bb%20%26c") }
 func testMetricDefinitionCapabilityKeys() throws { let d=Data(#"{"metricKey":"mood","category":"journal","valueType":"scale","minimum":1,"maximum":5,"allowedOptions":null,"aggregation":"average","canonicalUnit":null,"supportedUnits":[]}"#.utf8);let x=try JSONDecoder().decode(MetricDefinition.self,from:d);XCTAssertEqual(x.key,"mood");XCTAssertEqual(x.aggregation,"average") }
 func testMissingDailyNoteContentIsNull() throws { let x=try JSONDecoder().decode(DailyNote.self,from:Data(#"{"date":"2026-01-01","content":null,"createdAt":null,"updatedAt":null}"#.utf8));XCTAssertNil(x.content) }
 func testNullableStatisticsSubseries() throws { let x=try JSONDecoder().decode(StatisticsPoint.self,from:Data(#"{"date":"2026-01-01","value":null,"subseries":{"systolic":null}}"#.utf8));XCTAssertNil(x.subseries?["systolic"]!) }
 func testTypedConfiguration() throws { let d=Data(#"{"profile":{"heightCm":180,"heightDisplayUnit":"cm","dateOfBirth":"1990-01-01","growthReferenceSex":"male"},"metrics":{"weight":{"enabled":true,"checkInEnabled":false,"checkOutEnabled":true,"displayUnit":"kg"}},"searchDailyNotes":true}"#.utf8);let x=try JSONDecoder().decode(Configuration.self,from:d);XCTAssertEqual(x.profile.heightCm,180);XCTAssertEqual(x.metrics["weight"]?.displayUnit,"kg") }
 func testURLRequestMethodAndHeader() throws { let r=try RequestBlueprint(endpoint:.entries(.init(cursor:nil,limit:50)),method:.get).request(server:.init(server:"https://cloud.test"),authorization:"Basic abc"); XCTAssertEqual(r.httpMethod,"GET"); XCTAssertEqual(r.value(forHTTPHeaderField:"OCS-APIRequest"),"true") }
 func testScaleAndCounterRequireWholeNumbers() { XCTAssertThrowsError(try InputValidator.validate(value:2.5,metric:.init(key:"mood",category:.journal,valueType:.scale,minimum:1,maximum:5)));XCTAssertThrowsError(try InputValidator.validate(value:1.2,metric:.init(key:"fruit",category:.dailyValue,valueType:.counter,minimum:0))) }
 func testEventRequiresAllowedOption() { let metric=MetricDefinition(key:"hydration",category:.journal,valueType:.event,options:["tea"]);XCTAssertNoThrow(try InputValidator.validate(option:"tea",metric:metric));XCTAssertThrowsError(try InputValidator.validate(option:"soda",metric:metric)) }
 func testOCSMetadataFailureIsRejected() throws { let data=Data("{\"ocs\":{\"meta\":{\"status\":\"failure\",\"statuscode\":997,\"message\":\"no\"},\"data\":{}}}".utf8);let envelope=try JSONDecoder.health.decode(OCSMetadataResponse.self,from:data);XCTAssertThrowsError(try envelope.ocs.meta.validate()) }
}
