.pragma library

// Low urgency still gets a toast; only DND and notification updates suppress it.
function shouldShow(notification, dnd) {
    return !!notification && !dnd && !notification.lastGeneration
}
