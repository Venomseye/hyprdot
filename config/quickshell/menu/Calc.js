.pragma library

// Safe calculator for the menu: a small recursive-descent parser, no eval().
//   numbers   12  3.5  .5  1e3
//   operators + - * / % ^ (also **), parentheses, unary minus
//   constants pi  e  tau
//   functions sqrt cbrt abs round floor ceil exp ln log(base 10) sin cos tan asin acos atan min max pow
// evaluate("2*(3+4)^2") -> { ok: true, value: 98 };  anything else -> { ok: false }

const FUNCS = {
    sqrt: Math.sqrt, cbrt: Math.cbrt, abs: Math.abs, round: Math.round, floor: Math.floor, ceil: Math.ceil,
    exp: Math.exp, ln: Math.log, log: Math.log10, sin: Math.sin, cos: Math.cos, tan: Math.tan,
    asin: Math.asin, acos: Math.acos, atan: Math.atan, min: Math.min, max: Math.max, pow: Math.pow
};
const CONSTS = { pi: Math.PI, e: Math.E, tau: 2 * Math.PI };

function evaluate(input) {
    const s = String(input).replace(/\*\*/g, "^").replace(/\u00d7/g, "*").replace(/\u00f7/g, "/");
    let i = 0;

    function bad() { throw new Error("syntax"); }
    function ws() { while (i < s.length && (s[i] === " " || s[i] === "\t")) i++; }
    function peek() { ws(); return s[i]; }

    function expr() {
        let v = term();
        for (;;) {
            const c = peek();
            if (c === "+") { i++; v += term(); }
            else if (c === "-") { i++; v -= term(); }
            else return v;
        }
    }

    function term() {
        let v = unary();
        for (;;) {
            const c = peek();
            if (c === "*") { i++; v *= unary(); }
            else if (c === "/") { i++; v /= unary(); }
            else if (c === "%") { i++; v %= unary(); }
            else return v;
        }
    }

    // -3^2 is -(3^2); 2^3^2 is 2^(3^2); 2^-3 works.
    function unary() {
        const c = peek();
        if (c === "-") { i++; return -unary(); }
        if (c === "+") { i++; return unary(); }
        return power();
    }

    function power() {
        const base = primary();
        if (peek() === "^") { i++; return Math.pow(base, unary()); }
        return base;
    }

    function primary() {
        ws();
        const rest = s.slice(i);
        let m = rest.match(/^(\d+\.?\d*|\.\d+)(e[+-]?\d+)?/i);
        if (m) { i += m[0].length; return parseFloat(m[0]); }
        if (s[i] === "(") {
            i++;
            const v = expr();
            if (peek() !== ")") bad();
            i++;
            return v;
        }
        m = rest.match(/^[a-z][a-z0-9]*/i);
        if (m) {
            const name = m[0].toLowerCase();
            i += m[0].length;
            if (peek() === "(") {
                i++;
                const args = [expr()];
                while (peek() === ",") { i++; args.push(expr()); }
                if (peek() !== ")") bad();
                i++;
                if (!Object.prototype.hasOwnProperty.call(FUNCS, name)) bad();
                return FUNCS[name].apply(null, args);
            }
            if (Object.prototype.hasOwnProperty.call(CONSTS, name)) return CONSTS[name];
        }
        return bad();
    }

    try {
        const v = expr();
        ws();
        if (i !== s.length || typeof v !== "number" || !isFinite(v)) return { ok: false };
        return { ok: true, value: v };
    } catch (e) {
        return { ok: false };
    }
}

// Worth showing as a calculator row: has a digit and an operator/function, or starts with "=".
function looksLikeMath(term) {
    return /\d/.test(term) && /[+\-*/^%()]/.test(term);
}

function format(v) {
    if (Number.isInteger(v) && Math.abs(v) < 1e15) return String(v);
    return String(Number(v.toPrecision(12)));
}
