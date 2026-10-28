// Cottonil dashboard logic. Loaded after data.js (window.COTTONIL).
"use strict";
const D = window.COTTONIL;

// n8n webhooks. The ngrok address changes every time ngrok restarts: update N8N_BASE only.
// Set it to "" to show the page without n8n (buttons and chat stay disabled).
const N8N_BASE = "";   // public copy: webhook address removed. Put your n8n webhook base here to go live.
const N8N = N8N_BASE ? { reactivation: N8N_BASE + "cottonil-reactivation", guardrail: N8N_BASE + "cottonil-guardrail",
  digest: N8N_BASE + "cottonil-digest", assistant: N8N_BASE + "cottonil-assistant" } : {};

/* ---------- format ---------- */
const nf0 = new Intl.NumberFormat("en-US", {maximumFractionDigits:0});
const nf1 = new Intl.NumberFormat("en-US", {minimumFractionDigits:1, maximumFractionDigits:1});
const nf2 = new Intl.NumberFormat("en-US", {minimumFractionDigits:2, maximumFractionDigits:2});
const M = v => (Math.abs(v) >= 1e6 ? nf1.format(v/1e6) + "M" : Math.abs(v) >= 1e3 ? nf0.format(v/1e3) + "K" : nf0.format(v));
const pct = (v, d=1) => (d===2?nf2:nf1).format(v) + "%";
const sgn = v => (v >= 0 ? "+" : "−") + nf1.format(Math.abs(v)) + "%";
const el = (tag, cls, txt) => { const e = document.createElement(tag); if (cls) e.className = cls; if (txt != null) e.textContent = txt; return e; };
const css = name => getComputedStyle(document.documentElement).getPropertyValue(name).trim();
const NS = "http://www.w3.org/2000/svg";
const S = (tag, attrs={}, parent) => { const e = document.createElementNS(NS, tag); for (const k in attrs) e.setAttribute(k, attrs[k]); if (parent) parent.appendChild(e); return e; };

/* ---------- tooltip ---------- */
const tip = document.getElementById("tip");
function showTip(x, y, title, rows){
  tip.replaceChildren();
  tip.appendChild(el("div", "tt", title));
  rows.forEach(r => { const d = el("div", "tr"); if (r.color){ const i = el("i"); i.style.background = r.color; d.appendChild(i); }
    d.appendChild(el("b", null, r.value)); d.appendChild(el("span", null, r.label)); tip.appendChild(d); });
  tip.hidden = false;
  const w = tip.offsetWidth, h = tip.offsetHeight;
  let left = x + 14, top = y - h - 10;
  if (left + w > innerWidth - 8) left = x - w - 14;
  if (top < 8) top = y + 16;
  tip.style.left = left + "px"; tip.style.top = top + "px";
}
const hideTip = () => { tip.hidden = true; };
// pointerleave is skipped when the mouse exits the window fast or the tab loses focus, so hide on anything outside a [data-tip] owner
addEventListener("pointermove", e => { if (!tip.hidden && !e.target.closest?.("[data-tip]")) hideTip(); }, {passive:true});
document.documentElement.addEventListener("pointerleave", hideTip);
addEventListener("blur", hideTip);
addEventListener("pointerdown", e => { if (!e.target.closest?.("[data-tip]")) hideTip(); });

/* ---------- table helper ---------- */
function table(target, head, rows, rightCols=[]){
  const t = el("table"), tr = el("tr");
  head.forEach((h,i) => { const th = el("th", rightCols.includes(i) ? "r" : null, h); tr.appendChild(th); });
  const th = el("thead"); th.appendChild(tr); t.appendChild(th);
  const tb = el("tbody");
  rows.forEach(r => { const row = el("tr"); r.forEach((c,i) => row.appendChild(el("td", rightCols.includes(i) ? "r" : null, c))); tb.appendChild(row); });
  t.appendChild(tb); document.getElementById(target).replaceChildren(t);
}

/* ---------- nice ticks ---------- */
function ticks(min, max, n=5){
  const span = max - min, step0 = span / n, mag = Math.pow(10, Math.floor(Math.log10(step0)));
  const step = [1,2,2.5,5,10].map(m => m*mag).find(s => s >= step0);
  const lo = Math.floor(min/step)*step, hi = Math.ceil(max/step)*step, out = [];
  for (let v = lo; v <= hi + 1e-9; v += step) out.push(+v.toFixed(10));
  return out;
}

/* ---------- line chart ---------- */
function lineChart(id, {labels, series, yFmt, height=260, yMin, endLabels=true, xEvery=1, zero=false, startLabel=false}){
  const host = document.getElementById(id); host.replaceChildren();
  const W = Math.max(300, host.clientWidth), H = typeof height === "function" ? height(W) : height;
  const m = {l:44, r: endLabels ? 108 : 14, t:12, b:26};
  const all = series.flatMap(s => s.values);
  let lo = yMin != null ? yMin : Math.min(...all), hi = Math.max(...all);
  if (zero) lo = Math.min(0, lo);
  const tk = ticks(lo, hi, 4); lo = tk[0]; hi = tk[tk.length-1];
  const x = i => m.l + (labels.length === 1 ? 0 : i * (W - m.l - m.r) / (labels.length - 1));
  const y = v => m.t + (hi - v) * (H - m.t - m.b) / (hi - lo);
  const svg = S("svg", {viewBox:`0 0 ${W} ${H}`, role:"img"}, host);
  const ax = S("g", {class:"ax"}, svg);
  tk.forEach(v => { S("line", {class: v===0 ? "b" : "g", x1:m.l, x2:W-m.r, y1:y(v), y2:y(v)}, ax);
    const t = S("text", {x:m.l-8, y:y(v)+4, "text-anchor":"end"}, ax); t.textContent = yFmt(v); });
  labels.forEach((L,i) => { if (i % xEvery) return; const t = S("text", {x:x(i), y:H-6, "text-anchor":"middle"}, ax); t.textContent = L; });
  series.forEach(s => {
    const d = s.values.map((v,i) => (i ? "L" : "M") + x(i).toFixed(1) + " " + y(v).toFixed(1)).join(" ");
    S("path", {d, fill:"none", stroke:s.color, "stroke-width":2, "stroke-linejoin":"round", "stroke-linecap":"round"}, svg);
    const li = s.values.length - 1;
    S("circle", {cx:x(li), cy:y(s.values[li]), r:4, fill:s.color, stroke:css("--surface"), "stroke-width":2}, svg);
  });
  if (endLabels){
    const ends = series.map(s => ({s, y:y(s.values[s.values.length-1])})).sort((a,b) => a.y - b.y);
    for (let i = 1; i < ends.length; i++) if (ends[i].y - ends[i-1].y < 30) ends[i].y = ends[i-1].y + 30;
    ends.forEach(e => {
      const v = S("text", {x:W-m.r+10, y:e.y, class:"lbl-ink"}, svg); v.textContent = yFmt(e.s.values[e.s.values.length-1], true);
      const n = S("text", {x:W-m.r+10, y:e.y+14, class:"lbl-2"}, svg); n.textContent = e.s.short || e.s.name;
    });
  }
  if (startLabel){
    series.forEach(s => { const t = S("text", {x:x(0)+8, y:y(s.values[0])-8, class:"lbl-ink"}, svg); t.textContent = yFmt(s.values[0], true);
      S("circle", {cx:x(0), cy:y(s.values[0]), r:4, fill:s.color, stroke:css("--surface"), "stroke-width":2}, svg); });
  }
  const cross = S("line", {class:"hair", y1:m.t, y2:H-m.b, x1:m.l, x2:m.l, visibility:"hidden"}, svg);
  const hit = S("rect", {x:m.l-10, y:0, width:W-m.l-m.r+20, height:H, fill:"transparent", "data-tip":""}, svg);
  const move = ev => {
    const r = svg.getBoundingClientRect(), px = (ev.clientX - r.left) * W / r.width;
    const i = Math.max(0, Math.min(labels.length-1, Math.round((px - m.l) / ((W - m.l - m.r) / Math.max(1, labels.length - 1)))));
    cross.setAttribute("x1", x(i)); cross.setAttribute("x2", x(i)); cross.setAttribute("visibility", "visible");
    showTip(ev.clientX, ev.clientY, labels[i], series.map(s => ({color:s.color, value:yFmt(s.values[i], true), label:s.name})));
  };
  hit.addEventListener("pointermove", move);
  hit.addEventListener("pointerleave", () => { hideTip(); cross.setAttribute("visibility", "hidden"); });
}

