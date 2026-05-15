# ✂️ Craft Tutorial Maker

Craft Tutorial Maker is a specialized Progressive Web App (PWA) designed to convert videos and reels into beautiful, step-by-step tutorials. Capture key moments, add descriptions, and export your creations as standalone HTML or JSON files.

## 🚀 Features

- **📼 Video Library**: Browse and filter a curated list of craft videos.
- **📹 Multi-Source Support**: 
  - Drag and drop local `mp4` files.
  - Embed support for YouTube and Facebook.
- **📸 Precision Snapping**:
  - **Manual Snap**: Capture the exact frame you need.
  - **Auto Snap**: Automatically capture frames every few seconds while the video plays.
  - **Frame Stepping**: Move frame-by-frame for the perfect shot.
- **📋 Tutorial Editor**:
  - Add notes and descriptions to each step.
  - Reorder steps using drag-and-drop.
  - Delete or re-snap steps as needed.
- **⬇️ Export & Share**:
  - **Share**: Send your tutorial directly using the Web Share API.
  - **HTML**: Export a standalone, stylized HTML file containing your full tutorial.
  - **JSON**: Save the raw data for advanced use cases.
- **📱 Mobile Optimized**: Fully responsive interface with a dedicated mobile navigation and floating snap button.
- **⚡ PWA Ready**: Install the app on your device for offline access and a native-app feel.

## 🛠 Usage

1. **Select a Video**: Pick a video from the **Library** or drop your own local video into the **Editor**.
2. **Capture Steps**: 
   - Use the player controls to find key moments.
   - Click **📸 Snap Frame** to capture a step.
   - Alternatively, use **⚡ Auto** to capture frames at regular intervals.
3. **Refine Tutorial**:
   - Go to the **Steps** panel.
   - Add a title for your tutorial.
   - Write descriptions for each captured step.
   - Drag steps to reorder them if needed.
4. **Share Your Work**: Use the **Share** or **HTML** buttons to distribute your finished tutorial.

## ⌨️ Keyboard Shortcuts

| Key | Action |
|-----|--------|
| `Space` | Play / Pause |
| `S` | Take Screenshot (Snap) |
| `Arrow Left` | Step Frame Backward |
| `Arrow Right` | Step Frame Forward |
| `Arrow Up` | Increase Playback Speed |
| `Arrow Down` | Decrease Playback Speed |

## 📦 Setup

Since this is a client-side web application, you can run it using any static file server.

1. Clone the repository.
2. Ensure your videos are listed in `videos.json`.
3. Open `index.html` in a modern browser.

---
Built with ✂️ for crafters by crafters.
