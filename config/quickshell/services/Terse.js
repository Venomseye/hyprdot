.pragma library

// Split one line of `nmcli -t` output on ":" while honouring "\:" and "\\" escapes
// (SSIDs can contain colons).
function split(line) {
    const out = [];
    let cur = "";
    for (let i = 0; i < line.length; i++) {
        const c = line[i];
        if (c === "\\" && i + 1 < line.length) { cur += line[i + 1]; i++; }
        else if (c === ":") { out.push(cur); cur = ""; }
        else cur += c;
    }
    out.push(cur);
    return out;
}
