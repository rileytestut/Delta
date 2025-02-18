//
//  PauseViewController+Lu.swift
//  Delta
//
//  Created by Fikri Firat on 15/01/2025.
//  Copyright © 2025 Riley Testut. All rights reserved.
//
import Foundation
import UIKit
import DeltaFeatures

// MARK: - Logging

import os.log

private extension OSLog {
    static let lu = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "com.rileytestut.Delta", category: "Lu")
}

private func luLog(_ type: OSLogType = .info, _ message: String) {
    os_log("[Lu] %{public}@", log: .lu, type: type, message)
}

// MARK: - API Data Structures
private struct LuRequest: Codable {
    let game_id: String
    let question: String
    let remember_conversation: Bool
        
    // Add an initializer with a default value for remember_conversation
    init(game_id: String, question: String, remember_conversation: Bool = false) {
        self.game_id = game_id
        self.question = question
        self.remember_conversation = remember_conversation
    }
}
private struct LuResponse: Codable {
    let message_id: String
    let answer: String
}

private struct GameSupportResponse: Codable {
    let game_id: String
}

private struct FeedbackRequest: Codable {
    let message_id: String
    let feedback: String
    let feedback_message: String?
}


private struct APIContext: Codable {
    let device_context: DeviceContext
    let game_context: GameContext
    
    struct DeviceContext: Codable {
        let device_id: String
        let device_name: String
        let system_name: String
        let system_version: String
        let model: String
        let bundle_id: String
    }
    
    struct GameContext: Codable {
        let name: String
        let identifier: String
        let type: String
        let save_states_count: Int
        let cheats_count: Int
        let last_played: String?
    }
}

private extension URLRequest {
    mutating func addContextHeaders(context: APIContext) {
        if let contextData = try? JSONEncoder().encode(context),
           let contextString = String(data: contextData, encoding: .utf8) {
            setValue(contextString, forHTTPHeaderField: "x-lu-context")
            luLog(.info, "Adding context headers")
        }
    }
}

private extension Date {
    func ISO8601String() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: self)
    }
}

private func createAPIContext(for game: Game) -> APIContext {
    let deviceContext = APIContext.DeviceContext(
        device_id: UIDevice.current.identifierForVendor?.uuidString ?? "unknown",
        device_name: UIDevice.current.name,
        system_name: UIDevice.current.systemName,
        system_version: UIDevice.current.systemVersion,
        model: UIDevice.current.model,
        bundle_id: Bundle.main.bundleIdentifier ?? "unknown"
    )
    
    let gameContext = APIContext.GameContext(
        name: game.name,
        identifier: game.identifier,
        type: game.type.rawValue,
        save_states_count: game.saveStates.count,
        cheats_count: game.cheats.count,
        last_played: game.playedDate?.ISO8601String()
    )
    
    return APIContext(
        device_context: deviceContext,
        game_context: gameContext
    )
}

private enum APIConstants {
    private static let plist: [String: Any] = {
        guard let plistPath = Bundle.main.path(forResource: "Lu-Info", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: plistPath) as? [String: Any] else {
            fatalError("[Lu] Failed to load Lu-Info.plist")
        }
        return plist
    }()
    
    static let baseURL: String = {
        guard let url = plist["LU_BASE_URL"] as? String else {
            fatalError("[Lu] Missing LU_BASE_URL in Lu-Info.plist")
        }
        return url
    }()
    
    static let askBaseURL = "\(baseURL)/ask"
    static let supportBaseURL = "\(baseURL)/check-rom"
    static let feedbackBaseURL = "\(baseURL)/feedbacks"
    
    static let supportTimeout: TimeInterval = {
        guard let timeout = plist["SUPPORT_TIMEOUT"] as? TimeInterval else {
            return 10
        }
        return timeout
    }()
    
    static let askTimeout: TimeInterval = {
        guard let timeout = plist["ASK_TIMEOUT"] as? TimeInterval else {
            return 30
        }
        return timeout
    }()
    
    static let feedbackTimeout: TimeInterval = {
        guard let timeout = plist["FEEDBACK_TIMEOUT"] as? TimeInterval else {
            return 10
        }
        return timeout
    }()
}

