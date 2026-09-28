---
name: cesium
description: CesiumJS and Resium in React - installed-version awareness, entities vs primitives, billboards, camera control, render loop and request-render mode, cleanup, React state/render interactions, and performance verification.
---

# CesiumJS / Resium

Use this skill for 3D globe work in apps that use `cesium` (optionally through
`resium`). Do not switch an app between Cesium and MapLibre without an
architectural decision.

## Before you start

- Check installed versions of `cesium` and `resium`; Cesium ships breaking
  changes regularly (removed APIs, renamed options), so follow the installed
  version's typings in `node_modules/@cesium/engine` / `node_modules/cesium`.
- Find where the `Viewer` is created (Resium `<Viewer>` or manual
  `new Viewer(...)`), how it is shared (context/ref), and where the Cesium ion
  token or asset base URL is configured. Do not add a second Viewer.
- Check the build setup for Cesium static assets (`CESIUM_BASE_URL`, Vite
  plugin); do not change it casually.

## Entities vs primitives

- **Entities** (`viewer.entities`, Resium `<Entity>`): declarative, good for
  moderate counts and time-dynamic data; property changes are reactive.
- **Primitives** (`PointPrimitiveCollection`, `BillboardCollection`,
  `PolylineCollection`, custom `Primitive`): imperative, much faster for large
  or frequently-updated sets. Use them when entity counts or update rates cause
  frame drops.
- Billboards: reuse images/`Image` objects; set `scaleByDistance` /
  `distanceDisplayCondition` to keep dense scenes readable; batch adds and
  removes.
- Do not mix ownership: one module owns a collection's lifecycle.

## Camera

- Use `camera.flyTo` / `setView` / `lookAt` with explicit `Cartesian3` /
  `HeadingPitchRange`; clear `lookAtTransform` when done (`lookAtTransform(Matrix4.IDENTITY)`).
- Persist/restore camera state via the app's existing mechanism (URL, store);
  do not add a second one.
- Debounce camera-driven queries (`camera.changed`, `moveEnd`).

## Render loop and request-render mode

- Inspect `viewer.scene.requestRenderMode` and `maximumRenderTimeChange`
  before adding per-frame work.
- Prefer request-render mode; call `scene.requestRender()` after data changes
  instead of forcing continuous rendering.
- Never do heavy work inside `preRender`/`postRender` listeners or
  `CallbackProperty` getters; precompute outside the render loop.

## Cleanup

- Remove entities/primitives you added, `removeEventListener` on
  `scene.preRender`, `camera.changed`, `ScreenSpaceEventHandler.destroy()`, and
  clock/tick listeners in the same effect that created them.
- Destroy `DataSource`s and terrain/imagery providers you created; never
  `viewer.destroy()` a shared viewer from a child component.

## React interactions

- Keep Cesium objects out of React state; hold them in refs. Re-rendering
  React must not recreate Cesium objects.
- Derive Cesium updates from props in effects with precise dependencies; batch
  updates and call `requestRender()` once.
- With Resium, prefer its components for declarative parts and refs for
  imperative parts; avoid mixing both for the same object.

## Performance verification

- Measure before/after: `scene.debugShowFramesPerSecond = true` locally or
  the browser performance panel; note entity/primitive counts.
- Check for leaks: navigate away and back, confirm collections and listeners
  are gone.
- Use the `browser` subagent for smoke checks (page loads, no console errors,
  screenshot); it cannot judge frame rate reliably, so report measured
  numbers yourself.
