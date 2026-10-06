.pragma library

// Pure date helpers for the calendar popup (kept out of QML so they're testable).

// ISO-8601 week number of the week containing `d`.
function isoWeek(d) {
    const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
    const day = t.getUTCDay() || 7;
    t.setUTCDate(t.getUTCDate() + 4 - day);
    const yearStart = new Date(Date.UTC(t.getUTCFullYear(), 0, 1));
    return Math.ceil(((t - yearStart) / 86400000 + 1) / 7);
}

// Monday on or before the 1st of the month containing `month`.
function gridStart(month) {
    const first = new Date(month.getFullYear(), month.getMonth(), 1);
    const offset = (first.getDay() + 6) % 7;
    return new Date(first.getFullYear(), first.getMonth(), 1 - offset);
}

// Date for grid row r (0-5), weekday column c (0 = Monday .. 6 = Sunday).
function cellDate(month, r, c) {
    const s = gridStart(month);
    return new Date(s.getFullYear(), s.getMonth(), s.getDate() + r * 7 + c);
}

function sameDay(a, b) {
    return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
}