extension PauseViewController {
    func configureLuMenuItem() -> MenuItem {
        return MenuItem(text: NSLocalizedString("Ask Lu", comment: ""),
                        image: #imageLiteral(resourceName: "Lu"),
                        action: { [weak self] menuItem in
            guard let self = self,
                  let game = self.emulatorCore?.game as? Game else {
                return
            }

            
            if let mostRecentSaveState = game.saveStates.max(by: { $0.modifiedDate < $1.modifiedDate }) {
                let identifier = mostRecentSaveState.identifier
                ExperimentalFeatures.shared.Lu.wrappedValue.activeSaveStateId = identifier
            }
            
            // Show initial loading indicator
            let loadingAlert = UIAlertController(
                title: nil,
                message: "Checking game...",
                preferredStyle: .alert
            )
            
            let loadingIndicator = UIActivityIndicatorView(frame: CGRect(x: 10, y: 5, width: 50, height: 50))
            loadingIndicator.hidesWhenStopped = true
            loadingIndicator.style = .medium
            loadingIndicator.startAnimating()
            
            loadingAlert.view.addSubview(loadingIndicator)
            self.present(loadingAlert, animated: true)
            
            // Check if game is supported before proceeding
            self.checkGameSupport(for: game) { supported in
                DispatchQueue.main.async {
                    loadingAlert.dismiss(animated: true) {
                        if supported {
                            if !ExperimentalFeatures.shared.Lu.wrappedValue.didShowWelcomeMessage {
                                self.showLuWelcomeMessage(for: game)
                            } else {
                                self.showLuQuestionPrompt(for: game)
                            }
                        } else {
                            self.showUnsupportedGameMessage()
                        }
                        menuItem.isSelected = false
                    }
                }
            }
        })
    }
    
    private func showLuWelcomeMessage(for game: Game) {
        let welcomeAlert = UIAlertController(
            title: NSLocalizedString("Welcome to Lu!", comment: ""),
            message: NSLocalizedString("We and our service providers may record your chat with us. By using this chat, you agree to our Terms of Service and Privacy Policy. \n \n https://lulabs.ai/legal", comment: ""),
            preferredStyle: .alert
        )
        
        let okAction = UIAlertAction(
            title: NSLocalizedString("Got it!", comment: ""),
            style: .default
        ) { [weak self] _ in
            ExperimentalFeatures.shared.Lu.wrappedValue.didShowWelcomeMessage = true
            self?.showLuQuestionPrompt(for: game)
        }
        
        welcomeAlert.addAction(okAction)
        self.present(welcomeAlert, animated: true)
    }
    
    private func showLuQuestionPrompt(for game: Game) {
        
        let alertController = UIAlertController(
            title: NSLocalizedString("Ask Lu about \(game.name)", comment: ""),
            message: NSLocalizedString("What would you like to know about this game?", comment: ""),
            preferredStyle: .alert
        )
        
        alertController.addTextField { textField in
            textField.placeholder = NSLocalizedString("Enter your question here", comment: "")
        }
        
        let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel)
        let askAction = UIAlertAction(
            title: NSLocalizedString("Ask", comment: ""),
            style: .default
        ) { [weak self] _ in
            guard let question = alertController.textFields?.first?.text,
                  !question.isEmpty else {
                return
            }
            self?.askLu(question: question, for: game)
        }
        
        alertController.addAction(cancelAction)
        alertController.addAction(askAction)
        
