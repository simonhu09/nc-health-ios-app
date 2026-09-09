// SPDX-License-Identifier: AGPL-3.0-or-later
import SwiftUI
import HealthCore
struct RecordsView:View {
 @EnvironmentObject var store:AppStore
 @State private var mode=0
 @State private var addEntry=false
 @State private var addMeasurement=false
 @State private var addDaily=false
 @State private var editEntry:Entry?
 @State private var editMeasurement:Measurement?
 @State private var editDaily:DailyValue?
 @State private var pendingEntryDelete:Entry?
 @State private var pendingMeasurementDelete:Measurement?
 var body:some View {
  List {
   Picker("Record type",selection:$mode) { Text("Journal").tag(0);Text("Measurements").tag(1);Text("Daily values").tag(2) }.pickerStyle(.segmented)
   if mode==0 {
    ForEach(store.entries){entry in Button(action:{editEntry=entry}){EntryRow(entry:entry)}}
     .onDelete{offsets in pendingEntryDelete=offsets.first.map{store.entries[$0]}}
    if store.entries.isEmpty { ContentUnavailableView("No entries",systemImage:"list.bullet") }
   } else if mode==1 {
    ForEach(store.measurements){item in Button(action:{editMeasurement=item}){MeasurementRow(item:item)}}
     .onDelete{offsets in pendingMeasurementDelete=offsets.first.map{store.measurements[$0]}}
    if store.measurements.isEmpty { ContentUnavailableView("No measurements",systemImage:"waveform.path.ecg") }
   } else {
    ForEach(store.dailyValues){item in
     Button { editDaily=item } label: { HStack {Text(item.metricKey.replacingOccurrences(of:"_",with:" ").capitalized);Spacer();Text(item.numericValue,format:.number)} }
     .swipeActions{Button("Delete",role:.destructive){Task{await deleteDaily(item)}}}
    }
   }
  }
  .navigationTitle("Records")
  .toolbar { Button {if mode==1{addMeasurement=true}else if mode==2{addDaily=true}else{addEntry=true}} label:{Label("Add record",systemImage:"plus")} }
  .sheet(isPresented:$addEntry){NavigationStack{EntryFormView()}}
  .sheet(isPresented:$addMeasurement){NavigationStack{MeasurementFormView()}}
  .sheet(isPresented:$addDaily){NavigationStack{DailyValueFormView()}}
  .sheet(item:$editEntry){entry in NavigationStack{EntryFormView(existing:entry)}}
  .sheet(item:$editMeasurement){item in NavigationStack{MeasurementFormView(existing:item)}}
  .sheet(item:$editDaily){item in NavigationStack{DailyValueFormView(existing:item)}}
  .confirmationDialog("Delete this entry?",isPresented:Binding(get:{pendingEntryDelete != nil},set:{if !$0{pendingEntryDelete=nil}})){Button("Delete",role:.destructive){if let x=pendingEntryDelete{Task{do{_ = try await store.client?.deleteEntry(x.id);await store.refreshDay()}catch{store.error=error.localizedDescription}}}}}
  .confirmationDialog("Delete this measurement?",isPresented:Binding(get:{pendingMeasurementDelete != nil},set:{if !$0{pendingMeasurementDelete=nil}})){Button("Delete",role:.destructive){if let x=pendingMeasurementDelete{Task{do{_ = try await store.client?.deleteMeasurement(x.id);await store.refreshDay()}catch{store.error=error.localizedDescription}}}}}
  .task{await store.refreshDay()}
 }
 func deleteEntries(_ offsets:IndexSet)async {guard let c=store.client else{return};for i in offsets{do{_ = try await c.deleteEntry(store.entries[i].id)}catch{store.error=error.localizedDescription}};await store.refreshDay()}
 func deleteMeasurements(_ offsets:IndexSet)async {guard let c=store.client else{return};for i in offsets{do{_ = try await c.deleteMeasurement(store.measurements[i].id)}catch{store.error=error.localizedDescription}};await store.refreshDay()}
 func deleteDaily(_ item:DailyValue)async{do{_ = try await store.client?.deleteDailyValue(item.metricKey,date:item.localDate);await store.refreshDay()}catch{store.error=error.localizedDescription}}
}
struct EntryRow:View {let entry:Entry;var body:some View{VStack(alignment:.leading){Text(entry.metricKey.replacingOccurrences(of:"_",with:" ").capitalized).font(.headline);HStack{if let n=entry.numericValue{Text(n,format:.number)};if let o=entry.optionValue{Text(o)};Spacer();Text(entry.recordedAt).font(.caption).foregroundStyle(.secondary)};if let n=entry.note{Text(n).lineLimit(2)}}.accessibilityElement(children:.combine)}}
struct MeasurementRow:View {let item:Measurement;var body:some View{VStack(alignment:.leading){Text(item.metricKey.replacingOccurrences(of:"_",with:" ").capitalized).font(.headline);if let n=item.numericValue{Text(n,format:.number)};if let v=item.values{Text(v.map{"\($0.key): \($0.value)"}.joined(separator:", "))};Text(item.recordedAt).font(.caption).foregroundStyle(.secondary)}.accessibilityElement(children:.combine)}}
struct EntryFormView:View {
 @EnvironmentObject var store:AppStore
 @Environment(\.dismiss) var dismiss
 var existing:Entry?
 @State private var metric="mood"
 @State private var numeric=3.0
 @State private var option=""
 @State private var context="manual"
 @State private var note=""
 @State private var recordedAt=Date()
 init(existing:Entry?=nil){self.existing=existing;_metric=State(initialValue:existing?.metricKey ?? "mood");_numeric=State(initialValue:existing?.numericValue ?? 3);_option=State(initialValue:existing?.optionValue ?? "");_context=State(initialValue:existing?.context ?? "manual");_note=State(initialValue:existing?.note ?? "");_recordedAt=State(initialValue:existing.flatMap{ISO8601DateFormatter().date(from:$0.recordedAt)} ?? Date())}
 var definition:MetricDefinition{store.metrics.first{$0.key==metric} ?? MetricDefinition.fallback[0]}
 var body:some View {Form{Section("Record"){Picker("Metric",selection:$metric){ForEach(store.metrics.filter{$0.category == .journal}){Text($0.key.capitalized).tag($0.key)}};if definition.valueType == .event{Picker("Option",selection:$option){Text("Choose").tag("");ForEach(definition.options,id:\.self){Text($0).tag($0)}}}else{TextField("Value",value:$numeric,format:.number).keyboardType(.decimalPad)};Picker("Context",selection:$context){Text("Manual").tag("manual");Text("Check-in").tag("checkin");Text("Check-out").tag("checkout")};DatePicker("Recorded at",selection:$recordedAt);TextField("Note",text:$note,axis:.vertical)};Button(existing == nil ? "Add entry":"Save changes"){Task{await save()}}.buttonStyle(.borderedProminent)}.navigationTitle(existing == nil ? "New Entry":"Edit Entry").toolbar{Button("Cancel"){dismiss()}}}
 func save()async{guard let c=store.client else{return};do{if definition.valueType == .event{try InputValidator.validate(option:option,metric:definition)}else{try InputValidator.validate(value:numeric,metric:definition)};let b=EntryInput(metricKey:metric,numericValue:definition.valueType == .event ? nil:numeric,optionValue:option.isEmpty ? nil:option,context:context,recordedAt:ISO8601DateFormatter().string(from:recordedAt),note:note.isEmpty ? nil:note,operationId:existing == nil ? UUID():nil);if let x=existing{_ = try await c.updateEntry(x.id,b)}else{_ = try await c.createEntry(b)};await store.refreshDay();dismiss()}catch{store.error=error.localizedDescription}}
}
struct DailyValueFormView:View {
 @EnvironmentObject var store:AppStore
 @Environment(\.dismiss) var dismiss
 let existing:DailyValue?
 @State private var metric:String
 @State private var value:Double
 @State private var date:Date
 @State private var unit:String
 init(existing:DailyValue?=nil){self.existing=existing;_metric=State(initialValue:existing?.metricKey ?? "weight");_value=State(initialValue:existing?.numericValue ?? 0);_date=State(initialValue:existing.flatMap{ISO8601DateFormatter().date(from:"\($0.localDate)T00:00:00Z")} ?? Date());_unit=State(initialValue:existing.flatMap{v in MetricDefinition.fallback.first{$0.key==v.metricKey}?.canonicalUnit} ?? (existing == nil ? "kg":""))}
 var definition:MetricDefinition{store.metrics.first{$0.key==metric} ?? MetricDefinition.fallback.first{$0.category == .dailyValue}!}
 var body:some View {
  Form {
   Picker("Metric",selection:$metric){ForEach(store.metrics.filter{$0.category == .dailyValue}){Text($0.key.replacingOccurrences(of:"_",with:" ").capitalized).tag($0.key)}}
   DatePicker("Date",selection:$date,displayedComponents:.date)
   TextField("Value",value:$value,format:.number).keyboardType(.decimalPad)
   if !definition.supportedUnits.isEmpty{Picker("Unit",selection:$unit){ForEach(definition.supportedUnits,id:\.self){Text($0).tag($0)}}}
   Button("Save daily value"){Task{await save()}}.buttonStyle(.borderedProminent)
  }
  .navigationTitle(existing == nil ? "New Daily Value" : "Edit Daily Value")
  .toolbar{Button("Cancel"){dismiss()}}
  .onAppear{let desired=store.configuration?.metrics[metric]?.displayUnit ?? definition.canonicalUnit ?? "";if existing != nil,let canonical=definition.canonicalUnit,!desired.isEmpty,canonical != desired{value=(try? UnitConverter.convert(value,from:canonical,to:desired)) ?? value};unit=desired}
  .onChange(of:metric){_,_ in unit=store.configuration?.metrics[metric]?.displayUnit ?? definition.canonicalUnit ?? ""}
 }
 func save()async{guard let c=store.client else{return};do{try InputValidator.validate(value:value,metric:definition);_ = try await c.putDailyValue(metric,date:LocalDate.string(from:date),value:value,unit:unit.isEmpty ? nil:unit);store.date=date;await store.refreshDay();dismiss()}catch{store.error=error.localizedDescription}}
}
struct MeasurementFormView:View {
 @EnvironmentObject var store:AppStore
 @Environment(\.dismiss) var dismiss
 var existing:Measurement?
 @State private var metric="pulse"
 @State private var value=70.0
 @State private var systolic=120.0
 @State private var diastolic=80.0
 @State private var unit=""
 @State private var context="manual"
 @State private var note=""
 @State private var recordedAt=Date()
 init(existing:Measurement?=nil){self.existing=existing;_metric=State(initialValue:existing?.metricKey ?? "pulse");_value=State(initialValue:existing?.numericValue ?? 70);_systolic=State(initialValue:existing?.values?["systolic"] ?? 120);_diastolic=State(initialValue:existing?.values?["diastolic"] ?? 80);_context=State(initialValue:existing?.context ?? "manual");_note=State(initialValue:existing?.note ?? "");_recordedAt=State(initialValue:existing.flatMap{ISO8601DateFormatter().date(from:$0.recordedAt)} ?? Date())}
 var definition:MetricDefinition{store.metrics.first{$0.key==metric} ?? MetricDefinition.fallback.first{$0.key=="pulse"}!}
 var body:some View{Form{Section("Measurement"){Picker("Metric",selection:$metric){ForEach(store.metrics.filter{$0.category == .measurement}){Text($0.key.capitalized).tag($0.key)}};if metric=="blood_pressure"{TextField("Systolic",value:$systolic,format:.number).keyboardType(.decimalPad);TextField("Diastolic",value:$diastolic,format:.number).keyboardType(.decimalPad)}else{TextField("Value",value:$value,format:.number).keyboardType(.decimalPad)};if !definition.supportedUnits.isEmpty{Picker("Unit",selection:$unit){ForEach(definition.supportedUnits,id:\.self){Text($0).tag($0)}}};DatePicker("Recorded at",selection:$recordedAt);TextField("Note",text:$note,axis:.vertical)};Button(existing == nil ? "Add measurement":"Save changes"){Task{await save()}}.buttonStyle(.borderedProminent)}.navigationTitle(existing == nil ? "New Measurement":"Edit Measurement").toolbar{Button("Cancel"){dismiss()}}.onAppear{if unit.isEmpty{unit=store.configuration?.metrics[metric]?.displayUnit ?? definition.canonicalUnit ?? "";convertExistingToDisplayUnit()}}.onChange(of:metric){_,_ in unit=store.configuration?.metrics[metric]?.displayUnit ?? definition.canonicalUnit ?? ""}}
 func convertExistingToDisplayUnit(){guard existing != nil,let canonical=definition.canonicalUnit,!unit.isEmpty,canonical != unit else{return};if metric=="blood_pressure"{systolic=(try? UnitConverter.convert(systolic,from:canonical,to:unit)) ?? systolic;diastolic=(try? UnitConverter.convert(diastolic,from:canonical,to:unit)) ?? diastolic}else{value=(try? UnitConverter.convert(value,from:canonical,to:unit)) ?? value}}
 func save()async{guard let c=store.client else{return};do{if metric=="blood_pressure"{guard systolic.isFinite,diastolic.isFinite else{throw HealthCoreError.invalidValue("Values must be finite")}}else{try InputValidator.validate(value:value,metric:definition)};let b=MeasurementInput(metricKey:metric,numericValue:metric=="blood_pressure" ? nil:value,values:metric=="blood_pressure" ? ["systolic":systolic,"diastolic":diastolic]:nil,unit:unit.isEmpty ? nil:unit,context:context,recordedAt:ISO8601DateFormatter().string(from:recordedAt),note:note.isEmpty ? nil:note,operationId:existing == nil ? UUID():nil);if let x=existing{_ = try await c.updateMeasurement(x.id,b)}else{_ = try await c.createMeasurement(b)};await store.refreshDay();dismiss()}catch{store.error=error.localizedDescription}}
}
