function inject(scripts) {
    for (const script of scripts) {
        const element = document.createElement("script");
        element.textContent = script;
        document.head.appendChild(element);
    }
}

async function execute() {
    const response = await browser.runtime.sendMessage({ method: "getCodeForInjecting" });
    if (!response || !response.scripts) {
        console.error(`Invalid response: ${response}`);
        return;
    }

    if (document.readyState !== "loading") {
        inject(response.scripts);
    } else {
        document.addEventListener("DOMContentLoaded", () => {
            inject(response.scripts);
        });
    }
}

execute();