/* ---------- column chart ---------- */
function columns(id, {items, yFmt, height=220, ref, color, labelAll=false}){
  const host = document.getElementById(id); host.replaceChildren();
  const W = Math.max(280, host.clientWidth), H = typeof height === "function" ? height(W) : height, m = {l:40, r:8, t:20, b:26};
  const vals = items.map(d => d.value);
  const tk = ticks(Math.min(0, ...vals), Math.max(...vals), 4), lo = tk[0], hi = tk[tk.length-1];
  const bw = (W - m.l - m.r) / items.length, barW = Math.min(24, bw * 0.62);
  const y = v => m.t + (hi - v) * (H - m.t - m.b) / (hi - lo);
  const svg = S("svg", {viewBox:`0 0 ${W} ${H}`, role:"img"}, host);
  const ax = S("g", {class:"ax"}, svg);
  tk.forEach(v => { S("line", {class: v===lo ? "b" : "g", x1:m.l, x2:W-m.r, y1:y(v), y2:y(v)}, ax);
    const t = S("text", {x:m.l-8, y:y(v)+4, "text-anchor":"end"}, ax); t.textContent = yFmt(v); });
  if (ref != null){ S("line", {x1:m.l, x2:W-m.r, y1:y(ref), y2:y(ref), stroke:css("--axis"), "stroke-width":1}, svg); }
  items.forEach((d,i) => {
    const cx = m.l + bw*i + bw/2, x0 = cx - barW/2, top = y(d.value), base = y(Math.max(lo,0)), r = Math.min(4, (base-top)/2);
    const fill = d.hl ? color || css("--s1") : (d.quiet ? css("--bar-quiet") : (color || css("--s1")));
    const p = `M${x0} ${base} V${top+r} Q${x0} ${top} ${x0+r} ${top} H${x0+barW-r} Q${x0+barW} ${top} ${x0+barW} ${top+r} V${base} Z`;
    S("path", {d:p, fill}, svg);
    const t = S("text", {x:cx, y:H-6, "text-anchor":"middle"}, ax); t.textContent = d.label;
    if (labelAll || d.hl){ const v = S("text", {x:cx, y:top-6, "text-anchor":"middle", class:"lbl-ink"}, svg); v.textContent = yFmt(d.value, true); }
    const hit = S("rect", {x:m.l + bw*i, y:m.t, width:bw, height:H-m.t-m.b, fill:"transparent", "data-tip":""}, svg);
    hit.addEventListener("pointermove", ev => showTip(ev.clientX, ev.clientY, d.tipTitle || d.label, [{color:fill, value:yFmt(d.value, true), label:d.tipLabel || ""}]));
    hit.addEventListener("pointerleave", hideTip);
  });
}

/* ---------- horizontal bars (html) ---------- */
function hbars(id, items, fmt){
  const host = document.getElementById(id); host.replaceChildren();
  const max = Math.max(...items.map(d => d.total || d.value));
  items.forEach(d => {
    const row = el("div", "hb" + (d.hl ? " hl" : "")); row.dataset.tip = "";
    row.appendChild(el("div", "t", d.label));
    const tr = el("div", "track");
    if (d.total){ const q = el("div", "fill tot"); q.style.width = (100*d.total/max) + "%"; tr.appendChild(q); }
    const f = el("div", "fill" + (d.total ? " part" : "")); f.style.width = (100*d.value/max) + "%";
    tr.appendChild(f); row.appendChild(tr);
    row.appendChild(el("div", "v", fmt(d)));
    row.addEventListener("pointermove", ev => showTip(ev.clientX, ev.clientY, d.label, d.tip));
    row.addEventListener("pointerleave", hideTip);
    host.appendChild(row);
  });
}

/* ---------- data prep ---------- */
const Y = D.yearly.filter(r => !r.partial);                 // 2019..2025
const y19 = Y[0], y25 = Y[Y.length-1];
const totalNet = D.category.reduce((a,c) => a + c.net, 0);
const totalUnits = D.category.reduce((a,c) => a + c.units, 0);
const ytdNet = 100*(D.ytd.net26/D.ytd.net25 - 1), ytdU = 100*(D.ytd.u26/D.ytd.u25 - 1);
const dorm = D.rfm.filter(r => r.dormant), dormN = dorm.reduce((a,r) => a + r.n, 0);
const hiD = D.rfm.find(r => r.tier === "High" && r.dormant);

