import Foundation

extension ChatViewModel {
    /// Chat view model that follows the provider chosen in Settings.
    static func live() -> ChatViewModel {
        let model = ChatViewModel()
        model.serviceProvider = {
            AIServiceFactory.makeService(settings: SettingsViewModel.shared)
        }
        return model
    }
}
