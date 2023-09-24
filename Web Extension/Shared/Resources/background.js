async function forwardMessage(request, sender, sendResponse) {
    console.log("Received request: ", request);
    const response = await browser.runtime.sendNativeMessage(request);
    console.log("Received response: ", response);
    sendResponse(response);
    return true;
}

browser.runtime.onMessage.addListener(forwardMessage);
