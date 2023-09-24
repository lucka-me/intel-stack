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

    const scripts = response.scripts.map((item) => { return `(function() { ${item} })();` });
    if (document.readyState !== "loading") {
        inject(scripts);
    } else {
        document.addEventListener("DOMContentLoaded", () => {
            inject(scripts);
        });
    }
}

execute();
