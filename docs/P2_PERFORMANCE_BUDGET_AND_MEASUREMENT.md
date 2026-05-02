# P2 Performance Budget and Measurement Plan

Owner: __________  
Date: __________  
Build: __________  
Device tier(s): low / mid / high

## Targets (Initial Budget)

## 1) App Startup

- Cold start to first usable screen:
  - Low-end: <= 4.0s
  - Mid-end: <= 3.0s
  - High-end: <= 2.2s
- Warm start to usable screen:
  - All tiers: <= 1.2s

## 2) SkulMate Generation Latency (Client-perceived)

- Text source:
  - p50 <= 12s, p95 <= 25s
- Document/image source:
  - p50 <= 20s, p95 <= 40s

## 3) UI Smoothness

- No sustained jank during Upload -> Generate -> Results flow
- Keep frame build/raster spikes minimal on mid/low devices

## 4) Memory Guardrails

- Avoid runaway memory growth during image/document upload
- Verify no repeated large allocation spikes after returning from generation

## Measurement Procedure

## A) Startup timing

1. Run release build on target device.
2. Capture 5 cold starts + 5 warm starts.
3. Record median and p95.

## B) Generation timing

1. Run 10 text generations, 10 file/image generations.
2. Track:
   - tap on Generate timestamp
   - game-ready / error visible timestamp
3. Report p50/p95 and failure rate.

## C) Runtime profiling

Use Flutter DevTools (profile/release mode):
- CPU and frame timeline around:
  - Upload selection
  - Generation transition
  - Results render
- Memory snapshots before upload / during upload / after results

## D) Backend timing (SkulMate route)

Record from backend logs:
- extraction time
- generation model + duration
- total request time
- 4xx/5xx counts

## Optimization Backlog Template

For each issue:
- Symptom:
- Repro steps:
- Device tier:
- Baseline metric:
- Proposed fix:
- Post-fix metric:

## Sign-off

- [ ] Startup budget met on target devices
- [ ] Generation latency budget met (or accepted deviations documented)
- [ ] Memory profile acceptable
- [ ] Jank profile acceptable

