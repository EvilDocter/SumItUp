#!/usr/bin/env python3
"""
SumItUp - Native macOS Desktop Floating AI Web Summarizer
Grammarly & Shazam style floating widget that sits over your screen.
Automatically summarizes the active browser webpage or clipboard with Google Gemini.
"""

import os
import sys
import json
import re
import urllib.request
import subprocess
import threading
import tkinter as tk
from tkinter import font as tkfont
from dotenv import load_dotenv

# Path setup & Environment
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
load_dotenv(os.path.join(BASE_DIR, ".env"))

CONFIG_PATH = os.path.expanduser("~/.sumitup_config.json")
PID_FILE = "/tmp/sumitup.pid"

def ensure_single_instance():
    if os.path.exists(PID_FILE):
        try:
            with open(PID_FILE, "r") as f:
                old_pid = int(f.read().strip())
            os.kill(old_pid, 0)
            # If no exception, already running
            print(f"SumItUp is already running (PID: {old_pid})")
            sys.exit(0)
        except (OSError, ValueError):
            pass
    try:
        with open(PID_FILE, "w") as f:
            f.write(str(os.getpid()))
    except Exception:
        pass

ensure_single_instance()

try:
    from llm import ask_ai
except ImportError:
    sys.path.append(BASE_DIR)
    from llm import ask_ai


def load_config():
    if os.path.exists(CONFIG_PATH):
        try:
            with open(CONFIG_PATH, "r") as f:
                return json.load(f)
        except Exception:
            pass
    return {"x": None, "y": None}


def save_config(config):
    try:
        with open(CONFIG_PATH, "w") as f:
            json.dump(config, f)
    except Exception:
        pass


def get_frontmost_browser_info():
    """
    Detects the active browser and retrieves the current webpage's URL, Title, and Text.
    Works with Google Chrome, Safari, Brave, Edge, and Arc.
    Falls back to clipboard if no browser is active.
    """
    browsers = ["Google Chrome", "Safari", "Brave Browser", "Microsoft Edge"]
    url = ""
    title = ""
    page_text = ""

    for b in browsers:
        if b == "Safari":
            sc = '''
            tell application "Safari"
                try
                    if (count of windows) > 0 then
                        return (URL of current tab of front window) & "|||" & (name of current tab of front window)
                    end if
                end try
            end tell
            return ""
            '''
        else:
            sc = f'''
            tell application "{b}"
                try
                    if (count of windows) > 0 then
                        return (URL of active tab of front window) & "|||" & (title of active tab of front window)
                    end if
                end try
            end tell
            return ""
            '''
        try:
            res = subprocess.run(["osascript", "-e", sc], capture_output=True, text=True, timeout=2)
            out = res.stdout.strip()
            if "|||" in out:
                parts = out.split("|||", 1)
                cand_url = parts[0].strip()
                cand_title = parts[1].strip() if len(parts) > 1 else ""
                if cand_url and not cand_url.startswith("chrome://") and not cand_url.startswith("favorites://"):
                    url = cand_url
                    title = cand_title
                    break
        except Exception:
            pass

    # Fetch webpage text if URL found
    if url and (url.startswith("http://") or url.startswith("https://")):
        try:
            req = urllib.request.Request(
                url,
                headers={"User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"}
            )
            with urllib.request.urlopen(req, timeout=5) as response:
                html = response.read().decode("utf-8", errors="ignore")
                
                clean_html = re.sub(r"<(script|style|nav|header|footer|aside)[^>]*>.*?</\1>", " ", html, flags=re.DOTALL | re.IGNORECASE)
                text_content = re.sub(r"<[^<]+?>", " ", clean_html)
                clean_text = " ".join(text_content.split())
                
                if "youtube.com" in url or "youtu.be" in url or len(clean_text) < 150:
                    desc_match = re.findall(r'<meta\s+[^>]*(?:name|property)=["\'](?:description|og:description)["\'][^>]*content=["\']([^"\']*)["\']', html, re.IGNORECASE)
                    if desc_match:
                        clean_text = f"Title: {title}\n\nDescription:\n{desc_match[0]}\n\nContent:\n{clean_text}"
                
                if len(clean_text) > 40:
                    page_text = clean_text
        except Exception:
            pass

    if page_text:
        return {
            "source": "Browser",
            "title": title or "Webpage",
            "url": url,
            "text": page_text
        }

    # Fallback to clipboard
    try:
        clip_proc = subprocess.run(["pbpaste"], capture_output=True, text=True, timeout=1)
        clip_text = clip_proc.stdout.strip()
        if clip_text and len(clip_text) > 40:
            return {
                "source": "Clipboard",
                "title": "Copied Text",
                "url": "",
                "text": clip_text
            }
    except Exception:
        pass

    return None


