function setupBeforeBoot() {
    // Set the RENDERER_PADDING for iPadOS to fix the canvas size overflow
    if ('renderPadding' in document.currentScript.dataset) {
        window.RENDERER_PADDING = parseFloat(document.currentScript.dataset.renderPadding);
    }
}

function setupAfterBoot() {
    if (!window.isSmartphone()) {
        return;
    }

    const playerStatNode = document.getElementById("playerstat");
    playerStatNode.style.display = "flex";

    // Create a dismiss button for info screen
    const closeButtonNode = document.createElement("span");
    closeButtonNode.textContent = "X";
    closeButtonNode.title = "Close info screen";
    closeButtonNode.style.border = "1px outset #20A8B1";
    closeButtonNode.style.color = "#FFCE00";
    closeButtonNode.style.fontSize = "16px";
    closeButtonNode.style.padding = "4px";
    closeButtonNode.style.margin = "3px 5px";
    closeButtonNode.addEventListener("click", () => { show('map'); });

    playerStatNode.prepend(closeButtonNode);
}

setupBeforeBoot();

if (window.iitcLoaded) {
    // Should never happens since the script is injected before IITC scripts
    setupAfterBoot();
} else {
    window.addHook("iitcLoaded", setupAfterBoot);
}