document.getElementById("th-net").textContent = nf1.format(y25.net/y19.net) + "×";
document.getElementById("th-units").textContent = nf1.format(y25.units/y19.units) + "×";
const heroBig = document.getElementById("hero-net");
heroBig.firstChild.textContent = nf1.format(D.l12m.net/1e6) + "M";

/* tiles */
const tiles = [
  {lbl:"Net revenue, Jan–Sep 2026", v:M(D.ytd.net26) + " EGP", d:sgn(ytdNet) + " vs Jan–Sep 2025", cls:"up"},
  {lbl:"Pieces sold, Jan–Sep 2026", v:nf0.format(D.ytd.u26), d:sgn(ytdU) + " vs Jan–Sep 2025", cls:"up"},
  {lbl:"Gross margin, 2025", v:pct(y25.gm), d:"Between " + pct(Math.min(...Y.map(r => r.gm)), 2) + " and " + pct(Math.max(...Y.map(r => r.gm)), 2) + " every year since 2019", cls:""},
  {lbl:"Orders per registered customer, 2025", v:nf2.format(y25.opc), d:"Down from " + nf2.format(y19.opc) + " in 2019", cls:"down"},
];
const tilesEl = document.getElementById("tiles");
tiles.forEach(t => { const d = el("div", "tile"); d.append(el("div","lbl",t.lbl), el("div","v",t.v), el("div","d " + t.cls, t.d)); tilesEl.appendChild(d); });

/* five findings */
const capRow = D.capSim.find(c => c.cap === 10);
const five = [
  {fig:nf1.format(y25.net/y19.net) + "×", figSub:"net revenue vs " + nf1.format(y25.units/y19.units) + "× pieces", h:"Growth is price, not volume", p:"Revenue per piece rose " + nf1.format(y25.npu/y19.npu) + "× from 2019 to 2025. Growth depends on prices continuing to rise.", owner:"CFO, Commercial", st:["watch","Watch"], tags:["Computed"], href:"#growth"},
  {fig:pct(D.disc[0].gm) + " → " + pct(D.disc[4].gm), figSub:"gross margin, no discount vs 15–25%", h:"Deep discounts cost margin", p:"A 10% cap would have kept " + M(capRow.egp) + " EGP in the last 12 months if the same lines still sold. Automated as the discount guardrail.", owner:"Commercial director", st:["act","Act now"], tags:["Computed","Scenario"], href:"#discount"},
  {fig:nf2.format(y19.opc) + " → " + nf2.format(y25.opc), figSub:"orders per customer per year", h:"Customers buy less often", p:nf0.format(dormN) + " buyers have not ordered in a year, " + nf0.format(hiD.n) + " of them high-value. Automated as the reactivation workflow.", owner:"CRM manager", st:["act","Act now"], tags:["Computed","Scenario"], href:"#customers"},
  {fig:pct(100*(D.category[0].net + D.category[1].net)/totalNet), figSub:"of revenue from two categories", h:"Revenue leans on men's boxers and tops", p:"Men boxers alone are " + pct(100*D.category[0].net/totalNet) + " of revenue. A shock to one men's line hits the whole year.", owner:"Head of merchandising", st:["watch","Watch"], tags:["Computed","Scenario"], href:"#range"},
  {fig:pct(y19.opex_pct) + " → " + pct(y25.opex_pct), figSub:"operating costs as % of net", h:"Profit gains rest on cost leverage", p:"The 18.8% EBITDA proxy depends on payroll covering 185 of 640 staff. Confirm headcount before quoting profit.", owner:"CFO", st:["cav","Check first"], tags:["Computed","Scenario"], href:"#costs"},
];
const fiveEl = document.getElementById("five");
five.forEach(f => {
  const a = el("a", "frow"); a.href = f.href;
  const fig = el("div", "fig", f.fig); fig.appendChild(el("small", null, f.figSub));
  const mid = el("div"); mid.append(el("h3", null, f.h), el("p", null, f.p));
  const meta = el("div", "meta");
  const st = el("span", "state " + f.st[0]); st.appendChild(el("i")); st.appendChild(document.createTextNode(f.st[1]));
  const tg = el("div"); tg.style.display = "flex"; tg.style.gap = "6px"; tg.style.flexWrap = "wrap";
  f.tags.forEach(t => tg.appendChild(el("span", "tag" + (t === "Scenario" ? " scn" : ""), t)));
  meta.append(st, el("span", null, f.owner), tg);
  a.append(fig, mid, meta); fiveEl.appendChild(a);
});

