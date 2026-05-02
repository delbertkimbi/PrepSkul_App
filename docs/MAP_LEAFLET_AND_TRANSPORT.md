# Map Widget: Leaflet (OSM) and Future Transport Cost

## Decision: Use Leaflet, Not Google Maps

The in-app map placeholder should be replaced with **Leaflet** (OpenStreetMap-based), not Google Maps.

- **No API key** required for OSM tiles (and typically for OSRM routing).
- **Good coverage in Cameroon**; OSM is well-mapped for the target regions.
- **Cost**: Free tiles and routing vs Google’s pricing.
- **Routing**: Leaflet Routing Machine (or similar) with OSRM gives turn-by-turn/directions.

### Flutter implementation options

1. **flutter_map** – Native Flutter map with OSM tiles (e.g. OpenStreetMap or Stadia). Show session location; “Get directions” can open OSM/Leaflet in browser or in-app WebView for full routing.
2. **WebView with Leaflet + Routing Machine** – Full in-app Leaflet map and routing UI; requires a small HTML/JS map page and WebView.

Use whichever fits the app best (simpler: flutter_map + link out for directions; richer: WebView + Leaflet Routing Machine).

---

## Later: Tutor Transport Cost (Home → Onsite)

Leaflet/OSM routing will also support a **future feature**:

- During **onsite booking**, approximate the **tutor’s travel** from their home to the parent’s onsite address.
- Use **distance/duration** from routing (e.g. OSRM) to **adapt transportation cost** (e.g. show or suggest a transport fee based on distance).

No implementation now; this doc is the reference for when that feature is prioritized. The map/routing choice (Leaflet + OSRM) is already aligned with it.
