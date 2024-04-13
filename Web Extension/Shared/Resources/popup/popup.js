function presentAlert(content) {
    const dialogNode = document.createElement("dialog");

    const contentNode = document.createElement("p");
    contentNode.textContent = content;
    dialogNode.appendChild(contentNode);

    {
        const actionsForm = document.createElement("form");
        actionsForm.method = "dialog";
    
        const closeButton = document.createElement("button");
        dialogNode.autofocus = true;
        closeButton.textContent = browser.i18n.getMessage("popup_alert_cancel");
        actionsForm.appendChild(closeButton);

        dialogNode.appendChild(actionsForm);
    }

    document.body.appendChild(dialogNode);

    dialogNode.addEventListener("close", () => { document.body.removeChild(dialogNode); });

    dialogNode.showModal();
}

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
            if (event.target === null) {
                return;
            }
            const enable = event.target.checked;
            const response = await browser.runtime.sendMessage({
                method: "setScriptsEnabled",
                arguments: { enable }
            });
            if (!response) {
                presentAlert(browser.i18n.getMessage("error_invalid_response"));
                event.target.checked = !enable;
                return;
            }
            if (response.error) {
                presentAlert(response.error);
                event.target.checked = !enable;
                return;
            }
            if (!response.succeed) {
                event.target.checked = !enable;
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
            if (event.target === null) {
                return;
            }
            const enable = event.target.checked;
            const response = await browser.runtime.sendMessage({
                method: "setPluginEnabled",
                arguments: { uuid, enable }
            });
            if (!response) {
                presentAlert(browser.i18n.getMessage("error_invalid_response"));
                event.target.checked = !enable;
                return;
            }
            if (response.error) {
                presentAlert(response.error);
                event.target.checked = !enable;
                return;
            }
            if (!response.succeed) {
                event.target.checked = !enable;
            }
        });
        rowNode.appendChild(toggleNode);

        contentNode.appendChild(rowNode);
    }
    sectionNode.appendChild(contentNode);

    mainNode.appendChild(sectionNode);
}

function setupWithError(error, mainNode) {
    mainNode.classList.add("error");

    const textNode = document.createElement("p");
    textNode.textContent = error;

    mainNode.appendChild(textNode);
}

async function setupContents() {
    const response = await browser.runtime.sendMessage({ method: "getPopupContentData" });

    const mainNode = document.createElement("main");
    document.body.appendChild(mainNode);

    if (!response) {
        setupWithError(browser.i18n.getMessage("error_invalid_response"), mainNode);
        return;
    }

    if (response.platform === "macOS") {
        document.body.classList.add("desktop");
    }

    if (response.error) {
        console.log(response);
        setupWithError(response.error, mainNode);
        return;
    }

    buildScriptsSection(response.scriptsEnabled, mainNode);

    for (const category of response.categories) {
        buildSection(category, mainNode);
    }
}

setupContents();
