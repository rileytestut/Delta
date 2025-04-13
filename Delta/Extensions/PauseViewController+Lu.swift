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
    let sha1: String
    let question: String
    let remember_conversation: Bool
    let attachments: [APIContext.Attachment]?

    // Add an initializer with a default value for remember_conversation and attachments
    init(game_id: String,
        question: String,
        sha1: String,
        remember_conversation: Bool = false,
        attachments: [APIContext.Attachment]? = nil) {
        self.game_id = game_id
        self.sha1 = sha1
        self.question = question
        self.remember_conversation = remember_conversation
        self.attachments = attachments
    }
}

private struct LuResponse: Codable {
    let message_id: String
    let answer: String
}

private struct GameSupportResponse: Codable {
    let game_id: String
    let supports_attachments: Bool?
    let supports_savestates: Bool?
}

private struct FeedbackRequest: Codable {
    let message_id: String
    let feedback: String
    let feedback_message: String?
}


private struct APIContext: Codable {
    let device_context: DeviceContext
    let game_context: GameContext
    let attachments: [Attachment]?

    // Add a header-only version of context
    var headerContext: HeaderContext {
        HeaderContext(
            device_context: device_context,
            game_context: game_context
        )
    }

    // New structure for header-only context
    struct HeaderContext: Codable {
        let device_context: DeviceContext
        let game_context: GameContext
    }

    struct DeviceContext: Codable {
        let device_id: String
        let device_name: String
        let system_name: String
        let system_version: String
        let model: String
        let bundle_id: String
    }

    struct SaveStateMetadata: Codable {
        let name: String
        let creation_date: String
        let modified_date: String
        let type: String
    }

    struct GameContext: Codable {
        let name: String
        let identifier: String
        let type: String
        let save_states_count: Int
        let cheats_count: Int
        let last_played: String?
        let save_states_metadata: [String: SaveStateMetadata]?
    }

    struct Attachment: Codable {
        let type: String
        let content: String
        let filename: String
    }
}

