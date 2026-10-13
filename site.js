// The website's three pages: home (how to install), the form tab, and the
// report. Which one this is comes from data-page on <body>.
// Wording comes from the Copy tab of the sheet, as everywhere else.
(async () => {
  const $ = (id) => document.getElementById(id);
  const page = document.body.dataset.page;

  // The form tab is drawn by the Pause extension, which marks the page when it
  // is there. Without it, show the page's own note instead.
  if (page === "form") {
    setTimeout(() => {
      if (!document.documentElement.dataset.pause) document.querySelector("main").hidden = false;
    }, 800);
    return;
  }

  const get = async (query) => (await fetch(self.PROBE_ENDPOINT + query)).json();
  let config;
  let report;
  try {
    if (page === "report") {
      // The two codes arrive after the # in the address, which stays in the browser.
      const who = new URLSearchParams(location.hash.slice(1));
      const codes = "&code=" + encodeURIComponent(who.get("me") || "") + "&room=" + encodeURIComponent(who.get("room") || "");
      [config, report] = await Promise.all([get("?action=config"), get("?action=report" + codes)]);
      if (!report.ok) throw new Error("no report");
    } else {
      config = await get("?action=config");
    }
  } catch (e) {
    $("offline").hidden = false;
    return;
  }
  const copy = ProbeForm.copy(config);
  ProbeForm.paint(document, copy);

  if (page === "report") {
    ProbeForm.fillInto($("heading"), copy.report_heading, { name: report.name });
    $("moments-label").textContent = report.moments === 1 ? copy.report_moment : copy.report_moments;
    $("length").textContent = ProbeForm.fill(copy.report_length, { minutes: report.minutes });
    const tools = new Intl.ListFormat("en-GB", { type: "conjunction" }).format(report.tools);
    $("tools").textContent = ProbeForm.fill(copy.report_tools, { tools });
    $("tools").hidden = !report.tools.length;
    countUp($("moments"), report.moments);
  }
  $("page").hidden = false;

  // The big number counts up to its value, quickly at first and then settling.
  function countUp(node, value) {
    const still = matchMedia("(prefers-reduced-motion: reduce)").matches;
    const start = performance.now();
    const length = Math.min(900, 250 + value * 60);
    const step = (now) => {
      const t = still ? 1 : Math.min(1, (now - start) / length);
      node.textContent = Math.round(value * (1 - Math.pow(1 - t, 3)));
      if (t < 1) requestAnimationFrame(step);
    };
    step(start);
  }
})();
