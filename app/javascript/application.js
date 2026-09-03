// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

const walletKey = "shuffl-wallet";
const readWallet = () => JSON.parse(localStorage.getItem(walletKey) || "[]");
const writeWallet = cards => localStorage.setItem(walletKey, JSON.stringify(cards));

document.addEventListener("turbo:load", () => {
  const quiz = document.querySelector("[data-questionnaire]");
  if (quiz) {
    let step = 1; const steps = [...quiz.querySelectorAll("[data-step]")];
    const render = () => { steps.forEach(s => s.classList.toggle("active", +s.dataset.step === step)); quiz.querySelector("[data-progress]").style.width = `${Math.round(step * 100 / 17)}%`; quiz.querySelector("#step-label").textContent = `Step ${step} of 17`; quiz.querySelector("[data-prev]").disabled = step === 1; quiz.querySelector("[data-next]").textContent = step === 17 ? "Build my stack →" : "Continue →"; };
    quiz.querySelector("[data-next]").onclick = () => { const current = steps[step-1]; const hasCheckboxOnly = current.querySelector("input[type=checkbox]") && !current.querySelector("input[type=radio]"); const checked = current.querySelector("input:checked"); if (!checked && !hasCheckboxOnly) { current.classList.add("shake"); setTimeout(()=>current.classList.remove("shake"),400); return; } if(step < 17){ step++; render(); } else quiz.querySelector("form").requestSubmit(); };
    quiz.querySelector("[data-prev]").onclick = () => { if(step > 1){ step--; render(); } };
    quiz.querySelector("[data-reset]").onclick = () => { quiz.querySelector("form").reset(); step=1; render(); };
    render();
  }

  const results = document.querySelector("[data-results]");
  if (results) {
    const alternatives = JSON.parse(results.dataset.alternatives || "[]"); let nextAlt = 0;
    const updateCount = () => results.querySelector("[data-kept-count]").textContent = readWallet().length;
    results.querySelectorAll(".result-card").forEach(cardEl => {
      const keep = cardEl.querySelector(".keep-card");
      keep.onclick = () => { const card = JSON.parse(cardEl.dataset.card); const wallet = readWallet(); const exists = wallet.some(c => c.id === card.id); writeWallet(exists ? wallet.filter(c => c.id !== card.id) : [...wallet, card]); keep.textContent = exists ? "♡ Keep" : "✓ Kept"; keep.classList.toggle("kept", !exists); updateCount(); };
      cardEl.querySelector(".swap-card").onclick = () => { if(!alternatives.length) return; const card = alternatives[nextAlt++ % alternatives.length]; cardEl.dataset.card = JSON.stringify(card); cardEl.querySelector(".card-visual strong").textContent = card.name; cardEl.querySelector(".card-body h3").textContent = card.name; cardEl.querySelector(".card-body p").textContent = `Best for ${card.categories.slice(0,2).join(" & ")}, with rewards that fit this stack.`; cardEl.querySelector(".tags").innerHTML = card.perks.slice(0,3).map(p=>`<span>${p}</span>`).join(""); cardEl.querySelector(".reward-line strong").textContent = `+${Math.max(...Object.values(card.rewards))}× back`; keep.textContent="♡ Keep"; keep.classList.remove("kept"); };
    }); updateCount();
  }

  // ── Wallet: interactive card spread ──
  const walletPage = document.querySelector("[data-wallet]");
  if (walletPage) {
    const spread = walletPage.querySelector("[data-wallet-spread]");
    const emptyState = walletPage.querySelector("[data-wallet-empty]");
    const countEl = walletPage.querySelector("[data-wallet-count]");
    const detailPanel = walletPage.querySelector("[data-wallet-detail-panel]");
    const navLinks = walletPage.querySelector(".wallet-nav-links");

    const tones = [
      "linear-gradient(145deg,#6c63ff,#4a3fd4)",
      "linear-gradient(145deg,#16b89a,#0a7a65)",
      "linear-gradient(145deg,#8b87a5,#5a576e)",
      "linear-gradient(145deg,#e85d75,#b8344d)",
      "linear-gradient(145deg,#f0a030,#c07818)",
      "linear-gradient(145deg,#3498db,#2176ad)"
    ];

    let activeCardId = null;

    const toneFor = (id, cards) => tones[cards.findIndex(c => c.id === id) % tones.length];
    const dotsFor = (id, cards) => "•••• " + (4829 + cards.findIndex(c => c.id === id) * 813);

    function buildCardEl(card, cards) {
      const el = document.createElement("div");
      el.className = "spread-card";
      el.dataset.cardId = card.id;

      const topRow = document.createElement("div");
      const chip = document.createElement("span");
      chip.className = "mini-chip";
      const issuer = document.createElement("b");
      issuer.textContent = card.issuer;
      topRow.appendChild(chip);
      topRow.appendChild(issuer);
      const netSpan = document.createElement("div");
      netSpan.textContent = card.cardNetwork;
      netSpan.style.cssText = "font-size:10px;opacity:.75";
      topRow.appendChild(netSpan);

      const name = document.createElement("strong");
      name.textContent = card.name;

      const dots = document.createElement("span");
      dots.className = "spread-dots";
      dots.textContent = dotsFor(card.id, cards);

      el.appendChild(topRow);
      el.appendChild(name);
      el.appendChild(dots);

      el.addEventListener("click", () => selectCard(card));
      return el;
    }

    function renderWallet() {
      const cards = readWallet();
      countEl.textContent = cards.length + " card" + (cards.length === 1 ? "" : "s") + " in your wallet";
      emptyState.hidden = cards.length > 0;
      spread.style.display = cards.length > 0 ? "block" : "none";
      if (navLinks) navLinks.hidden = cards.length === 0;
      if (cards.length === 0) { detailPanel.hidden = true; activeCardId = null; }

      // The selected card is pulled out of the stack entirely — only the rest fan out here
      const stackCards = cards.filter(c => c.id !== activeCardId);

      const keepIds = new Set(stackCards.map(c => c.id));
      spread.querySelectorAll(".spread-card").forEach(el => {
        if (!keepIds.has(el.dataset.cardId)) el.remove();
      });

      const total = stackCards.length;
      const fanAngle = Math.min(10, 60 / Math.max(total, 1));
      const startAngle = -(total - 1) * fanAngle / 2;
      // Spread cards across the available width so more of each one is visible, without overflowing narrower screens
      const cardWidth = window.innerWidth <= 650 ? Math.min(300, window.innerWidth * 0.85) : 340;
      const availableWidth = spread.clientWidth || 440;
      const maxSpacing = Math.max(0, (availableWidth - cardWidth) / Math.max(total - 1, 1));
      const horizontalSpacing = Math.min(50, maxSpacing);
      const startX = -(total - 1) * horizontalSpacing / 2;
      const verticalSpacing = Math.min(20, 150 / Math.max(total, 1));

      stackCards.forEach((card, i) => {
        const angle = startAngle + i * fanAngle;
        const xOff = startX + i * horizontalSpacing;
        const yOff = i * verticalSpacing;
        const baseTransform = "translateX(calc(-50% + " + xOff + "px)) translateY(" + yOff + "px) rotate(" + angle + "deg)";

        let el = spread.querySelector('[data-card-id="' + CSS.escape(card.id) + '"]');
        const isNew = !el;
        if (isNew) el = buildCardEl(card, cards);

        el.style.setProperty("--z", i + 1);
        el.style.background = toneFor(card.id, cards);

        if (isNew) {
          // Fly back into the stack from above, fading in, then settle into its fan position
          el.style.transition = "none";
          el.style.transform = "translateX(-50%) translateY(" + (yOff - 40) + "px) scale(.9)";
          el.style.opacity = "0";
          spread.appendChild(el);
          requestAnimationFrame(() => {
            requestAnimationFrame(() => {
              el.style.transition = "";
              el.style.transform = baseTransform;
              el.style.opacity = "1";
            });
          });
        } else {
          el.style.transform = baseTransform;
          el.style.opacity = "1";
        }
      });
    }

    function selectCard(card) {
      if (activeCardId === card.id) return;

      const el = spread.querySelector('[data-card-id="' + CSS.escape(card.id) + '"]');
      if (el) {
        el.style.transition = "transform .25s ease, opacity .25s ease";
        el.style.transform = "translateX(-50%) translateY(-40px) scale(.9)";
        el.style.opacity = "0";
      }

      activeCardId = card.id;
      setTimeout(() => {
        if (activeCardId !== card.id) return;
        renderWallet();
        showDetail(card);
      }, 260);
    }

    function deselectCard() {
      activeCardId = null;
      detailPanel.hidden = true;
      renderWallet();
    }

    detailPanel.querySelector("[data-detail-close]").addEventListener("click", deselectCard);

    function showDetail(card) {
      const cards = readWallet();
      detailPanel.hidden = false;

      // Restart the flip-in animation every time (including re-selecting a different card)
      detailPanel.style.animation = "none";
      void detailPanel.offsetWidth;
      detailPanel.style.animation = "";

      // Card visual
      const vis = detailPanel.querySelector("[data-detail-visual]");
      vis.style.background = toneFor(card.id, cards);
      detailPanel.querySelector("[data-detail-issuer]").textContent = card.issuer;
      detailPanel.querySelector("[data-detail-network]").textContent = card.cardNetwork;
      detailPanel.querySelector("[data-detail-name]").textContent = card.name;
      detailPanel.querySelector("[data-detail-dots]").textContent = dotsFor(card.id, cards);

      // Rewards
      const rewardsEl = detailPanel.querySelector("[data-detail-rewards]");
      rewardsEl.innerHTML = "";
      Object.entries(card.rewards).sort((a, b) => b[1] - a[1]).forEach(([cat, val]) => {
        const pill = document.createElement("div");
        pill.className = "reward-pill";
        pill.innerHTML = '<span class="rp-cat">' + cat + '</span><span class="rp-val">' + val + '\u00d7</span>';
        rewardsEl.appendChild(pill);
      });

      // Key details
      const metaEl = detailPanel.querySelector("[data-detail-meta]");
      metaEl.innerHTML = "";
      [
        ["Annual Fee", card.annualFee === 0 ? "$0" : "$" + card.annualFee],
        ["Min. Credit Score", card.creditScoreMin],
        ["Points Currency", card.pointsCurrency],
        ["Foreign Txn Fee", card.foreignTransactionFee ? "Yes" : "None"]
      ].forEach(([label, value]) => {
        const item = document.createElement("div");
        item.className = "meta-item";
        item.innerHTML = '<span>' + label + '</span><b>' + value + '</b>';
        metaEl.appendChild(item);
      });

      // Perks
      const perksEl = detailPanel.querySelector("[data-detail-perks]");
      perksEl.innerHTML = "";
      (card.perks || []).forEach(p => {
        const tag = document.createElement("span");
        tag.className = "perk-tag";
        tag.textContent = p;
        perksEl.appendChild(tag);
      });

      // Transfer partners
      const partnersSection = detailPanel.querySelector("[data-detail-partners-section]");
      const partnersEl = detailPanel.querySelector("[data-detail-partners]");
      if (card.transferPartners && card.transferPartners.length > 0) {
        partnersSection.hidden = false;
        partnersEl.innerHTML = "";
        card.transferPartners.forEach(p => {
          const tag = document.createElement("span");
          tag.className = "partner-tag";
          tag.textContent = p;
          partnersEl.appendChild(tag);
        });
      } else {
        partnersSection.hidden = true;
      }

      // Sign-up bonus
      const bonusSection = detailPanel.querySelector("[data-detail-bonus-section]");
      const bonusEl = detailPanel.querySelector("[data-detail-bonus]");
      if (card.signUpBonus && card.signUpBonus.amount > 0) {
        bonusSection.hidden = false;
        bonusEl.innerHTML = '<span class="bonus-amount">' + card.signUpBonus.amount.toLocaleString() + " " + card.pointsCurrency + '</span><span class="bonus-spend">Spend $' + card.signUpBonus.spend.toLocaleString() + " in " + card.signUpBonus.months + " months</span>";
      } else {
        bonusSection.hidden = true;
      }

      // Sign-up button
      detailPanel.querySelector("[data-detail-signup]").href = "#";
      detailPanel.querySelector("[data-detail-signup]").onclick = (e) => {
        e.preventDefault();
        alert("Affiliate link coming soon for " + card.name + "!");
      };

      // Remove button
      detailPanel.querySelector("[data-detail-remove]").onclick = () => {
        const wallet = readWallet().filter(c => c.id !== card.id);
        writeWallet(wallet);
        activeCardId = null;
        detailPanel.hidden = true;
        renderWallet();
      };
    }

    renderWallet();
  }
});