        self.present(alertController, animated: true)
    }
    
    private func askLu(question: String, for game: Game) {

        let loadingAlert = UIAlertController(
            title: nil,
            message: "Lu is thinking...",
            preferredStyle: .alert
        )
        
        let loadingIndicator = UIActivityIndicatorView(frame: CGRect(x: 10, y: 5, width: 50, height: 50))
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.style = .medium
        loadingIndicator.startAnimating()
        
        loadingAlert.view.addSubview(loadingIndicator)
        self.present(loadingAlert, animated: true)
        
        // Prepare request
        let urlString = APIConstants.askBaseURL
        guard let url = URL(string: urlString) else {
            loadingAlert.dismiss(animated: true)
            self.showError("Failed to create request")
            return
        }
        
        let activeGameId = ExperimentalFeatures.shared.Lu.wrappedValue.activeGameId
        if activeGameId.isEmpty {
            loadingAlert.dismiss(animated: true)
            self.showError("Failed to prepare your question")
            return
        }
        
        // Create request with remember_conversation parameter if option is enabled
        let shouldRememberConversation = ExperimentalFeatures.shared.Lu.wrappedValue.rememberConversations
        let request = LuRequest(
            game_id: activeGameId,
            question: question,
            remember_conversation: shouldRememberConversation
        )
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = APIConstants.askTimeout
        
        
        let context = createAPIContext(for: game)
        urlRequest.addContextHeaders(context: context)
        
        do {
            urlRequest.httpBody = try JSONEncoder().encode(request)
        } catch {
            loadingAlert.dismiss(animated: true)
            self.showError("Failed to prepare your question")
            return
        }
        luLog(.info, "Making request to URL: \(urlString), remembering conversation : \(shouldRememberConversation)")
        
        let task = URLSession.shared.dataTask(with: urlRequest) { [weak self] (data, response, error) in
            DispatchQueue.main.async {
                loadingAlert.dismiss(animated: true) {
                    if let error = error as? URLError {
                        switch error.code {
                        case .timedOut:
                            self?.showError("Lu is taking longer than usual to respond. Please try again.")
                        case .notConnectedToInternet:
                            self?.showError("No internet connection. Please check your connection and try again.")
                        default:
                            self?.showError("Unable to connect to Lu. Please try again later.")
                        }
                        return
                    }
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        self?.showError("Received an invalid response. Please try again.")
                        return
                    }
                    
                    guard httpResponse.statusCode == 200,
                          let data = data else {
                        self?.showError("Lu encountered an error. Please try again later.")
                        return
                    }
                    
                    do {
                        let luResponse = try JSONDecoder().decode(LuResponse.self, from: data)
                        self?.showLuResponse(response: luResponse, question: question, for: game)
                    } catch {
                        self?.showError("Failed to understand Lu's response. Please try again.")
                    }
                }
            }
        }
        task.resume()
    }
    
    private func showLuResponse(response: LuResponse, question: String, for game: Game) {
        var messageText = ""
        
        messageText += """
        Q: \(question)
        
        \(response.answer)
        """
        
        if ExperimentalFeatures.shared.Lu.wrappedValue.rememberConversations {
            messageText += "\n\n(Conversation will be remembered for this game)"
        }
        
        let responseAlert = UIAlertController(
            title: NSLocalizedString("Lu's Response", comment: ""),
            message: messageText,
            preferredStyle: .alert
        )
        
        let askAnotherAction = UIAlertAction(
            title: NSLocalizedString("Ask another", comment: ""),
            style: .default
        ) { [weak self] _ in
            self?.showLuQuestionPrompt(for: game)
        }
        
        let feedbackActions = UIAlertAction(
            title: "Share feedback",
            style: .default
        ) { [weak self] _ in
            let feedbackAlert = UIAlertController(
                title: "Feedback",
                message: "Let us know how Lu handled your question:\n\n\"\(question)\"",
                preferredStyle: .alert
            )
            
            let thumbsUpAction = UIAlertAction(
                title: "👍 Great!",
                style: .default
            ) { [weak self] _ in
                self?.sendFeedback(messageId: response.message_id, feedback: "POSITIVE", feedbackMessage: nil, for: game) {
                    let successAlert = UIAlertController(
                        title: "Thank You!",
                        message: "Your feedback helps Lu improve and provide even better answers in the future.",
                        preferredStyle: .alert
                    )
                    successAlert.addAction(UIAlertAction(title: "OK", style: .default))
                    self?.present(successAlert, animated: true)
                }
            }
            
            let thumbsDownAction = UIAlertAction(
                title: "👎 Needs Improvement",
                style: .default
            ) { [weak self] _ in
                let inputAlert = UIAlertController(
                    title: "Additional Feedback",
                    message: "How can Lu improve its response to your question?\n\n\"\(question)\"",
                    preferredStyle: .alert
                )
                
                inputAlert.addTextField { textField in
                    textField.placeholder = "Enter your feedback"
                }
                
                let sendAction = UIAlertAction(
                    title: "Send",
                    style: .default
                ) { _ in
                    if let message = inputAlert.textFields?.first?.text {
                        self?.sendFeedback(messageId: response.message_id, feedback: "NEGATIVE", feedbackMessage: message, for: game) {
                            let successAlert = UIAlertController(
                                title: "Feedback Received",
                                message: "Thank you for helping Lu learn and grow. Your feedback is greatly appreciated!",
                                preferredStyle: .alert
                            )
                            successAlert.addAction(UIAlertAction(title: "OK", style: .default))
                            self?.present(successAlert, animated: true)
                        }
                    } else {
                        self?.sendFeedback(messageId: response.message_id, feedback: "NEGATIVE", feedbackMessage: nil, for: game) {
                            let successAlert = UIAlertController(
                                title: "Feedback Received",
                                message: "Thank you for your feedback. Lu will keep working to provide better responses.",
                                preferredStyle: .alert
                            )
                            successAlert.addAction(UIAlertAction(title: "OK", style: .default))
                            self?.present(successAlert, animated: true)
                        }
                    }
                }
                
                let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
                
                inputAlert.addAction(sendAction)
                inputAlert.addAction(cancelAction)
                
                self?.present(inputAlert, animated: true)
            }
            
            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
            
            feedbackAlert.addAction(thumbsUpAction)
            feedbackAlert.addAction(thumbsDownAction)
            feedbackAlert.addAction(cancelAction)
            
            // Set the preferred action to display the buttons side by side
            feedbackAlert.preferredAction = cancelAction
            
            self?.present(feedbackAlert, animated: true)
        }
        
        let dismissAction = UIAlertAction(
            title: NSLocalizedString("Back to game", comment: ""),
            style: .default
        ) { _ in }
        
        responseAlert.addAction(askAnotherAction)
        responseAlert.addAction(feedbackActions)
        responseAlert.addAction(dismissAction)
        self.present(responseAlert, animated: true)
    }
    
    private func sendFeedback(messageId: String, feedback: String, feedbackMessage: String?, for game: Game, completion: @escaping () -> Void) {
        
        // Show loading indicator
        let loadingAlert = UIAlertController(
            title: nil,
            message: "Sharing feedback...",
            preferredStyle: .alert
        )
        
        let loadingIndicator = UIActivityIndicatorView(frame: CGRect(x: 10, y: 5, width: 50, height: 50))
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.style = .medium
        loadingIndicator.startAnimating()
        
        loadingAlert.view.addSubview(loadingIndicator)
        present(loadingAlert, animated: true)
        
        let urlString = APIConstants.feedbackBaseURL
        guard let url = URL(string: urlString) else {
            loadingAlert.dismiss(animated: true)
            return
        }
        luLog(.info, "Making request to URL: \(urlString)")
        let feedbackRequest = FeedbackRequest(message_id: messageId, feedback: feedback, feedback_message: feedbackMessage)
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = APIConstants.feedbackTimeout
        
        let context = createAPIContext(for: game)
        urlRequest.addContextHeaders(context: context)
        
        do {
            urlRequest.httpBody = try JSONEncoder().encode(feedbackRequest)
        } catch {
            loadingAlert.dismiss(animated: true)
            return
        }
        
        let task = URLSession.shared.dataTask(with: urlRequest) { [weak self] (data, response, error) in
            DispatchQueue.main.async {
                loadingAlert.dismiss(animated: true) {
                    if let error = error {
                        
                        let errorAlert = UIAlertController(
                            title: "Feedback Error",
                            message: "Failed to send feedback. Please try again later.",
                            preferredStyle: .alert
                        )
                        luLog(.error, "[feedbacks] Failed to send feedback to Lu API")
                        errorAlert.addAction(UIAlertAction(title: "OK", style: .default))
                        self?.present(errorAlert, animated: true)
                        return
                    }
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        return
                    }
                    
                    
                    if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
                        luLog(.info, "Response [feedbacks]: Successfully sent feedback, status=\(httpResponse.statusCode)")
                        completion()
                    } else {
                        // Show error alert for non-200 status codes
                        let errorAlert = UIAlertController(
                            title: "Lu can't help you right now",
                            message: "Something went wrong while sharing your feedback with Lu. Please try again later.",
                            preferredStyle: .alert
                        )
                        luLog(.error, "Error [feedbacks]: Failed to send feedback due to errors, status=\(httpResponse.statusCode)")
                        errorAlert.addAction(UIAlertAction(title: "OK", style: .default))
                        self?.present(errorAlert, animated: true)
                    }
                }
            }
        }
        task.resume()
    }
    
    private func showError(_ message: String) {
        let alert = UIAlertController(
            title: "Lu can't help you right now",
            message: message,
            preferredStyle: .alert
        )
        
        let okAction = UIAlertAction(title: "OK", style: .default)
        alert.addAction(okAction)
        
        self.present(alert, animated: true)
    }
    
    private func showUnsupportedGameMessage() {
        let alert = UIAlertController(
            title: "Lu Can't Help You Yet",
            message: "Sorry, but Lu doesn't support this game just yet. Don't worry—we're already working on getting it onboarded as soon as possible. Thank you so much for giving Lu a try!",
            preferredStyle: .alert
        )
        
        let okAction = UIAlertAction(title: "OK", style: .default)
        alert.addAction(okAction)
        
        self.present(alert, animated: true)
    }
    
    private func checkGameSupport(for game: Game, completion: @escaping (Bool) -> Void) {
        let sha1 = game.identifier.uppercased()
        
        // Log the check-rom request
        luLog(.info, "Checking game availability on Lu")
        
        let urlString = "\(APIConstants.supportBaseURL)?sha1=\(sha1)"
        guard let url = URL(string: urlString) else {
            luLog(.error, "Invalid URL for check-rom endpoint")
            showError("Sorry, but Lu can't help you with this game right now. Don't worry—we're already working on getting it fixed as soon as possible. Thank you so much for giving Lu a try! Issue : Something went wrong while checking game knowledge")
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = APIConstants.supportTimeout
        
        let context = createAPIContext(for: game)
        request.addContextHeaders(context: context)
        luLog(.info, "Making request to URL: \(urlString)")
        let task = URLSession.shared.dataTask(with: request) { [weak self] (data, response, error) in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let error = error as? URLError {
                    let errorMessage: String
                    switch error.code {
                    case .timedOut:
                        errorMessage = "Connection timed out. Please check your internet connection and try again."
                    case .notConnectedToInternet:
                        errorMessage = "No internet connection. Please check your connection and try again."
                    default:
                        errorMessage = "Unable to connect to Lu. Please try again later."
                    }
                    
                    luLog(.error,"check-rom error: \(errorMessage) - \(error.localizedDescription)")
                    self.showError("Sorry, but Lu can't help you with this game right now. Don't worry—we're already working on getting it fixed as soon as possible. Thank you so much for giving Lu a try! Issue : \(errorMessage)")
                    completion(false)
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    self.showError("Sorry, but Lu can't help you with this game right now. Don't worry—we're already working on getting it fixed as soon as possible. Thank you so much for giving Lu a try! Issue : Received an invalid response. Please try again.")
                    luLog(.error,"check-rom error: invalid response \(response)")
                    completion(false)
                    return
                }
                
                switch httpResponse.statusCode {
                case 200:
                    if let data = data {
                        do {
                            let supportResponse = try JSONDecoder().decode(GameSupportResponse.self, from: data)

                            ExperimentalFeatures.shared.Lu.wrappedValue.activeGameId = supportResponse.game_id
                            
                            // Log successful response
                            luLog(.info, "Response [check-rom]: game_id=\(supportResponse.game_id), status=\(httpResponse.statusCode)")
                            
                            completion(true)
                        } catch {
                            luLog(.error, "check-rom decode error: \(error.localizedDescription)")
                            self.showError("Failed to process game support information")
                            completion(false)
                        }
                    }
                case 404:
                    luLog(.info, "Response [check-rom]: Game not available yet, status=\(httpResponse.statusCode)")
                    self.showUnsupportedGameMessage()
                    completion(false)
                case 500...599:
                    luLog(.error, "check-rom server error: Status \(httpResponse.statusCode)")
                    self.showError("Lu is temporarily unavailable. Please try again later.")
                    completion(false)
                    
                default:
                    luLog(.error, "check-rom unexpected error, status: \(httpResponse.statusCode)")
                    self.showError("Something unexpected happened. Please try again.")
                    completion(false)
                }
            }
        }
        
        task.resume()
    }
}
