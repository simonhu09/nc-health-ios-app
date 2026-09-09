// SPDX-License-Identifier: AGPL-3.0-or-later
import SwiftUI
import HealthCore
struct RootView:View {
 @EnvironmentObject var store:AppStore
 var body:some View {
  Group {
   if store.account == nil { LoginView() }
   else { MainTabs() }
  }
  .onReceive(NotificationCenter.default.publisher(for:.remoteWipeRequired)){_ in Task{await store.handleRemoteWipe()}}
  .alert("Error",isPresented:Binding(get:{store.error != nil},set:{if !$0{store.error=nil}})){Button("OK",role:.cancel){}} message:{Text(store.error ?? "")}
 }
}
struct MainTabs:View {
 var body:some View {
  TabView {
   NavigationStack { JournalView() }
    .tabItem { Label("Journal",systemImage:"book") }
   NavigationStack { RecordsView() }
    .tabItem { Label("Records",systemImage:"list.bullet.rectangle") }
   NavigationStack { GoalsView() }
    .tabItem { Label("Goals",systemImage:"target") }
   NavigationStack { StatisticsView() }
    .tabItem { Label("Statistics",systemImage:"chart.xyaxis.line") }
   NavigationStack { SettingsView() }
    .tabItem { Label("Settings",systemImage:"gear") }
  }
 }
}
struct LoginView:View {
 @EnvironmentObject var store:AppStore
 @State private var server=""
 @State private var login=""
 @State private var password=""
 @State private var manual=false
 @State private var connecting=false
 var body:some View {
  NavigationStack {
   Form {
    Section {
     TextField("Server URL",text:$server)
      .textContentType(.URL)
      .keyboardType(.URL)
      .textInputAutocapitalization(.never)
      .autocorrectionDisabled()
      .accessibilityLabel("Nextcloud server URL")
     Text("Use the full HTTPS URL, including a subfolder if your Nextcloud is installed in one.")
      .font(.footnote)
      .foregroundStyle(.secondary)
    } header:{Text("Nextcloud")}
    Section {
     Button {
      Task { await loginFlow() }
     } label:{
      Label(connecting ? "Waiting for approval…" : "Sign in with Nextcloud",systemImage:"person.badge.key")
     }
     .disabled(server.isEmpty || connecting)
     Text("Recommended. The app opens Nextcloud in your browser. Approve access there, then return here.")
      .font(.footnote)
      .foregroundStyle(.secondary)
    } header:{Text("Login Flow v2")}
    Section {
     DisclosureGroup("Manual app password",isExpanded:$manual) {
      TextField("Login name",text:$login)
       .textContentType(.username)
       .textInputAutocapitalization(.never)
       .accessibilityLabel("Nextcloud login name")
      SecureField("App password",text:$password)
       .textContentType(.password)
       .accessibilityLabel("Nextcloud app password")
       Button("Connect manually") {
       Task { do { try await store.connect(.init(server:server,login:login,appPassword:password)) }
       catch { store.error=error.localizedDescription } }
      }
      .disabled(server.isEmpty || login.isEmpty || password.isEmpty)
     }
     Text("Create an app password in Nextcloud security settings. Never enter your normal account password.")
      .font(.footnote)
      .foregroundStyle(.secondary)
    }
    Section("Privacy") {
     Label("Credentials are stored in Keychain",systemImage:"lock.shield")
     Label("Fetched health records are memory-only",systemImage:"externaldrive.badge.xmark")
     Label("Offline Quick Entry is encrypted and opt-in",systemImage:"lock.doc")
    }
   }
   .navigationTitle("Health Journal")
  }
 }
 private func loginFlow()async {
  connecting=true
  defer{connecting=false}
  do {
   let config=try ServerConfiguration(server:server)
   let(start,session)=try await NextcloudLoginFlow.start(server:config)
   let result=try await NextcloudLoginFlow.poll(start,session:session)
   try await store.connect(.init(server:result.server,login:result.loginName,appPassword:result.appPassword))
  } catch { store.error=error.localizedDescription }
 }
}
