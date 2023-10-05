function sleep(interval) {
    return new Promise(resolve => setTimeout(resolve, interval));
}

async function execute() {
    while (!window.isSmartphone) {
        await sleep(100);
    }
    if (!window.isSmartphone()) {
        return;
    }

    // Create a dismiss button for details sheet
    const toolboxNode = document.getElementById("toolbox");
    const dismissButtonNode = document.createElement("a");
    dismissButtonNode.textContent = "Dismiss"
    dismissButtonNode.addEventListener("click", () => { show('map'); });
    toolboxNode.appendChild(dismissButtonNode);
}

execute();