class SumItUpDesktopApp:
    def __init__(self):
        self.root = tk.Tk()
        self.root.title("SumItUp Floating Bubble")
        self.root.overrideredirect(True)
        self.root.attributes("-topmost", True)

        try:
            self.root.attributes("-alpha", 0.96)
        except Exception:
            pass

        self.size = 56
        screen_w = self.root.winfo_screenwidth()
        screen_h = self.root.winfo_screenheight()

        cfg = load_config()
        self.x = cfg.get("x") or (screen_w - self.size - 36)
        self.y = cfg.get("y") or (screen_h - self.size - 90)

        # Boundary checks
        self.x = max(10, min(screen_w - self.size - 10, self.x))
        self.y = max(30, min(screen_h - self.size - 10, self.y))

        self.root.geometry(f"{self.size}x{self.size}+{self.x}+{self.y}")

        self.drag_start_x = 0
        self.drag_start_y = 0
        self.drag_moved = False

        self.card_window = None
        self.current_summary = ""
        self.current_title = ""
        self.current_mode = "overview"
        self.last_extracted = None

        self.setup_bubble_ui()

    def setup_bubble_ui(self):
        self.canvas = tk.Canvas(
            self.root,
            width=self.size,
            height=self.size,
            bg="#0b0f19",
            highlightthickness=0,
            cursor="hand2"
        )
        self.canvas.pack(fill="both", expand=True)

        pad = 2
        # Outer Glowing Circle
        self.circle_id = self.canvas.create_oval(
            pad, pad, self.size - pad, self.size - pad,
            fill="#4f46e5", outline="#06b6d4", width=2.5
        )

        # Inner Gradient Illusion
        self.canvas.create_oval(
            pad + 3, pad + 3, self.size - pad - 3, self.size - pad - 3,
            fill="#6366f1", outline=""
        )

        # Shazam/Grammarly Center AI Star
        cx, cy = self.size / 2, self.size / 2
        star = [
            cx, cy - 14,
            cx + 4, cy - 4,
            cx + 14, cy,
            cx + 4, cy + 4,
            cx, cy + 14,
            cx - 4, cy + 4,
            cx - 14, cy,
            cx - 4, cy - 4
        ]
        self.canvas.create_polygon(star, fill="#ffffff", outline="")

        # Accent sparkle
        accent = [
            cx + 8, cy - 12,
            cx + 10, cy - 9,
            cx + 13, cy - 8,
            cx + 10, cy - 7,
            cx + 8, cy - 4,
            cx + 7, cy - 7,
            cx + 4, cy - 8,
            cx + 7, cy - 9
        ]
        self.canvas.create_polygon(accent, fill="#a5f3fc", outline="")

        # Bindings
        self.canvas.bind("<ButtonPress-1>", self.on_press)
        self.canvas.bind("<B1-Motion>", self.on_drag)
        self.canvas.bind("<ButtonRelease-1>", self.on_release)
        self.canvas.bind("<Button-2>", self.show_context_menu)  # macOS right-click
        self.canvas.bind("<Button-3>", self.show_context_menu)
        self.canvas.bind("<Enter>", self.on_enter)
        self.canvas.bind("<Leave>", self.on_leave)

    def on_enter(self, e):
        self.canvas.itemconfig(self.circle_id, outline="#38bdf8", width=3.5)

    def on_leave(self, e):
        self.canvas.itemconfig(self.circle_id, outline="#06b6d4", width=2.5)

    def on_press(self, e):
        self.drag_start_x = e.x_root
        self.drag_start_y = e.y_root
        self.drag_moved = False

    def on_drag(self, e):
        dx = e.x_root - self.drag_start_x
        dy = e.y_root - self.drag_start_y
        if abs(dx) + abs(dy) > 4:
            self.drag_moved = True
            self.x += dx
            self.y += dy
            self.root.geometry(f"+{self.x}+{self.y}")
            self.drag_start_x = e.x_root
            self.drag_start_y = e.y_root

    def on_release(self, e):
        if self.drag_moved:
            save_config({"x": self.x, "y": self.y})
        else:
            self.toggle_summary_card()

    def show_context_menu(self, e):
        menu = tk.Menu(self.root, tearoff=0, bg="#1e293b", fg="#f8fafc", activebackground="#4f46e5", activeforeground="#ffffff")
        menu.add_command(label="Summarize Active Webpage", command=self.open_and_summarize)
        menu.add_command(label="📋 Summarize Clipboard", command=self.summarize_clipboard)
        menu.add_separator()
        menu.add_command(label="📍 Reset Position to Bottom Right", command=self.reset_position)
        menu.add_separator()
        menu.add_command(label="✕ Quit SumItUp", command=self.quit_app)
        menu.tk_popup(e.x_root, e.y_root)

    def reset_position(self):
        screen_w = self.root.winfo_screenwidth()
        screen_h = self.root.winfo_screenheight()
        self.x = screen_w - self.size - 36
        self.y = screen_h - self.size - 90
        self.root.geometry(f"+{self.x}+{self.y}")
        save_config({"x": self.x, "y": self.y})

    def quit_app(self):
        if os.path.exists(PID_FILE):
            try:
                os.remove(PID_FILE)
            except Exception:
                pass
        if self.card_window:
            self.card_window.destroy()
        self.root.destroy()
        sys.exit(0)

    def toggle_summary_card(self):
        if self.card_window and self.card_window.winfo_exists():
            self.card_window.destroy()
            self.card_window = None
        else:
            self.open_and_summarize()

    def open_and_summarize(self):
        self.create_card_window()
        threading.Thread(target=self.run_summarization, daemon=True).start()

    def summarize_clipboard(self):
        self.create_card_window()
        threading.Thread(target=self.run_clipboard_summarization, daemon=True).start()

    def create_card_window(self):
        if self.card_window and self.card_window.winfo_exists():
            self.card_window.destroy()

        self.card_window = tk.Toplevel(self.root)
        self.card_window.title("SumItUp AI Summary")
        self.card_window.attributes("-topmost", True)
        self.card_window.overrideredirect(True)

        cw, ch = 480, 520
        # Position nicely adjacent to the bubble
        px = max(20, self.x - cw - 16)
        py = max(40, self.y - ch + self.size)
        self.card_window.geometry(f"{cw}x{ch}+{px}+{py}")
        self.card_window.configure(bg="#0b0f19")

        # Outer border frame
        outer = tk.Frame(self.card_window, bg="#1e293b", padx=1, pady=1)
        outer.pack(fill="both", expand=True)

        inner = tk.Frame(outer, bg="#0f172a")
        inner.pack(fill="both", expand=True)

        # Header Bar
        header = tk.Frame(inner, bg="#1e293b", padx=16, pady=12)
        header.pack(fill="x")

        # Brand Title
        brand_frame = tk.Frame(header, bg="#1e293b")
        brand_frame.pack(side="left")

        brand_lbl = tk.Label(brand_frame, text="SumItUp AI", font=("Helvetica", 14, "bold"), bg="#1e293b", fg="#ffffff")
        brand_lbl.pack(side="left")

        gemini_tag = tk.Label(brand_frame, text="GEMINI", font=("Helvetica", 9, "bold"), bg="#312e81", fg="#a5b4fc", padx=6, pady=2)
        gemini_tag.pack(side="left", padx=8)

        # Close button
        close_btn = tk.Button(
            header, text="✕", font=("Helvetica", 11, "bold"),
            bg="#334155", fg="#cbd5e1", relief="flat",
            activebackground="#ef4444", activeforeground="#ffffff",
            cursor="hand2", padx=6, pady=2,
            command=self.close_card
        )
        close_btn.pack(side="right")

        # Mode Filter Pills
        pills_frame = tk.Frame(inner, bg="#0f172a", padx=16, pady=8)
        pills_frame.pack(fill="x")

        self.pill_btns = {}
        modes = [
            ("overview", "⚡ Overview"),
            ("keypoints", "🎯 Key Points"),
            ("eli5", "👶 Explain Like I'm 5"),
            ("deepdive", "🔬 Deep Dive")
        ]
        for mode_key, mode_label in modes:
            btn = tk.Button(
                pills_frame,
                text=mode_label,
                font=("Helvetica", 10, "bold" if mode_key == self.current_mode else "normal"),
                bg="#4f46e5" if mode_key == self.current_mode else "#1e293b",
                fg="#ffffff" if mode_key == self.current_mode else "#94a3b8",
                relief="flat",
                cursor="hand2",
                padx=8,
                pady=4,
                command=lambda m=mode_key: self.switch_mode(m)
            )
            btn.pack(side="left", padx=(0, 6))
            self.pill_btns[mode_key] = btn

        # Metadata Bar
        self.meta_lbl = tk.Label(
            inner,
            text="🔍 Connecting to frontmost webpage...",
            font=("Helvetica", 11),
            bg="#0f172a",
            fg="#94a3b8",
            padx=16,
            pady=4,
            anchor="w"
        )
        self.meta_lbl.pack(fill="x")

        # Text Summary Area
        text_frame = tk.Frame(inner, bg="#0f172a", padx=16, pady=4)
        text_frame.pack(fill="both", expand=True)

        self.text_widget = tk.Text(
            text_frame,
            wrap="word",
            font=("Helvetica", 12),
            bg="#1e293b",
            fg="#f8fafc",
            padx=14,
            pady=12,
            relief="flat",
            highlightthickness=1,
            highlightbackground="#334155"
        )
        self.text_widget.pack(fill="both", expand=True)
        self.text_widget.insert("1.0", "⏳ Extracting page contents and summarizing with Gemini...")
        self.text_widget.config(state="disabled")

        # Bottom Toolbar
        footer = tk.Frame(inner, bg="#1e293b", padx=16, pady=10)
        footer.pack(fill="x")

        self.copy_btn = tk.Button(
            footer, text="📋 Copy", font=("Helvetica", 11, "bold"),
            bg="#4f46e5", fg="#ffffff", relief="flat", cursor="hand2",
            padx=10, pady=5, command=self.copy_summary
        )
        self.copy_btn.pack(side="left", padx=(0, 6))

        self.speak_btn = tk.Button(
            footer, text="🔊 Read Aloud", font=("Helvetica", 11),
            bg="#334155", fg="#e2e8f0", relief="flat", cursor="hand2",
            padx=10, pady=5, command=self.speak_summary
        )
        self.speak_btn.pack(side="left", padx=(0, 6))

        self.toast_lbl = tk.Label(footer, text="", font=("Helvetica", 10, "bold"), bg="#1e293b", fg="#10b981")
        self.toast_lbl.pack(side="left", padx=8)

        done_btn = tk.Button(
            footer, text="Done", font=("Helvetica", 11, "bold"),
            bg="#334155", fg="#f8fafc", relief="flat", cursor="hand2",
            padx=12, pady=5, command=self.close_card
        )
        done_btn.pack(side="right")

    def close_card(self):
        if self.card_window:
            self.card_window.destroy()
            self.card_window = None

    def switch_mode(self, mode_key):
        self.current_mode = mode_key
        for k, btn in self.pill_btns.items():
            if k == mode_key:
                btn.config(bg="#4f46e5", fg="#ffffff", font=("Helvetica", 10, "bold"))
            else:
                btn.config(bg="#1e293b", fg="#94a3b8", font=("Helvetica", 10, "normal"))

        if self.last_extracted:
            threading.Thread(target=self.summarize_with_extracted, args=(self.last_extracted,), daemon=True).start()

    def run_summarization(self):
        extracted = get_frontmost_browser_info()
        if not extracted:
            self.display_message(
                "Could not find an active webpage or readable text.\n\n"
                "💡 Quick Tip:\n"
                "1. Switch to your browser window (Chrome, Safari, Brave, Edge).\n"
                "2. Or highlight/copy any article text to your clipboard.\n"
                "3. Then click this SumItUp bubble again!",
                title="No webpage detected"
            )
            return

        self.last_extracted = extracted
        self.summarize_with_extracted(extracted)

    def run_clipboard_summarization(self):
        try:
            clip_text = subprocess.run(["pbpaste"], capture_output=True, text=True).stdout.strip()
            if clip_text:
                extracted = {"source": "Clipboard", "title": "Copied Text", "url": "", "text": clip_text}
                self.last_extracted = extracted
                self.summarize_with_extracted(extracted)
            else:
                self.display_message("Your clipboard is currently empty.", title="Clipboard Empty")
        except Exception as e:
            self.display_message(f"Error reading clipboard: {e}", title="Error")

    def summarize_with_extracted(self, extracted):
        title = extracted.get("title", "Webpage")
        text = extracted.get("text", "")
        words = len(text.split())

        self.root.after(0, lambda: self.meta_lbl.config(
            text=f"📄 {title[:42]}... (~{words} words)"
        ))

        # Build style guidance
        if self.current_mode == "keypoints":
            guide = "Format strictly as 5 to 7 bullet points capturing the key takeaways and core arguments. Bold the first 2-3 words of each bullet point."
        elif self.current_mode == "eli5":
            guide = "Explain this in very simple, conversational English as if explaining to a beginner or curious teenager. Use an intuitive analogy."
        elif self.current_mode == "deepdive":
            guide = "Provide a comprehensive, structured breakdown with section headings: Context, Key Findings, and Takeaways."
        else:
            guide = "Provide an executive summary: 1-2 clear paragraphs capturing the core story, followed by 3 key bullet points."

        # Cap text to 35,000 characters
        if len(text) > 35000:
            text = text[:35000]

        prompt = f"""You are SumItUp, an elite AI research assistant. Summarize the following content.

Guidelines:
- {guide}
- Be factual and truthful to the text provided.
- Do NOT hallucinate facts not in the source text.
- Preserve any critical figures, names, or outcomes.

TITLE: {title}
CONTENT:
{text}"""

        try:
            summary = ask_ai(prompt)
            self.display_message(summary, title=title)
        except Exception as e:
            self.display_message(f"Failed to generate summary: {e}", title="Error")

    def display_message(self, text, title=""):
        def _update():
            if not self.card_window or not self.card_window.winfo_exists():
                return
            self.current_summary = text
            self.current_title = title
            words = len(text.split())
            if title:
                self.meta_lbl.config(text=f"✅ Ready: {title[:42]} ({words} words)")
            self.text_widget.config(state="normal")
            self.text_widget.delete("1.0", "end")
            self.text_widget.insert("1.0", text)
            self.text_widget.config(state="disabled")
        self.root.after(0, _update)

    def copy_summary(self):
        if self.current_summary:
            self.root.clipboard_clear()
            self.root.clipboard_append(self.current_summary)
            self.toast_lbl.config(text="✓ Copied!")
            self.root.after(2000, lambda: self.toast_lbl.config(text=""))

    def speak_summary(self):
        if self.current_summary:
            clean = self.current_summary.replace("*", "").replace("#", "")
            subprocess.Popen(["say", clean[:600]])

    def run(self):
        self.root.mainloop()


if __name__ == "__main__":
    app = SumItUpDesktopApp()
    app.run()