/* ---------- charts that depend on width ---------- */
// chart height follows its width (ratio), kept between lo and hi so phones and wide screens both read well
const fit = (ratio, lo, hi) => W => Math.round(Math.min(hi, Math.max(lo, W * ratio)));
function drawAll(){
  hideTip();
  if (typeof wireArch === "function") wireArch();
  const s1 = css("--s1"), s2 = css("--s2"), s3 = css("--s3");

  // spark: monthly net, 2019-01..2026-09
  const mo = D.monthly;
  lineChart("ch-spark", {labels: mo.map(r => r[0]), series:[{name:"Net revenue", short:"", color:s1, values: mo.map(r => r[1])}],
    yFmt: v => M(v), height:120, endLabels:false, xEvery:24, zero:true});
  document.querySelectorAll("#ch-spark .ax text").forEach(t => { if (/^\d{4}-\d{2}$/.test(t.textContent)) t.textContent = t.textContent.slice(0,4); });

  // growth index
  const lab = Y.map(r => String(r.yr));
  const idx = k => Y.map(r => 100 * r[k] / y19[k]);
  const gs = [
    {name:"Net revenue", short:"Net revenue", color:s1, values: idx("net")},
    {name:"Revenue per piece", short:"Per piece", color:s2, values: idx("npu")},
    {name:"Pieces sold", short:"Pieces", color:s3, values: idx("units")},
  ];
  lineChart("ch-growth", {labels:lab, series:gs, yFmt:(v) => nf0.format(v), height:fit(0.42, 240, 360), zero:true});
  const lg = document.getElementById("lg-growth"); lg.replaceChildren();
  gs.forEach(s => { const sp = el("span"); const i = el("i"); i.style.background = s.color; sp.append(i, document.createTextNode(s.name)); lg.appendChild(sp); });

  // season
  const mn = ["J","F","M","A","M","J","J","A","S","O","N","D"], mfull = ["January","February","March","April","May","June","July","August","September","October","November","December"];
  columns("ch-season", {items: D.season.map(s => ({label:mn[s.m-1], value:s.net, hl: s.m >= 11, quiet: s.m < 11, tipTitle:mfull[s.m-1], tipLabel:"index"})),
    // side by side with the category bars: match their height so both cards end on one line
    yFmt:(v) => nf0.format(v), ref:100, height: W => getComputedStyle(document.getElementById("range-two")).gridTemplateColumns.split(" ").length > 1
      ? Math.max(240, document.getElementById("hb-cat").offsetHeight) : fit(0.6, 220, 300)(W)});

  // customers
  columns("ch-pool", {items: Y.map(r => ({label:"'" + String(r.yr).slice(2), value:r.pool, tipTitle:String(r.yr), tipLabel:"registered customers", hl: r.yr===2019 || r.yr===2025, quiet: !(r.yr===2019 || r.yr===2025)})),
    yFmt:(v, full) => full ? nf0.format(v) : M(v), height:fit(0.62, 210, 280)});
  lineChart("ch-opc", {labels: Y.map(r => "'" + String(r.yr).slice(2)), series:[{name:"Orders per customer", short:"orders/yr", color:s1, values: Y.map(r => r.opc)}],
    yFmt:(v) => nf2.format(v), height:fit(0.62, 210, 280), zero:true, startLabel:true});

  // discount bands
  columns("ch-disc", {items: D.disc.map(b => ({label:b.band, value:b.gm, tipTitle:"Discount " + b.band, tipLabel:"gross margin · " + nf0.format(b.lines) + " lines"})),
    yFmt:(v, full) => full ? pct(v) : nf0.format(v) + "%", height:fit(0.34, 220, 300), labelAll:true});

  // costs
  const cs = [
    {name:"Operating costs", short:"Opex", color:s1, values: Y.map(r => r.opex_pct)},
    {name:"EBITDA proxy", short:"EBITDA proxy", color:s2, values: Y.map(r => r.ebitda_pct)},
  ];
  lineChart("ch-costs", {labels:lab, series:cs, yFmt:(v) => nf1.format(v) + "%", height:fit(0.38, 230, 330), zero:true});
  const lc = document.getElementById("lg-costs"); lc.replaceChildren();
  cs.forEach(s => { const sp = el("span"); const i = el("i"); i.style.background = s.color; sp.append(i, document.createTextNode(s.name)); lc.appendChild(sp); });
}

/* ---------- static (non-svg) pieces ---------- */
table("tb-growth", ["Year","Net revenue (EGP)","Pieces","Net per piece (EGP)","Index net","Index per piece","Index pieces"],
  Y.map(r => [r.yr, nf0.format(r.net), nf0.format(r.units), nf2.format(r.npu), nf0.format(100*r.net/y19.net), nf0.format(100*r.npu/y19.npu), nf0.format(100*r.units/y19.units)]), [1,2,3,4,5,6]);

hbars("hb-cat", D.category.map((c,i) => ({label:c.cat, value:c.net, hl:i<2,
  tip:[{value:pct(100*c.net/totalNet), label:"of net"},{value:M(c.net) + " EGP", label:"net"},{value:pct(100*c.units/totalUnits), label:"of pieces"}]})),
  d => pct(100*d.value/totalNet));
table("tb-cat", ["Category","Net (EGP)","Share of net","Pieces","Share of pieces","Gross margin"],
  D.category.map(c => [c.cat, nf0.format(c.net), pct(100*c.net/totalNet), nf0.format(c.units), pct(100*c.units/totalUnits), pct(c.gm)]), [1,2,3,4,5]);

const pl = document.getElementById("pl-top");
D.products.forEach((p,i) => { const li = el("li"); li.appendChild(el("span","k", String(i+1).padStart(2,"0")));
  const nm = el("span"); nm.appendChild(el("span","ar", p.n)); nm.appendChild(el("span","c", p.c)); li.appendChild(nm);
  li.appendChild(el("span","v", pct(100*p.net/totalNet))); pl.appendChild(li); });
