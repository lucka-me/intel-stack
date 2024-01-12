async function execute() {
    const response = await browser.runtime.sendMessage({ method: "getInjectionData" });
    if (!response || !response.scripts) {
        console.error(`Invalid response: ${response}`);
        return;
    }
    if (response.scripts.length === 0) {
        return;
    }

    const extraScriptNode = document.createElement("script");
    extraScriptNode.src = browser.runtime.getURL("content/prepare.js");
    if ((response.device === 'iPad' || (response.device === 'vision'))) {
        extraScriptNode.dataset.renderPadding = 0.1;
    }
    document.head.appendChild(extraScriptNode);

    for (const script of response.scripts) {
        const node = document.createElement("script");
        node.textContent = script;
        document.head.appendChild(node);
    }
}

execute();
