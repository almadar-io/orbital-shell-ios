import CoreGraphics

// Tailwind maxWidth / width / minWidth scales resolved from @almadar/ui tailwind-preset.cjs (rem x 16 -> dp/pt, px as-is).
// Only static length entries are emitted. Keyword and relative entries (none, full, min, max, fit, prose, screen,
// auto, percentages, var(--token, px) entries) are not lengths: `full` means "no cap" and is expressed at the call
// site (Dp.Infinity / .infinity), never as a member here.
enum AlmadarSizes {
{{members}}
}
