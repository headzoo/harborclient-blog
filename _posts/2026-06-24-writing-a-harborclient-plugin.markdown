---
layout: post
title: "Writing a HarborClient Plugin"
date: 2026-06-24 20:00:00 +0000
categories: rest-api testing tools
image: /assets/images/writing-a-harborclient-plugin.png
image_alt: "A harbor scene with glowing modular plugin blocks and code, representing HarborClient plugin development"
---

[HarborClient](https://harborclient.com/) plugins let you extend the app with installable packages — custom tabs, sidebar panels, themes, HTTP hooks, and persistent storage — without waiting for a new release. Each plugin ships as a `.hcp` file, which is really just a ZIP archive with a friendly extension.

If you have not read the announcement yet, start with [HarborClient Adds Plugin Support](https://harborclient-blog.com/2026/06/24/harborclient-adds-plugin-support/) for the big picture. This guide walks through building your first plugin step by step, using the official [plugin API docs](https://harborclient.github.io/plugin-api/) as reference.

HarborClient already has [request scripts](https://harborclient.com/request-scripts) that run once per send inside a sandboxed utility process. Plugins are different: they are long-lived extensions with a broader API suited to UI contributions, themes, storage, and HTTP hooks that stay active until you disable the plugin.

## What you will build

You will create a **Request Audit** tab — a read-only panel in the request editor that summarizes the active draft as JSON: method, URL, header count, whether a body is present, and the last response status.

This example comes straight from the [request audit tab docs](https://harborclient.github.io/plugin-api/examples/request-audit-tab.html). It is a good first plugin because it needs only the `ui` permission and a single renderer entry — no main-process code, no IPC, no filesystem access.

## Prerequisites

Before you start, make sure you have:

- **HarborClient 1.8.0 or later** — base plugin support. Use **1.9.0+** if you want `hc.pluginId`, renderer-side `onAfterSend`, or `hc.host.openRequestDraft`.
- **Node.js** and **pnpm**
- **`@harborclient/plugin-api`** as a dev dependency in your plugin project

## Scaffold the project

The fastest way to start is the official skeleton:

```bash
npx @harborclient/plugin-skeleton@latest
cd my-plugin
pnpm install
```

You can also clone the [plugin-skeleton repo](https://github.com/harborclient/plugin-skeleton) and adapt it. Either way, you get a project layout, TypeScript config, and esbuild scripts ready to go.

## Understand the package layout

A plugin project mirrors what goes inside a `.hcp` file:

```
my-plugin/
├── manifest.json
├── README.md
├── src/
│   └── renderer.tsx      # your source — not loaded at runtime
└── dist/
    └── renderer.js       # bundled output — referenced by manifest
```

You author code in `src/`. HarborClient loads the bundled files in `dist/` at runtime. Optional folders like `assets/` hold icons and screenshots for the Settings → Plugins detail page.

## Write the manifest

Every plugin needs a `manifest.json` at the project root. For the audit tab, keep it minimal:

```json
{
  "id": "com.example.request-audit",
  "name": "Request Audit",
  "version": "1.0.0",
  "engines": { "harborclient": ">=1.9.0" },
  "renderer": "dist/renderer.js",
  "permissions": ["ui"],
  "contributes": {
    "requestTabs": [{ "id": "audit", "title": "Audit" }]
  }
}
```

A few fields matter here:

- **`id`** — reverse-DNS identifier. HarborClient uses it to namespace storage and track updates.
- **`engines.harborclient`** — minimum app version your plugin requires.
- **`permissions`** — capabilities shown in the install dialog. This plugin only needs `ui`.
- **`contributes.requestTabs`** — declares a tab slot before your code runs.

There is an important contract between the manifest and your code: contribution `id` values must match what you pass to registration calls. Here, the manifest declares `"id": "audit"`, so your renderer must call `registerRequestTab({ id: 'audit', ... })`.

## Write the renderer entry

Create `src/renderer.tsx`. Every renderer plugin starts with two steps: wire up React from the host, then register contributions inside `activate()`.

```tsx
import { installReact } from '@harborclient/plugin-api';
import type { PluginContext, RequestTabContext } from '@harborclient/plugin-api';

function AuditTab({ context }: { context: RequestTabContext }) {
  const { draft, response } = context;
  const summary = {
    method: draft.method,
    url: draft.url,
    headerCount: draft.headers.filter((h) => h.enabled && h.key).length,
    hasBody: draft.body.trim().length > 0,
    lastStatus: response?.status ?? null
  };

  return (
    <pre className="m-0 overflow-auto rounded-md bg-control p-3 text-[14px] text-text">
      {JSON.stringify(summary, null, 2)}
    </pre>
  );
}

export function activate(hc: PluginContext): void {
  installReact(hc.react);
  hc.subscriptions.push(
    hc.ui.registerRequestTab({
      id: 'audit',
      title: 'Audit',
      Component: AuditTab
    })
  );
}
```

Three things to notice:

1. **`installReact(hc.react)`** — the host provides React. Do not bundle `react` or `react-dom` in your plugin.
2. **`RequestTabContext`** — gives you the active draft and the last response. The tab re-renders locally when the user edits the request — no IPC round-trip per keystroke.
3. **`hc.subscriptions`** — every `register*` call returns a disposable. Push it here so HarborClient cleans up automatically when the plugin deactivates.

## Configure the build

Bundle with esbuild. A typical renderer build script looks like this:

```bash
esbuild src/renderer.tsx \
  --bundle --outfile=dist/renderer.js --format=esm \
  --jsx=automatic --jsx-import-source=@harborclient/plugin-api \
  --external:react --external:react-dom
```

In `package.json`, wire that into `dev` and `build` scripts. Use `--watch` on the dev script so rebuilds happen automatically while you edit.

For TypeScript, set `jsx: "react-jsx"` and `jsxImportSource: "@harborclient/plugin-api"` in `tsconfig.json`. Import types from `@harborclient/plugin-api` and export `activate` (and optionally `deactivate`) as named exports.

## Develop with unpacked loading

You do not need to package a `.hcp` file on every change. HarborClient can load your project folder directly while you develop.

1. Run `pnpm dev` to start esbuild in watch mode.
2. In HarborClient, open **Settings → Plugins** and click **Load unpacked…**. Select your plugin project folder.
3. Open a request in the editor and click the **Audit** tab. That triggers plugin activation.
4. Edit your source, save, and wait for esbuild to rebuild. HarborClient watches `manifest.json` and entry files, debounces briefly, then deactivates and re-activates your plugin.

For day-to-day work on the same plugin, you can register the path at startup:

```bash
HARBOR_PLUGINS_DEV=~/projects/my-plugin harborclient
```

Or pass `--plugin-dev ~/projects/my-plugin` on the command line. The plugin appears in Settings → Plugins the same way as one loaded through the UI.

## Going further

Once the audit tab works, you can explore other APIs without changing the basic shape of a plugin.

### Main entry for HTTP hooks

UI code belongs in the renderer entry. If you need to **mutate** outgoing requests — inject headers, sign payloads, add trace IDs — add a separate main entry that runs in the SES utility process:

```typescript
import type { MainPluginContext } from '@harborclient/plugin-api/main';

export function activate(hc: MainPluginContext): void {
  hc.subscriptions.push(
    hc.http.onBeforeSend((request) => {
      request.headers['X-Trace'] = '1';
    })
  );
}
```

Reference it in `manifest.json` with `"main": "dist/main.js"` and add the `"http"` permission. For read-only logging after a send, renderer-side `hc.http.onAfterSend` is often simpler — no main entry required.

### Permissions

HarborClient shows requested permissions before install. Common grants:

| Permission | Grants |
|------------|--------|
| `ui` | Settings panels, tabs, themes, menus, toasts |
| `storage` | Namespaced persistent key-value storage |
| `filesystem:pick` | Open and save file dialogs |
| `filesystem:read` / `filesystem:write` | Read or write allowlisted paths |
| `http` | Before/after send hooks |
| `ipc` | Custom channels between renderer and main |

Request only what you need. Users see the full list in the install confirmation dialog.

### Other UI contributions

The same registration pattern works for other surfaces. A settings section is often the simplest next step after a request tab:

```typescript
hc.ui.registerSettingsSection({
  id: 'myPlugin.settings',
  title: 'My Plugin',
  Component: SettingsPanel
});
```

You can also add sidebar panels, response tabs, footer panels, toolbar actions, context menu items, status bar entries, and custom themes. See the [UI contributions reference](https://harborclient.github.io/plugin-api/renderer-ui.html) for the full list.

### SDK helpers

The npm package ships utility subpaths for common plugin tasks (requires `@harborclient/plugin-api` 0.3.1+):

```typescript
import { resolveRequest } from '@harborclient/plugin-api/http';
import { createCappedList } from '@harborclient/plugin-api/storage';
import { methodColorClass } from '@harborclient/plugin-api/ui';
import { randomId } from '@harborclient/plugin-api/runtime-utils';
```

`resolveRequest` mirrors HarborClient's send-time variable substitution — useful if you build history or audit plugins that need the resolved URL and headers.

## Package and distribute

When you are ready to ship, build and zip:

```bash
pnpm build
zip -r ../request-audit.hcp manifest.json README.md assets dist
```

Install the `.hcp` file through **Settings → Plugins**. To publish to the HarborClient plugin marketplace, open a pull request against the [plugin catalog](https://github.com/harborclient/harborclient/blob/main/plugins/catalog.json) with a link to a public repository containing prebuilt files.

## Checklist

Before you share your plugin, confirm:

- [ ] Scaffolded project with `@harborclient/plugin-skeleton`
- [ ] Manifest declares permissions and contributions
- [ ] Renderer entry calls `installReact` and registers UI on `hc.subscriptions`
- [ ] esbuild marks React as external
- [ ] Tested with Load unpacked and hot reload
- [ ] Packaged as `.hcp` for distribution

For the full API reference, worked examples, and performance guidelines, keep the [plugin API docs](https://harborclient.github.io/plugin-api/) open while you build.
