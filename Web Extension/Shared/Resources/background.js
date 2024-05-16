function forwardMessage(request, sender, sendResponse) {
    return browser.runtime.sendNativeMessage(request);
}

browser.runtime.onMessage.addListener(forwardMessage);
