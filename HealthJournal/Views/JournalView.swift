// SPDX-License-Identifier: AGPL-3.0-or-later
import SwiftUI
import HealthCore
struct JournalView:View {
 @EnvironmentObject var store:AppStore
 @State private var showingQuick=false
 @State private var savingNote=false
 @State private var noteSaveTask:Task<Void,Never>?
 var body:some View {
  List {
   Section {
    DatePicker("Journal date",selection:$store.date,displayedComponents:.date)
     .datePickerStyle(.compact)
     .accessibilityLabel("Selected journal date")
   }
   Section("Daily note") {
    TextEditor(text:$store.note)
     .frame(minHeight:120)
     .accessibilityLabel("Daily journal note")
     .onChange(of:store.note){_,_ in scheduleNoteAutosave()}
    Button(savingNote ? "Saving…" : "Save note") { Task { await saveNote() } }
     .disabled(savingNote)
   }
   Section("Daily values") {
    if store.dailyValues.isEmpty { ContentUnavailableView("No daily values",systemImage:"calendar.badge.minus") }
    ForEach(store.dailyValues) { value in
     HStack {
      Label(value.metricKey.replacingOccurrences(of:"_",with:" ").capitalized,systemImage:"gauge")
      Spacer()
      Text(value.numericValue,format:.number.precision(.fractionLength(0...2)))
      if let bmi=value.bmi { Text("BMI \(bmi,format:.number.precision(.fractionLength(1)))").foregroundStyle(.secondary) }
     }
     .accessibilityElement(children:.combine)
    }
   }
   Section("Journal entries") {
    if store.entries.isEmpty { Text("No journal events for this date").foregroundStyle(.secondary) }
    ForEach(store.entries) { entry in
     VStack(alignment:.leading,spacing:4) {
      Text(entry.metricKey.replacingOccurrences(of:"_",with:" ").capitalized).font(.headline)
      if let v=entry.numericValue { Text(v,format:.number) }
      if let option=entry.optionValue { Text(option.replacingOccurrences(of:"_",with:" ")) }
      if let note=entry.note,!note.isEmpty { Text(note).font(.subheadline).foregroundStyle(.secondary) }
     }
    }
   }
   Section("Measurements") {
    if store.measurements.isEmpty { Text("No measurements for this date").foregroundStyle(.secondary) }
    ForEach(store.measurements) { measurement in
     VStack(alignment:.leading) {
      Text(measurement.metricKey.replacingOccurrences(of:"_",with:" ").capitalized).font(.headline)
      if let value=measurement.numericValue { Text(value,format:.number.precision(.fractionLength(0...2))) }
      if let values=measurement.values {
       ForEach(values.sorted(by:{$0.key<$1.key}),id:\.key) { key,value in
        LabeledContent(key.capitalized,value:value.formatted())
       }
      }
     }
    }
   }
  }
  .overlay { if store.busy { ProgressView().controlSize(.large) } }
  .navigationTitle("Journal")
  .toolbar {
   ToolbarItem(placement:.topBarLeading) {
    Button { store.date=Calendar.current.date(byAdding:.day,value:-1,to:store.date)!;Task{await store.refreshDay()} } label:{Image(systemName:"chevron.left")}
     .accessibilityLabel("Previous day")
   }
   ToolbarItemGroup(placement:.topBarTrailing) {
    Button { Task{await store.refreshDay()} } label:{Image(systemName:"arrow.clockwise")}
     .accessibilityLabel("Refresh journal")
    Button { store.date=Date() } label:{Image(systemName:"calendar")}
     .accessibilityLabel("Today")
    Button { store.date=Calendar.current.date(byAdding:.day,value:1,to:store.date)!;Task{await store.refreshDay()} } label:{Image(systemName:"chevron.right")}
     .accessibilityLabel("Next day")
    Button { showingQuick=true } label:{Image(systemName:"bolt.fill")}
     .accessibilityLabel("Quick Entry")
   }
  }
  .sheet(isPresented:$showingQuick){NavigationStack{QuickEntryView()}}
  .task(id:store.date){await store.refreshDay()}
  .refreshable{await store.refreshDay()}
  .onDisappear{noteSaveTask?.cancel()}
 }
 private func scheduleNoteAutosave(){
  noteSaveTask?.cancel()
  let date=LocalDate.string(from:store.date)
  let content=store.note
  noteSaveTask=Task{
   try? await Task.sleep(for:.milliseconds(750))
   guard !Task.isCancelled,let client=store.client else{return}
   do{_=try await client.updateDailyNote(date,content:content)}catch{store.error=error.localizedDescription}
  }
 }
 private func saveNote()async {
  guard let c=store.client else{return}
  savingNote=true
  defer{savingNote=false}
  do { _=try await c.updateDailyNote(LocalDate.string(from:store.date),content:store.note) }
  catch { store.error=error.localizedDescription }
 }
}
struct QuickEntryView:View {
 @EnvironmentObject var store:AppStore
 @Environment(\.dismiss) var dismiss
 @State private var metric="mood"
 @State private var value=3.0
 @State private var systolic=120.0
 @State private var diastolic=80.0
 @State private var option=""
 @State private var offline=false
 var quickMetrics:[MetricDefinition]{store.metrics.filter{store.configuration?.metrics[$0.key]?.enabled ?? true}}
 var definition:MetricDefinition { quickMetrics.first{$0.key==metric} ?? MetricDefinition.fallback[0] }
 var body:some View {
  Form {
   Section("Quick Entry") {
    Picker("Metric",selection:$metric) { ForEach(quickMetrics){Text($0.key.replacingOccurrences(of:"_",with:" ").capitalized).tag($0.key)} }
    if definition.valueType == .event {
     Picker("Option",selection:$option) { Text("Choose").tag("");ForEach(definition.options,id:\.self){Text($0.replacingOccurrences(of:"_",with:" ")).tag($0)} }
    } else if definition.valueType == .composite {
     TextField("Systolic",value:$systolic,format:.number).keyboardType(.decimalPad)
     TextField("Diastolic",value:$diastolic,format:.number).keyboardType(.decimalPad)
    } else {
     LabeledContent("Value") { TextField("Value",value:$value,format:.number).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
    }
    Toggle("Save directly to encrypted queue",isOn:$offline)
    Button("Record") { Task{await record()} }.buttonStyle(.borderedProminent)
   }
   Section("Sync status") {
    if store.outbox.operations.isEmpty { Label("Queue empty",systemImage:"checkmark.circle") }
    ForEach(store.outbox.operations) { op in
     HStack { Text(op.endpoint);Spacer();Text(op.state.rawValue.capitalized);if op.attempts>0{Text("\(op.attempts) retries")}}
    }
    Button("Retry queued entries") { Task{await store.flushOutbox()} }.disabled(store.outbox.operations.isEmpty)
   }
   Section { Text("Quick Entry intentionally shows no history or current values. The encrypted queue contains only entries you explicitly choose to save offline.").font(.footnote).foregroundStyle(.secondary) }
  }
  .navigationTitle("Quick Entry")
  .toolbar { Button("Done"){dismiss()} }
 }
 private func record()async {
  let id=UUID();let iso=ISO8601DateFormatter().string(from:Date());let unit=store.configuration?.metrics[metric]?.displayUnit ?? definition.canonicalUnit
  do {
   let endpoint:String;let method:HTTPMethod;let data:Data
   switch definition.category {
   case .journal:
    let input=EntryInput(metricKey:metric,numericValue:definition.valueType == .event ? nil:value,optionValue:option.isEmpty ? nil:option,context:"manual",recordedAt:iso,note:nil,operationId:id)
    if definition.valueType == .event {try InputValidator.validate(option:option,metric:definition)}else{try InputValidator.validate(value:value,metric:definition)}
    endpoint="entries";method = .post;data=try JSONEncoder().encode(input)
   case .measurement:
    let values=definition.valueType == .composite ? ["systolic":systolic,"diastolic":diastolic]:nil
    let input=MeasurementInput(metricKey:metric,numericValue:definition.valueType == .composite ? nil:value,values:values,unit:unit,context:"manual",recordedAt:iso,note:nil,operationId:id)
    if definition.valueType == .composite {guard systolic.isFinite,diastolic.isFinite else{throw HealthCoreError.invalidValue("Values must be finite")}}else{try InputValidator.validate(value:value,metric:definition)}
    endpoint="measurements";method = .post;data=try JSONEncoder().encode(input)
   case .dailyValue:
    let input=DailyValueInput(numericValue:value,unit:unit)
    try InputValidator.validate(value:value,metric:definition)
    let date=LocalDate.string(from:store.date);endpoint="daily-values/\(metric)/\(date)";method = .put;data=try JSONEncoder().encode(input)
   }
   try store.outbox.enqueue(endpoint:endpoint,method:method,body:data)
   if !offline {await store.flushOutbox()}
   dismiss()
  } catch { store.error=error.localizedDescription }
 }
}
