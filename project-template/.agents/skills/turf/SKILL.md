---
name: turf
description: Geospatial computation with Turf.js - GeoJSON structure, [longitude, latitude] order, explicit units, empty and invalid geometries, bounds, distance, area, transformations, antimeridian handling, and keeping expensive geometry work out of React render.
---

# Turf

Use this skill when computing distances, areas, buffers, bounds, intersections,
or other geometry operations with `@turf/*` packages.

## Before you start

- Check the installed Turf version (`@turf/turf` or individual `@turf/<fn>`
  packages). Import individual packages when the project does, to keep bundles
  small.
- Reuse existing geo helpers in the repo before adding new ones.

## GeoJSON basics

- Coordinates are `[longitude, latitude]` (x, y). Many UI and API sources use
  `lat, lng`; convert at the boundary and name variables accordingly.
- Turf works on GeoJSON `Feature`/`Geometry`/`FeatureCollection`; wrap raw
  coordinates with `point()`, `lineString()`, `polygon()`, `featureCollection()`.
- Polygon rings must be closed (first == last position) and follow the
  right-hand rule for reliable results; use `rewind` when input is untrusted.

## Units

- Always pass `{ units: "meters" | "kilometers" | ... }` explicitly to
  functions that accept it (`distance`, `buffer`, `length`, `circle`). The
  default (kilometers) is easy to forget.
- `area` returns square meters. Convert at the presentation layer.

## Empty and invalid geometries

- Guard against empty coordinate arrays, `null` geometries, NaN coordinates,
  and degenerate polygons (fewer than 4 positions) before calling Turf;
  several functions throw or return `null`/`undefined`.
- Validate untrusted input with the project's schema layer (Valibot) and, when
  needed, `booleanValid` / `kinks` / `cleanCoords`.
- Handle `undefined` results from `intersect`, `union`, `difference`.

## Common operations

- Bounds: `bbox`, `bboxPolygon`, `envelope`; use the bbox to fit map cameras.
- Distance/length: `distance` (two points), `length` (line), `nearestPoint`,
  `pointToLineDistance`.
- Containment: `booleanPointInPolygon`, `booleanWithin`, `booleanIntersects`.
- Transformations: `buffer`, `simplify`, `transformRotate/Scale/Translate`,
  `centroid`/`centerOfMass`, `flip` (for lat/lng conversion).

## Antimeridian and poles

- Geometries crossing the antimeridian (longitude 180) break bbox, buffer,
  and containment logic; detect large longitude jumps and split (or
  normalize) before computing. Near the poles, planar approximations are
  wrong; prefer geodesic functions and validate results.

## React

- Never run buffers, unions, or large-collection operations inside render or
  in effects without memoization; compute in `useMemo` keyed on the actual
  inputs, in a worker for large datasets, or on the server.
- Keep derived geometry out of component state when it can be recomputed
  from props with `useMemo`.

## Verification

- Unit-test with known coordinates (including an antimeridian case and an
  empty geometry case) and assert units explicitly.
