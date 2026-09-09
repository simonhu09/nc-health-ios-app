// SPDX-License-Identifier: AGPL-3.0-or-later
import SwiftUI
import HealthCore
import Network
@MainActor final class AppStore:ObservableObject {
 @Published var account:StoredAccount?
 @Published var client:HealthAPIClient?
 @Published var metrics=MetricDefinition.fallback
 @Published var date=Date()
 @Published var note=""
 @Published var entries:[Entry]=[]
 @Published var measurements:[Measurement]=[]
 @Published var dailyValues:[DailyValue]=[]
 @Published var goals:[Goal]=[]
 @Published var goalTargets:[GoalTarget]=[]
 @Published var progress:[GoalProgress]=[]
 @Published var statistics:StatisticsResponse?
 @Published var savedViews:[SavedStatisticsView]=[]
 @Published var configuration:Configuration?
 @Published var busy=false
 @Published var error:String?
 let keychain=KeychainStore()
 lazy var outbox=EncryptedOutbox(keychain:keychain)
 private let networkMonitor=NWPathMonitor()
 private let networkQueue=DispatchQueue(label:"com.check27.healthjournal.connectivity")
 private var flushing=false
 init(){
  if let a=try? keychain.load(StoredAccount.self,key:"account"){account=a;client=try? HealthAPIClient(account:a);Task{await refreshConnectionMetadata()}}
  networkMonitor.pathUpdateHandler={ [weak self] path in
   guard path.status == .satisfied else{return}
   Task {@MainActor [weak self] in await self?.flushOutbox()}
  }
  networkMonitor.start(queue:networkQueue)
 }
 deinit{networkMonitor.cancel()}
 func connect(_ a:StoredAccount)async throws{_ = try ServerConfiguration(server:a.server);let candidate=try HealthAPIClient(account:a);let caps=try await candidate.capabilities();guard caps.apiVersions.contains("2") else{throw HealthCoreError.invalidValue("Nextcloud Health API v2 is required")};metrics=(caps.metrics?.isEmpty == false ? caps.metrics!:MetricDefinition.fallback);try keychain.save(a,key:"account");account=a;client=candidate;await loadConfiguration()}
 func refreshConnectionMetadata()async{guard let client else{return};do{let caps=try await client.capabilities();guard caps.apiVersions.contains("2")else{throw HealthCoreError.invalidValue("Nextcloud Health API v2 is required")};metrics=(caps.metrics?.isEmpty == false ? caps.metrics!:MetricDefinition.fallback);await loadConfiguration()}catch{self.error=error.localizedDescription}}
 func purgeLocal()throws{try outbox.erase();try keychain.delete(key:"account");account=nil;client=nil;metrics=MetricDefinition.fallback;note="";entries=[];measurements=[];dailyValues=[];goals=[];goalTargets=[];progress=[];statistics=nil;savedViews=[];configuration=nil}
 func handleRemoteWipe()async{guard let retained=client else{return};do{try purgeLocal();await retained.signalWipeSuccess();error="This account was remotely wiped by the Nextcloud administrator."}catch{self.error="Remote wipe could not securely erase local data: \(error.localizedDescription)"}}
 func removeAccount()async{var warning:String?;if let client{do{try await client.removeAppPassword()}catch{warning="The server app password could not be revoked. Revoke it in Nextcloud security settings."}};do{try purgeLocal()}catch{warning="Local data could not be fully erased: \(error.localizedDescription)"};error=warning}
 func refreshDay()async{guard let c=client else{return};busy=true;defer{busy=false};do{let d=LocalDate.string(from:date);let range=LocalDayRange(date:date).rfc3339;async let n=c.dailyNote(d);async let v=c.dailyValues(d);async let e=c.allEntries(.init(from:range.0,to:range.1,limit:200));async let m=c.measurements(from:range.0,to:range.1);let(nn,vv,ee,mm)=try await(n,v,e,m);note=nn.content ?? "";dailyValues=vv;entries=ee;measurements=mm}catch{self.error=error.localizedDescription}}
 func refreshGoals(period:GoalPeriod = .week)async{guard let c=client else{return};do{let page=try await c.goals();goals=page.goals;goalTargets=page.targets;progress=try await c.goalProgress(period:period,date:LocalDate.string(from:date))}catch{self.error=error.localizedDescription}}
 func refreshStatistics(period:StatisticsPeriod = .last30Days)async{guard let c=client else{return};do{statistics=try await c.statistics(period,metrics:metrics.map(\.key));savedViews=try await c.views()}catch{self.error=error.localizedDescription}}
 func loadConfiguration()async{guard let c=client else{return};do{configuration=try await c.configuration()}catch{self.error=error.localizedDescription}}
 func flushOutbox()async{guard let c=client,!flushing else{return};flushing=true;defer{flushing=false};for operation in outbox.operations{do{try outbox.mark(operation.id,state:.syncing);let endpoint:APIEndpoint;if operation.endpoint=="entries"{endpoint = .entries(.init())}else if operation.endpoint=="measurements"{endpoint = .measurements(from:nil,to:nil)}else{let p=operation.endpoint.split(separator:"/");guard p.count==3 else{throw HealthCoreError.invalidResponse};endpoint = .dailyValue(metric:String(p[1]),date:String(p[2]))};_ = try await c.sendValidatedRaw(endpoint,method:operation.method,body:operation.body);try outbox.remove(operation.id)}catch{try? outbox.mark(operation.id,state:.failed,error:error.localizedDescription)}}}
}
