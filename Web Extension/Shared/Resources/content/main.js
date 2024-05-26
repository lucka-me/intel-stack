async function execute() {
    const response = await browser.runtime.sendMessage({ method: "getInjectionData" });
    if (!response) {
        alert(browser.i18n.getMessage("error_invalid_response"));
        return;
    }

    if (response.error) {
        alert(response.error);
        return;
    }

    if (response.scripts.length === 0) {
        return;
    }

    const extraScriptNode = document.createElement("script");
    extraScriptNode.src = browser.runtime.getURL("content/extra.js");
    if ((response.device === 'iPad' || (response.device === 'vision'))) {
        extraScriptNode.dataset.renderPadding = 0.1;
    }
    document.head.appendChild(extraScriptNode);

    for (const script of response.scripts) {
        const node = document.createElement("script");
        node.textContent = script;
        document.head.appendChild(node);
    }

    if (response.warnings) {
        alert(response.warnings.join("\n"));
    }
}

execute();
