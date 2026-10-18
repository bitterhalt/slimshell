.pragma library

// Size from the original input, not the filtered matches, to avoid resizing
// while typing. Keep oversized requests within the available screen space.
function visibleRows(lines, minimal, itemCount, availableRows) {
    const requested = Math.max(0, lines)
    const count = minimal ? Math.min(requested, itemCount) : requested
    return Math.min(count, Math.max(0, availableRows))
}
