async function setupScriptsSection() {
    const scriptsToggle = document.getElementById("toggle-scripts");

    const scriptsEnabledResponse = await browser.runtime.sendMessage({ method: "getScriptsEnabled" });
    if (scriptsEnabledResponse && typeof(scriptsEnabledResponse.enabled) === "boolean") {
        scriptsToggle.checked = scriptsEnabledResponse.enabled;
    }

    scriptsToggle.addEventListener("change", async (event) => {
        const enable = event.currentTarget.checked;
            const response = await browser.runtime.sendMessage({
                method: "setScriptsEnabled",
                arguments: { enable }
            });
            if (!response || !response.succeed) {
                event.currentTarget.checked = !checked;
            }
    });

    // const openAppButton = document.getElementById("button-open-app");
    // openAppButton.onclick = () => {
    //     /// TODO: Try something to open the app
    // };
}

function buildSection(category) {
    const sectionNode = document.createElement("section");

    const headerNode = document.createElement("header");
    headerNode.textContent = category.name;
    sectionNode.appendChild(headerNode);

    const contentNode = document.createElement("div");
    contentNode.className = "list-content";
    for (const plugin of category.plugins) {
        const uuid = plugin.uuid;
        const toggleId = `toggle-plugin-${uuid}`;

        const rowNode = document.createElement("div");

        const labelNode = document.createElement("label");
        labelNode.textContent = plugin.name;
        labelNode.htmlFor = toggleId;
        rowNode.appendChild(labelNode);

        const toggleNode = document.createElement("input");
        toggleNode.type = "checkbox";
        toggleNode.id = toggleId;
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

    document.body.appendChild(sectionNode);
}

async function buildPluginSections() {
    const response = await browser.runtime.sendMessage({ method: "getPopupContentData" });
    if (!response || !response.categories) {
        console.error(`Invalid response: ${response}`);
        return;
    }

    for (const category of response.categories) {
        buildSection(category);
    }
}

setupScriptsSection();
buildPluginSections();
