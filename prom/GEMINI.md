# Gemini Project Context: Prompt Explorer

## Project Overview
**Prompt Explorer** is a Progressive Web App (PWA) designed to store, categorize, and explore AI prompts. It features a clean, responsive UI with support for favorites, searching, and importing/exporting data.

### Core Technologies
- **Frontend:** HTML5, Vanilla CSS3, Vanilla JavaScript (ES6+).
- **Storage:** [IndexedDB](https://developer.mozilla.org/en-US/docs/Web/API/IndexedDB_API) for persistent client-side storage.
- **PWA Features:** Service Workers for offline support (`sw.js`, `offline.html`) and a Web App Manifest (`manifest.json`).
- **Push Notifications:** Firebase Cloud Messaging (FCM) integration (`firebase-messaging-sw.js`).
- **Testing:** Python script (`send_test.py`) for testing FCM notifications.

## Architecture
The application follows a **client-side only architecture**. All logic for data management (CRUD operations via IndexedDB) and UI rendering is contained within `index.html`.

### Key Files
- `index.html`: The monolithic entry point containing HTML, CSS, and JS logic.
- `sw.js`: Main Service Worker handling caching and offline capabilities.
- `firebase-messaging-sw.js`: Specialized Service Worker for handling Firebase background notifications.
- `manifest.json`: Configuration for PWA installation and appearance.
- `prompts-copy.json`: A collection of sample prompts for initial data or backups.
- `send_test.py`: Python script to trigger test notifications via Firebase Admin SDK.

## Building and Running
Since this is a static web application, no build step is required.

### Local Development
To run the project locally, serve the root directory using any static file server:

```bash
# Using Python
python3 -m http.server 8000

# Using Node.js (if installed)
npx serve .
```

**Note on PWA/FCM Features:**
- Service Workers and Push Notifications usually require **HTTPS** or `localhost` to function.
- Firebase configuration is hardcoded in `index.html`. To use your own, update the `firebaseConfig` object.

### Testing Notifications
1. Ensure you have a `service_account.json` file in the parent directory (as referenced in `send_test.py`).
2. Install the `firebase-admin` Python package:
   ```bash
   pip install firebase-admin
   ```
3. Get the Registration Token from the browser console after granting notification permission.
4. Update `registration_token` in `send_test.py` and run:
   ```bash
   python3 send_test.py
   ```

## Development Conventions
- **Single File Logic:** Most UI and logic changes happen directly in `index.html`.
- **CSS Variables:** The app uses CSS variables (defined in `:root`) for theming and consistency.
- **IndexedDB:** Use the `initDB`, `addPromptToDB`, `getAllPromptsFromDB`, etc., functions for data persistence.
- **PWA Updates:** When modifying assets, remember to update the `CACHE_NAME` in `sw.js` to trigger a cache refresh for users.
- **Icons:** App icons are located in the `icons/` directory in various sizes.
