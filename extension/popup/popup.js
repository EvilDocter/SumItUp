document.addEventListener("DOMContentLoaded", () => {
  const apiKeyInput = document.getElementById("api-key");
  const toggleKeyVisibilityBtn = document.getElementById("toggle-key-visibility");
  const modelSelect = document.getElementById("model-select");
  const floatingToggle = document.getElementById("floating-icon-toggle");
  const saveBtn = document.getElementById("save-settings-btn");
  const saveStatus = document.getElementById("save-status");
  const quickSummarizeBtn = document.getElementById("quick-summarize-btn");

  // Load existing settings
  chrome.storage.sync.get(["geminiApiKey", "model", "showFloatingIcon"], (data) => {
    if (data.geminiApiKey) apiKeyInput.value = data.geminiApiKey;
    if (data.model) modelSelect.value = data.model;
    if (data.showFloatingIcon !== undefined) floatingToggle.checked = data.showFloatingIcon;
  });

  // Toggle API key visibility
  toggleKeyVisibilityBtn.addEventListener("click", () => {
    if (apiKeyInput.type === "password") {
      apiKeyInput.type = "text";
      toggleKeyVisibilityBtn.textContent = "🔒";
    } else {
      apiKeyInput.type = "password";
      toggleKeyVisibilityBtn.textContent = "👁️";
    }
  });

  // Save settings
  saveBtn.addEventListener("click", () => {
    const key = apiKeyInput.value.trim();
    const model = modelSelect.value;
    const showFloating = floatingToggle.checked;

    chrome.storage.sync.set(
      {
        geminiApiKey: key,
        model: model,
        showFloatingIcon: showFloating
      },
      () => {
        saveStatus.classList.add("show");
        setTimeout(() => saveStatus.classList.remove("show"), 2000);
      }
    );
  });

  // Quick Summarize current tab
  quickSummarizeBtn.addEventListener("click", async () => {
    const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
    if (tab && tab.id) {
      chrome.tabs.sendMessage(tab.id, { action: "TRIGGER_SUMMARIZE" }, () => {
        window.close(); // Close popup once triggered
      });
    }
  });
});
