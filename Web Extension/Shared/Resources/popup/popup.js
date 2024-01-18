function buildScriptsSection(scriptsEnabled, mainNode) {
    const sectionNode = document.createElement("section");

    const contentNode = document.createElement("div");
    contentNode.className = "list-content";

    {
        const rowNode = document.createElement("div");

        const labelNode = document.createElement("label");
        labelNode.htmlFor = "toggle-scripts";

        const iconNode = document.createElement("i");
        iconNode.className = "icon icon-power";
        labelNode.appendChild(iconNode);

        const textNode = document.createElement("span");
        textNode.textContent = browser.i18n.getMessage("popup_scripts_enabled");
        labelNode.appendChild(textNode);

        rowNode.appendChild(labelNode);

        const toggleNode = document.createElement("input");
        toggleNode.type = "checkbox";
        toggleNode.id = labelNode.htmlFor;
        toggleNode.className = "toggle";
        toggleNode.checked = scriptsEnabled;
        toggleNode.addEventListener("change", async (event) => {
            const enable = event.currentTarget.checked;
            const response = await browser.runtime.sendMessage({
                method: "setScriptsEnabled",
                arguments: { enable }
            });
            if (!response || !response.succeed) {
                event.currentTarget.checked = !checked;
            }
        });
        rowNode.appendChild(toggleNode);

        contentNode.appendChild(rowNode);
    }

    sectionNode.appendChild(contentNode);

    mainNode.appendChild(sectionNode);
}

function buildSection(category, mainNode) {
    const sectionNode = document.createElement("section");
    sectionNode.className = "expandable";

    {
        const toggleNode = document.createElement("input");
        toggleNode.type = "checkbox";
        toggleNode.id = `toggle-section-${category.name}`;
        sectionNode.appendChild(toggleNode);

        const labelNode = document.createElement("label");
        labelNode.htmlFor = toggleNode.id;

        const contentNode = document.createElement("span");
        contentNode.textContent = category.name;
        labelNode.appendChild(contentNode);

        const indicatorNode = document.createElement("i");
        labelNode.appendChild(indicatorNode);

        sectionNode.appendChild(labelNode);
    }

    const contentNode = document.createElement("div");
    contentNode.className = "list-content";
    for (const plugin of category.plugins) {
        const uuid = plugin.uuid;

        const rowNode = document.createElement("div");

        const labelNode = document.createElement("label");
        labelNode.textContent = plugin.name;
        labelNode.htmlFor = `toggle-plugin-${uuid}`;
        rowNode.appendChild(labelNode);

        const toggleNode = document.createElement("input");
        toggleNode.type = "checkbox";
        toggleNode.id = labelNode.htmlFor;
        toggleNode.className = "toggle";
        toggleNode.checked = plugin.enabled;
        toggleNode.addEventListener("change", async (event) => {
            const enable = event.currentTarget.checked;
            const response = await browser.runtime.sendMessage({
                method: "setPluginEnabled",
                arguments: { uuid, enable }
            });
            if (!response || !response.succeed) {
                event.currentTarget.checked = !checked;
            }
        });
        rowNode.appendChild(toggleNode);

        contentNode.appendChild(rowNode);
    }
    sectionNode.appendChild(contentNode);

    mainNode.appendChild(sectionNode);
}

async function setupContents() {
    const response = await browser.runtime.sendMessage({ method: "getPopupContentData" });
    if (!response || !response.categories) {
        console.error(`Invalid response: ${response}`);
        return;
    }

    if (response.platform === "macOS") {
        document.body.classList.add("desktop");
    }

    const mainNode = document.createElement("main");

    buildScriptsSection(response.scriptsEnabled, mainNode);

    for (const category of response.categories) {
        buildSection(category, mainNode);
    }

    document.body.appendChild(mainNode);
}

setupContents();