private extension URLRequest {
    mutating func addContextHeaders(context: APIContext) {
        if let contextData = try? JSONEncoder().encode(context.headerContext),
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
    
    private func createAPIContext(for game: Game, includeAttachments: Bool = false) -> APIContext {
        let deviceContext = APIContext.DeviceContext(
            device_id: UIDevice.current.identifierForVendor?.uuidString ?? "unknown",
            device_name: UIDevice.current.name,
            system_name: UIDevice.current.systemName,
            system_version: UIDevice.current.systemVersion,
            model: UIDevice.current.model,
            bundle_id: Bundle.main.bundleIdentifier ?? "unknown"
        )

        // Create save states metadata only if shareGameplayData is enabled
        var saveStatesMetadata: [String: APIContext.SaveStateMetadata] = [:]

        if ExperimentalFeatures.shared.Lu.wrappedValue.shareGameplayData {
            let saveStates = SaveState.instancesWithPredicate(
                NSPredicate(format: "%K == %@", #keyPath(SaveState.game), game),
                inManagedObjectContext: DatabaseManager.shared.viewContext,
                type: SaveState.self
            )

            for saveState in saveStates {
                saveStatesMetadata[saveState.identifier] = APIContext.SaveStateMetadata(
                    name: saveState.name ?? "Untitled",
                    creation_date: saveState.creationDate.ISO8601String(),
                    modified_date: saveState.modifiedDate.ISO8601String(),
                    type: {
                        switch saveState.type {
                        case .auto: return "auto"
                        case .quick: return "quick"
                        case .general: return "general"
                        case .locked: return "locked"
                        }
                    }()  // Immediately execute this inline closure
                )
            }

            // Log the metadata collection
            if !saveStatesMetadata.isEmpty {
                luLog(.info, "Added \(saveStatesMetadata.count) save states to context metadata")
            }
        } else {
            luLog(.info, "Not including save state metadata (user has not enabled shareGameplayData)")
        }

        let gameContext = APIContext.GameContext(
            name: game.name,
            identifier: game.identifier,
            type: game.type.rawValue,
            save_states_count: game.saveStates.count,
            cheats_count: game.cheats.count,
            last_played: game.playedDate?.ISO8601String(),
            save_states_metadata: ExperimentalFeatures.shared.Lu.wrappedValue.shareGameplayData && !saveStatesMetadata.isEmpty ? saveStatesMetadata : nil
        )
        // Prepare attachments only if explicitly requested
        var attachments: [APIContext.Attachment]? = nil

        if includeAttachments, let emulatorCore = self.emulatorCore {
            // Create a collection of attachments
            var contextAttachments: [APIContext.Attachment] = []
            var tempSaveStateURL: URL? = nil

            // 1. Capture screenshot if available and supported
            if includeAttachments && ExperimentalFeatures.shared.Lu.wrappedValue.supportsAttachments,
               let snapshot = emulatorCore.videoManager.snapshot(),
               let imageData = snapshot.pngData() {

                // Generate timestamp for filename
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
                let timestamp = dateFormatter.string(from: Date())

                // Log screenshot info
                let dataPrefix = imageData.prefix(16)
                let hexString = dataPrefix.map { String(format: "%02x", $0) }.joined()
                luLog(.info, "Screenshot data prefix: \(hexString)")
                luLog(.info, "Screenshot size: \(imageData.count) bytes")

                let screenshotAttachment = APIContext.Attachment(
                    type: "screenshot",
                    content: imageData.base64EncodedString(),
                    filename: "screen_\(timestamp).png"
                )

                contextAttachments.append(screenshotAttachment)
                luLog(.info, "Added screenshot to API context")
            } else if !ExperimentalFeatures.shared.Lu.wrappedValue.supportsAttachments {
                luLog(.info, "Screenshots not supported for this game - skipping")
            }

            // 2. Capture current game state if supported
            if includeAttachments && ExperimentalFeatures.shared.Lu.wrappedValue.supportsSavestates {
                tempSaveStateURL = FileManager.default.temporaryDirectory.appendingPathComponent("lu_temp_\(UUID().uuidString)")
                let tempSaveState = emulatorCore.saveSaveState(to: tempSaveStateURL!)
                if let saveStateData = try? Data(contentsOf: tempSaveState.fileURL) {
                    let saveStateAttachment = APIContext.Attachment(
                        type: "save_state",
                        content: saveStateData.base64EncodedString(),
                        filename: "state_\(tempSaveStateURL!)"
                    )
                    contextAttachments.append(saveStateAttachment)
                    luLog(.info, "Added current save state to API context (size: \(saveStateData.count) bytes)")
                    
                    // Clean up temporary save state file
                    if let url = tempSaveStateURL {
                        luLog(.debug, "Attempting to delete temporary save state file at: \(url.path)")
                        do {
                            try FileManager.default.removeItem(at: url)
                            luLog(.info, "Successfully deleted temporary save state file")
                        } catch let error {
                            luLog(.error, "Failed to delete temporary save state file: \(error.localizedDescription)")
                        }
                    }
                }
            } else {
                luLog(.info, "Save states not supported for this game - skipping")
            }

            // Set the attachments if we have any
            if !contextAttachments.isEmpty {
                attachments = contextAttachments
                luLog(.info, "Added \(contextAttachments.count) attachments to API context")
            }

            
        }

        return APIContext(
            device_context: deviceContext,
            game_context: gameContext,
            attachments: attachments
        )
    }
    
    func configureLuMenuItem() -> MenuItem {
        return MenuItem(text: NSLocalizedString("Ask Lu", comment: ""),
                        image: #imageLiteral(resourceName: "Lu"),
                        action: { [weak self] menuItem in
            guard let self = self,
                  let game = self.emulatorCore?.game as? Game else {
                return
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
            message: NSLocalizedString("We and our service providers may record your chat with us. By using this chat, you agree to our Terms of Service and Privacy Policy. \n \n https://www.lulabs.ai/legal", comment: ""),
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
        
        // Check if user has opted in to sharing gameplay data
        let shouldIncludeAttachments = ExperimentalFeatures.shared.Lu.wrappedValue.shareGameplayData

        if shouldIncludeAttachments {
            luLog(.info, "Including gameplay data with question (user opted in, supports_attachments=\(ExperimentalFeatures.shared.Lu.wrappedValue.supportsAttachments), supports_savestates=\(ExperimentalFeatures.shared.Lu.wrappedValue.supportsSavestates))")
        } else {
            luLog(.info, "Not including gameplay data with question (user opted out)")
        }
        // Create context and include attachments only if user has opted in
        let context = createAPIContext(for: game, includeAttachments: shouldIncludeAttachments)
        
        let request = LuRequest(
            game_id: activeGameId,
            question: question, sha1: game.identifier.uppercased(),
            remember_conversation: ExperimentalFeatures.shared.Lu.wrappedValue.rememberConversations,
            attachments: context.attachments
        )

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = APIConstants.askTimeout
        
        urlRequest.addContextHeaders(context: context)
        
        do {
            // Encode the request body
            let requestData = try JSONEncoder().encode(request)
            urlRequest.httpBody = requestData

            // Log the request body and attachment information
            let totalSize = requestData.count
            luLog(.info, "Request payload size: \(totalSize) bytes")

            // Log attachment information
            if let attachments = context.attachments {
                luLog(.info, "Request includes \(attachments.count) attachments:")
                for (index, attachment) in attachments.enumerated() {
                    let contentSize = attachment.content.count
                    luLog(.info, "  [\(index + 1)] Type: \(attachment.type), Filename: \(attachment.filename), Content size: \(contentSize) bytes")
                }
            } else {
                luLog(.info, "Request does not include any attachments")
            }

            // Only log the full request body if it's not too large
            if totalSize < 10000 { // Don't log huge payloads with attachments
                if let requestString = String(data: requestData, encoding: .utf8) {
                    luLog(.info, "Request body: \(requestString)")
                }
            } else {
                // For large payloads, create a compact representation
                var requestInfo: [String: Any] = [
                    "game_id": activeGameId,
                    "question": question,
                    "remember_conversation": ExperimentalFeatures.shared.Lu.wrappedValue.rememberConversations
                ]

                if let attachments = context.attachments {
                    var attachmentInfo: [[String: Any]] = []
                    for attachment in attachments {
                        attachmentInfo.append([
                            "type": attachment.type,
                            "filename": attachment.filename,
                            "content_size": attachment.content.count
                        ])
                    }
                    requestInfo["attachments"] = attachmentInfo
                }

                if let compactJson = try? JSONSerialization.data(withJSONObject: requestInfo),
                   let compactString = String(data: compactJson, encoding: .utf8) {
                    luLog(.info, "Request body (summarized): \(compactString)")
                }
            }

            // Log all request headers
            luLog(.info, "Request headers:")
            for (header, value) in urlRequest.allHTTPHeaderFields ?? [:] {
                if header == "x-lu-context" {
                    luLog(.info, "  \(header): [context object - logged above]")
                } else {
                    luLog(.info, "  \(header): \(value)")
                }
            }

            luLog(.info, "Request prepared successfully, about to send to \(urlString)")
        } catch {
            luLog(.error, "Failed to encode request: \(error.localizedDescription)")
            loadingAlert.dismiss(animated: true)
            self.showError("Failed to prepare your question")
            return
        }



        luLog(.info, "Making request to URL: \(urlString). Options : Remember Conversation(\(ExperimentalFeatures.shared.Lu.wrappedValue.rememberConversations)), Share Gameplay Data(\(shouldIncludeAttachments))")
        
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
        
        // This endpoint doesn't need gameplay attachments
        let context = createAPIContext(for: game, includeAttachments: false)
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
        
        // This endpoint doesn't need gameplay attachments
        let context = createAPIContext(for: game, includeAttachments: false)
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
                            // Store the supports_attachments and supports_savestates flags
                            let supportsAttachments = supportResponse.supports_attachments ?? false
                            let supportsSavestates = supportResponse.supports_savestates ?? false
                            ExperimentalFeatures.shared.Lu.wrappedValue.supportsAttachments = supportsAttachments
                            ExperimentalFeatures.shared.Lu.wrappedValue.supportsSavestates = supportsSavestates
                            
                            // Log successful response
                            luLog(.info, "Response [check-rom]: game_id=\(supportResponse.game_id), supports_attachments=\(supportsAttachments), supports_savestates=\(supportsSavestates), status=\(httpResponse.statusCode)")
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
