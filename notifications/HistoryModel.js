.pragma library

function actionsFor(actions) {
    const used = new Set(["c", "x", "j", "k"])
    const entries = []
    let hasClose = false
    for (let i = 0; i < (actions || []).length; ++i) {
        const action = actions[i]
        const label = action.text || (action.identifier === "default" ? "Open" : "Action")
        const close = label.replace(/&/g, "").trim().toLowerCase() === "close"
        if (close && hasClose)
            continue
        let key = "c"
        if (close) {
            hasClose = true
        } else {
            const candidates = label.toLowerCase().replace(/[^a-z0-9]/g, "")
                + "abcdefghijklmnopqrstuvwxyz0123456789"
            key = candidates.split("").find(letter => !used.has(letter)) || ""
            if (key !== "")
                used.add(key)
        }
        entries.push({label: label, key: key, action: action, dismiss: close})
    }
    if (!hasClose)
        entries.push({label: "Close", key: "c", action: null, dismiss: true})
    return entries
}

function selectionIndex(rows, id, fallback) {
    const index = rows.findIndex(row => String(row.id) === id)
    return index >= 0 ? index : rows.length ? Math.max(0, Math.min(rows.length - 1, fallback)) : -1
}
