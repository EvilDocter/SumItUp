// SumItUp Content Script - Floating Grammarly & Shazam-style AI Summarizer
(function () {
  if (window.__SUMITUP_INITIALIZED__) return;
  window.__SUMITUP_INITIALIZED__ = true;

  // Create isolated container host
  const host = document.createElement("div");
  host.id = "sumitup-extension-host";
  document.body.appendChild(host);

  const shadow = host.attachShadow({ mode: "open" });

  // Load stylesheet inside Shadow DOM
  const styleEl = document.createElement("style");
  styleEl.textContent = `
    :host {
      all: initial;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
      font-size: 14px;
      line-height: 1.5;
      color: #1e293b;
      -webkit-font-smoothing: antialiased;
      z-index: 2147483647;
      position: fixed;
      pointer-events: none;
      top: 0;
      left: 0;
      width: 100vw;
      height: 100vh;
    }

    * {
      box-sizing: border-box;
      margin: 0;
      padding: 0;
    }

    /* Floating Bubble (Grammarly / Shazam style) */
    .sumitup-bubble-wrapper {
      position: fixed;
      bottom: 28px;
      right: 28px;
      pointer-events: auto;
      z-index: 2147483647;
      user-select: none;
      touch-action: none;
    }

    .sumitup-bubble {
      width: 52px;
      height: 52px;
      border-radius: 50%;
      background: linear-gradient(135deg, #4f46e5 0%, #7c3aed 50%, #06b6d4 100%);
      box-shadow: 0 10px 25px -5px rgba(79, 70, 229, 0.5), 0 8px 10px -6px rgba(79, 70, 229, 0.4);
      display: flex;
      align-items: center;
      justify-content: center;
      cursor: pointer;
      position: relative;
      transition: transform 0.22s cubic-bezier(0.34, 1.56, 0.64, 1), box-shadow 0.22s ease;
      border: 2px solid rgba(255, 255, 255, 0.35);
      backdrop-filter: blur(8px);
    }

    .sumitup-bubble:hover {
      transform: scale(1.08) translateY(-2px);
      box-shadow: 0 14px 30px -4px rgba(79, 70, 229, 0.65), 0 10px 12px -5px rgba(6, 182, 212, 0.5);
    }

    .sumitup-bubble:active {
      transform: scale(0.96);
    }

    /* Shazam Pulsing Halo Ring */
    .sumitup-bubble::before {
      content: "";
      position: absolute;
      inset: -6px;
      border-radius: 50%;
      background: radial-gradient(circle, rgba(99, 102, 241, 0.4) 0%, rgba(6, 182, 212, 0) 70%);
      opacity: 0.8;
      animation: pulse-ring 2.4s cubic-bezier(0.215, 0.61, 0.355, 1) infinite;
      pointer-events: none;
      z-index: -1;
    }

    @keyframes pulse-ring {
      0% {
        transform: scale(0.85);
        opacity: 0.9;
      }
      50% {
        transform: scale(1.35);
        opacity: 0.2;
      }
      100% {
        transform: scale(1.6);
        opacity: 0;
      }
    }

    .sumitup-bubble svg {
      width: 24px;
      height: 24px;
      fill: #ffffff;
      filter: drop-shadow(0 2px 4px rgba(0, 0, 0, 0.2));
      transition: transform 0.3s ease;
    }

    .sumitup-bubble:hover svg {
      transform: rotate(12deg) scale(1.08);
    }

    /* Tooltip */
    .sumitup-tooltip {
      position: absolute;
      right: 64px;
      top: 50%;
      transform: translateY(-50%) translateX(6px);
      background: #0f172a;
      color: #f8fafc;
      font-size: 12px;
      font-weight: 500;
      padding: 6px 12px;
      border-radius: 8px;
      white-space: nowrap;
      pointer-events: none;
      opacity: 0;
      visibility: hidden;
      transition: all 0.2s cubic-bezier(0.16, 1, 0.3, 1);
      box-shadow: 0 4px 14px rgba(0, 0, 0, 0.25);
      border: 1px solid rgba(255, 255, 255, 0.1);
    }

    .sumitup-tooltip::after {
      content: "";
      position: absolute;
      right: -4px;
      top: 50%;
      transform: translateY(-50%) rotate(45deg);
      width: 8px;
      height: 8px;
      background: #0f172a;
    }

    .sumitup-bubble-wrapper:hover .sumitup-tooltip {
      opacity: 1;
      visibility: visible;
      transform: translateY(-50%) translateX(0);
    }

    /* Floating Modal Drawer (Glassmorphic) */
    .sumitup-drawer {
      position: fixed;
      bottom: 92px;
      right: 28px;
      width: 440px;
      max-width: calc(100vw - 40px);
      max-height: calc(100vh - 120px);
      background: rgba(255, 255, 255, 0.94);
      backdrop-filter: blur(24px) saturate(180%);
      -webkit-backdrop-filter: blur(24px) saturate(180%);
      border: 1px solid rgba(226, 232, 240, 0.85);
      border-radius: 20px;
      box-shadow: 0 25px 60px -15px rgba(15, 23, 42, 0.25), 0 0 0 1px rgba(0, 0, 0, 0.04);
      display: flex;
      flex-direction: column;
      pointer-events: auto;
      overflow: hidden;
      opacity: 0;
      visibility: hidden;
      transform: translateY(16px) scale(0.97);
      transition: all 0.28s cubic-bezier(0.16, 1, 0.3, 1);
      z-index: 2147483647;
    }

    @media (prefers-color-scheme: dark) {
      .sumitup-drawer {
        background: rgba(15, 23, 42, 0.92);
        border: 1px solid rgba(255, 255, 255, 0.12);
        box-shadow: 0 25px 60px -15px rgba(0, 0, 0, 0.65), 0 0 0 1px rgba(255, 255, 255, 0.08);
        color: #f1f5f9;
      }
    }

    .sumitup-drawer.open {
      opacity: 1;
      visibility: visible;
      transform: translateY(0) scale(1);
    }

    /* Modal Header */
    .sumitup-header {
      padding: 16px 20px;
      border-bottom: 1px solid rgba(226, 232, 240, 0.8);
      display: flex;
      align-items: center;
      justify-content: space-between;
      background: linear-gradient(to right, rgba(99, 102, 241, 0.06), rgba(6, 182, 212, 0.04));
    }

    @media (prefers-color-scheme: dark) {
      .sumitup-header {
        border-bottom: 1px solid rgba(255, 255, 255, 0.08);
      }
    }

    .sumitup-brand {
      display: flex;
      align-items: center;
      gap: 10px;
    }

    .sumitup-logo-badge {
      width: 28px;
      height: 28px;
      border-radius: 8px;
      background: linear-gradient(135deg, #4f46e5, #06b6d4);
      display: flex;
      align-items: center;
      justify-content: center;
    }

    .sumitup-logo-badge svg {
      width: 15px;
      height: 15px;
      fill: #fff;
    }

    .sumitup-title {
      font-weight: 700;
      font-size: 15px;
      letter-spacing: -0.01em;
      background: linear-gradient(135deg, #4f46e5 0%, #06b6d4 100%);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
    }

    .sumitup-badge-tag {
      font-size: 10px;
      font-weight: 600;
      text-transform: uppercase;
      letter-spacing: 0.05em;
      padding: 2px 7px;
      border-radius: 12px;
      background: rgba(99, 102, 241, 0.12);
      color: #6366f1;
    }

    .sumitup-actions-top {
      display: flex;
      align-items: center;
      gap: 6px;
    }

    .sumitup-btn-icon {
      background: transparent;
      border: none;
      width: 30px;
      height: 30px;
      border-radius: 8px;
      cursor: pointer;
      display: flex;
      align-items: center;
      justify-content: center;
      color: #64748b;
      transition: all 0.15s ease;
    }

    .sumitup-btn-icon:hover {
      background: rgba(148, 163, 184, 0.18);
      color: #0f172a;
    }

    @media (prefers-color-scheme: dark) {
      .sumitup-btn-icon {
        color: #94a3b8;
      }
      .sumitup-btn-icon:hover {
        background: rgba(255, 255, 255, 0.1);
        color: #f8fafc;
      }
    }

    .sumitup-btn-icon svg {
      width: 16px;
      height: 16px;
      fill: currentColor;
    }

    /* Style Pills Filter Bar */
    .sumitup-pills-bar {
      display: flex;
      align-items: center;
      gap: 6px;
      padding: 10px 18px;
      overflow-x: auto;
      border-bottom: 1px solid rgba(226, 232, 240, 0.6);
      background: rgba(248, 250, 252, 0.6);
      scrollbar-width: none;
    }

    .sumitup-pills-bar::-webkit-scrollbar {
      display: none;
    }

    @media (prefers-color-scheme: dark) {
      .sumitup-pills-bar {
        background: rgba(15, 23, 42, 0.5);
        border-bottom: 1px solid rgba(255, 255, 255, 0.05);
      }
    }

    .sumitup-pill {
      font-size: 11.5px;
      font-weight: 500;
      padding: 5px 11px;
      border-radius: 20px;
      background: transparent;
      color: #64748b;
      border: 1px solid rgba(148, 163, 184, 0.3);
      cursor: pointer;
      white-space: nowrap;
      transition: all 0.15s ease;
    }

    .sumitup-pill:hover {
      border-color: #6366f1;
      color: #6366f1;
    }

    .sumitup-pill.active {
      background: #6366f1;
      color: #ffffff;
      border-color: #6366f1;
      font-weight: 600;
      box-shadow: 0 2px 8px rgba(99, 102, 241, 0.35);
    }

    /* Content Area */
    .sumitup-body {
      padding: 18px 20px;
      overflow-y: auto;
      flex: 1;
      max-height: 440px;
      min-height: 190px;
      scroll-behavior: smooth;
    }

    .sumitup-body::-webkit-scrollbar {
      width: 6px;
    }
    .sumitup-body::-webkit-scrollbar-thumb {
      background: rgba(148, 163, 184, 0.3);
      border-radius: 10px;
    }

    /* Article Meta Info */
    .sumitup-meta-info {
      display: flex;
      align-items: center;
      justify-content: space-between;
      font-size: 11.5px;
      color: #64748b;
      margin-bottom: 14px;
      padding-bottom: 10px;
      border-bottom: 1px dashed rgba(226, 232, 240, 0.8);
    }

    @media (prefers-color-scheme: dark) {
      .sumitup-meta-info {
        border-bottom-color: rgba(255, 255, 255, 0.1);
        color: #94a3b8;
      }
    }

    .sumitup-meta-left {
      display: flex;
      align-items: center;
      gap: 6px;
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
      max-width: 65%;
      font-weight: 500;
    }

    .sumitup-meta-right {
      display: flex;
      align-items: center;
      gap: 8px;
    }

    .sumitup-saved-time {
      color: #10b981;
      font-weight: 600;
      background: rgba(16, 185, 129, 0.1);
      padding: 2px 7px;
      border-radius: 6px;
    }

    /* AI Pulsing Loading Animation */
    .sumitup-loading {
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      padding: 36px 12px;
      text-align: center;
    }

    .ai-orb {
      width: 44px;
      height: 44px;
      border-radius: 50%;
      background: linear-gradient(135deg, #6366f1, #06b6d4);
      box-shadow: 0 0 0 0 rgba(99, 102, 241, 0.7);
      animation: orb-pulse 1.5s cubic-bezier(0.2, 0.6, 0.4, 1) infinite;
      margin-bottom: 18px;
      display: flex;
      align-items: center;
      justify-content: center;
    }

    .ai-orb svg {
      width: 22px;
      height: 22px;
      fill: #fff;
    }

    @keyframes orb-pulse {
      0% {
        box-shadow: 0 0 0 0 rgba(99, 102, 241, 0.7);
      }
      70% {
        box-shadow: 0 0 0 20px rgba(99, 102, 241, 0);
      }
      100% {
        box-shadow: 0 0 0 0 rgba(99, 102, 241, 0);
      }
    }

    .sumitup-loading-text {
      font-weight: 600;
      font-size: 14px;
      color: #4f46e5;
      margin-bottom: 6px;
    }

    .sumitup-loading-sub {
      font-size: 12px;
      color: #64748b;
      margin-bottom: 20px;
    }

    .shimmer-line {
      height: 10px;
      width: 100%;
      margin-bottom: 10px;
      border-radius: 6px;
      background: linear-gradient(90deg, rgba(148, 163, 184, 0.15) 25%, rgba(148, 163, 184, 0.35) 50%, rgba(148, 163, 184, 0.15) 75%);
      background-size: 200% 100%;
      animation: shimmer-sweep 1.6s infinite;
    }

    @keyframes shimmer-sweep {
      0% { background-position: 200% 0; }
      100% { background-position: -200% 0; }
    }

    /* Formatted Summary Content */
    .sumitup-summary-content {
      font-size: 13.5px;
      line-height: 1.68;
      color: #334155;
    }

    @media (prefers-color-scheme: dark) {
      .sumitup-summary-content {
        color: #cbd5e1;
      }
    }

    .sumitup-summary-content p {
      margin-bottom: 12px;
    }

    .sumitup-summary-content ul, .sumitup-summary-content ol {
      margin-left: 20px;
      margin-bottom: 12px;
    }

    .sumitup-summary-content li {
      margin-bottom: 6px;
    }

    .sumitup-summary-content strong {
      color: #0f172a;
      font-weight: 600;
    }

    @media (prefers-color-scheme: dark) {
      .sumitup-summary-content strong {
        color: #f8fafc;
      }
    }

    .sumitup-summary-content h2, .sumitup-summary-content h3 {
      font-size: 14.5px;
      font-weight: 700;
      margin-top: 14px;
      margin-bottom: 6px;
      color: #1e293b;
    }

    @media (prefers-color-scheme: dark) {
      .sumitup-summary-content h2, .sumitup-summary-content h3 {
        color: #f1f5f9;
      }
    }

    /* Footer Toolbar */
    .sumitup-footer {
      padding: 12px 20px;
      border-top: 1px solid rgba(226, 232, 240, 0.8);
      background: rgba(248, 250, 252, 0.7);
      display: flex;
      align-items: center;
      justify-content: space-between;
    }

    @media (prefers-color-scheme: dark) {
      .sumitup-footer {
        border-top-color: rgba(255, 255, 255, 0.08);
        background: rgba(15, 23, 42, 0.7);
      }
    }

    .sumitup-btn {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      font-size: 12px;
      font-weight: 600;
      padding: 7px 13px;
      border-radius: 8px;
      cursor: pointer;
      border: 1px solid rgba(148, 163, 184, 0.3);
      background: #ffffff;
      color: #334155;
      transition: all 0.15s ease;
    }

    @media (prefers-color-scheme: dark) {
      .sumitup-btn {
        background: rgba(30, 41, 59, 0.8);
        color: #e2e8f0;
        border-color: rgba(255, 255, 255, 0.12);
      }
    }

    .sumitup-btn:hover {
      background: #f1f5f9;
      border-color: #94a3b8;
    }

    .sumitup-btn-primary {
      background: linear-gradient(135deg, #4f46e5, #6366f1);
      color: #ffffff;
      border: none;
    }

    .sumitup-btn-primary:hover {
      background: linear-gradient(135deg, #4338ca, #4f46e5);
      color: #ffffff;
    }

    .sumitup-btn svg {
      width: 14px;
      height: 14px;
      fill: currentColor;
    }

    .sumitup-footer-left {
      display: flex;
      align-items: center;
      gap: 8px;
    }

    .sumitup-toast {
      font-size: 11.5px;
      color: #10b981;
      font-weight: 600;
      opacity: 0;
      transition: opacity 0.2s ease;
    }
    .sumitup-toast.show {
      opacity: 1;
    }
  `;
  shadow.appendChild(styleEl);

  // SVG Icons constants
  const SPARKLE_SVG = `<svg viewBox="0 0 24 24"><path d="M12 2L14.4 9.6L22 12L14.4 14.4L12 22L9.6 14.4L2 12L9.6 9.6L12 2Z"/></svg>`;
  const CLOSE_SVG = `<svg viewBox="0 0 24 24"><path d="M19 6.41L17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12z"/></svg>`;
  const COPY_SVG = `<svg viewBox="0 0 24 24"><path d="M16 1H4C2.9 1 2 1.9 2 3V17H4V3H16V1ZM19 5H8C6.9 5 6 5.9 6 7V21C6 22.1 6.9 23 8 23H19C20.1 23 21 22.1 21 21V7C21 5.9 20.1 5 19 5ZM19 21H8V7H19V21Z"/></svg>`;
  const SPEAKER_SVG = `<svg viewBox="0 0 24 24"><path d="M3 9V15H7L12 20V4L7 9H3ZM16.5 12C16.5 10.23 15.48 8.71 14 7.97V16.02C15.48 15.29 16.5 13.77 16.5 12ZM14 3.23V5.29C16.89 6.15 19 8.83 19 12C19 15.17 16.89 17.85 14 18.71V20.77C18.01 19.86 21 16.28 21 12C21 7.72 18.01 4.14 14 3.23Z"/></svg>`;
  const REFRESH_SVG = `<svg viewBox="0 0 24 24"><path d="M17.65 6.35C16.2 4.9 14.21 4 12 4c-4.42 0-7.99 3.58-7.99 8s3.57 8 7.99 8c3.73 0 6.84-2.55 7.73-6h-2.08c-.82 2.33-3.04 4-5.65 4-3.31 0-6-2.69-6-6s2.69-6 6-6c1.66 0 3.14.69 4.22 1.78L13 11h7V4l-2.35 2.35z"/></svg>`;

  // Create UI Structure
  const wrapper = document.createElement("div");
  wrapper.className = "sumitup-bubble-wrapper";

  wrapper.innerHTML = `
    <div class="sumitup-tooltip">Summarize page (SumItUp)</div>
    <div class="sumitup-bubble" id="sumitup-trigger" title="Click to summarize this page">
      ${SPARKLE_SVG}
    </div>
  `;
  shadow.appendChild(wrapper);

  // Modal Drawer
  const drawer = document.createElement("div");
  drawer.className = "sumitup-drawer";
  drawer.innerHTML = `
    <div class="sumitup-header">
      <div class="sumitup-brand">
        <div class="sumitup-logo-badge">${SPARKLE_SVG}</div>
        <div class="sumitup-title">SumItUp</div>
        <span class="sumitup-badge-tag">Gemini AI</span>
      </div>
      <div class="sumitup-actions-top">
        <button class="sumitup-btn-icon" id="sumitup-refresh-btn" title="Re-summarize">${REFRESH_SVG}</button>
        <button class="sumitup-btn-icon" id="sumitup-close-btn" title="Close">${CLOSE_SVG}</button>
      </div>
    </div>

    <div class="sumitup-pills-bar">
      <button class="sumitup-pill active" data-style="balanced">⚡ Quick Overview</button>
      <button class="sumitup-pill" data-style="takeaways">🎯 Key Takeaways</button>
      <button class="sumitup-pill" data-style="deepdive">🔬 Deep Dive</button>
      <button class="sumitup-pill" data-style="eli5">👶 Explain Like I'm 5</button>
    </div>

    <div class="sumitup-body" id="sumitup-content-body">
      <!-- Injected dynamically -->
    </div>

    <div class="sumitup-footer">
      <div class="sumitup-footer-left">
        <button class="sumitup-btn" id="sumitup-copy-btn">${COPY_SVG} <span>Copy</span></button>
        <button class="sumitup-btn" id="sumitup-tts-btn">${SPEAKER_SVG} <span id="tts-label">Read Aloud</span></button>
        <span class="sumitup-toast" id="sumitup-toast">Copied to clipboard!</span>
      </div>
      <button class="sumitup-btn sumitup-btn-primary" id="sumitup-done-btn">Done</button>
    </div>
  `;
  shadow.appendChild(drawer);

  // References
  const bubble = shadow.getElementById("sumitup-trigger");
  const closeBtn = shadow.getElementById("sumitup-close-btn");
  const doneBtn = shadow.getElementById("sumitup-done-btn");
  const refreshBtn = shadow.getElementById("sumitup-refresh-btn");
  const copyBtn = shadow.getElementById("sumitup-copy-btn");
  const ttsBtn = shadow.getElementById("sumitup-tts-btn");
  const contentBody = shadow.getElementById("sumitup-content-body");
  const toast = shadow.getElementById("sumitup-toast");
  const pills = shadow.querySelectorAll(".sumitup-pill");

  let currentSummaryText = "";
  let currentStyle = "balanced";
  let isSpeaking = false;
  let synth = window.speechSynthesis;

  // Make Bubble Draggable
  let isDragging = false;
  let hasMoved = false;
  let startX, startY, origBottom, origRight;

  bubble.addEventListener("pointerdown", (e) => {
    isDragging = true;
    hasMoved = false;
    startX = e.clientX;
    startY = e.clientY;
    const rect = wrapper.getBoundingClientRect();
    origBottom = window.innerHeight - rect.bottom;
    origRight = window.innerWidth - rect.right;
    bubble.setPointerCapture(e.pointerId);
  });

  bubble.addEventListener("pointermove", (e) => {
    if (!isDragging) return;
    const dx = e.clientX - startX;
    const dy = e.clientY - startY;
    if (Math.hypot(dx, dy) > 4) {
      hasMoved = true;
      const newBottom = Math.max(12, Math.min(window.innerHeight - 64, origBottom - dy));
      const newRight = Math.max(12, Math.min(window.innerWidth - 64, origRight - dx));
      wrapper.style.bottom = `${newBottom}px`;
      wrapper.style.right = `${newRight}px`;
      drawer.style.bottom = `${newBottom + 64}px`;
      drawer.style.right = `${newRight}px`;
    }
  });

  bubble.addEventListener("pointerup", (e) => {
    if (!isDragging) return;
    isDragging = false;
    bubble.releasePointerCapture(e.pointerId);
  });

  // Check if floating icon should be displayed
  chrome.storage.sync.get(["showFloatingIcon"], (data) => {
    if (data.showFloatingIcon === false) {
      wrapper.style.display = "none";
    }
  });

  chrome.storage.onChanged.addListener((changes) => {
    if (changes.showFloatingIcon) {
      wrapper.style.display = changes.showFloatingIcon.newValue ? "block" : "none";
    }
  });

  // Toggle drawer on click
  bubble.addEventListener("click", () => {
    if (hasMoved) return; // Ignore drag end
    toggleDrawer();
  });

  closeBtn.addEventListener("click", () => closeDrawer());
  doneBtn.addEventListener("click", () => closeDrawer());

  // Listen for background shortcut
  chrome.runtime.onMessage.addListener((msg) => {
    if (msg.action === "TRIGGER_SUMMARIZE") {
      openDrawer();
    }
  });

  function toggleDrawer() {
    if (drawer.classList.contains("open")) {
      closeDrawer();
    } else {
      openDrawer();
    }
  }

  function openDrawer() {
    drawer.classList.add("open");
    if (!currentSummaryText) {
      runSummarization();
    }
  }

  function closeDrawer() {
    drawer.classList.remove("open");
    if (synth && isSpeaking) {
      synth.cancel();
      isSpeaking = false;
      shadow.getElementById("tts-label").textContent = "Read Aloud";
    }
  }

  // Style Pills
  pills.forEach((pill) => {
    pill.addEventListener("click", () => {
      pills.forEach((p) => p.classList.remove("active"));
      pill.classList.add("active");
      currentStyle = pill.dataset.style;
      runSummarization();
    });
  });

  refreshBtn.addEventListener("click", () => runSummarization());

  // Copy Summary
  copyBtn.addEventListener("click", () => {
    if (!currentSummaryText) return;
    navigator.clipboard.writeText(currentSummaryText).then(() => {
      toast.classList.add("show");
      setTimeout(() => toast.classList.remove("show"), 2000);
    });
  });

  // Text to Speech
  ttsBtn.addEventListener("click", () => {
    if (!synth || !currentSummaryText) return;
    if (isSpeaking) {
      synth.cancel();
      isSpeaking = false;
      shadow.getElementById("tts-label").textContent = "Read Aloud";
    } else {
      synth.cancel();
      const utterance = new SpeechSynthesisUtterance(currentSummaryText.replace(/[*#_`-]/g, " "));
      utterance.rate = 1.05;
      utterance.onend = () => {
        isSpeaking = false;
        shadow.getElementById("tts-label").textContent = "Read Aloud";
      };
      utterance.onerror = () => {
        isSpeaking = false;
        shadow.getElementById("tts-label").textContent = "Read Aloud";
      };
      synth.speak(utterance);
      isSpeaking = true;
      shadow.getElementById("tts-label").textContent = "Stop";
    }
  });

  // Smart Page Text Extractor
  function extractPageContent() {
    // 1. If user highlighted text, prioritize that!
    const selection = window.getSelection().toString().trim();
    if (selection && selection.length > 50) {
      return {
        text: selection,
        title: document.title || "Selected Text",
        isSelection: true,
        wordCount: selection.split(/\s+/).length
      };
    }

    // 2. Clone document body to clean up without affecting real page
    const clone = document.body.cloneNode(true);

    // Remove noise elements
    const unwanted = clone.querySelectorAll(
      "nav, header, footer, aside, script, style, noscript, iframe, svg, form, [role='navigation'], [role='banner'], .nav, .menu, .sidebar, .comments, .ad, .advertisement, #cookie-banner, .cookie-notice"
    );
    unwanted.forEach((el) => el.remove());

    // Look for primary content article containers
    const candidates = clone.querySelectorAll(
      "article, [role='main'], main, .post-content, .entry-content, .article-body, #content"
    );
    let chosenText = "";

    if (candidates.length > 0) {
      // Find candidate with most meaningful text
      let maxLen = 0;
      candidates.forEach((c) => {
        const text = c.innerText.trim();
        if (text.length > maxLen) {
          maxLen = text.length;
          chosenText = text;
        }
      });
    }

    // Fallback to clone's innerText
    if (!chosenText || chosenText.length < 200) {
      chosenText = clone.innerText.trim();
    }

    // Clean whitespace
    chosenText = chosenText.replace(/\n\s*\n\s*\n/g, "\n\n").trim();
    const wordCount = chosenText.split(/\s+/).length;

    // Cap text to avoid overflowing prompt limits (approx 35k chars)
    if (chosenText.length > 35000) {
      chosenText = chosenText.slice(0, 35000) + "... [truncated]";
    }

    return {
      text: chosenText,
      title: document.title || "Webpage",
      isSelection: false,
      wordCount: wordCount
    };
  }

  // Run Summarization via Gemini
  async function runSummarization() {
    const extracted = extractPageContent();
    if (!extracted.text || extracted.text.length < 50) {
      renderError("Could not find enough readable content on this page to summarize.");
      return;
    }

    renderLoading(extracted);

    // Style prompt builder
    let styleInstruction = "";
    if (currentStyle === "takeaways") {
      styleInstruction = "- Format strictly as 5 to 7 bullet points capturing the key takeaways and actionable conclusions.\n- Bold the first 2-3 words of each bullet point.";
    } else if (currentStyle === "deepdive") {
      styleInstruction = "- Provide an insightful, structured deep-dive summary with headings for Background, Main Findings/Arguments, and Implications.\n- Keep it thoroughly informative yet clear.";
    } else if (currentStyle === "eli5") {
      styleInstruction = "- Explain this in very simple, plain English as if explaining to a beginner or curious teenager.\n- Use intuitive analogies where helpful. Avoid complex jargon.";
    } else {
      styleInstruction = "- Provide a clear, balanced executive summary: 1-2 concise paragraphs giving the core narrative, followed by 3 key bullet points.\n- Be direct, crisp, and informative.";
    }

    const prompt = `You are SumItUp, an elite AI research assistant. Summarize the following ${extracted.isSelection ? "selected passage" : "webpage"}.

Guidelines:
${styleInstruction}
- Be factual and truthful to the text provided.
- Do NOT hallucinate details not mentioned in the source.
- Preserve any critical numbers, names, or outcomes.

TITLE: ${extracted.title}
CONTENT:
${extracted.text}`;

    // Get settings
    chrome.storage.sync.get(["geminiApiKey", "model"], (settings) => {
      chrome.runtime.sendMessage(
        {
          action: "GENERATE_SUMMARY",
          prompt: prompt,
          model: settings.model || "gemini-3.5-flash-lite",
          apiKey: settings.geminiApiKey
        },
        (response) => {
          if (chrome.runtime.lastError) {
            renderError(chrome.runtime.lastError.message);
            return;
          }

          if (response && response.success) {
            currentSummaryText = response.data.text;
            renderSummary(response.data.text, extracted);
          } else {
            renderError(response?.error || "Failed to generate summary.");
          }
        }
      );
    });
  }

  function renderLoading(meta) {
    const estTime = Math.max(1, Math.ceil(meta.wordCount / 220));
    contentBody.innerHTML = `
      <div class="sumitup-meta-info">
        <span class="sumitup-meta-left" title="${meta.title}">
          📄 ${meta.isSelection ? "Selected text" : meta.title}
        </span>
        <div class="sumitup-meta-right">
          <span>~${estTime} min read (${meta.wordCount} words)</span>
        </div>
      </div>
      <div class="sumitup-loading">
        <div class="ai-orb">${SPARKLE_SVG}</div>
        <div class="sumitup-loading-text">SumItUp AI is analyzing this page...</div>
        <div class="sumitup-loading-sub">Distilling key ideas with Gemini</div>
        <div class="shimmer-line" style="width: 95%;"></div>
        <div class="shimmer-line" style="width: 80%;"></div>
        <div class="shimmer-line" style="width: 88%;"></div>
        <div class="shimmer-line" style="width: 65%;"></div>
      </div>
    `;
  }

  function renderSummary(text, meta) {
    const origReadMin = Math.max(1, Math.ceil(meta.wordCount / 220));
    const sumWordCount = text.split(/\s+/).length;
    const sumReadMin = Math.max(1, Math.ceil(sumWordCount / 220));
    const savedMin = Math.max(0, origReadMin - sumReadMin);

    // Format markdown to HTML cleanly
    const formattedHtml = formatMarkdown(text);

    contentBody.innerHTML = `
      <div class="sumitup-meta-info">
        <span class="sumitup-meta-left" title="${meta.title}">
          📄 ${meta.isSelection ? "Selected text" : meta.title}
        </span>
        <div class="sumitup-meta-right">
          ${savedMin > 0 ? `<span class="sumitup-saved-time">Saved ~${savedMin}m read</span>` : ""}
          <span>${sumWordCount} words</span>
        </div>
      </div>
      <div class="sumitup-summary-content">
        ${formattedHtml}
      </div>
    `;
  }

  function renderError(errorMessage) {
    contentBody.innerHTML = `
      <div style="padding: 24px 8px; text-align: center;">
        <div style="font-size: 28px; margin-bottom: 10px;">⚠️</div>
        <div style="font-weight: 600; color: #ef4444; margin-bottom: 8px;">Unable to summarize</div>
        <div style="font-size: 12.5px; color: #64748b; line-height: 1.5; margin-bottom: 16px;">
          ${errorMessage}
        </div>
        <button class="sumitup-btn sumitup-btn-primary" id="sumitup-retry-btn">Try Again</button>
      </div>
    `;
    const retry = shadow.getElementById("sumitup-retry-btn");
    if (retry) {
      retry.addEventListener("click", () => runSummarization());
    }
  }

  function formatMarkdown(md) {
    // Simple fast safe markdown to HTML parser
    let html = md
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;");

    // Headings
    html = html.replace(/^### (.*?)$/gm, "<h3>$1</h3>");
    html = html.replace(/^## (.*?)$/gm, "<h2>$1</h2>");
    html = html.replace(/^# (.*?)$/gm, "<h2>$1</h2>");

    // Bold & italic
    html = html.replace(/\*\*(.*?)\*\*/g, "<strong>$1</strong>");
    html = html.replace(/\*(.*?)\*/g, "<em>$1</em>");

    // Bullet lists
    html = html.replace(/^\s*[-*]\s+(.*?)$/gm, "<li>$1</li>");
    html = html.replace(/(<li>.*?<\/li>)/gs, "<ul>$1</ul>");
    html = html.replace(/<\/ul>\s*<ul>/g, "");

    // Paragraphs
    const paras = html.split(/\n\n+/);
    html = paras
      .map((p) => {
        p = p.trim();
        if (!p) return "";
        if (p.startsWith("<h2>") || p.startsWith("<h3>") || p.startsWith("<ul>")) return p;
        return `<p>${p.replace(/\n/g, "<br>")}</p>`;
      })
      .join("");

    return html;
  }
})();
