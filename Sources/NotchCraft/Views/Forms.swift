import SwiftUI

struct NewTaskView: View {
    @Environment(WorkspaceStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var prompt=""
    @State private var allowWrites=false
    @State private var isStarting=false
    var body: some View {
        VStack(alignment:.leading,spacing:22) {
            HStack(alignment:.top) { PanelHeading(title:L("new.title"),subtitle:L("new.subtitle")); Spacer(); Button { dismiss() } label: { Image(systemName:"xmark") }.buttonStyle(IconButton()).disabled(isStarting).help(L("common.close")) }
            VStack(alignment:.leading,spacing:10) {
                Text(L("new.project")).font(.system(size:11,weight:.medium))
                HStack { Image(systemName:"folder").foregroundStyle(Theme.green); Text(store.projectPath.isEmpty ? L("new.choose"):store.projectPath).font(.system(size:11)).lineLimit(1).truncationMode(.middle); Spacer(); Button(L("new.choose")) { store.chooseProject() }.buttonStyle(QuietButton()) }.padding(12).background(Theme.raised).clipShape(RoundedRectangle(cornerRadius:8))
            }
            VStack(alignment:.leading,spacing:10) {
                Text(L("new.task")).font(.system(size:11,weight:.medium))
                ZStack(alignment:.topLeading) {
                    TextEditor(text:$prompt).font(.system(size:13)).scrollContentBackground(.hidden).padding(10).frame(height:150)
                    if prompt.isEmpty { Text(L("new.placeholder")).font(.system(size:12)).foregroundStyle(Theme.muted).padding(17).allowsHitTesting(false) }
                }.background(Theme.raised).clipShape(RoundedRectangle(cornerRadius:8)).overlay(RoundedRectangle(cornerRadius:8).strokeBorder(Theme.line))
            }
            Toggle(L("new.writes"),isOn:$allowWrites).toggleStyle(.switch).tint(Theme.green).font(.system(size:12))
            Text(L("new.safety")).font(.system(size:11)).foregroundStyle(Theme.muted).lineSpacing(4)
            Divider().overlay(Theme.line)
            Text(L("new.paid")).font(.system(size:10)).foregroundStyle(Theme.muted)
            HStack { Spacer(); Button(L("common.cancel")) { dismiss() }.buttonStyle(QuietButton()).disabled(isStarting); Button { isStarting=true; Task { await store.startTask(prompt:prompt,allowWrites:allowWrites); isStarting=false } } label: { HStack { if isStarting { ProgressView().controlSize(.mini) }; Text(L("new.start")) } }.buttonStyle(QuietButton(prominent:true)).disabled(isStarting || prompt.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty || store.projectPath.isEmpty || !store.isConnected) }
        }.padding(30).frame(width:590).background(Theme.background).foregroundStyle(Theme.text).preferredColorScheme(.dark).interactiveDismissDisabled(isStarting)
    }
}
struct SettingsPanel: View {
    @Environment(WorkspaceStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var confirmDelete=false
    @State private var confirmDisconnect=false
    var body: some View {
        @Bindable var store=store
        VStack(alignment:.leading,spacing:18) {
            HStack { Text(L("settings.title")).font(.system(size:23,weight:.medium)); Spacer(); Button { dismiss() } label: { Image(systemName:"xmark") }.buttonStyle(IconButton()).help(L("common.close")) }
            ScrollView {
                VStack(alignment:.leading,spacing:24) {
                    settingGroup("settings.general") {
                        Picker(L("settings.language"),selection:$store.language) { Text("한국어").tag("ko"); Text("English").tag("en") }.pickerStyle(.segmented)
                        Toggle(L("settings.notch"),isOn:$store.showNotch)
                        Toggle(L("settings.reduced"),isOn:$store.reduceMotion)
                        Toggle(L("settings.low"),isOn:$store.lowPower)
                    }
                    settingGroup("settings.connection") {
                        Text(L("settings.limit")).foregroundStyle(Theme.muted).lineSpacing(4)
                        HStack { Text("Codex"); Spacer(); Tag(text:L(store.isConnected ? "connection.connected":"connection.offline")); Button(L(store.isConnected ? "connection.disconnect":"connection.connect")) { if store.isConnected { confirmDisconnect=true } else { Task { await store.connect() } } }.buttonStyle(QuietButton()).disabled(store.isConnecting) }
                    }
                    settingGroup("settings.privacy") {
                        Text(L("settings.local")).foregroundStyle(Theme.muted).lineSpacing(4)
                        Toggle(L("settings.history"),isOn:$store.saveHistory)
                        Button(L("settings.delete"),role:.destructive) { confirmDelete=true }.buttonStyle(QuietButton())
                    }
                    settingGroup("settings.notifications") {
                        Toggle(L("settings.notify"),isOn:Binding(get:{store.notifications},set:{ value in if value { Task { await store.enableNotifications() } } else { store.notifications=false } }))
                    }
                    Text(L("settings.version")).font(.system(size:10,design:.monospaced)).foregroundStyle(Theme.muted)
                }.padding(.vertical,8)
            }
        }.font(.system(size:12)).toggleStyle(.switch).tint(Theme.green).padding(28).frame(width:560,height:650).background(Theme.background).foregroundStyle(Theme.text).preferredColorScheme(.dark)
        .confirmationDialog(L("settings.deleteTitle"),isPresented:$confirmDelete) { Button(L("common.delete"),role:.destructive) { store.deleteHistory() } } message: { Text(L("settings.deleteNote")) }
        .confirmationDialog(L("confirm.disconnect"),isPresented:$confirmDisconnect) { Button(L("connection.disconnect"),role:.destructive) { store.disconnect() } }
    }
    private func settingGroup<Content:View>(_ title:String,@ViewBuilder content:()->Content) -> some View {
        VStack(alignment:.leading,spacing:16) { Text(L(title)).font(.system(size:11,weight:.semibold)).foregroundStyle(Theme.green); content() }.padding(18).frame(maxWidth:.infinity,alignment:.leading).background(Theme.surface).clipShape(RoundedRectangle(cornerRadius:9)).overlay(RoundedRectangle(cornerRadius:9).strokeBorder(Theme.line))
    }
}
struct WelcomeView: View {
    @Environment(WorkspaceStore.self) private var store
    var body: some View {
        @Bindable var store=store
        VStack(spacing:24) {
            HStack { BrandMark().frame(width:25,height:25); Text("NotchCraft").font(.system(size:15,weight:.semibold,design:.rounded)); Spacer(); Picker(L("settings.language"),selection:$store.language) { Text("한국어").tag("ko"); Text("English").tag("en") }.labelsHidden().frame(width:110) }
            Image(nsImage:WorldArtwork.image).resizable().interpolation(.none).scaledToFit().frame(height:220).padding(.vertical,-25).accessibilityHidden(true)
            VStack(spacing:16) {
                Text(L("onboarding.eyebrow")).font(.system(size:9,weight:.medium,design:.monospaced)).tracking(2).foregroundStyle(Theme.green)
                Text(L("onboarding.title")).font(.system(size:31,weight:.medium)).tracking(-1).multilineTextAlignment(.center).lineSpacing(5)
                Text(L("onboarding.detail")).font(.system(size:12)).foregroundStyle(Theme.muted).multilineTextAlignment(.center).lineSpacing(6)
            }
            VStack(spacing:10) {
                Button { store.finishWelcome(); Task { await store.connect() } } label: { Text(L("onboarding.live")).frame(maxWidth:.infinity) }.buttonStyle(QuietButton(prominent:true)).disabled(ExecutableLocator.find("codex") == nil)
                Button { store.finishWelcome() } label: { Text(L("onboarding.explore")).frame(maxWidth:.infinity) }.buttonStyle(QuietButton())
            }.padding(.horizontal,40)
            Text(L("onboarding.note")).font(.system(size:9)).foregroundStyle(Theme.muted)
        }.padding(30).frame(width:540).background(Theme.background).foregroundStyle(Theme.text).preferredColorScheme(.dark)
    }
}
