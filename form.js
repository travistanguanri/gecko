// Shared form: builds the questions and collects the answers, and fills
// pages with the sheet's wording. Used by the extension (content.js,
// popup.js) and the website (site.js). Styled by form.css.
(function () {
  function el(tag, props, kids) {
    const node = Object.assign(document.createElement(tag), props || {});
    (kids || []).forEach(function (k) { node.append(k); });
    return node;
  }

  // An option called "Others", or any option ending in "...", is a box they
  // type their own answer into, such as "Your definition...".
  const isOther = function (label) { return /^others?$/i.test(label || "") || /(\.\.\.|…)$/.test(label || ""); };
  const bare = function (label) { return String(label).replace(/\s*(\.\.\.|…)$/, ""); };

  // Every field returns { node, value() }. value() is "" until it is answered.

  // Options as buttons. A typable option ("Others", or one ending in "...") is
  // a box in the same row, with its words as the grey hint: they click in and
  // type their own answer.
  function choiceField(q, changed) {
    const values = q.values || q.options;
    let picked = q.preset ? values.indexOf(q.preset) : -1;
    const other = el("input", { type: "text", className: "probe-input probe-other" });
    const controls = q.options.map(function (label, i) {
      const pick = function () { picked = i; refresh(); changed(); };
      if (isOther(label)) {
        other.placeholder = label;
        // Clicking in or typing picks it. Passing through it with the Tab key
        // does not, so a choice already made is not lost on the way to Send.
        other.addEventListener("click", pick);
        other.addEventListener("input", pick);
        return other;
      }
      const b = el("button", { type: "button", className: "probe-option", textContent: label });
      b.addEventListener("click", pick);
      return b;
    });
    function refresh() {
      controls.forEach(function (c, i) {
        if (c === other) c.dataset.picked = String(i === picked);
        else c.setAttribute("aria-pressed", String(i === picked));
      });
    }
    refresh();
    return {
      node: el("div", { className: "probe-options" }, controls),
      value: function () {
        if (picked < 0) return "";
        if (!isOther(q.options[picked])) return String(values[picked]);
        const typed = other.value.trim();
        return typed ? bare(q.options[picked]) + ": " + typed : "";
      },
    };
  }

  // 1 to 5, with the two options as end labels.
  function scaleField(q, changed) {
    const f = choiceField({ options: ["1", "2", "3", "4", "5"] }, changed);
    f.node.classList.add("probe-scale");
    if ((q.options || []).length !== 2) return f;
    const ends = el("div", { className: "probe-ends" }, [
      el("span", { textContent: q.options[0] }), el("span", { textContent: q.options[1] }),
    ]);
    return { node: el("div", null, [f.node, ends]), value: f.value };
  }

  function textField(q, changed) {
    const input = el(q.type === "long" ? "textarea" : "input", { className: "probe-input" });
    if (q.type === "long") input.rows = 3; else input.type = "text";
    input.addEventListener("input", changed);
    return { node: input, value: function () { return input.value.trim(); } };
  }

  self.ProbeForm = {
    // form = { title, questions: [{ id, question, type, options, values, preset, required }],
    //          submitLabel, sending, error, optional, out }  (wording, except out)
    // Every question must be answered, except one with required: false, which
    // carries the word in form.optional beside it. onSubmit(answers) returns a
    // promise; if it rejects, the participant can press the button again.
    // out = { label, send } adds a quieter second button that needs no
    // answers: a way to say the form does not apply. send() returns a promise.
    render: function (root, form, onSubmit) {
      const button = el("button", { type: "button", className: "probe-submit", textContent: form.submitLabel || "Send" });
      const note = el("p", { className: "probe-note" });
      let fields = [];
      const changed = function () {
        button.disabled = fields.some(function (f, i) { return form.questions[i].required !== false && !f.value(); });
      };

      root.classList.add("probe");
      root.replaceChildren();
      if (form.title) root.append(el("h1", { className: "probe-title", textContent: form.title }));
      fields = form.questions.map(function (q) {
        const make = q.type === "choice" ? choiceField : q.type === "scale" ? scaleField : textField;
        const f = make(q, changed);
        const label = el("p", { className: "probe-label", textContent: q.question });
        if (q.required === false && form.optional) {
          label.append(" ", el("span", { className: "probe-optional", textContent: form.optional }));
        }
        root.append(el("div", { className: "probe-question" }, [label, f.node]));
        return f;
      });
      const out = form.out && form.out.label
        ? el("button", { type: "button", className: "probe-submit probe-quiet", textContent: form.out.label }) : null;
      root.append(el("div", { className: "probe-actions" }, out ? [button, out] : [button]), note);
      changed();

      // Both buttons send something: lock them while it goes, unlock if it fails.
      function run(send) {
        button.disabled = true;
        if (out) out.disabled = true;
        note.textContent = form.sending || "Sending...";
        Promise.resolve().then(send).then(
          function () { note.textContent = ""; },
          function () {
            note.textContent = form.error || "Couldn't send. Check your internet and try again.";
            if (out) out.disabled = false;
            changed();
          }
        );
      }
      button.addEventListener("click", function () {
        const answers = {};
        form.questions.forEach(function (q, i) { answers[q.id] = fields[i].value(); });
        run(function () { return onSubmit(answers); });
      });
      if (out) out.addEventListener("click", function () { run(form.out.send); });
    },

    // The sheet's questions plus the closing "when should I bug you next?" question.
    // Its answer comes back under the id "next" as "now", "default" or "snooze".
    // An option whose text is blank or missing in the Copy tab is left out.
    // values fills placeholders, e.g. { name: "Sam" } for {name} in the title.
    fromSheet: function (config, values) {
      const c = ProbeForm.copy(config);
      const text = function (key) { return ProbeForm.fill(c[key], values || {}).trim(); };
      const next = ["now", "default", "snooze"].filter(function (v) { return text("next_option_" + v); });
      return {
        title: text("form_title"), submitLabel: text("form_send"),
        sending: text("form_sending"), error: text("form_error"),
        questions: config.questions.concat({
          id: "next", question: text("next_question"), type: "choice",
          options: next.map(function (v) { return text("next_option_" + v); }),
          values: next, preset: "now",
        }),
      };
    },

    // All the wording, from the sheet's Copy tab. (An older sheet kept a few
    // of these in Settings, so those are read too.)
    copy: function (config) {
      return Object.assign({}, config && config.settings, config && config.copy);
    },

    // "Hey {name}!" with { name: "Sam" } becomes "Hey Sam!". {Name} works too.
    fill: function (text, values) {
      return String(text == null ? "" : text).replace(/\{(\w+)\}/g, function (whole, key) {
        key = key.toLowerCase();
        return key in values ? values[key] : whole;
      });
    },

    // Like fill, but writes into a node, and everything from the first
    // filled-in value onwards goes in <strong>. "Hello again, {name}!" becomes
    // "Hello again, " + <strong>Sam!</strong>, so the name can be styled apart.
    fillInto: function (node, text, values) {
      const parts = String(text == null ? "" : text).split(/(\{\w+\})/);
      let strong = null;
      node.replaceChildren();
      parts.forEach(function (part) {
        const key = /^\{\w+\}$/.test(part) ? part.slice(1, -1).toLowerCase() : null;
        if (key && key in values) {
          if (!strong) { strong = el("strong"); node.append(strong); }
          strong.append(String(values[key]));
        } else if (part) {
          (strong || node).append(part);
        }
      });
    },

    // Fills a page with wording: data-copy="key" shows that row's text, and
    // data-list="prefix_" shows every row with that prefix as list items.
    paint: function (root, copy) {
      root.querySelectorAll("[data-copy]").forEach(function (node) { node.textContent = copy[node.dataset.copy] || ""; });
      root.querySelectorAll("[data-list]").forEach(function (node) {
        node.replaceChildren.apply(node, ProbeForm.list(copy, node.dataset.list).map(function (text) {
          return el("li", { textContent: text });
        }));
      });
    },

    // The app helper's install lines for one sign-up: { mac, windows }.
    helperLines: function (site, code) {
      return {
        mac: "curl -fsSL " + site + "/install.sh | bash -s -- " + code,
        windows: "$env:GECKO_CODE='" + code + "'; [Net.ServicePointManager]::SecurityProtocol='Tls12'; "
          + "iex (New-Object Net.WebClient).DownloadString('" + site + "/install.ps1')",
      };
    },

    // Bullet points: every row named prefix + a number, in the sheet's order.
    list: function (copy, prefix) {
      return Object.keys(copy)
        .filter(function (key) { return key.indexOf(prefix) === 0 && /^\d+$/.test(key.slice(prefix.length)); })
        .map(function (key) { return copy[key]; })
        .filter(String);
    },
  };
})();