table("tb-season", ["Month","Index"], D.season.map(s => [["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][s.m-1], nf1.format(s.net)]), [1]);

table("tb-cust", ["Year","Registered customers","Active customers","Registered orders per customer","Active % of list"],
  Y.map(r => [r.yr, nf0.format(r.pool), nf0.format(r.active), nf2.format(r.opc), pct(r.act_pct)]), [1,2,3,4]);

const tiers = ["High","Mid","Low"];
hbars("hb-dorm", tiers.map(t => { const a = D.rfm.find(r => r.tier===t && !r.dormant), d = D.rfm.find(r => r.tier===t && r.dormant);
  return {label:t + " value", value:d.n, total:a.n + d.n, hl: t==="High",
    tip:[{value:nf0.format(d.n), label:"dormant buyers"},{value:M(d.net) + " EGP", label:"their past spend"},{value:nf0.format(a.n), label:"active buyers"}]}; }),
  d => nf0.format(d.value));
table("tb-dorm", ["Tier","Dormant buyers","Dormant past spend (EGP)","Active buyers","Avg order value, dormant (EGP)"],
  tiers.map(t => { const a = D.rfm.find(r => r.tier===t && !r.dormant), d = D.rfm.find(r => r.tier===t && r.dormant);
    return [t, nf0.format(d.n), nf0.format(d.net), nf0.format(a.n), nf0.format(d.aov)]; }), [1,2,3,4]);

table("tb-disc", ["Discount band","Lines","Discount (EGP)","Net (EGP)","Gross margin","Line return rate"],
  D.disc.map(b => [b.band, nf0.format(b.lines), nf0.format(b.disc), nf0.format(b.net), pct(b.gm,2), pct(b.ret,2)]), [1,2,3,4,5]);

table("tb-costs", ["Year","Net (EGP)","Opex (EGP)","Opex %","Payroll paid (EGP)","Paid staff","EBITDA proxy (EGP)","EBITDA proxy %"],
  Y.map(r => [r.yr, nf0.format(r.net), nf0.format(r.opex), pct(r.opex_pct,2), nf0.format(r.payroll), nf0.format(r.paid), nf0.format(r.ebitda), pct(r.ebitda_pct,2)]), [1,2,3,4,5,6,7]);

/* cap simulator */
const seg = document.getElementById("seg-cap"), sim = document.getElementById("sim");
function setCap(c){
  seg.querySelectorAll("button").forEach(b => b.setAttribute("aria-pressed", String(+b.dataset.cap === c)));
  const r = D.capSim.find(x => x.cap === c);
  sim.replaceChildren();
  [["Discount kept", nf2.format(r.egp / 1e6) + "M EGP"], ["Lines above the cap", nf0.format(r.lines)], ["Share of 12-month discount", pct(100*r.egp/D.l12m.disc)]]
    .forEach(([l,v]) => { const d = el("div"); d.append(el("span","lbl",l), el("span","v",v)); sim.appendChild(d); });
}
D.capSim.forEach(c => { const b = el("button", null, c.cap + "% cap"); b.type = "button"; b.dataset.cap = c.cap; b.addEventListener("click", () => setCap(c.cap)); seg.appendChild(b); });
setCap(10);

/* automations */
const G = D.guardDay, DG = D.stack.digest;
const flows = [
  {key:"reactivation", title:"Reactivation", tagline:"Brings back buyers who stopped ordering, and measures whether it worked.",
   st:["act","Monthly"], steps:[
     ["Trigger", "1st of each month, or Run now"],
     ["Picks", "dormant buyers ranked by recency, frequency and spend"],
     ["Holds out", "10% of each group at random, to measure the lift"],
     ["Writes", "one Arabic message per group with the buyer's favourite category; no deep discount"],
     ["Sends", "the plan to the CRM manager on Telegram; nothing goes out without a yes"]],
   preview:{h:"Would select now", rows:[["High-value dormant", nf0.format(hiD.n)],["Their past spend", M(hiD.net) + " EGP"],["Top favourite category", D.reactCat[0].c + " (" + nf0.format(D.reactCat[0].n) + ")"],["Held out (about 10%)", nf0.format(Math.round(hiD.n*0.1))]]}},
  {key:"guardrail", title:"Discount guardrail", tagline:"Flags lines discounted above 15%, with the margin lost in EGP.",
   st:["act","Daily"], steps:[
     ["Trigger", "every morning, or replay any past day"],
     ["Reads", "yesterday's order lines above 15% discount (about 22 a day)"],
     ["Counts", "EGP given above a 10% cap, by channel and category"],
     ["Writes", "a short alert with the amount and one suggested action"],
     ["Sends", "to the commercial director; logs every alert"]],
   preview:{h:"Replay of " + G.day, rows:[["Lines above 15%", nf0.format(G.lines)],["EGP above the 10% cap", nf0.format(G.excess)],["Largest channel", G.byChannel[0].ch + " (" + nf0.format(G.byChannel[0].ex) + " EGP)"],["Last 12 months", M(G.l12mExcess) + " EGP · " + nf0.format(G.l12mLines) + " lines"]]}},
  {key:"assistant", title:"Ask the data", tagline:"Answers questions with the number, its period and its source. Refuses what the data cannot answer.",
   st:["ok","On demand"], steps:[
     ["Trigger", "a question in the chat below"],
     ["Finds", "definitions, rules and checked SQL examples (46 entries)"],
     ["Queries", "certified views only, read-only account"],
     ["Answers", "with the number from the query; no number from memory"],
     ["Proves", "a 19-question test set scored before the demo"]],
   preview:{h:"Knowledge base", rows:[["Entries", "46"],["Checked SQL examples", "14"],["Refusal rules", "10"],["Raw tables it can read", "0"]]}},
  {key:"digest", title:"Weekly digest", tagline:"One short message every Monday: how last week went and whether the other workflows are healthy.",
   st:["ok","Weekly"], steps:[
     ["Trigger", "Monday 08:00, or Run now"],
     ["Reads", "last week's sales against the week before and the same week last year"],
     ["Adds", "discount above the cap, reactivation status and assistant health"],
     ["Writes", "the message with fixed rules; no AI, so no invented numbers"],
     ["Sends", "to management on Telegram"]],
   preview:{h:"Last digest · " + DG.week, rows:[["Net revenue", nf0.format(DG.net) + " EGP"],["Week over week", sgn(DG.wow)],["Same week last year", sgn(DG.yoy)],["Digests sent so far", nf0.format(D.stack.runs.digest)]]}},
];

/* finding -> workflow -> owner map (CSS draws the connectors) */
const mapRows = [
  {fig:nf2.format(y19.opc) + " → " + nf2.format(y25.opc), f:"Customers buy less often", href:"#customers", wf:"Reactivation", when:"Monthly, after a yes",
   who:"CRM manager", how:"Approves the list and the Arabic message in Telegram before anything is sent"},
  {fig:pct(D.disc[0].gm) + " → " + pct(D.disc[4].gm), f:"Deep discounts cost margin", href:"#discount", wf:"Discount guardrail", when:"Every morning",
   who:"Commercial director", how:"Gets the EGP given above the cap, by channel, only on unusual days"},
  {fig:nf1.format(D.l12m.net/1e6) + "M EGP", f:"Questions come up between reports", href:"#overview", wf:"Ask the data", when:"On demand",
   who:"Anyone on the team", how:"Gets the number with its period and source, or a clear refusal"},
  {fig:sgn(ytdNet) + " YTD", f:"Management needs a weekly pulse", href:"#overview", wf:"Weekly digest", when:"Monday 08:00",
   who:"Management", how:"Reads one message: sales, discount leakage, workflow health"},
];
const mapEl = document.getElementById("map");
mapRows.forEach(r => {
  const row = el("div", "mrow");
  const a = el("a", "mcell"); a.href = r.href; a.append(el("span", "fg", r.fig), el("small", null, r.f));
  const w = el("div", "mcell wf"); w.append(el("b", null, r.wf), el("small", null, r.when));
  const o = el("div", "mcell"); o.append(el("b", null, r.who), el("small", null, r.how));
  row.append(a, w, o); mapEl.appendChild(row);
});
const flowsEl = document.getElementById("flows");
flows.forEach(f => {
  const card = el("article", "flow");
  const hd = el("header");
  hd.append(el("span", "eyebrow", "Runs " + f.st[1].toLowerCase()), el("h3", null, f.title), el("p", null, f.tagline)); card.appendChild(hd);
  const ol = el("ol", "steps"); f.steps.forEach(([b,t]) => { const li = el("li"); const s = el("span"); s.append(el("b", null, b + " "), document.createTextNode(t)); li.appendChild(s); ol.appendChild(li); });
  card.appendChild(ol);
  const pv = el("div", "preview"); pv.appendChild(el("div", "h", f.preview.h));
  f.preview.rows.forEach(([a,b]) => { const r = el("div", "row"); r.append(el("span", null, a), el("span", null, b)); pv.appendChild(r); });
  card.appendChild(pv);
  const out = el("div", "runout"); out.id = "out-" + f.key;
  const ft = el("footer");
  const connected = !!N8N[f.key];
  ft.appendChild(el("span", "tag", connected ? "Connected to n8n" : "n8n not connected yet"));
  if (f.key !== "assistant"){
    const b = el("button", "btn", "Run now"); b.type = "button"; b.disabled = !connected;
    b.title = connected ? "Runs the workflow in n8n" : "Add the n8n webhook URL to connect";
    b.addEventListener("click", async () => {
      b.disabled = true; out.textContent = "Running…";
      try { const r = await fetch(N8N[f.key], {method:"POST", headers:{"Content-Type":"application/json", "ngrok-skip-browser-warning":"1"}, body:JSON.stringify({source:"dashboard", replay_day: f.key === "guardrail" ? G.day : undefined}), signal:AbortSignal.timeout(60000)});
        const j = await r.json().catch(() => ({})); out.textContent = j.summary || ("Finished with status " + r.status + "."); }
      catch(e){ out.textContent = "Could not reach n8n. Check that the workflow is active and the URL is right."; }
      b.disabled = false; });
    ft.appendChild(b);
  } else {
    const a = el("button", "btn", "Open assistant"); a.type = "button"; a.addEventListener("click", () => openPanel()); ft.appendChild(a);
  }
  card.append(ft, out); flowsEl.appendChild(card);
});

/* ask: conversation rendering (answers arrive from the n8n assistant only) */
const msgs = document.getElementById("msgs");
const BOT = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 19V9M10 19V5M16 19v-7M21 19H3"/></svg>';
const scrollMsgs = () => { msgs.scrollTop = msgs.scrollHeight; };
function addQ(text){ document.getElementById("chat-empty")?.remove(); const m = el("div", "msg q", text); m.dir = "auto"; msgs.appendChild(m); scrollMsgs(); return m; }
// a = {value, unit, text, why, meta:[[label, value]], sql, refuse}; every field optional except text
function addA(a){
  const m = el("div", "msg a"); const av = el("div", "av"); av.innerHTML = BOT; av.setAttribute("aria-hidden", "true");
  const b = el("div", "bub" + (a.refuse ? " refuse" : ""));
  if (a.verdict !== false){ const top = el("div", "bhead"); top.appendChild(el("span", "verdict" + (a.refuse ? " no" : ""), a.refuse ? "Refused" : "Answered")); b.appendChild(top); }
  if (a.value){ const v = el("div", "val", a.value); if (a.unit) v.appendChild(el("small", null, a.unit)); b.appendChild(v); }
  if (a.text){ const t = el("div", "txt", a.text); t.dir = "auto"; b.appendChild(t); }
  if (a.why){ const w = el("div", "why"); w.append(el("b", null, "Why"), el("span", null, a.why)); b.appendChild(w); }
  if (a.meta && a.meta.length){ const mt = el("div", "meta"); a.meta.forEach(([k,v]) => { const s = el("span"); s.append(el("em", null, k + " "), document.createTextNode(v)); mt.appendChild(s); }); b.appendChild(mt); }
  if (a.sql){ const d = el("details"); d.append(el("summary", null, "Show the query"), el("pre", null, a.sql)); b.appendChild(d); }
  m.append(av, b); msgs.appendChild(m); scrollMsgs(); return m;
}
function addTyping(){ const m = el("div", "msg a"); const av = el("div", "av"); av.innerHTML = BOT; const b = el("div", "bub"); const t = el("span", "typing"); t.setAttribute("aria-label", "Looking it up"); t.append(el("i"), el("i"), el("i")); b.appendChild(t); m.append(av, b); msgs.appendChild(m); scrollMsgs(); return m; }

// empty state until the first question; addQ removes it
const empty = el("div", "empty"); empty.id = "chat-empty";
const eic = el("div", "eic"); eic.innerHTML = BOT; eic.setAttribute("aria-hidden", "true");
empty.append(eic, el("b", null, "Ask about Cottonil's sales and customers"),
  el("p", null, "Every answer comes from one read-only query, with its period and source. Pick a question below or type your own, in English or Arabic."));
msgs.appendChild(empty);

// one memory session per browser tab, so follow-up questions keep their context
const SESSION = "dash-" + Math.random().toString(36).slice(2, 10);
const sample = ["How many buyers are dormant?", "Which category earns the most?", "How much discount did we give last year?", "Which branch performs best?"];
const chips = document.getElementById("chips");
const askInput = document.getElementById("ask-input"), askForm = document.getElementById("ask-form"), askSend = document.getElementById("ask-send");
const askMode = document.getElementById("ask-mode"), askHint = document.getElementById("ask-hint");
sample.forEach(q => { const b = el("button", null, q); b.type = "button"; b.addEventListener("click", () => { askInput.value = q; askInput.focus(); }); chips.appendChild(b); });
if (N8N.assistant){ askMode.classList.add("live"); askMode.lastChild.textContent = "Live"; askHint.textContent = "Every number comes from a query result. Ask in English or Arabic."; }
else { askSend.disabled = true; askSend.title = "Connects when the n8n assistant is live"; askInput.placeholder = "Chat connects when the n8n assistant is live";
  askHint.textContent = "Preview: answers start once the n8n assistant workflow is connected."; }
askForm.addEventListener("submit", async ev => {
  ev.preventDefault(); const q = askInput.value.trim(); if (!q || !N8N.assistant) return;
  addQ(q); askInput.value = ""; askSend.disabled = true; const wait = addTyping();
  try { const r = await fetch(N8N.assistant, {method:"POST", headers:{"Content-Type":"application/json", "ngrok-skip-browser-warning":"1"}, body:JSON.stringify({chatInput:q, sessionId:SESSION, channel:"dashboard"}), signal:AbortSignal.timeout(60000)});
    const j = await r.json(); wait.remove();
    if (j.status !== "answered" && j.status !== "refused"){ addA({verdict:false, text:j.answer || "No answer returned."}); }
    else {
      const meta = [["period", j.period], ["grain", j.grain], ["source", j.source],
        ["", j.cached ? "cached" : (j.evidence === "live_sql" ? "live query" : "")], ["", j.latency_ms ? (j.latency_ms / 1000).toFixed(1) + "s" : ""]].filter(([, v]) => v);
      addA({refuse: j.status === "refused", value: j.status === "answered" ? j.value : "", unit: j.unit,
        text: j.answer + (j.grounded === false ? " ⚠ " + j.warning : ""), why: j.why, meta, sql: j.sql });
    } }
  catch(e){ wait.remove(); addA({verdict:false, text: e.name === "TimeoutError" ? "The assistant took too long to answer. Please try again." : "Could not reach the assistant. Check that the n8n workflow is active."}); }
  askSend.disabled = false;
});

/* trust */
const statusName = {usable:"Usable", usable_with_caveat:"Usable with caveat", not_usable:"Not usable"};
const statusCls = {usable:"ok", usable_with_caveat:"watch", not_usable:"act"};
const tl = document.getElementById("trust-legend");
Object.keys(statusName).forEach(k => { const n = D.trust.filter(t => t.status === k).length; const s = el("span", "state " + statusCls[k]); s.appendChild(el("i")); s.appendChild(document.createTextNode(statusName[k] + " · " + n)); tl.appendChild(s); });
const tr = document.getElementById("trust-rows");
const head = el("div", "trow head"); ["Topic","Status","What you can say","What it cannot answer"].forEach(h => head.appendChild(el("div", null, h))); tr.appendChild(head);
D.trust.forEach(t => {
  const r = el("div", "trow");
  r.appendChild(el("div", "tp", t.topic));
  const s = el("div"); const sp = el("span", "state " + statusCls[t.status]); sp.appendChild(el("i")); sp.appendChild(document.createTextNode(statusName[t.status])); s.appendChild(sp); r.appendChild(s);
  r.appendChild(el("div", null, t.safe));
  const c = el("div"); c.appendChild(el("div", null, t.cannot || "Nothing material")); c.appendChild(el("div", "why", t.reason)); r.appendChild(c);
  tr.appendChild(r);
});

/* how it's built: lanes of boxes; wireArch() draws the lines between them */
const ST = D.stack, rowsTotal = Object.values(ST.rows).reduce((a, b) => a + b, 0);
const lanes = [
  {h:"Source", nodes:[
    {id:"raw", k:"COTTONIL_Data/*.csv", b:"Cottonil extract", p:"23 tables, Oct 2018 – Oct 2026. Read-only, never edited."},
    {id:"mart", k:"scripts/30_build_mart.py", b:"Clean mart", p:"13 files; totals checked against the raw files before loading."}]},
  {h:"Supabase · Postgres 17 + pgvector", box:true, nodes:[
    {id:"core", k:"schema cottonil", b:"Sales spine", p:nf0.format(rowsTotal) + " rows in 11 tables, keys and links enforced."},
    {id:"ana", k:"schema analytics", b:"Certified views", p:ST.analyticsViews + " views on " + ST.matViews + " pre-computed tables, plus the data-trust table."},
    {id:"kb", k:"kb_chunks · vector(1536)", b:"Knowledge base", p:ST.kbChunks + " definitions, rules and checked SQL; hybrid keyword + vector search."},
    {id:"logs", k:"automation_runs · assistant_log", b:"Audit trail", p:"Every workflow run and every question, with its answer."}]},
  {h:"n8n workflows", box:true, nodes:[
    {id:"w-ask", k:"webhook · on demand", b:"Ask the data", p:"Search knowledge, run one read-only query, check every number."},
    {id:"w-react", k:"monthly", b:"Reactivation", p:"Dormant high-value buyers, 10% holdout, Arabic messages."},
    {id:"w-guard", k:"daily", b:"Discount guardrail", p:"Discount above the cap, alert on unusual days."},
    {id:"w-dig", k:"weekly", b:"Weekly digest", p:"Sales and workflow health, no AI."},
    {id:"w-kb", k:"nightly + Sunday", b:"Knowledge refresh and test", p:"Embeds new entries; scores the " + ST.eval.questions + "-question test set."}]},
  {h:"Where people see it", nodes:[
    {id:"dash", k:"dashboard/index.html", b:"This dashboard", p:"Snapshot of the certified views, chat, Run now buttons."},
    {id:"tg", k:"Telegram", b:"Approvals and alerts", p:"CRM manager approves; directors get alerts and the digest."}]},
];
const edges = [["raw","mart"],["mart","core"],
  ["core","w-guard"],["ana","w-ask"],["kb","w-ask"],["ana","w-react"],["ana","w-dig"],["kb","w-kb"],["logs","w-dig"],
  ["w-ask","dash"],["w-react","dash"],["w-guard","dash"],["w-react","tg"],["w-guard","tg"],["w-dig","tg"]];
const arch = document.getElementById("arch");
lanes.forEach(L => {
  const lane = el("div", "lane" + (L.box ? " box" : "")); lane.appendChild(el("div", "lane-h", L.h));
  L.nodes.forEach(n => { const d = el("div", "node"); d.dataset.id = n.id; d.tabIndex = 0;
    d.append(el("span", "k", n.k), el("b", null, n.b), el("p", null, n.p)); lane.appendChild(d); });
  arch.appendChild(lane);
});
// focus a box: its lines and neighbours light up, the rest fades
function focusNode(id){
  if (arch.dataset.stacked === "1") id = null;   // phones: lanes are stacked and there are no per-box lines to follow
  arch.classList.toggle("focus", !!id);
  const near = new Set(id ? [id] : []);
  arch.querySelectorAll(".wires g").forEach(g => { const on = !!id && (g.dataset.a === id || g.dataset.b === id); g.classList.toggle("hot", on);
    if (on){ near.add(g.dataset.a); near.add(g.dataset.b); } });
  arch.querySelectorAll(".node").forEach(n => n.classList.toggle("hot", near.has(n.dataset.id)));
}
arch.querySelectorAll(".node").forEach(n => {
  n.addEventListener("pointerenter", () => focusNode(n.dataset.id)); n.addEventListener("focus", () => focusNode(n.dataset.id));
  n.addEventListener("pointerleave", () => focusNode(null)); n.addEventListener("blur", () => focusNode(null));
});
addEventListener("pointerdown", e => { if (!e.target.closest?.("#arch .node")) focusNode(null); });   // touch has no pointerleave
// side by side: one curve per edge, right edge -> left edge. Stacked (phones): one line from each lane to the next.
function wireArch(){
  arch.querySelector("svg.wires")?.remove();
  if (!arch.offsetParent) return;
  const box = arch.getBoundingClientRect(), svg = S("svg", {class:"wires", width:box.width, height:box.height}, null);
  const rel = e => { const r = e.getBoundingClientRect(); return {l:r.left-box.left, r:r.right-box.left, t:r.top-box.top, b:r.bottom-box.top, cx:(r.left+r.right)/2-box.left, cy:(r.top+r.bottom)/2-box.top}; };
  const laneEls = [...arch.querySelectorAll(".lane")];
  const stacked = laneEls[1].getBoundingClientRect().top > laneEls[0].getBoundingClientRect().bottom - 1;
  arch.dataset.stacked = stacked ? "1" : "0"; if (stacked) focusNode(null);
  const line = (d, x, y, a, b) => { const g = S("g", {"data-a":a, "data-b":b}, svg); S("path", {d}, g); S("circle", {cx:x, cy:y, r:3}, g); };
  if (stacked){
    for (let i = 1; i < laneEls.length; i++){ const p = rel(laneEls[i-1]), q = rel(laneEls[i]); const x = Math.min(p.l, q.l) + 28;
      line(`M${x} ${p.b} V${q.t}`, x, q.t, "", ""); }
  } else {
    edges.forEach(([a, b]) => {
      const p = rel(arch.querySelector(`[data-id="${a}"]`)), q = rel(arch.querySelector(`[data-id="${b}"]`)), mx = (p.r + q.l) / 2;
      line(`M${p.r} ${p.cy} C${mx} ${p.cy} ${mx} ${q.cy} ${q.l} ${q.cy}`, q.l, q.cy, a, b);
    });
  }
  arch.prepend(svg);
}

const ss = document.getElementById("stack-stats");
[["Database used", ST.dbMb + " MB", "of " + ST.dbLimitMb + " MB on the free plan", ST.dbMb / ST.dbLimitMb],
 ["Rows loaded", nf0.format(rowsTotal), "11 tables, nothing cut"],
 ["Assistant test set", ST.eval.passed + " / " + ST.eval.questions, "last run · median answer " + nf1.format(ST.eval.p50ms / 1000) + " s"],
 ["Logged so far", nf0.format(ST.askLog) + " questions", nf0.format(Object.values(ST.runs).reduce((a, b) => a + b, 0)) + " workflow runs"]]
  .forEach(([l, v, d, m]) => { const c = el("div"); c.append(el("span", "lbl", l), el("span", "v", v), el("span", "d", d));
    if (m != null){ const mt = el("div", "meter"); const i = el("i"); i.style.width = (100*m) + "%"; mt.appendChild(i); c.appendChild(mt); }
    ss.appendChild(c); });

/* theme toggle: flips data-theme; the MutationObserver below redraws the charts in the new palette */
const themeBtn = document.getElementById("theme-btn");
function syncThemeBtn(){ themeBtn.setAttribute("aria-label", document.documentElement.dataset.theme === "dark" ? "Switch to light mode" : "Switch to dark mode"); }
themeBtn.addEventListener("click", () => {
  const t = document.documentElement.dataset.theme === "dark" ? "light" : "dark";
  document.documentElement.dataset.theme = t; syncThemeBtn();
  try { localStorage.setItem("cottonil-theme", t); } catch (e) {}
});
syncThemeBtn();

/* assistant panel: opens over any tab; Esc, the close button or the scrim close it */
const panel = document.getElementById("assistant"), fab = document.getElementById("fab"), scrim = document.getElementById("scrim");
const infoBtn = document.getElementById("ask-info-btn"), info = document.getElementById("ask-info");
function openPanel(){
  panel.classList.add("open"); panel.removeAttribute("inert"); panel.setAttribute("aria-hidden", "false");
  fab.setAttribute("aria-expanded", "true"); scrim.hidden = innerWidth >= 1100;   // wide screens keep the page usable beside the panel
  setTimeout(() => askInput.focus({preventScroll:true}), 60);
}
function closePanel(){
  panel.classList.remove("open"); panel.setAttribute("inert", ""); panel.setAttribute("aria-hidden", "true");
  fab.setAttribute("aria-expanded", "false"); scrim.hidden = true; fab.focus({preventScroll:true});
}
fab.addEventListener("click", openPanel);
document.getElementById("ask-close").addEventListener("click", closePanel);
scrim.addEventListener("click", closePanel);
addEventListener("keydown", e => { if (e.key === "Escape" && panel.classList.contains("open")) closePanel(); });
infoBtn.addEventListener("click", () => { const show = info.hidden; info.hidden = !show; infoBtn.setAttribute("aria-expanded", String(show)); });

/* tabs: the hash picks the chapter; only that one is shown. #ask opens the assistant instead */
const pages = [...document.querySelectorAll("main > section")];
const links = [...document.querySelectorAll("#chapters a")], nav = document.getElementById("chapters");
let current = null;
pages.forEach((p, i) => {
  const pg = el("nav", "pager"); pg.setAttribute("aria-label", "Chapter navigation");
  [[links[i-1], "prev", "← Previous"], [links[i+1], "next", "Next →"]].forEach(([a, cls, lbl]) => {
    if (!a) return; const l = el("a", cls); l.href = a.getAttribute("href"); l.append(el("span", null, lbl), el("b", null, a.textContent)); pg.appendChild(l); });
  p.querySelector(".wrap") ? p.querySelector(".wrap").appendChild(pg) : p.appendChild(pg);
});
function route(){
  let id = location.hash.slice(1);
  if (id === "ask"){ openPanel(); id = current || "overview"; history.replaceState(null, "", "#" + id); if (current === id) return; }
  if (!pages.some(p => p.id === id)) id = "overview";
  pages.forEach(p => { p.hidden = p.id !== id; });
  links.forEach(a => { const on = a.getAttribute("href") === "#" + id; a.classList.toggle("on", on);
    if (on){ a.setAttribute("aria-current", "page"); nav.scrollLeft = a.offsetLeft - (nav.clientWidth - a.offsetWidth) / 2; } else a.removeAttribute("aria-current"); });
  const link = links.find(a => a.getAttribute("href") === "#" + id);
  document.title = (id === "overview" ? "" : link.textContent + " · ") + "Cottonil Commercial Review";
  current = id; hideTip(); scrollTo({top:0, behavior:"instant"}); drawAll();
}
addEventListener("hashchange", route);

/* draw + redraw on resize / theme change; a tooltip never outlives a scroll */
addEventListener("scroll", hideTip, {passive:true});
route();
let rt; addEventListener("resize", () => { clearTimeout(rt); rt = setTimeout(drawAll, 120); });
matchMedia("(prefers-color-scheme: dark)").addEventListener("change", drawAll);
new MutationObserver(drawAll).observe(document.documentElement, {attributes:true, attributeFilter:["data-theme"]});
