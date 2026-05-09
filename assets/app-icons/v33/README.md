# Next2V app icon variants (v33)

Base geometry: v25/v24 locked mark — two vertical-side rounded parallelograms with a shared right vertical edge, scaled to 94% foreground size.

Default project icon: `sunset_solid`.

Variants:
- `cyan_solid`, `cyan_glass`
- `azure_solid`, `azure_glass`
- `emerald_solid`, `emerald_glass`
- `sunset_solid`, `sunset_glass`
- `coral_solid`, `coral_glass`
- `slate_solid`, `slate_glass`

Files:
- `*_1024.png`: 1024×1024 square PNG source for app-store/AGC style assets.
- `*.svg`: vector source.

HarmonyOS notes:
- HarmonyOS launcher icons use layered resources (`app_icon_layered.json`) with separate 1024px background and transparent foreground PNGs.
- `entry/src/main/resources/base/media/app_icon_layered.json` and `AppScope/resources/base/media/app_icon_layered.json` point to `sunset_solid`.
- Flat PNGs (`app_icon.png` and `assets/agc/app_icon_1024.png`) are kept as fallback/store assets and are set to `sunset_solid`.
