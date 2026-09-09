// SPDX-License-Identifier: AGPL-3.0-or-later
import SwiftUI
import Charts
import HealthCore
struct StatisticsView:View {
 @EnvironmentObject var store:AppStore
 @State private var period:StatisticsPeriod = .last30Days
 @State private var selected=Set<String>()
 @State private var showingView=false
 @State private var editingView:SavedStatisticsView?
 var body:some View {
  List {
   Section {
    Picker("Period",selection:$period) {
     ForEach(StatisticsPeriod.allCases,id:\.self) { value in
      Text(value.rawValue.replacingOccurrences(of:"_",with:" ").capitalized).tag(value)
     }
    }
    ScrollView(.horizontal) {
     HStack {
      ForEach(store.metrics) { metric in
       Toggle(metric.key.replacingOccurrences(of:"_",with:" ").capitalized,isOn:Binding(get:{selected.contains(metric.key)},set:{if $0{selected.insert(metric.key)}else{selected.remove(metric.key)}}))
        .toggleStyle(.button)
      }
     }
    }
    Button("Update statistics") { Task{await load()} }
   }
   if let statistics=store.statistics {
    ForEach(statistics.metrics) { metric in
     Section(metric.metricKey.replacingOccurrences(of:"_",with:" ").capitalized) {
      Chart {
       ForEach(metric.series) { point in
        if let value=point.value {
         LineMark(x:.value("Date",point.date),y:.value("Value",value))
         PointMark(x:.value("Date",point.date),y:.value("Value",value))
        }
        if let pressure=point.subseries {
         ForEach(pressure.keys.sorted(),id:\.self) { seriesKey in
          if let eventValue=pressure[seriesKey] ?? nil,metric.valueType=="event" {
           BarMark(x:.value("Date",point.date),y:.value("Count",eventValue))
            .foregroundStyle(by:.value("Series",seriesKey))
            .position(by:.value("Series",seriesKey))
          }
         }
         if let systolic=pressure["systolic"] ?? nil {
          LineMark(x:.value("Date",point.date),y:.value("Systolic",systolic)).foregroundStyle(by:.value("Series","Systolic"))
         }
         if let diastolic=pressure["diastolic"] ?? nil {
          LineMark(x:.value("Date",point.date),y:.value("Diastolic",diastolic)).foregroundStyle(by:.value("Series","Diastolic"))
         }
        }
       }
       ForEach(metric.goals) { goal in
        RuleMark(y:.value("Goal",goal.targetValue))
         .lineStyle(StrokeStyle(dash:[5]))
         .foregroundStyle(.orange)
         .annotation(position:.top,alignment:.leading) { Text("Goal") }
       }
      }
      .frame(height:220)
      .accessibilityLabel("Chart for \(metric.metricKey)")
      if let summary=metric.summary {
       Grid(alignment:.leading,horizontalSpacing:24,verticalSpacing:8) {
        GridRow { Text("Average");Text(summary.average?.formatted() ?? "—") }
        GridRow { Text("Minimum");Text(summary.minimum?.formatted() ?? "—") }
        GridRow { Text("Maximum");Text(summary.maximum?.formatted() ?? "—") }
        GridRow { Text("Records");Text(summary.count.formatted()) }
        GridRow { Text("Active days");Text(summary.activeDays.formatted()) }
       }
       .font(.subheadline)
      }
     }
    }
   } else {
    ContentUnavailableView("No statistics loaded",systemImage:"chart.xyaxis.line",description:Text("Choose metrics and a period."))
   }
   Section("Saved views") {
    ForEach(store.savedViews) { view in
     Button { selected=Set(view.metricKeys);period=StatisticsPeriod(rawValue:view.period) ?? .last30Days;Task{await load()} } label:{HStack{Text(view.icon.isEmpty ? "📊":view.icon);Text(view.title)}}
      .swipeActions {
       Button("Edit") {editingView=view}.tint(.blue)
       Button("Clone") {Task{await clone(view)}}.tint(.green)
       Button("Delete",role:.destructive) {Task{do{_ = try await store.client?.deleteView(view.id);await store.refreshStatistics(period:period)}catch{store.error=error.localizedDescription}}}
      }
    }
    Button {showingView=true} label:{Label("Save current view",systemImage:"plus")}
     .disabled(selected.isEmpty)
   }
  }
  .navigationTitle("Statistics")
  .task {if selected.isEmpty{selected=Set(store.metrics.prefix(3).map(\.key))};await load()}
  .onChange(of:period){_,_ in Task{await load()}}
  .refreshable{await load()}
  .sheet(isPresented:$showingView){NavigationStack{StatisticsViewForm(metricKeys:Array(selected),period:period)}}
  .sheet(item:$editingView){view in NavigationStack{StatisticsViewForm(existing:view,metricKeys:view.metricKeys,period:StatisticsPeriod(rawValue:view.period) ?? .last30Days)}}
 }
 func load()async {guard let c=store.client else{return};do{store.statistics=try await c.statistics(period,metrics:Array(selected));store.savedViews=try await c.views()}catch{store.error=error.localizedDescription}}
 func clone(_ view:SavedStatisticsView)async {
  guard let c=store.client else{return}
  let input=StatisticsViewInput(title:"\(view.title) Copy",icon:view.icon,metricKeys:view.metricKeys,period:view.period)
  do{_ = try await c.createView(input);store.savedViews=try await c.views()}catch{store.error=error.localizedDescription}
 }
}
struct StatisticsViewForm:View {
 @EnvironmentObject var store:AppStore
 @Environment(\.dismiss) var dismiss
 var existing:SavedStatisticsView?
 let metricKeys:[String]
 let period:StatisticsPeriod
 @State private var title=""
 @State private var icon="📊"
 init(existing:SavedStatisticsView?=nil,metricKeys:[String],period:StatisticsPeriod){self.existing=existing;self.metricKeys=metricKeys;self.period=period;_title=State(initialValue:existing?.title ?? "") ;_icon=State(initialValue:existing?.icon ?? "📊")}
 var body:some View {
  Form {
   TextField("View title",text:$title)
   Picker("Icon",selection:$icon) {
    Text("📊 Chart").tag("📊")
    Text("❤️ Heart").tag("❤️")
    Text("🏃 Activity").tag("🏃")
    Text("⚖️ Weight").tag("⚖️")
    Text("🩺 Health").tag("🩺")
   }
   TextField("Custom emoji",text:$icon)
    .accessibilityLabel("Saved view emoji")
   Section("Metrics") { ForEach(metricKeys,id:\.self){Text($0.replacingOccurrences(of:"_",with:" ").capitalized)} }
   Button(existing == nil ? "Create saved view":"Save changes") {Task{await save()}}.buttonStyle(.borderedProminent).disabled(title.isEmpty)
  }
  .navigationTitle("Statistics View")
  .toolbar{Button("Cancel"){dismiss()}}
 }
 func save()async{guard let c=store.client else{return};let input=StatisticsViewInput(title:title,icon:icon,metricKeys:metricKeys,period:period.rawValue);do{if let existing{_ = try await c.updateView(existing.id,input)}else{_ = try await c.createView(input)};await store.refreshStatistics(period:period);dismiss()}catch{store.error=error.localizedDescription}}
}
