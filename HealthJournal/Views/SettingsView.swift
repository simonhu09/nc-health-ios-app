// SPDX-License-Identifier: AGPL-3.0-or-later
import SwiftUI
import HealthCore
struct SettingsView:View {
 @EnvironmentObject var store:AppStore
 @State private var showingCheckIn=false
 @State private var showingCheckOut=false
 @State private var confirmRemoval=false
 var body:some View {
  List {
   Section("Routines") {
    Button {showingCheckIn=true} label:{Label("Check-in",systemImage:"sunrise")}
     .accessibilityLabel("Start check-in routine")
    Button {showingCheckOut=true} label:{Label("Check-out",systemImage:"sunset")}
     .accessibilityLabel("Start check-out routine")
    Text("Routine fields follow the metric switches in your Nextcloud Health configuration and are submitted atomically.")
     .font(.footnote)
     .foregroundStyle(.secondary)
   }
   if let configuration=store.configuration {
    ProfileSettingsSection(configuration:configuration)
    Section("Metrics") {
     ForEach(store.metrics) { metric in
      NavigationLink {
       MetricSettingsView(metric:metric)
      } label: {
       HStack {
        VStack(alignment:.leading) {
         Text(metric.key.replacingOccurrences(of:"_",with:" ").capitalized)
         Text(metric.category.rawValue.replacingOccurrences(of:"_",with:" ").capitalized)
          .font(.caption)
          .foregroundStyle(.secondary)
        }
        Spacer()
        if configuration.metrics[metric.key]?.enabled == true {
         Image(systemName:"checkmark.circle.fill").foregroundStyle(.green)
        }
       }
      }
     }
    }
    Section("Search") {
     Toggle("Include daily notes in search",isOn:Binding(get:{store.configuration?.searchDailyNotes ?? false},set:{store.configuration?.searchDailyNotes=$0}))
     Button("Save configuration") {Task{await saveConfiguration()}}
    }
   } else {
    Section { ProgressView("Loading configuration…") }
   }
   Section("Privacy") {
    Label("Fetched records are not persisted",systemImage:"memorychip")
    Label("Offline queue: AES-GCM encrypted",systemImage:"lock.shield")
    LabeledContent("Queued operations",value:store.outbox.operations.count.formatted())
    if let queueError=store.outbox.loadError {Text(queueError).foregroundStyle(.red);Button("Reset unreadable queue",role:.destructive){do{try store.outbox.erase()}catch{store.error=error.localizedDescription}}}
    if !store.outbox.operations.isEmpty {
     Button("Retry queue") {Task{await store.flushOutbox()}}
     Button("Erase offline queue",role:.destructive) {do{try store.outbox.erase()}catch{store.error=error.localizedDescription}}
    }
   }
   Section("Account") {
    if let account=store.account {
     LabeledContent("Server",value:account.server)
     LabeledContent("Login",value:account.login)
    }
    Button("Remove account",role:.destructive) {confirmRemoval=true}
   }
   Section("About") {
    Text("Health Journal is an independent AGPL-3.0-or-later client for Nextcloud Health API v2.")
    Link("Source and licenses",destination:URL(string:"https://github.com/nextcloud/health")!)
   }
  }
  .navigationTitle("Settings")
  .task {await store.loadConfiguration()}
  .sheet(isPresented:$showingCheckIn){NavigationStack{RoutineFormView(context:"check-in")}}
  .sheet(isPresented:$showingCheckOut){NavigationStack{RoutineFormView(context:"check-out")}}
  .confirmationDialog("Remove this account?",isPresented:$confirmRemoval,titleVisibility:.visible) {
   Button("Revoke app password and remove",role:.destructive){Task{await store.removeAccount()}}
   Button("Cancel",role:.cancel){}
  } message:{Text("Local credentials and the encrypted offline queue will be erased even if server revocation fails.")}
 }
 func saveConfiguration()async {
  guard let c=store.client,let config=store.configuration else{return}
  let p=config.profile
  let height=p.heightDisplayUnit=="in" ? (try? UnitConverter.convert(p.heightCm ?? 0,from:"cm",to:"in")):p.heightCm
  let update=ConfigurationUpdate(profile:.init(height:height,heightUnit:p.heightDisplayUnit,dateOfBirth:p.dateOfBirth,growthReferenceSex:p.growthReferenceSex),metrics:config.metrics,searchDailyNotes:config.searchDailyNotes)
  do {store.configuration=try await c.updateConfiguration(update)}
  catch {store.error=error.localizedDescription}
 }
}
struct ProfileSettingsSection:View {
 @EnvironmentObject var store:AppStore
 let configuration:Configuration
 var displayHeight:Binding<Double?> {Binding(get:{guard let cm=store.configuration?.profile.heightCm else{return nil};return store.configuration?.profile.heightDisplayUnit=="in" ? try? UnitConverter.convert(cm,from:"cm",to:"in"):cm},set:{guard let shown=$0 else{store.configuration?.profile.heightCm=nil;return};store.configuration?.profile.heightCm=store.configuration?.profile.heightDisplayUnit=="in" ? (try? UnitConverter.convert(shown,from:"in",to:"cm")):shown})}
 var body:some View {
  Section("Profile") {
   TextField("Height",value:displayHeight,format:.number)
    .keyboardType(.decimalPad)
   Picker("Height display unit",selection:Binding(get:{store.configuration?.profile.heightDisplayUnit ?? "cm"},set:{store.configuration?.profile.heightDisplayUnit=$0})) {
    Text("Centimetres").tag("cm")
    Text("Inches").tag("in")
   }
   TextField("Date of birth",text:Binding(get:{store.configuration?.profile.dateOfBirth ?? ""},set:{store.configuration?.profile.dateOfBirth=$0.isEmpty ? nil:$0}))
    .accessibilityLabel("Date of birth in year month day format")
   Picker("Growth reference sex",selection:Binding(get:{store.configuration?.profile.growthReferenceSex ?? ""},set:{store.configuration?.profile.growthReferenceSex=$0.isEmpty ? nil:$0})) {
    Text("Not set").tag("")
    Text("Female").tag("female")
    Text("Male").tag("male")
   }
  }
 }
}
struct MetricSettingsView:View {
 @EnvironmentObject var store:AppStore
 let metric:MetricDefinition
 var config:MetricConfiguration {store.configuration?.metrics[metric.key] ?? .init(enabled:true,checkInEnabled:false,checkOutEnabled:false,displayUnit:metric.canonicalUnit)}
 var body:some View {
  Form {
   Toggle("Enabled",isOn:binding(\.enabled))
   Toggle("Show in check-in",isOn:binding(\.checkInEnabled))
   Toggle("Show in check-out",isOn:binding(\.checkOutEnabled))
   if !metric.supportedUnits.isEmpty {
    Picker("Display unit",selection:Binding(get:{config.displayUnit ?? metric.canonicalUnit ?? ""},set:{var x=config;x.displayUnit=$0;store.configuration?.metrics[metric.key]=x})) {
     ForEach(metric.supportedUnits,id:\.self){Text($0).tag($0)}
    }
   }
   Section("Definition") {
    LabeledContent("Category",value:metric.category.rawValue)
    LabeledContent("Value type",value:metric.valueType.rawValue)
    if let aggregation=metric.aggregation {LabeledContent("Aggregation",value:aggregation)}
   }
  }
  .navigationTitle(metric.key.replacingOccurrences(of:"_",with:" ").capitalized)
 }
 func binding(_ path:WritableKeyPath<MetricConfiguration,Bool>)->Binding<Bool>{Binding(get:{config[keyPath:path]},set:{var x=config;x[keyPath:path]=$0;store.configuration?.metrics[metric.key]=x})}
}
struct RoutineFormView:View {
 @EnvironmentObject var store:AppStore
 @Environment(\.dismiss) var dismiss
 let context:String
 @State private var values:[String:Double]=[:]
 @State private var options:[String:String]=[:]
 @State private var included=Set<String>()
 @State private var recordedAt=Date()
 var enabled:[MetricDefinition] {
  store.metrics.filter { metric in
   guard let c=store.configuration?.metrics[metric.key],c.enabled else{return false}
   return context=="check-in" ? c.checkInEnabled:c.checkOutEnabled
  }
 }
 var body:some View {
  Form {
   Section {
    DatePicker("Recorded at",selection:$recordedAt)
   }
   ForEach(enabled) { metric in
    Section(metric.key.replacingOccurrences(of:"_",with:" ").capitalized) {
     Toggle("Include",isOn:Binding(get:{included.contains(metric.key)},set:{if $0{included.insert(metric.key)}else{included.remove(metric.key)}}))
     if metric.valueType == .event {
      Picker("Option",selection:Binding(get:{options[metric.key] ?? ""},set:{options[metric.key]=$0})) {
       Text("Choose").tag("")
       ForEach(metric.options,id:\.self){Text($0.replacingOccurrences(of:"_",with:" ")).tag($0)}
      }
     } else if metric.valueType == .composite {
      TextField("Systolic",value:valueBinding("\(metric.key).systolic",default:120),format:.number).keyboardType(.decimalPad)
      TextField("Diastolic",value:valueBinding("\(metric.key).diastolic",default:80),format:.number).keyboardType(.decimalPad)
     } else {
      TextField("Value",value:valueBinding(metric.key,default:0),format:.number).keyboardType(.decimalPad)
     }
    }
   }
   if enabled.isEmpty {ContentUnavailableView("No routine metrics",systemImage:"slider.horizontal.3",description:Text("Enable check-in or check-out metrics in Settings."))}
   Button("Submit \(context)"){Task{await submit()}}.buttonStyle(.borderedProminent).disabled(included.isEmpty)
  }
  .navigationTitle(context=="check-in" ? "Check-in":"Check-out")
  .toolbar{Button("Cancel"){dismiss()}}
 }
 func valueBinding(_ key:String,default initial:Double)->Binding<Double>{Binding(get:{values[key] ?? initial},set:{values[key]=$0})}
 func submit()async {
  guard let c=store.client else{return}
  let iso=ISO8601DateFormatter().string(from:recordedAt)
  var journal:[EntryInput]=[];var measurements:[MeasurementInput]=[];var daily:[RoutineDailyValueInput]=[]
  for m in enabled where included.contains(m.key) {
   if m.category == .journal {journal.append(.init(metricKey:m.key,numericValue:m.valueType == .event ? nil:(values[m.key] ?? 0),optionValue:options[m.key],context:context=="check-in" ? "checkin":"checkout",recordedAt:iso,note:nil,operationId:UUID()))}
   else if m.category == .measurement {measurements.append(.init(metricKey:m.key,numericValue:m.valueType == .composite ? nil:(values[m.key] ?? 0),values:m.valueType == .composite ? ["systolic":values["\(m.key).systolic"] ?? 120,"diastolic":values["\(m.key).diastolic"] ?? 80]:nil,unit:store.configuration?.metrics[m.key]?.displayUnit ?? m.canonicalUnit,context:context=="check-in" ? "checkin":"checkout",recordedAt:iso,note:nil,operationId:UUID()))}
   else {daily.append(.init(metricKey:m.key,numericValue:values[m.key] ?? 0,unit:store.configuration?.metrics[m.key]?.displayUnit ?? m.canonicalUnit))}
  }
   let routineDate=LocalDate.string(from:recordedAt)
  let input=RoutineInput(date:routineDate,recordedAt:iso,journalMetrics:journal,measurements:measurements,dailyValues:daily)
  do {_ = try await c.routine(context,input);await store.refreshDay();dismiss()}catch{store.error=error.localizedDescription}
 }
}
