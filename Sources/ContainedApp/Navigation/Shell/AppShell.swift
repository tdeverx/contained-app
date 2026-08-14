import SwiftUI
import ContainedUX

/// The single app shell: the container grid sits beneath permanent toolbar chrome, while resource
/// browsers, utilities, and creation/edit flows are presented by toolbar morph panels.
struct AppShell: View {
    var body: some View {
        ZStack {
            pageContent
            AppToolbar()
                .environment(\.morphSafeAreaManager, toolbarSafeAreaManager)
                .ignoresSafeArea(.container, edges: .vertical)
        }
        .environment(\.morphSafeAreaManager, UX.SafeArea.Manager(system: EdgeInsets()))
    }

    private var pageContent: some View {
        let insets = toolbarSafeAreaManager.insets(UX.SafeArea.Policy(excluding: .top, padding: .none))
        return ContainersGridView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.top, insets.top)
            .ignoresSafeArea(.container, edges: .vertical)
    }

    private var toolbarSafeAreaManager: UX.SafeArea.Manager {
        UX.SafeArea.Manager(system: EdgeInsets(),
                           topToolbarHeight: AppToolbar.bandHeight,
                           bottomToolbarHeight: AppToolbar.bandHeight)
    }
}
