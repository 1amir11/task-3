// Cottonil dashboard data snapshot.
// Source: Supabase project "task3", analytics layer, queried 2026-10-23 with scripts/38_dashboard_snapshot.sql.
// Data window 2018-10-19 .. 2026-10-18. Values are pasted from the query result; nothing is typed by hand.
window.COTTONIL = {
  asOf: "2026-10-18",
  yearly: [
    {yr:2018,orders:8576,units:54593,gross:3904067,disc:169198,net:3734869,margin:1439846,gm:38.55,npu:68.41,opex:1137894,opex_pct:30.47,payroll:9872,paid:3,ebitda:292080,ebitda_pct:7.82,pool:2153,active:1658,opc:3.211,act_pct:77,partial:true},
    {yr:2019,orders:44108,units:277858,gross:22593360,disc:973155,net:21620205,margin:8282661,gm:38.31,npu:77.81,opex:6287546,opex_pct:29.08,payroll:630865,paid:62,ebitda:1364250,ebitda_pct:6.31,pool:12771,active:9993,opc:2.79,act_pct:78.3,partial:false},
    {yr:2020,orders:46425,units:293811,gross:26878582,disc:1169240,net:25709342,margin:9851333,gm:38.32,npu:87.5,opex:7219580,opex_pct:28.08,payroll:2519962,paid:164,ebitda:111791,ebitda_pct:0.43,pool:23418,active:17182,opc:1.606,act_pct:73.4,partial:false},
    {yr:2021,orders:53269,units:336439,gross:34185006,disc:1468144,net:32716862,margin:12532489,gm:38.31,npu:97.24,opex:7866173,opex_pct:24.04,payroll:4756587,paid:264,ebitda:-90271,ebitda_pct:-0.28,pool:34035,active:23211,opc:1.265,act_pct:68.2,partial:false},
    {yr:2022,orders:61934,units:391843,gross:53925927,disc:2347452,net:51578474,margin:19678996,gm:38.15,npu:131.63,opex:10838114,opex_pct:21.01,payroll:7604088,paid:321,ebitda:1236794,ebitda_pct:2.4,pool:44653,active:29159,opc:1.124,act_pct:65.3,partial:false},
    {yr:2023,orders:72233,units:457698,gross:87967493,disc:3819559,net:84147935,margin:32285273,gm:38.37,npu:183.85,opex:15279914,opex_pct:18.16,payroll:10993527,paid:322,ebitda:6011832,ebitda_pct:7.14,pool:55271,active:35079,opc:1.058,act_pct:63.5,partial:false},
    {yr:2024,orders:81885,units:512715,gross:155478310,disc:6695959,net:148782350,margin:57115997,gm:38.39,npu:290.19,opex:23340297,opex_pct:15.69,payroll:15760626,paid:283,ebitda:18015075,ebitda_pct:12.11,pool:65918,active:40842,opc:1.005,act_pct:62,partial:false},
    {yr:2025,orders:93384,units:586290,gross:244712062,disc:10573514,net:234138548,margin:89786828,gm:38.35,npu:399.36,opex:31906387,opex_pct:13.63,payroll:13790701,paid:185,ebitda:44089740,ebitda_pct:18.83,pool:76535,active:47155,opc:0.989,act_pct:61.6,partial:false},
    {yr:2026,orders:78186,units:487408,gross:249550969,disc:10705379,net:238845590,margin:91584875,gm:38.34,npu:490.03,opex:31767764,opex_pct:13.3,payroll:3456287,paid:68,ebitda:56360824,ebitda_pct:23.6,pool:85000,active:44302,opc:0.744,act_pct:52.1,partial:true}
  ],
  // [month, net EGP, units]; complete months only
  monthly: [
    ["2019-01",1611424,21133],["2019-02",1505380,19254],["2019-03",1891756,24735],["2019-04",1877538,23895],["2019-05",1988095,25360],["2019-06",1586648,20847],["2019-07",1560443,20459],["2019-08",1712210,21493],["2019-09",1686672,21256],["2019-10",1750050,22175],["2019-11",2189512,28148],["2019-12",2260476,29103],
    ["2020-01",1983734,22603],["2020-02",1753362,19948],["2020-03",2296247,26733],["2020-04",2331443,26587],["2020-05",2193702,24969],["2020-06",1982137,22495],["2020-07",1992958,22207],["2020-08",1987187,23275],["2020-09",1854045,21445],["2020-10",1987799,22332],["2020-11",2653714,30597],["2020-12",2693014,30620],
    ["2021-01",2639396,26526],["2021-02",2443134,24948],["2021-03",2898782,29286],["2021-04",2772512,28353],["2021-05",2914996,29549],["2021-06",2443880,24683],["2021-07",2589684,26413],["2021-08",2566943,26279],["2021-09",2380263,25789],["2021-10",2391919,24883],["2021-11",3275080,34639],["2021-12",3400273,35091],
    ["2022-01",3863820,29556],["2022-02",3766544,28057],["2022-03",4590327,34555],["2022-04",4313049,32869],["2022-05",4834775,36607],["2022-06",3854250,29299],["2022-07",4131465,30621],["2022-08",3870404,29375],["2022-09",4040523,30211],["2022-10",4077300,31418],["2022-11",5084636,39443],["2022-12",5151383,39832],
    ["2023-01",6237221,33797],["2023-02",5695103,31492],["2023-03",7328634,39756],["2023-04",7173819,38946],["2023-05",7419051,39956],["2023-06",6582932,35576],["2023-07",6422404,35315],["2023-08",6428609,35374],["2023-09",6562585,35515],["2023-10",6606141,35519],["2023-11",8774011,47568],["2023-12",8917424,48884],
    ["2024-01",11258765,39439],["2024-02",10590028,36932],["2024-03",13578856,46538],["2024-04",12433531,43826],["2024-05",13470826,46274],["2024-06",10970962,37845],["2024-07",11228279,38145],["2024-08",11680153,39726],["2024-09",11449794,39829],["2024-10",11533613,39120],["2024-11",15112760,51835],["2024-12",15474782,53206],
    ["2025-01",17995720,44475],["2025-02",16286443,40954],["2025-03",20829089,52438],["2025-04",20674956,51279],["2025-05",21274710,52814],["2025-06",17103463,42952],["2025-07",18672543,47439],["2025-08",18612021,46558],["2025-09",17731272,44574],["2025-10",18390023,45788],["2025-11",22740268,57828],["2025-12",23828040,59191],
    ["2026-01",24661716,50082],["2026-02",21608270,44393],["2026-03",27313077,54657],["2026-04",27707827,56629],["2026-05",27982811,57237],["2026-06",23495285,47987],["2026-07",24699598,50931],["2026-08",23840701,49114],["2026-09",22941492,46864]
  ],
  ytd: {net26:224250776.8, net25:169180217.22, u26:457894, u25:423483, o26:73545, o25:67095},
  l12m: {net:289209108.02, gross:302232564.61, disc:13023456.59},
  category: [
    {cat:"Men boxers",units:381819,net:194199147,gm:38.2},{cat:"Men tops",units:442948,net:164524154,gm:38.41},
    {cat:"Socks",units:911138,net:116179055,gm:38.39},{cat:"Men underwear",units:189180,net:53063019,gm:38.47},
    {cat:"Women pajamas",units:78090,net:50215875,gm:38.32},{cat:"Women tops",units:339951,net:48536514,gm:38.37},
    {cat:"Girls pajamas",units:158994,net:38973530,gm:38.4},{cat:"Boys pajamas",units:156975,net:38187461,gm:38.41},
    {cat:"Home textiles",units:98800,net:33646540,gm:38.14},{cat:"Women bras",units:147080,net:32026817,gm:38.36},
    {cat:"Kids underwear",units:295974,net:27556267,gm:38.37},{cat:"Women underwear",units:38021,net:14516810,gm:38.55},
    {cat:"Men bottoms",units:74338,net:12318425,gm:38.33},{cat:"Girls underwear",units:36672,net:9130896,gm:38.49},
    {cat:"Accessories",units:24315,net:5189767,gm:38.21},{cat:"Women bottoms",units:24360,net:3009897,gm:38.02}
  ],
  products: [
    {n:"3 قطع بوكسر رجالى مارسريزيه",c:"Men boxers",units:56136,net:63056335},
    {n:"8 قطع بوكسر CN",c:"Men boxers",units:53586,net:38478486},
    {n:"تيشيرت مرسريزيه",c:"Men tops",units:48022,net:30651912},
    {n:"4 اندرشيرت كم استريتش",c:"Men tops",units:49911,net:28000754},
    {n:"5 قطع بوكسر كاجوال",c:"Men boxers",units:52657,net:27098563},
    {n:"بيجامة شتوي حريمي كود 2031",c:"Women pajamas",units:38936,net:25295516},
    {n:"بيجامة شتوي حريمي كود 2032",c:"Women pajamas",units:39154,net:24920360},
    {n:"تيشيرت مرسريزيه الوان ( رمادي - اسود - ذهبي- ابيض )",c:"Men tops",units:49140,net:23326709},
    {n:"6 قطع بوكسر ديجيتال",c:"Men boxers",units:54716,net:22381237},
    {n:"بوكسر مرسريزيه",c:"Men boxers",units:55278,net:20754577}
  ],
  nProducts: 139,
  disc: [
    {band:"0%",lines:523965,gross:404811466,disc:0,net:404811466,gm:41.02,ret:2.49},
    {band:"0–5%",lines:237821,gross:188056235,disc:7315436,net:180740799,gm:38.56,ret:2.5},
    {band:"5–10%",lines:188736,gross:147540456,disc:11413946,net:136126510,gm:36,ret:2.55},
    {band:"10–15%",lines:125129,gross:92683099,disc:11391111,net:81291988,gm:32.73,ret:2.52},
    {band:"15–25%",lines:62885,gross:46104520,disc:7801107,net:38303413,gm:29.16,ret:2.45}
  ],
  // L12M order lines: discount EGP above a cap (scenario: volume unchanged)
  capSim: [
    {cap:5,lines:69667,egp:5587012},{cap:7.5,lines:52483,egp:3714398},{cap:10,lines:34806,egp:1841869},
    {cap:12.5,lines:21100,egp:1077329},{cap:15,lines:11698,egp:312853}
  ],
  season: [
    {m:1,net:91.5},{m:2,net:84.7},{m:3,net:106.6},{m:4,net:103.4},{m:5,net:107.9},{m:6,net:90},
    {m:7,net:92.7},{m:8,net:93.3},{m:9,net:91.2},{m:10,net:93.4},{m:11,net:121.1},{m:12,net:124.3}
  ],
  channel: [
    {ch:"Retail POS",orders:388171,net:416226956},{ch:"Wholesale / reseller",orders:54169,net:319639136},{ch:"E-commerce",orders:97660,net:105408085}
  ],
  buyers: 74660, oneTime: 9861, anonShare: 19.07,
  rfm: [
    {tier:"High",dormant:false,n:12287,net:283951692,aov:3739},{tier:"High",dormant:true,n:2645,net:58158124,aov:3861},
    {tier:"Mid",dormant:false,n:21540,net:188808716,aov:1812},{tier:"Mid",dormant:true,n:8324,net:69741473,aov:1609},
    {tier:"Low",dormant:false,n:17770,net:48929145,aov:1224},{tier:"Low",dormant:true,n:12094,net:30732009,aov:966}
  ],
  reactCat: [{c:"Men boxers",n:959},{c:"Men tops",n:691},{c:"Women pajamas",n:199},{c:"Socks",n:197},{c:"Men underwear",n:142}],
  guardDay: {day:"2026-09-30", lines:25, excess:1532, byChannel:[{ch:"Retail POS",n:19,ex:1218},{ch:"E-commerce",n:6,ex:314}], l12mLines:11698, l12mExcess:1111067},
  trust: [
    {topic:"Sales revenue",status:"usable",safe:"Net revenue 841,274,176 EGP, 540,000 orders, 3,398,655 units (2018-10-19..2026-10-18). Monthly/yearly trends, category mix, discount, margin.",cannot:null,reason:"Header and line totals reconcile to the cent; reproduced by 3 independent methods."},
    {topic:"Price vs volume",status:"usable_with_caveat",safe:"Net 2019→2025 grew 10.83×, units 2.11×, net per unit 5.13×.",cannot:"Real pricing power or price elasticity.",reason:"Prices follow a ramp to the 2026 catalogue (0.14 → 1.01 of catalogue price); no competitor price or price experiment."},
    {topic:"Customers",status:"usable_with_caveat",safe:"Orders per registered customer fell from 2.79 (2019) to 0.99 (2025) per year; 23,063 buyers (30.9%) dormant >365 days; 19.07% of orders are anonymous.",cannot:"Churn reasons, loyalty by cohort, customer lifetime value forecasts.",reason:"Each year every registered customer orders at the same rate regardless of join year; the drop is base growth (pool 6× vs orders 2.1×), not proven cohort quality."},
    {topic:"Discount and margin",status:"usable_with_caveat",safe:"Line gross margin falls from 41.0% at 0% discount to 29.2% at 15–25% discount; discount pool 37.9M EGP.",cannot:"How much volume would be lost if discounts were cut.",reason:"No price/discount experiment, so the volume response is unknown."},
    {topic:"Opex and EBITDA",status:"usable_with_caveat",safe:"Opex fell from 29.1% of net (2019) to 13.6% (2025); EBITDA proxy 6.3% → 18.8%.",cannot:"Audited profit.",reason:"Payroll covers 62 (2019) to 185 (2025) paid employees out of 640 in the master; no D&A, interest or tax. Full-roster scenario turns the 2025 EBITDA proxy to about −11.4M EGP."},
    {topic:"Sales channel",status:"usable_with_caveat",safe:"Channel share of net: Wholesale 38.0%, E-commerce 12.5%, rest Retail POS.",cannot:"Channel profitability or B2B strategy.",reason:"Channel is an order label: discount and margin are identical across channels; 98.1% of wholesale orders come from customers tagged Retail."},
    {topic:"Returns",status:"usable_with_caveat",safe:"28,500 returns; 13.91M EGP refunds = 1.65% of net; 5.28% of orders have a return.",cannot:"Which reason or product drives returns.",reason:"Reasons are spread evenly (19.8%–20.3%) and independent of category/channel; order status contradicts returns for 38,108 orders."},
    {topic:"Marketing",status:"not_usable",safe:"2,200 campaigns; campaign spend 219.5M EGP, which is 18.7× the Marketing line in opex (11.76M EGP).",cannot:"ROI, ROAS, orders or revenue generated by campaigns, best channel.",reason:"No campaign_id on orders; orders_attributed = clicks × a fixed random rate (24.1M = 44.6× real orders)."},
    {topic:"Purchasing",status:"not_usable",safe:"41,500 POs exist; PO quantity is 99.9× units sold.",cannot:"Supplier performance, working capital, landed cost, reorder needs.",reason:"PO quantity per line is statistically uniform 90–6,500 and unrelated to SKU demand (corr 0.03); no goods-receipt table."},
    {topic:"Inventory",status:"not_usable",safe:"Stock and transfer tables exist in the extract.",cannot:"Stockouts, overstock, days of cover, replenishment.",reason:"Stock is not linked to demand; no stock ledger; stockout score has no predictive power (AUC 0.50)."},
    {topic:"Branches",status:"not_usable",safe:"80 branches; each sells 9.8M–11.4M EGP over the full history.",cannot:"Best/worst branch ranking, site selection.",reason:"Orders are assigned to branches at random (count CV 0.0125 vs 0.0121 expected by chance); 38,040 orders predate branch opening_date."},
    {topic:"Delivery",status:"not_usable",safe:"97,660 e-commerce shipments; median lead 4 days; about 3% delayed.",cannot:"Best carrier, delivery SLA performance.",reason:"All 3 carriers are identical; delay rate is the same at every lead time."}
  ],
  // How it is built: Supabase + n8n facts, queried 2026-10-27 (scripts/38_dashboard_snapshot.sql, query 4).
  stack: {
    dbMb:433, dbLimitMb:500,
    rows:{fact_order_line:1138536, fact_order:540000, fact_shipment:97660, dim_customer:85000, fact_opex:47000, fact_return:28500, fact_payroll:13210, marketing_campaigns:2200, dim_sku:695, dim_product:139, dim_branch:80},
    analyticsViews:9, matViews:9, kbChunks:46, kbEmbedded:46,
    eval:{questions:19, passed:19, pass:100, refusal:100, numeric:100, grounded:100, p50ms:5766, maxMs:12448, runs:3},
    askLog:101,
    runs:{reactivation:4, guardrail:5, digest:3},
    // last weekly digest sent by n8n (automation_runs, 2026-10-25)
    digest:{week:"12–18 Oct 2026", net:5522902, wow:-5.3, yoy:40.9}
  }
};
