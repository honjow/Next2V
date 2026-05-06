# HDS Usage Notes

Date: 2026-05-06

## Scope

These notes describe how Next2V currently uses Harmony Design System components in the app shell and settings-style screens. They are implementation rules for this repository, not a general HDS reference.

## App Shell

- `entry/src/main/ets/pages/Index.ets` owns the HDS shell.
- The root is `HdsNavigation(this.ns)` with stack destinations registered in `pm`.
- Main sections use `HdsTabs` with a floating bottom bar. Tab pages must leave enough bottom padding for `bottomAvoidHeight + ThemeConstants.FLOAT_BAR_HEIGHT`.
- Route pages should be mounted as `HdsNavDestination() { PageComponent() }.titleBar(this.navDestTitleBarOpts())`.
- Feature pages should be content components. Do not nest a platform `NavDestination` or another HDS navigation shell inside route pages.

## Safe Area And Title Bar

- Shared safe-area values come from `StorageKeys.TOP_AVOID_HEIGHT` and `StorageKeys.BOTTOM_AVOID_HEIGHT`.
- Main tab pages account for the root HDS title bar with `topH + ThemeConstants.TITLE_BAR_HEIGHT`.
- Home additionally accounts for the feed pill bottom builder with `ApiConstants.TAB_BAR_HEIGHT`.
- Stack destination content should add top padding for `topH + ThemeConstants.TITLE_BAR_HEIGHT`, plus normal content spacing when needed.
- Scrollable pages should keep bottom blank space or bottom padding when content can pass under the floating tab bar.

## Settings/List Layouts

- Use grouped list sections for settings-like surfaces: section header, card background, rows, inset divider.
- Keep cards for grouped content or repeated content items. Do not wrap every single setting in its own standalone card.
- Binary settings use `Toggle({ type: ToggleType.Switch })`.
- Small command groups and segmented choices use `ButtonType.Normal`, `ThemeConstants.RADIUS_MD`, and `ThemeConstants.TOUCH_TARGET_SM`.
- Destructive actions require explicit user confirmation before changing persisted state or clearing data.

## Tokens

- Use `ThemeConstants` for spacing, radii, font sizes, and stable touch dimensions.
- Prefer system color resources or `ThemeConstants` semantic aliases for text/background colors.
- Hard-coded colors should be limited to intentional semantic cases, such as selected button text on brand background or destructive/error states.
- Dense settings rows should use `FONT_SIZE_BODY` for primary labels, `FONT_SIZE_CAPTION` for descriptions, and `FONT_SIZE_TINY` for compact metadata.
- Text that can be user-generated or long should set `maxLines` and `textOverflow`.

## Route Checklist

Before adding or changing an HDS route:

1. Register the route in `Index.pm` with `HdsNavDestination`.
2. Keep the page body as a standalone content component.
3. Use shared top/bottom safe-area storage props.
4. Use `ThemeConstants` instead of local numeric spacing or button dimensions.
5. Run `bash dev.sh --build-only`.
6. Install on the debug device and capture screenshots for overlap, scrolling, and dark-mode readability.