// ── Chat widget ─────────────────────────────────────────────
document.addEventListener("turbo:load", () => {
  const widget = document.querySelector("[data-chat-widget]");
  if (!widget) return;

  const panel = widget.querySelector("[data-chat-panel]");
  const toggles = widget.querySelectorAll("[data-chat-toggle]");
  const icon = widget.querySelector("[data-chat-icon]");
  const form = widget.querySelector("[data-chat-form]");
  const input = widget.querySelector("[data-chat-input]");
  const messagesEl = widget.querySelector("[data-chat-messages]");

  let history = [];

  widget.querySelector(".chat-toggle").addEventListener("click", () => {
    panel.hidden = false;
    input.focus();
  });

  widget.querySelector(".chat-close").addEventListener("click", () => {
    panel.hidden = true;
  });

  const scrollBottom = () => {
    messagesEl.scrollTop = messagesEl.scrollHeight;
  };

  const addMessage = (role, text) => {
    const div = document.createElement("div");
    div.className = `chat-msg chat-msg-${role === "user" ? "user" : "bot"}`;

    const avatar = document.createElement("span");
    avatar.className = "chat-msg-avatar";
    avatar.textContent = role === "user" ? "N" : "S";

    const bubble = document.createElement("div");
    bubble.className = "chat-msg-bubble";
    // Support markdown bold
    bubble.innerHTML = text.replace(/\*\*(.+?)\*\*/g, "<strong>$1</strong>").replace(/\n/g, "<br>");

    div.appendChild(avatar);
    div.appendChild(bubble);
    messagesEl.appendChild(div);
    scrollBottom();
  };

  const addTyping = () => {
    const div = document.createElement("div");
    div.className = "chat-msg chat-msg-bot";
    div.id = "chat-typing";

    const avatar = document.createElement("span");
    avatar.className = "chat-msg-avatar";
    avatar.textContent = "S";

    const dots = document.createElement("div");
    dots.className = "chat-typing";
    dots.innerHTML = "<span></span><span></span><span></span>";

    div.appendChild(avatar);
    div.appendChild(dots);
    messagesEl.appendChild(div);
    scrollBottom();
  };

  const removeTyping = () => {
    const el = document.getElementById("chat-typing");
    if (el) el.remove();
  };

  form.addEventListener("submit", async (e) => {
    e.preventDefault();
    const message = input.value.trim();
    if (!message) return;

    input.value = "";
    addMessage("user", message);
    history.push({ role: "user", content: message });

    addTyping();

    try {
      const res = await fetch("/chat", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
        },
        body: JSON.stringify({ message, history: history.slice(-10) })
      });
      const data = await res.json();
      removeTyping();

      const reply = data.reply || "Sorry, something went wrong.";
      addMessage("assistant", reply);
      history.push({ role: "assistant", content: reply });
    } catch (err) {
      removeTyping();
      addMessage("assistant", "Sorry, I couldn't connect. Please try again.");
    }
  });
});
