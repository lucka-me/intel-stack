const scriptDataset = document.currentScript.dataset;

function setupBeforeBoot() {
    // Set the RENDERER_PADDING for iPadOS to fix the canvas size overflow
    if ("renderPadding" in scriptDataset) {
        window.RENDERER_PADDING = parseFloat(scriptDataset.renderPadding);
    }
}

function setupAfterBoot() {
    if (window.isSmartphone()) {
        const playerStatNode = document.getElementById("playerstat");
        playerStatNode.style.display = "flex";

        // Create a dismiss button for info screen
        const closeButtonNode = document.createElement("span");
        closeButtonNode.id = "extra-ios-close-info-screen";
        closeButtonNode.textContent = "X";
        closeButtonNode.title = "Close info screen";
        closeButtonNode.addEventListener("click", () => { show("map"); });

        playerStatNode.prepend(closeButtonNode);
    }

    // Inject extra CSS
    if ("extraStyleURL" in scriptDataset) {
        const extraStyleNode = document.createElement("link");
        extraStyleNode.rel = "stylesheet";
        extraStyleNode.type = "text/css";
        extraStyleNode.href = scriptDataset.extraStyleURL;
        document.head.appendChild(extraStyleNode);
    }
}

setupBeforeBoot();

if (window.iitcLoaded) {
    // Should never happens since the script is injected before IITC scripts
    setupAfterBoot();
} else {
    window.addHook("iitcLoaded", setupAfterBoot);
}
