// SPDX-License-Identifier: AGPL-3.0-or-later
import SwiftUI
import HealthCore
struct GoalsView:View {
 @EnvironmentObject var store:AppStore
 @State private var showingEditor=false
 @State private var editing:Goal?
 @State private var pendingDelete:Goal?
 @State private var progressPeriod:GoalPeriod = .week
 var body:some View {
  List {
   Section("Progress") {
    Picker("Period",selection:$progressPeriod){ForEach(GoalPeriod.allCases,id:\.self){Text($0.rawValue.replacingOccurrences(of:"_",with:" ").capitalized).tag($0)}}
    if store.progress.isEmpty {
     Text("No goal progress for this period")
      .foregroundStyle(.secondary)
    }
    ForEach(store.progress) { item in
     VStack(alignment:.leading,spacing:8) {
      HStack {
       Text(item.targetKey.replacingOccurrences(of:"_",with:" ").capitalized)
        .font(.headline)
       Spacer()
       Text(item.status.capitalized)
        .font(.caption)
        .padding(.horizontal,8)
        .padding(.vertical,3)
        .background(.tint.opacity(0.15),in:Capsule())
      }
      ProgressView(value:min(max(item.progressRatio ?? 0,0),1))
       .accessibilityLabel("Goal progress")
       .accessibilityValue("\(Int((item.progressRatio ?? 0)*100)) percent")
      HStack {
       Text("Current: \(item.currentValue ?? 0,format:.number)")
       Spacer()
       Text("Target: \(item.targetValue,format:.number)")
      }
      .font(.caption)
      .foregroundStyle(.secondary)
     }
     .padding(.vertical,4)
    }
   }
   Section("Goals") {
    ForEach(store.goals) { goal in
     Button {
      editing=goal
     } label: {
      VStack(alignment:.leading,spacing:5) {
       HStack {
        Text(goal.targetKey.capitalized)
         .font(.headline)
        Spacer()
        if goal.remindersEnabled {
         Image(systemName:"bell.fill")
          .accessibilityLabel("Reminders enabled")
        }
       }
       Text(goal.period.replacingOccurrences(of:"_",with:" ").capitalized)
        .foregroundStyle(.secondary)
       if let revision=goal.currentRevision {
        Text("\(revision.comparator.uppercased()) \(revision.targetValue,format:.number)")
       }
      }
     }
     .swipeActions {
      Button("Delete",role:.destructive) {
       pendingDelete=goal
      }
     }
    }
    if store.goals.isEmpty {
     ContentUnavailableView("No goals",systemImage:"target",description:Text("Add a goal from the server-provided target list."))
    }
   }
  }
  .navigationTitle("Goals")
  .toolbar {
   Button {
    showingEditor=true
   } label: {
    Label("Add goal",systemImage:"plus")
   }
  }
  .sheet(isPresented:$showingEditor) {
   NavigationStack { GoalFormView() }
  }
  .sheet(item:$editing) { goal in
   NavigationStack { GoalFormView(existing:goal) }
  }
  .confirmationDialog("Delete this goal?",isPresented:Binding(get:{pendingDelete != nil},set:{if !$0{pendingDelete=nil}}),titleVisibility:.visible) {
   Button("Delete Goal",role:.destructive) {
    guard let goal=pendingDelete else{return}
    Task {
     do { _ = try await store.client?.deleteGoal(goal.id);await store.refreshGoals() }
     catch { store.error=error.localizedDescription }
    }
   }
   Button("Cancel",role:.cancel) {}
  }
  .task { await store.refreshGoals(period:progressPeriod) }
  .onChange(of:progressPeriod){_,period in Task{await store.refreshGoals(period:period)}}
  .refreshable { await store.refreshGoals(period:progressPeriod) }
 }
}
struct GoalFormView:View {
 @EnvironmentObject var store:AppStore
 @Environment(\.dismiss) var dismiss
 let existing:Goal?
 @State private var targetKey=""
 @State private var period="day"
 @State private var comparator="gte"
 @State private var targetValue=1.0
 @State private var active=true
 @State private var reminders=false
 @State private var reminderPolicy="gentle"
 init(existing:Goal?=nil) {
  self.existing=existing
  _targetKey=State(initialValue:existing?.targetKey ?? "")
  _period=State(initialValue:existing?.period ?? "day")
  _comparator=State(initialValue:existing?.currentRevision?.comparator ?? "gte")
  _targetValue=State(initialValue:existing?.currentRevision?.targetValue ?? 1)
  _active=State(initialValue:existing?.active ?? true)
  _reminders=State(initialValue:existing?.remindersEnabled ?? false)
 }
 var selected:GoalTarget? { store.goalTargets.first{$0.targetKey==targetKey} }
 var body:some View {
  Form {
   Section("Target") {
    Picker("Target",selection:$targetKey) {
     Text("Choose a target").tag("")
     ForEach(store.goalTargets) { target in
      Text(target.targetKey.replacingOccurrences(of:".",with:" ").capitalized).tag(target.targetKey)
     }
    }
    Picker("Period",selection:$period) {
     ForEach(selected?.periods ?? ["day"],id:\.self) { Text($0.capitalized).tag($0) }
    }
    Picker("Comparison",selection:$comparator) {
     ForEach(selected?.comparators ?? ["gte"],id:\.self) { Text($0.uppercased()).tag($0) }
    }
    TextField("Target value",value:$targetValue,format:.number)
     .keyboardType(.decimalPad)
     .accessibilityLabel("Goal target value")
   }
   Section("Status and reminders") {
    Toggle("Active",isOn:$active)
    Toggle("Gentle reminders",isOn:$reminders)
    if reminders {
     Picker("Reminder policy",selection:$reminderPolicy) {
      Text("Gentle").tag("gentle")
      Text("Daily").tag("daily")
     }
    }
   }
   Button(existing == nil ? "Create goal" : "Save goal") {
    Task { await save() }
   }
   .buttonStyle(.borderedProminent)
   .disabled(targetKey.isEmpty)
  }
  .navigationTitle(existing == nil ? "New Goal" : "Edit Goal")
  .toolbar { Button("Cancel") { dismiss() } }
  .onAppear { if targetKey.isEmpty {targetKey=store.goalTargets.first?.targetKey ?? ""} }
 }
 func save()async {
  guard let client=store.client else{return}
  let input=GoalInput(targetKey:targetKey,period:period,comparator:comparator,targetValue:targetValue,active:active,remindersEnabled:reminders)
  do {
   if let existing { _ = try await client.updateGoal(existing.id,input) }
   else { _ = try await client.createGoal(input) }
   await store.refreshGoals()
   dismiss()
  } catch { store.error=error.localizedDescription }
 }
}
