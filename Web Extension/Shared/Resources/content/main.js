function inject(scripts) {
    for (const script of scripts) {
        const node = document.createElement("script");
        node.textContent = script;
        document.head.appendChild(node);
    }

    const extraScriptNode = document.createElement("script");
    extraScriptNode.src = browser.runtime.getURL("content/inject.js");
    document.head.appendChild(extraScriptNode);
}

async function execute() {
    const response = await browser.runtime.sendMessage({ method: "getCodeForInjecting" });
    if (!response || !response.scripts) {
        console.error(`Invalid response: ${response}`);
        return;
    }
    if (response.scripts.length === 0) {
        return;
    }

    if (document.readyState !== "loading") {
        inject(response.scripts);
    } else {
        document.addEventListener("DOMContentLoaded", () => { inject(response.scripts); }, { once: true });
    }
}

execute();
