# SumItUp - AI Web & Text Summarizer

1. **🍏 Native macOS Desktop App (`SumItUp.app`)**: A pure native Apple Silicon Cocoa app that floats an interactive Grammarly/Shazam-style AI orb on your screen. Click to summarize active webpages in Chrome, Safari, Brave, Edge, or Arc!
2. **🌐 Browser Extension (`extension/`)**: Injects the floating AI badge directly onto every website inside Google Chrome, Brave, Arc, or Microsoft Edge.
3. **📊 Streamlit Dashboard (`text_summarizer.py`)**: Full-screen side-by-side web dashboard for pasting long text and documents.

---

## 1. 🍏 Native macOS Desktop App (Installed on Desktop & Applications)

Look for **`SumItUp.app`** on your **Desktop (Home screen)** and in `~/Applications`!

### Features:
- **Floating AI Orb**: A circular, glowing gradient badge floating in the corner of your screen (draggable anywhere, remembers position).
- **1-Click Webpage Summarization**: Automatically reads the active tab in **Google Chrome**, **Safari**, **Brave**, **Edge**, or **Arc**.
- **Clipboard Mode**: Highlight and copy any text anywhere (PDFs, Notes, Slack) and click the orb.
- **Glassmorphic Card**: Native frosted glass (`NSVisualEffectView`) with **⚡ Overview**, **🎯 Key Points**, **👶 ELI5**, and **🔬 Deep Dive**.
- **Actions**: One-click **📋 Copy** and native **🔊 Read Aloud** speech.
- **Right-Click Menu**: Quick access to summarize clipboard, reset position, or quit.

---

## 2. 🌐 Chrome / Chromium Browser Extension (`extension/`)

For an in-page floating bubble on every website:
1. Open `chrome://extensions` (or `brave://extensions` / `edge://extensions`).
2. Turn **ON** **Developer mode**.
3. Click **Load unpacked** and select the [`extension/`](file:///Users/mahant/Desktop/SUM-IT-UP/extension) folder.
4. Try it on any website or [demo_page.html](file:///Users/mahant/Desktop/SUM-IT-UP/demo_page.html)!

---
