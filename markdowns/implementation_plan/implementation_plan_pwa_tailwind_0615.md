# Frontend Refactoring: Remove Flutter, Setup Tailwind v4 & PWA

This plan details the steps to clean up unnecessary Flutter/Dart files and properly configure your Vite + React project with Tailwind v4 and PWA (Progressive Web App) support, as requested.

## User Review Required
- **Tailwind v4 Setup**: We will install `tailwindcss` and `@tailwindcss/vite` (Tailwind v4) and add `@import "tailwindcss";` to your `src/index.css`. Your existing custom CSS will be preserved.
- **PWA Configuration**: We will install `vite-plugin-pwa` and configure it in `vite.config.ts` to generate a manifest and service worker, turning your React app into an installable PWA.

## Open Questions
- Are there any specific PWA manifest details you want to set right now (like theme color, specific app name)? Otherwise, we will use default values ("EduAI Platform", theme color `#ffffff`).

## Proposed Changes

---

### File Cleanup (Removing Flutter/Dart)

We will execute a command to delete the following files and directories from `frontend/` that are not needed for a Vite/React project:
- `[DELETE]` `.dart_tool/`
- `[DELETE]` `android/`, `ios/`, `linux/`, `macos/`, `windows/`
- `[DELETE]` `lib/`, `test/`, `web/`
- `[DELETE]` `analysis_options.yaml`, `frontend.iml`, `pubspec.lock`, `pubspec.yaml`

---

### Tailwind v4 Setup

#### [MODIFY] [package.json](file:///C:/Easyplex_AI/frontend/package.json)
Install `tailwindcss` and `@tailwindcss/vite` via `npm install tailwindcss @tailwindcss/vite`.

#### [MODIFY] [vite.config.ts](file:///C:/Easyplex_AI/frontend/vite.config.ts)
Import and add the Tailwind CSS plugin to the Vite configuration.

#### [MODIFY] [index.css](file:///C:/Easyplex_AI/frontend/src/index.css)
Add `@import "tailwindcss";` at the very top of the file to load Tailwind v4 base styles, components, and utilities.

---

### PWA Configuration

#### [MODIFY] [package.json](file:///C:/Easyplex_AI/frontend/package.json)
Install `vite-plugin-pwa` via `npm install vite-plugin-pwa --save-dev`.

#### [MODIFY] [vite.config.ts](file:///C:/Easyplex_AI/frontend/vite.config.ts)
Add the `VitePWA` plugin configuration with basic manifest settings (name, icons, theme color) and service worker registration strategies.

---

## Verification Plan

### Automated Tests
- Run `npm run build` in the `frontend` directory to ensure Vite successfully builds the project with Tailwind v4 and PWA plugins without any errors.

### Manual Verification
- Start the dev server (`npm run dev`) and verify that styles still apply correctly.
- Check the browser DevTools (Application tab) to verify the Web App Manifest is loaded and the Service Worker is registered for PWA capabilities.
