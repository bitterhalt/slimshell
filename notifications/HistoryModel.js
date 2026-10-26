.pragma library

function iconFromImage(image) {
    image = String(image || "")
    return image.startsWith("image://icon/") ? image.substring(13) : ""
}

function actionLabel(action) {
    return action.text || (action.identifier === "default" ? "Open" : "Action")
}

function isCloseAction(action) {
    return actionLabel(action).replace(/&/g, "").trim().toLowerCase() === "close"
}

function actionsFor(actions) {
    const used = new Set(["x", "j", "k"])
    const seen = new Set()
    const entries = []
    for (let i = 0; i < (actions || []).length; ++i) {
        const action = actions[i]
        const label = actionLabel(action)
        const normalized = label.replace(/&/g, "").trim().toLowerCase()
        if (isCloseAction(action) || seen.has(normalized))
            continue
        seen.add(normalized)
        const candidates = label.toLowerCase().replace(/[^a-z0-9]/g, "")
            + "abcdefghijklmnopqrstuvwxyz0123456789"
        const key = candidates.split("").find(letter => !used.has(letter)) || ""
        if (key !== "")
            used.add(key)
        entries.push({label: label, key: key, action: action})
    }
    return entries
}

function selectionIndex(rows, id, fallback) {
    const index = rows.findIndex(row => String(row.id) === id)
    return index >= 0 ? index : rows.length ? Math.max(0, Math.min(rows.length - 1, fallback)) : -1
}
