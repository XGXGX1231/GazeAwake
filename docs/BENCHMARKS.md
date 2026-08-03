# Benchmarks

## Important result

The current `VNDetectFaceLandmarksRequest` mode does **not** meet the original target of less than 20 MB memory and less than 5% CPU.

## Test machine

Only non-sensitive hardware fields are included.

| Field | Value |
|---|---|
| Model | MacBook Pro |
| Model identifier | Mac17,2 |
| Chip | Apple M5 |
| CPU cores | 10 total: 4 performance + 6 efficiency |
| Logical CPUs | 10 |
| Memory | 16 GB |
| Architecture | arm64 |
| macOS | 26.5.2 (25F84) |
| Xcode | 26.6 (17F113) |
| Swift | 6.3.3 compiler, Swift 5 language mode |
| Deployment target | macOS 13.0 |

Serial number, hardware UUID, account name, and device identifiers are intentionally omitted.

## Build and workload

- Release configuration, `-Osize`
- Locally signed application, not attached to the Xcode debugger
- Camera authorized and active
- Low-resolution session preset
- 12 fps capture
- Every third frame evaluated (~4 Vision requests/s)
- `VNDetectFaceLandmarksRequestRevision3`
- Measurement taken after approximately five minutes of active operation and Vision warm-up

## Observed results

| Metric | Observed value |
|---|---:|
| Pre-active startup physical footprint | ~11–12 MB |
| Active `phys_footprint` | 217,367,776 bytes (~207.3 MiB / 217 MB) |
| Peak `phys_footprint` | 305,792,152 bytes (~291.6 MiB / 306 MB) |
| `neural_peak` | 131,907,584 bytes (~125.8 MiB / 132 MB) |
| `ps` RSS | 106,688 KiB (~104.2 MiB / 109 MB) |
| Short CPU samples | ~21–27% |

The startup figure was observed before active camera/Vision processing and must not be presented as operational usage.

## Measurement commands

```bash
PID=$(pgrep -x GazeAwake | head -1)
ps -o pid=,%cpu=,rss=,etime= -p "$PID"
footprint --noCategories --format bytes "$PID"
```

Longer CSV sampling:

```bash
./Scripts/monitor-resources.sh 300
```

## Metric interpretation

- **Physical footprint** is the preferred process-level memory metric for this project.
- **RSS** includes resident mappings and uses a different accounting model; it should not be compared directly with physical footprint.
- **Neural peak** indicates substantial system-managed neural processing resources.
- Instruments and the debugger can perturb results.

## Why low-resolution frames are not the dominant cost

Approximate NV12 frame sizes:

| Resolution | One frame |
|---|---:|
| 320×240 | ~112.5 KiB |
| 352×288 | ~148.5 KiB |
| 640×480 | ~450 KiB |

Even a small CoreVideo pool is far below the observed neural and Vision allocation. Lowering inference frequency can reduce CPU, but it does not guarantee that Vision unloads its model or internal resources.

## Expected variability

Vision does not publish a per-request memory ceiling. Results can vary with:

- macOS and Vision framework version;
- Mac chip and available accelerators;
- camera driver and negotiated format;
- scene content and number of faces;
- warm-up state and system memory pressure;
- measurement tool.

Do not generalize the M5 result into a universal maximum or minimum.

## Lower-power research direction

A future mode may use `AVCaptureMetadataOutput` face metadata or `VNDetectFaceRectanglesRequest`, reduce evaluation to 1–2 fps, and replace pupils with face position/orientation. That would reduce semantic accuracy to coarse presence/attention and still requires measurement on every supported baseline. A strict 20 MB guarantee is not promised.
