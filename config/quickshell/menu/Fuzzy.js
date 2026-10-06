.pragma library

// Scoring for the menu search. 0 = no match, higher = better.
//   prefix match > substring > word initials ("sd" -> "Shut Down") > fuzzy
//   subsequence ("rlh" -> "Reload Hyprland").
function score(query, text) {
    if (!text) return 0;
    const t = text.toLowerCase();
    const i = t.indexOf(query);
    if (i === 0) return 100;
    if (i > 0) return 80 - Math.min(i, 30);

    const initials = t.split(/[\s\-_\u203a]+/).filter(w => w !== "").map(w => w[0]).join("");
    if (initials.startsWith(query)) return 70;
    if (initials.indexOf(query) >= 0) return 55;

    let pos = -1;
    let gaps = 0;
    for (let k = 0; k < query.length; k++) {
        const p = t.indexOf(query[k], pos + 1);
        if (p < 0) return 0;
        if (pos >= 0) gaps += p - pos - 1;
        pos = p;
    }
    return Math.max(10, 45 - gaps);
}

// Best score of `query` over several fields (name, generic name, ...).
function best(query, fields) {
    let s = 0;
    for (const f of fields) s = Math.max(s, score(query, f));
    return s;
}

// Flatten a menu tree below `nodes` into leaf rows, scored against `query`.
// Labels carry the trail ("System > Lock") so you can tell duplicates apart.
function search(query, nodes, trail) {
    const out = [];
    for (const n of nodes) {
        const here = trail.concat([n.title]);
        if (n.children) {
            for (const r of search(query, n.children, here)) out.push(r);
        } else {
            const s = best(query, [n.title, here.join(" \u203a ")]);
            if (s > 0) {
                out.push({
                    title: n.title,
                    subtitle: trail.join(" \u203a "),
                    glyph: n.glyph || "",
                    node: n,
                    action: n.action || "",
                    children: false,
                    score: s
                });
            }
        }
    }
    return out;
}
