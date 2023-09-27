async function forwardMessage(request, sender, sendResponse) {
    const response = await browser.runtime.sendNativeMessage(request);
    sendResponse(response);
    return true;
}

browser.runtime.onMessage.addListener(forwardMessage);
