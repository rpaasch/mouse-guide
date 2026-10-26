import SafariServices

// Safari requires a principal class for a web extension. Wider keeps all its
// state in the extension's own storage and never messages the app, so this
// only answers with what it was sent.
final class SafariWebExtensionHandler: NSObject, NSExtensionRequestHandling {
    func beginRequest(with context: NSExtensionContext) {
        let response = NSExtensionItem()
        if let request = context.inputItems.first as? NSExtensionItem {
            response.userInfo = request.userInfo
        }
        context.completeRequest(returningItems: [response], completionHandler: nil)
    }
}
