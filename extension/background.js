// SumItUp Background Service Worker (Manifest V3)
const DEFAULT_API_KEY = "";
const DEFAULT_MODEL = "gemini-3.5-flash-lite";

chrome.runtime.onInstalled.addListener(() => {
  chrome.storage.sync.get(["geminiApiKey", "model", "showFloatingIcon", "summaryStyle"], (data) => {
    const defaults = {};
    if (!data.geminiApiKey) defaults.geminiApiKey = DEFAULT_API_KEY;
    if (!data.model) defaults.model = DEFAULT_MODEL;
    if (data.showFloatingIcon === undefined) defaults.showFloatingIcon = true;
    if (!data.summaryStyle) defaults.summaryStyle = "balanced";
    
    if (Object.keys(defaults).length > 0) {
      chrome.storage.sync.set(defaults);
    }
  });
});

// Shortcut command listener (Cmd+Shift+S or Ctrl+Shift+S)
chrome.commands.onCommand.addListener(async (command) => {
  if (command === "summarize_page") {
    const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
    if (tab && tab.id) {
      chrome.tabs.sendMessage(tab.id, { action: "TRIGGER_SUMMARIZE" }).catch(() => {
        // Tab might not support content scripts (e.g. chrome://)
      });
    }
  }
});

// Relay Gemini API call from content script to bypass any host page CSP (Content Security Policy)
chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
  if (request.action === "GENERATE_SUMMARY") {
    callGeminiAPI(request.prompt, request.model, request.apiKey)
      .then((data) => sendResponse({ success: true, data }))
      .catch((err) => sendResponse({ success: false, error: err.message }));
    return true; // Keep channel open for async response
  }
});

async function callGeminiAPI(prompt, model = DEFAULT_MODEL, apiKey) {
  const key = apiKey || DEFAULT_API_KEY;
  if (!key || key.trim() === "") {
    throw new Error("No Gemini API key configured. Please enter your API key in extension settings.");
  }

  const selectedModel = model || DEFAULT_MODEL;
  const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/${selectedModel}:generateContent?key=${encodeURIComponent(key)}`;

  const response = await fetch(endpoint, {
    method: "POST",
    headers: {
      "Content-Type": "application/json"
    },
    body: JSON.stringify({
      contents: [
        {
          parts: [{ text: prompt }]
        }
      ]
    })
  });

  if (!response.ok) {
    const errorJson = await response.json().catch(() => ({}));
    const message = errorJson.error?.message || `API error (${response.status}: ${response.statusText})`;
    throw new Error(message);
  }

  const json = await response.json();
  const text = json.candidates?.[0]?.content?.parts?.map(p => p.text).filter(Boolean).join("\n");
  
  if (!text) {
    throw new Error("Gemini returned an empty response.");
  }

  return { text };
}
