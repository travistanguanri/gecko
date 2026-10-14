// The website's three pages: home (getting set up, in four tabs), the form
// tab, and the report. Which one this is comes from data-page on <body>.
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

  // ---- Talking to the extension (home page) ------------------------------

  // A web page cannot see an extension. Pause's own script on this page
  // (content.js) answers { pause: "ask" } messages with { pause: "tell" } ones.
  const ask = (msg) => window.postMessage(Object.assign({ pause: "ask" }, msg), location.origin);
  const hearing = [];
  window.addEventListener("message", (e) => {
    if (e.source !== window || !e.data || e.data.pause !== "tell") return;
    hearing.slice().forEach((heard) => heard(e.data));
  });
  // The next answer of one type, or null if none comes in time.
  function answer(type, ms) {
    return new Promise((resolve) => {
      const done = (value) => {
        hearing.splice(hearing.indexOf(heard), 1);
        clearTimeout(timer);
        resolve(value);
      };
      const heard = (msg) => { if (msg.type === type) done(msg); };
      const timer = setTimeout(() => done(null), ms);
      hearing.push(heard);
    });
  }
  // me: who is signed up in this Chrome, { name, code, apps }. It stays null
  // when Pause is not here, or has been reloaded since this page was opened.
  let me = null;
  let meChanged = () => {};
  hearing.push((msg) => {
    if (msg.type !== "state") return;
    me = msg;
    meChanged();
  });
  let asked = null;
  if (page === "home" && document.documentElement.dataset.pause) {
    asked = answer("state", 1500);
    ask({ type: "state" });
  }

  // ---- Wording, and the report's numbers ---------------------------------

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
    $("moments-unit").textContent = report.moments === 1 ? copy.report_time : copy.report_times;
    $("length").textContent = ProbeForm.fill(copy.report_length, { minutes: report.minutes });
    const tools = new Intl.ListFormat("en-GB", { type: "conjunction" }).format(report.tools);
    $("tools").textContent = ProbeForm.fill(copy.report_tools, { tools });
    $("tools").hidden = !report.tools.length;
    countUp($("moments"), report.moments);
    wrapUp();
  }
  if (page === "home") {
    await asked;
    home();
  }
  $("page").hidden = false;

  // ---- Home: four tabs ----------------------------------------------------

  // 1 Add extension, 2 Sign up, 3 Set up your apps, 4 Start discussing.
  // The page opens on the first one they have not finished. Finished tabs are
  // ticked and can be opened again; the ones further on wait their turn.
  function home() {
    const TICK = '<svg viewBox="0 0 12 12" width="12" height="12" aria-hidden="true"><path d="M2.5 6.4l2.4 2.4 4.6-5.3" '
      + 'fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"/></svg>';
    const firstName = (name) => String(name || "").trim().split(/\s+/)[0];
    const el = (tag, className, text) => Object.assign(document.createElement(tag), { className, textContent: text || "" });
    const reached = () => (!me ? 1 : !me.code ? 2 : !me.apps ? 3 : 4);
    let showing = reached();
    let welcome = false; // they signed up a moment ago, on this page
    // The browser remembers which sign-up the app helper was last set up for,
    // and that outlives the extension. A different code now means Pause was
    // removed and added again, and the helper is still linked to the old one.
    const LINKED = "pause-helper-code";
    const linked = () => { try { return localStorage.getItem(LINKED) || ""; } catch (e) { return ""; } };
    const again = () => Boolean(me && me.code && linked() && linked() !== me.code);

    const tabs = ProbeForm.list(copy, "site_tab_").slice(0, 4).map((name, i) => {
      const button = el("button", "probe-tab");
      const mark = el("span", "probe-tab-mark");
      button.type = "button";
      button.append(mark, el("span", "probe-tab-name", name),
        el("span", "probe-tab-note", i === 2 ? copy.site_tab_optional : ""));
      button.addEventListener("click", () => show(i + 1));
      const item = document.createElement("li");
      item.append(button);
      $("tabs").append(item);
      return { button, mark };
    });

    function draw() {
      const at = reached();
      tabs.forEach(({ button, mark }, i) => {
        const n = i + 1;
        button.disabled = n > at;
        button.dataset.reached = String(n <= at);
        if (n === showing) button.setAttribute("aria-current", "step"); else button.removeAttribute("aria-current");
        if (n < at) mark.innerHTML = TICK; else mark.textContent = n;
      });
      document.querySelectorAll("[data-tab]").forEach((section) => { section.hidden = Number(section.dataset.tab) !== showing; });

      // Sign up: once they have, the form goes. Straight after signing up, a
      // greeting heads the tab they land on.
      const code = (me && me.code) || "";
      $("signup").hidden = Boolean(code);
      $("welcome").hidden = !welcome;
      ProbeForm.fillInto($("welcome"), copy.done_heading, { name: firstName(me && me.name) });
      // Set up your apps: the install lines, with this person's code already in
      // them. Someone who set the helper up under an earlier sign-up is told to
      // paste the line again.
      const lines = ProbeForm.helperLines(self.PROBE_SITE, code);
      $("mac").textContent = lines.mac;
      $("windows").textContent = lines.windows;
      $("apps-heading").textContent = (again() ? copy.helper_again_heading : copy.helper_heading) || "";
      $("apps-text").textContent = (again() ? copy.helper_again_text : copy.helper_text) || "";
    }
    function show(n) {
      showing = n;
      draw();
      window.scrollTo(0, 0);
    }
    // News from the extension, such as a sign-up going through: move on when
    // it means a tab has just been finished.
    let was = reached();
    meChanged = () => {
      const now = reached();
      if (was === 2 && now > 2) welcome = true;
      if (now !== was) show(now); else draw();
      was = now;
    };

    const options = (text) => String(text || "").split("|").map((o) => o.trim()).filter(String);
    ProbeForm.render($("form"), {
      submitLabel: copy.signup_button, sending: copy.form_sending, error: copy.form_error,
      questions: [
        { id: "name", question: copy.signup_name, type: "text" },
        { id: "year", question: copy.signup_year, type: "choice", options: options(copy.signup_year_options) },
        { id: "ai", question: copy.signup_ai, type: "choice", options: options(copy.signup_ai_options) },
        { id: "collab", question: copy.signup_collab, type: "long" },
      ],
    }, async (answers) => {
      // The extension signs them up and keeps their code; the page hears back.
      const reply = answer("signup", 30000);
      ask({ type: "signup", answers });
      const res = await reply;
      if (!res || !res.ok) throw new Error("sign-up failed");
    });
    // The form stays locked until they agree to take part.
    const lock = () => { $("form").inert = !$("agree").checked; $("form").style.opacity = $("agree").checked ? 1 : 0.4; };
    $("agree").addEventListener("change", lock);
    lock();

    // Set up your apps is the one tab they finish by saying so, either way.
    const finishApps = (value) => {
      if (value === "done" && me && me.code) { try { localStorage.setItem(LINKED, me.code); } catch (e) {} }
      ask({ type: "apps", value });
      if (me) me = Object.assign({}, me, { apps: value });
      was = reached();
      show(was);
    };
    $("apps-done").addEventListener("click", () => finishApps("done"));
    $("apps-skip").addEventListener("click", () => finishApps("skipped"));

    draw();
  }

  // ---- Report: the wrap-up questions ----------------------------------------

  // Asked once per person per discussion, under their numbers. The answers go
  // straight to the sheet, which checks the two codes from the address.
  function wrapUp() {
    const questions = config.wrapup || [];
    if (!questions.length) return;
    const who = new URLSearchParams(location.hash.slice(1));
    // Once sent, the questions and their heading go, and one thank-you is left.
    const done = () => {
      $("wrapup-heading").hidden = true;
      $("wrapup-form").hidden = true;
      $("wrapup-done").hidden = false;
    };
    $("wrapup").hidden = false;
    $("thanks").hidden = true; // the thank-you after the questions takes its place
    if (report.wrapped) return done();
    const id = crypto.randomUUID(); // the same answers sent twice are only kept once
    ProbeForm.render($("wrapup-form"), {
      submitLabel: copy.report_wrapup_send, sending: copy.form_sending, error: copy.form_error,
      optional: copy.form_optional, questions,
    }, async (answers) => {
      const res = await (await fetch(self.PROBE_ENDPOINT, {
        method: "POST",
        body: JSON.stringify({ action: "wrapup", code: who.get("me"), room: who.get("room"), id, answers }),
      })).json();
      if (!res.ok) throw new Error(res.error || "not sent");
      done();
    });
  }

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
