// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

const themeKey = "shuffl-theme";
const systemTheme = () => window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light";
const savedTheme = localStorage.getItem(themeKey);

const cardVisualSelector = [
  ".card-visual",
  ".explore-card-visual",
  ".dialog-card-visual",
  ".card-product-visual",
  ".similar-card-visual"
].join(", ");
const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)");
const pageTransitionedMains = new WeakSet();
let cardTiltFrame;
let pendingTilt;

const hasOwnAnimation = element => {
  if (typeof element.getAnimations === "function") {
    return element.getAnimations({ subtree: false }).some(animation => animation.playState !== "finished");
  }

  return getComputedStyle(element).animationName.split(",").some(name => name.trim() !== "none");
};

const enterPage = () => {
  if (reducedMotion.matches) return;

  const main = document.querySelector("main");
  if (!main || pageTransitionedMains.has(main) || hasOwnAnimation(main)) return;

  pageTransitionedMains.add(main);
  main.classList.add("page-enter");
  const finishEntrance = animationEvent => {
    if (animationEvent.target !== main || animationEvent.animationName !== "pageEnter") return;
    main.classList.remove("page-enter");
    main.removeEventListener("animationend", finishEntrance);
  };
  main.addEventListener("animationend", finishEntrance);
};

document.addEventListener("turbo:before-render", event => {
  if (reducedMotion.matches) return;

  const main = document.querySelector("main");
  if (!main) return;

  // Stop our entrance before checking whether main has unrelated animation work.
  main.classList.remove("page-enter");
  if (hasOwnAnimation(main)) return;

  event.preventDefault();
  main.classList.add("page-exit");

  let resumed = false;
  const resumeRender = () => {
    if (resumed) return;
    resumed = true;
    event.detail.resume();
  };

  const finishExit = transitionEvent => {
    if (transitionEvent.target !== main || transitionEvent.propertyName !== "opacity") return;
    main.removeEventListener("transitionend", finishExit);
    resumeRender();
  };
  main.addEventListener("transitionend", finishExit);
  setTimeout(resumeRender, 180);
});

document.addEventListener("turbo:render", enterPage);
document.addEventListener("turbo:load", enterPage);

const resetCardTilt = card => {
  if (!card || card.matches(".spread-card")) return;
  card.classList.remove("is-tilting");
  card.style.setProperty("--tilt-x", "0deg");
  card.style.setProperty("--tilt-y", "0deg");
  card.style.setProperty("--highlight-x", "50%");
  card.style.setProperty("--highlight-y", "50%");
};

// Card visuals can be added by Turbo or client-side filtering, so keep one
// delegated listener instead of attaching handlers to every rendered card.
document.addEventListener("mousemove", event => {
  if (reducedMotion.matches || !(event.target instanceof Element)) return;
  const card = event.target.closest(cardVisualSelector);
  if (!card || card.matches(".spread-card")) return;

  pendingTilt = { card, clientX: event.clientX, clientY: event.clientY };
  if (cardTiltFrame) return;
  cardTiltFrame = requestAnimationFrame(() => {
    const { card: pendingCard, clientX, clientY } = pendingTilt;
    const bounds = pendingCard.getBoundingClientRect();
    const x = Math.min(1, Math.max(0, (clientX - bounds.left) / bounds.width));
    const y = Math.min(1, Math.max(0, (clientY - bounds.top) / bounds.height));
    pendingCard.classList.add("is-tilting");
    pendingCard.style.setProperty("--tilt-x", `${(0.5 - y) * 16}deg`);
    pendingCard.style.setProperty("--tilt-y", `${(x - 0.5) * 16}deg`);
    pendingCard.style.setProperty("--highlight-x", `${x * 100}%`);
    pendingCard.style.setProperty("--highlight-y", `${y * 100}%`);
    cardTiltFrame = null;
  });
});

document.addEventListener("mouseleave", event => {
  if (!(event.target instanceof Element) || !event.target.matches(cardVisualSelector)) return;
  if (pendingTilt?.card === event.target && cardTiltFrame) {
    cancelAnimationFrame(cardTiltFrame);
    cardTiltFrame = null;
    pendingTilt = null;
  }
  resetCardTilt(event.target);
}, true);

reducedMotion.addEventListener("change", event => {
  if (!event.matches) return;
  if (cardTiltFrame) cancelAnimationFrame(cardTiltFrame);
  cardTiltFrame = null;
  pendingTilt = null;
  document.querySelectorAll(cardVisualSelector).forEach(resetCardTilt);
});

// Restore the theme before turbo:load to minimize a flash of the wrong colors.
document.documentElement.dataset.theme = ["dark", "light"].includes(savedTheme) ? savedTheme : systemTheme();

const updateThemeToggle = () => {
  const isDark = document.documentElement.dataset.theme === "dark";
  document.querySelectorAll("[data-theme-toggle]").forEach(button => {
    const label = `Switch to ${isDark ? "light" : "dark"} mode`;
    button.setAttribute("aria-label", label);
    button.setAttribute("title", label);
    button.setAttribute("aria-pressed", String(isDark));
  });
};

const toggleTheme = () => {
  const nextTheme = document.documentElement.dataset.theme === "dark" ? "light" : "dark";
  document.documentElement.dataset.theme = nextTheme;
  localStorage.setItem(themeKey, nextTheme);
  updateThemeToggle();
};

document.addEventListener("turbo:load", () => {
  updateThemeToggle();
  document.querySelectorAll("[data-theme-toggle]").forEach(button => {
    button.addEventListener("click", toggleTheme);
  });
});

const shortcutGroups = () => {
  const groups = [{
    title: "Global",
    shortcuts: [
      ["?", "Keyboard shortcuts"],
      ["T", "Toggle theme"],
      ["H", "Home"],
      ["Q", "Quiz"],
      ["W", "Wallet"],
      ["E", "Explore"]
    ]
  }];

  if (document.querySelector("[data-questionnaire]")) {
    groups.push({ title: "Quiz", shortcuts: [["1–4", "Select an answer"], ["←", "Previous question"], ["→", "Next question"]] });
  }
  if (document.querySelector("[data-results]")) {
    groups.push({ title: "Results", shortcuts: [["K", "Keep highlighted card"]] });
  }
  return groups;
};

const isTypingTarget = target => target instanceof HTMLElement && (
  target.isContentEditable || target.matches("input, textarea, select")
);

document.addEventListener("turbo:load", () => {
  window.shortcutKeyboardController?.abort();
  document.querySelector("[data-shortcuts-dialog]")?.remove();

  const controller = new AbortController();
  window.shortcutKeyboardController = controller;
  const dialog = document.createElement("dialog");
  dialog.className = "shortcuts-dialog";
  dialog.dataset.shortcutsDialog = "";
  dialog.setAttribute("aria-labelledby", "shortcuts-title");
  dialog.innerHTML = `
    <div class="shortcuts-header">
      <div><span class="kicker">QUICK ACCESS</span><h2 id="shortcuts-title">Keyboard shortcuts</h2></div>
      <button type="button" class="shortcuts-close" aria-label="Close keyboard shortcuts">×</button>
    </div>
    <div class="shortcuts-groups">
      ${shortcutGroups().map(group => `<section><h3>${group.title}</h3>${group.shortcuts.map(([key, label]) => `<div class="shortcut-row"><span>${label}</span><kbd>${key}</kbd></div>`).join("")}</section>`).join("")}
    </div>`;
  document.body.appendChild(dialog);

  const closeDialog = () => { if (dialog.open) dialog.close(); };
  dialog.querySelector(".shortcuts-close").addEventListener("click", closeDialog);
  dialog.addEventListener("click", event => {
    if (event.target !== dialog) return;
    const bounds = dialog.getBoundingClientRect();
    const clickedBackdrop = event.clientX < bounds.left || event.clientX > bounds.right || event.clientY < bounds.top || event.clientY > bounds.bottom;
    if (clickedBackdrop) closeDialog();
  });

  document.addEventListener("keydown", event => {
    if (event.defaultPrevented || event.repeat || event.metaKey || event.ctrlKey || event.altKey) return;
    if (event.key === "Escape" && dialog.open) {
      event.preventDefault();
      closeDialog();
      return;
    }
    if (isTypingTarget(event.target)) return;
    if (event.key === "?") {
      event.preventDefault();
      dialog.open ? closeDialog() : dialog.showModal();
      return;
    }
    if (dialog.open) return;

    const destinations = { h: "/", q: "/questionnaire", w: "/wallet", e: "/explore" };
    const key = event.key.toLowerCase();
    if (key === "t") {
      event.preventDefault();
      toggleTheme();
    } else if (destinations[key]) {
      event.preventDefault();
      Turbo.visit(destinations[key]);
    } else if (key === "k") {
      const results = document.querySelector("[data-results]");
      if (!results) return;
      const highlighted = document.activeElement?.closest?.(".result-card") || results.querySelector(".result-card:hover") || results.querySelector(".result-card");
      const keepButton = highlighted?.querySelector(".keep-card");
      if (keepButton) {
        event.preventDefault();
        keepButton.click();
      }
    }
  }, { capture: true, signal: controller.signal });

  document.addEventListener("turbo:before-cache", () => dialog.remove(), { once: true });
});

document.addEventListener("turbo:load", () => {
  window.heroParallaxController?.abort();

  const heroVisual = document.querySelector(".hero-visual");
  const canTrackPointer = window.matchMedia("(hover: hover) and (pointer: fine)").matches;
  const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  if (!heroVisual || !canTrackPointer || reduceMotion) return;

  const controller = new AbortController();
  window.heroParallaxController = controller;
  const items = [
    [heroVisual.querySelector(".card-back"), 0.5],
    [heroVisual.querySelector(".card-front"), 0.3],
    ...[...heroVisual.querySelectorAll(".float-pill")].map(pill => [pill, 0.2])
  ].filter(([item]) => item);
  let frameId = null;
  let pointerX = 0;
  let pointerY = 0;

  const render = () => {
    frameId = null;
    const bounds = heroVisual.getBoundingClientRect();
    // Normalize the pointer to a subtle 24px movement field before applying depth.
    const offsetX = ((pointerX - bounds.left) / bounds.width - 0.5) * 48;
    const offsetY = ((pointerY - bounds.top) / bounds.height - 0.5) * 48;

    items.forEach(([item, depth]) => {
      item.style.setProperty("--parallax-x", `${offsetX * depth}px`);
      item.style.setProperty("--parallax-y", `${offsetY * depth}px`);
    });
  };

  heroVisual.addEventListener("mousemove", event => {
    pointerX = event.clientX;
    pointerY = event.clientY;
    heroVisual.classList.add("is-tracking-pointer");
    if (frameId === null) frameId = requestAnimationFrame(render);
  }, { signal: controller.signal });

  heroVisual.addEventListener("mouseleave", () => {
    if (frameId !== null) cancelAnimationFrame(frameId);
    frameId = null;
    heroVisual.classList.remove("is-tracking-pointer");
    items.forEach(([item]) => {
      item.style.setProperty("--parallax-x", "0px");
      item.style.setProperty("--parallax-y", "0px");
    });
  }, { signal: controller.signal });

  document.addEventListener("turbo:before-cache", () => {
    if (frameId !== null) cancelAnimationFrame(frameId);
    controller.abort();
  }, { once: true });
});

const walletKey = "shuffl-wallet";
const readWallet = () => JSON.parse(localStorage.getItem(walletKey) || "[]");
const writeWallet = cards => localStorage.setItem(walletKey, JSON.stringify(cards));

window.shufflToast = (message, type = "info", duration = 4000) => {
  const allowedTypes = new Set(["success", "info", "warning"]);
  const toastType = allowedTypes.has(type) ? type : "info";
  const dismissAfter = Number.isFinite(Number(duration)) ? Math.max(0, Number(duration)) : 4000;
  let container = document.querySelector(".toast-container");

  if (!container) {
    container = document.createElement("div");
    container.className = "toast-container";
    container.setAttribute("aria-live", "polite");
    container.setAttribute("aria-relevant", "additions");
    document.body.appendChild(container);
  }

  const dismiss = toast => {
    if (!toast || toast.dataset.dismissed === "true") return;
    toast.dataset.dismissed = "true";
    clearTimeout(toast.dismissTimer);
    toast.classList.add("toast-exiting");
    toast.addEventListener("transitionend", () => toast.remove(), { once: true });
    setTimeout(() => toast.remove(), 250);
  };

  const visibleToasts = [...container.querySelectorAll(".toast:not(.toast-exiting)")];
  if (visibleToasts.length >= 3) dismiss(visibleToasts[0]);

  const toast = document.createElement("div");
  toast.className = `toast toast-${toastType} toast-entering`;
  toast.setAttribute("role", "status");
  toast.style.setProperty("--toast-duration", `${dismissAfter}ms`);
  const text = document.createElement("span");
  text.className = "toast-message";
  text.textContent = String(message);
  const progress = document.createElement("span");
  progress.className = "toast-progress";
  progress.setAttribute("aria-hidden", "true");
  toast.append(text, progress);
  toast.addEventListener("click", () => dismiss(toast));
  container.appendChild(toast);

  requestAnimationFrame(() => requestAnimationFrame(() => toast.classList.remove("toast-entering")));
  toast.dismissTimer = setTimeout(() => dismiss(toast), dismissAfter);
  return toast;
};
const quizProgressKey = "shuffl-quiz-progress";

const readQuizProgress = () => {
  try {
    const progress = JSON.parse(localStorage.getItem(quizProgressKey));
    return progress && typeof progress.step === "number" && progress.answers && typeof progress.answers === "object" ? progress : null;
  } catch (_) {
    localStorage.removeItem(quizProgressKey);
    return null;
  }
};

document.addEventListener("turbo:load", () => {
  window.questionnaireKeyboardController?.abort();
  const quiz = document.querySelector("[data-questionnaire]");
  if (quiz) {
    const keyboardController = new AbortController();
    window.questionnaireKeyboardController = keyboardController;
    let step = 1; let transitioning = false; let transitionTimer; let bannerTimer;
    const steps = [...quiz.querySelectorAll("[data-step]")];
    const totalSteps = steps.length;
    const form = quiz.querySelector("form");
    const previousButton = quiz.querySelector("[data-prev]");
    const nextButton = quiz.querySelector("[data-next]");
    const keyboardHint = document.createElement("p");
    keyboardHint.className = "keyboard-hint";
    keyboardHint.textContent = "Tip: Use 1-4 to choose, → to continue";
    quiz.querySelector(".question-actions").appendChild(keyboardHint);

    const launchConfetti = () => {
      if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;

      const canvas = document.createElement("canvas");
      const context = canvas.getContext("2d");
      if (!context) return;

      canvas.setAttribute("aria-hidden", "true");
      Object.assign(canvas.style, {
        position: "fixed",
        inset: "0",
        width: "100vw",
        height: "100vh",
        pointerEvents: "none",
        zIndex: "999"
      });
      document.body.appendChild(canvas);

      const colors = ["#6c63ff", "#00d4aa", "#f0a030"];
      const duration = 2500;
      const particleCount = 50;
      const pixelRatio = Math.min(window.devicePixelRatio || 1, 2);
      let width;
      let height;

      const resizeCanvas = () => {
        width = window.innerWidth;
        height = window.innerHeight;
        canvas.width = width * pixelRatio;
        canvas.height = height * pixelRatio;
        context.setTransform(pixelRatio, 0, 0, pixelRatio, 0, 0);
      };
      resizeCanvas();

      const particles = Array.from({ length: particleCount }, (_, index) => ({
        x: width / 2 + (Math.random() - 0.5) * 30,
        y: Math.max(20, height * 0.08),
        velocityX: (Math.random() - 0.5) * 460,
        velocityY: 30 + Math.random() * 180,
        wind: (Math.random() - 0.35) * 28,
        width: 6 + Math.random() * 7,
        height: 4 + Math.random() * 5,
        rotation: Math.random() * Math.PI * 2,
        rotationSpeed: (Math.random() - 0.5) * 12,
        color: colors[index % colors.length]
      }));

      let previousTime;
      let startedAt;
      let animationFrame;
      const cleanup = () => {
        cancelAnimationFrame(animationFrame);
        window.removeEventListener("resize", resizeCanvas);
        canvas.remove();
      };
      const animate = timestamp => {
        startedAt ??= timestamp;
        previousTime ??= timestamp;
        const elapsed = timestamp - startedAt;
        const delta = Math.min((timestamp - previousTime) / 1000, 0.032);
        previousTime = timestamp;

        context.clearRect(0, 0, width, height);
        context.globalAlpha = Math.min(1, (duration - elapsed) / 450);
        particles.forEach(particle => {
          particle.velocityX += particle.wind * delta;
          particle.velocityY += 360 * delta;
          particle.x += particle.velocityX * delta;
          particle.y += particle.velocityY * delta;
          particle.rotation += particle.rotationSpeed * delta;

          context.save();
          context.translate(particle.x, particle.y);
          context.rotate(particle.rotation);
          context.fillStyle = particle.color;
          context.fillRect(-particle.width / 2, -particle.height / 2, particle.width, particle.height);
          context.restore();
        });
        context.globalAlpha = 1;

        if (elapsed < duration) animationFrame = requestAnimationFrame(animate);
        else cleanup();
      };

      window.addEventListener("resize", resizeCanvas);
      animationFrame = requestAnimationFrame(animate);
    };

    const dismissKeyboardHint = () => keyboardHint.classList.add("dismissed");
    const flashChoice = choice => {
      choice.classList.remove("key-flash");
      void choice.offsetWidth;
      choice.classList.add("key-flash");
      choice.addEventListener("animationend", () => choice.classList.remove("key-flash"), { once: true });
    };
    const answersFor = () => {
      const answers = {};
      const inputs = [...form.querySelectorAll("input[type=radio], input[type=checkbox]")];
      new Set(inputs.map(input => input.name)).forEach(name => {
        const group = inputs.filter(input => input.name === name);
        const checked = group.filter(input => input.checked).map(input => input.value);
        const answerName = name.replace(/\[\]$/, "");
        if (group[0].type === "checkbox") {
          if (checked.length) answers[answerName] = checked;
        } else if (checked.length) {
          answers[answerName] = checked[0];
        }
      });
      return answers;
    };
    const saveProgress = () => localStorage.setItem(quizProgressKey, JSON.stringify({ step, answers: answersFor() }));
    const clearProgress = () => localStorage.removeItem(quizProgressKey);
    const render = () => { steps.forEach(s => s.classList.toggle("active", +s.dataset.step === step)); quiz.querySelector("[data-progress]").style.width = `${Math.round(step * 100 / totalSteps)}%`; quiz.querySelector("#step-label").textContent = `Step ${step} of ${totalSteps}`; previousButton.disabled = step === 1; nextButton.textContent = step === totalSteps ? "Build my stack →" : "Continue →"; };
    const resetQuiz = () => {
      clearTimeout(transitionTimer);
      steps.forEach(s => s.classList.remove("exit-left"));
      transitioning = false;
      form.reset();
      step = 1;
      clearProgress();
      render();
    };
    const dismissBanner = banner => {
      clearTimeout(bannerTimer);
      banner.classList.add("quiz-resume-banner--leaving");
      banner.addEventListener("transitionend", () => banner.remove(), { once: true });
      setTimeout(() => banner.remove(), 250);
    };
    const restoreProgress = progress => {
      [...form.querySelectorAll("input[type=radio], input[type=checkbox]")].forEach(input => {
        const saved = progress.answers[input.name.replace(/\[\]$/, "")];
        input.checked = Array.isArray(saved) ? saved.includes(input.value) : saved === input.value;
      });
      step = Math.min(Math.max(progress.step, 1), totalSteps);
      render();
    };
    const showResumeBanner = progress => {
      const savedStep = Math.min(Math.max(progress.step, 1), totalSteps);
      const banner = document.createElement("div");
      banner.className = "quiz-resume-banner";
      banner.setAttribute("role", "status");
      banner.innerHTML = `<p>Welcome back! You were on step <strong>${savedStep}</strong> of ${totalSteps}.</p><div class="quiz-resume-actions"><button type="button" class="quiz-resume-continue">Continue where I left off</button><button type="button" class="quiz-resume-fresh">Start fresh</button></div>`;
      document.body.prepend(banner);
      banner.querySelector(".quiz-resume-continue").addEventListener("click", () => { restoreProgress(progress); dismissBanner(banner); });
      banner.querySelector(".quiz-resume-fresh").addEventListener("click", () => { resetQuiz(); dismissBanner(banner); });
      bannerTimer = setTimeout(() => dismissBanner(banner), 10000);
      document.addEventListener("turbo:before-cache", () => { clearTimeout(bannerTimer); banner.remove(); }, { once: true });
    };
    const goToStep = (nextStep, direction) => {
      if (transitioning) return;
      transitioning = true;
      const current = steps[step - 1];
      const next = steps[nextStep - 1];

      if (direction === "forward") {
        current.classList.add("exit-left");
        transitionTimer = setTimeout(() => {
          current.classList.remove("active", "exit-left");
          step = nextStep;
          render();
          saveProgress();
          transitioning = false;
        }, 350);
      } else {
        current.classList.remove("active");
        next.classList.add("active", "exit-left");
        step = nextStep;
        render();
        saveProgress();
        requestAnimationFrame(() => requestAnimationFrame(() => {
          next.classList.remove("exit-left");
          transitioning = false;
        }));
      }
    };
    nextButton.onclick = () => { const current = steps[step-1]; const hasCheckboxOnly = current.querySelector("input[type=checkbox]") && !current.querySelector("input[type=radio]"); const checked = current.querySelector("input:checked"); if (!checked && !hasCheckboxOnly) { current.classList.add("shake"); setTimeout(()=>current.classList.remove("shake"),400); return; } if(step < totalSteps){ goToStep(step + 1, "forward"); } else { launchConfetti(); form.requestSubmit(); } };
    previousButton.onclick = () => { if(step > 1){ goToStep(step - 1, "backward"); } };
    quiz.querySelector("[data-reset]").onclick = resetQuiz;
    form.addEventListener("change", event => { if (event.target.matches("input[type=radio], input[type=checkbox]")) saveProgress(); });
    form.addEventListener("submit", clearProgress);
    document.addEventListener("keydown", event => {
      if (event.defaultPrevented || event.repeat || event.metaKey || event.ctrlKey || event.altKey) return;
      if (event.target instanceof HTMLElement && (event.target.isContentEditable || event.target.matches('button, a, input:not([type="radio"]):not([type="checkbox"]), textarea, select'))) return;

      if (["1", "2", "3", "4"].includes(event.key)) {
        const choices = [...steps[step - 1].querySelectorAll(".choice-card, .mini-choice, .line-choice")];
        const choice = choices[Number(event.key) - 1];
        if (!choice) return;

        event.preventDefault();
        choice.querySelector("input")?.click();
        flashChoice(choice);
        dismissKeyboardHint();
      } else if (event.key === "ArrowRight" || event.key === "Enter") {
        event.preventDefault();
        nextButton.click();
        dismissKeyboardHint();
      } else if (event.key === "ArrowLeft") {
        event.preventDefault();
        previousButton.click();
        dismissKeyboardHint();
      }
    }, { signal: keyboardController.signal });
    const savedProgress = readQuizProgress();
    if (savedProgress) showResumeBanner(savedProgress);
    render();
  }

  const results = document.querySelector("[data-results]");
  if (results) {
    const comparedCards = new Set();
    const compareLink = results.querySelector(".compare-link");
    const renderComparisonSelection = () => {
      const ids = [...comparedCards].map(card => JSON.parse(card.dataset.card).id);
      results.querySelector("[data-compare-count]").textContent = ids.length;
      compareLink.href = `/compare?ids=${encodeURIComponent(ids.join(","))}`;
      compareLink.setAttribute("aria-disabled", ids.length < 2);
    };
    compareLink.addEventListener("click", event => { if (comparedCards.size < 2) event.preventDefault(); });
    results.addEventListener("click", event => {
      const card = event.target.closest(".result-card");
      if (!card) return;
      if (event.target.closest(".compare-card")) {
        if (comparedCards.has(card)) comparedCards.delete(card); else if (comparedCards.size < 4) comparedCards.add(card);
      } else if (event.target.closest(".swap-card")) {
        comparedCards.delete(card);
      } else return;
      const selected = comparedCards.has(card);
      const button = card.querySelector(".compare-card");
      button.textContent = selected ? "✓ Comparing" : "＋ Compare";
      button.classList.toggle("selected", selected);
      button.setAttribute("aria-pressed", selected);
      renderComparisonSelection();
    });
    renderComparisonSelection();
    const cardsGrid = results.querySelector(".matched-cards");
    setTimeout(() => cardsGrid.classList.add("is-loaded"), 300);

    const summaryCounters = [
      results.querySelector(".match-summary .summary-stat > strong"),
      ...results.querySelectorAll(".match-summary .summary-meta b")
    ].filter(Boolean);

    const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    const easeOutExpo = progress => progress === 1 ? 1 : 1 - Math.pow(2, -10 * progress);

    const animateCounter = element => {
      const textNode = [...element.childNodes].find(node => node.nodeType === Node.TEXT_NODE);
      if (!textNode) return;

      const finalText = textNode.textContent.trim();
      const match = finalText.match(/-?[\d,]+(?:\.\d+)?/);
      if (!match) return;

      const finalValue = Number(match[0].replaceAll(",", ""));
      const prefix = finalText.includes("$") ? "$" : "";
      const render = value => { textNode.textContent = `${prefix}${Math.round(value).toLocaleString()}`; };

      if (reducedMotion) {
        render(finalValue);
        return;
      }

      const duration = 1500;
      let startedAt;
      render(0);

      const tick = timestamp => {
        startedAt ??= timestamp;
        const progress = Math.min((timestamp - startedAt) / duration, 1);
        render(finalValue * easeOutExpo(progress));

        if (progress < 1) {
          requestAnimationFrame(tick);
        } else {
          render(finalValue);
          element.animate(
            [
              { transform: "scale(1)" },
              { transform: "scale(1.05)", offset: 0.5 },
              { transform: "scale(1)" }
            ],
            { duration: 250, easing: "cubic-bezier(0.23, 1, 0.32, 1)" }
          );
        }
      };

      requestAnimationFrame(tick);
    };

    if ("IntersectionObserver" in window) {
      const counterObserver = new IntersectionObserver((entries, observer) => {
        entries.forEach(entry => {
          if (!entry.isIntersecting) return;
          observer.unobserve(entry.target);
          animateCounter(entry.target);
        });
      }, { threshold: 0.25 });
      summaryCounters.forEach(counter => counterObserver.observe(counter));
    } else {
      summaryCounters.forEach(animateCounter);
    }

    const projection = results.querySelector("[data-savings-projection]");
    const spendingSlider = projection?.querySelector("[data-spending-slider]");
    const projectionAnimations = new Map();

    const animateProjectionValue = (element, nextValue) => {
      const previousValue = Number(element.dataset.value || 0);
      projectionAnimations.get(element) && cancelAnimationFrame(projectionAnimations.get(element));

      const render = value => {
        element.textContent = `$${Math.round(value).toLocaleString()}`;
        element.dataset.value = String(value);
      };

      if (reducedMotion) {
        render(nextValue);
        return;
      }

      const startedAt = performance.now();
      const duration = 350;
      const tick = timestamp => {
        const progress = Math.min((timestamp - startedAt) / duration, 1);
        render(previousValue + ((nextValue - previousValue) * easeOutExpo(progress)));
        if (progress < 1) {
          projectionAnimations.set(element, requestAnimationFrame(tick));
        } else {
          projectionAnimations.delete(element);
          render(nextValue);
        }
      };
      projectionAnimations.set(element, requestAnimationFrame(tick));
    };

    const updateSavingsProjection = () => {
      if (!projection || !spendingSlider) return;
      const monthlySpend = Number(spendingSlider.value);
      const cards = [...results.querySelectorAll(".result-card")].slice(0, 3).map(card => JSON.parse(card.dataset.card));
      const cardCashback = cards.map(card => {
        const topReward = Math.max(0, ...Object.values(card.rewards || {}).map(Number));
        return monthlySpend * 12 * (topReward / 100);
      });
      const annualCashback = cardCashback.reduce((sum, value) => sum + value, 0);
      const signupValue = cards.reduce((sum, card) => sum + (Number(card.signUpBonus?.amount) || 0) / 100, 0);
      const annualFees = cards.reduce((sum, card) => sum + (Number(card.annualFee) || 0), 0);
      const maximumCashback = Math.max(...cardCashback, 1);
      const progress = ((monthlySpend - Number(spendingSlider.min)) / (Number(spendingSlider.max) - Number(spendingSlider.min))) * 100;

      spendingSlider.style.setProperty("--slider-progress", `${progress}%`);
      projection.querySelector("[data-spending-output]").textContent = `$${monthlySpend.toLocaleString()}`;
      animateProjectionValue(projection.querySelector("[data-annual-cashback]"), annualCashback);
      animateProjectionValue(projection.querySelector("[data-signup-value]"), signupValue);
      animateProjectionValue(projection.querySelector("[data-net-value]"), annualCashback + signupValue - annualFees);
      projection.querySelectorAll("[data-projection-chart] span").forEach((bar, index) => {
        const card = cards[index];
        const value = cardCashback[index] || 0;
        bar.style.setProperty("--bar-height", `${(value / maximumCashback) * 100}%`);
        bar.setAttribute("title", card ? `${card.name}: $${Math.round(value).toLocaleString()}` : "No card");
      });
    };

    spendingSlider?.addEventListener("input", updateSavingsProjection);
    updateSavingsProjection();

    const alternatives = JSON.parse(results.dataset.alternatives || "[]"); let nextAlt = 0;
    const updateCount = () => results.querySelector("[data-kept-count]").textContent = readWallet().length;
    results.querySelectorAll(".result-card").forEach(cardEl => {
      const keep = cardEl.querySelector(".keep-card");
      keep.onclick = () => { const card = JSON.parse(cardEl.dataset.card); const wallet = readWallet(); const exists = wallet.some(c => c.id === card.id); writeWallet(exists ? wallet.filter(c => c.id !== card.id) : [...wallet, card]); keep.textContent = exists ? "♡ Keep" : "✓ Kept"; keep.classList.toggle("kept", !exists); keep.classList.toggle("pulse-kept", !exists); updateCount(); if (!exists) window.shufflToast(`${card.name} added to wallet`, "success"); };
      cardEl.querySelector(".swap-card").onclick = () => { if(!alternatives.length) return; const card = alternatives[nextAlt++ % alternatives.length]; cardEl.dataset.card = JSON.stringify(card); cardEl.querySelector(".card-visual strong").textContent = card.name; const nameLink = cardEl.querySelector(".card-body h3 a"); nameLink.textContent = card.name; nameLink.href = "/cards/" + encodeURIComponent(card.id); cardEl.querySelector(".card-body p").textContent = `Best for ${card.categories.slice(0,2).join(" & ")}, with rewards that fit this stack.`; cardEl.querySelector(".tags").innerHTML = card.perks.slice(0,3).map(p=>`<span>${p}</span>`).join(""); cardEl.querySelector(".reward-line strong").textContent = `+${Math.max(...Object.values(card.rewards))}× back`; keep.textContent="♡ Keep"; keep.classList.remove("kept"); updateSavingsProjection(); window.shufflToast(`Swapped to ${card.name}`, "info"); };
    }); updateCount();

    const shareButton = results.querySelector("[data-share-stack]");
    if (shareButton) {
      const roundedRect = (context, x, y, width, height, radius) => {
        context.beginPath();
        context.roundRect(x, y, width, height, radius);
        context.fill();
      };

      const fitText = (context, value, maxWidth) => {
        let text = value;
        while (text.length > 1 && context.measureText(text).width > maxWidth) text = text.slice(0, -1);
        return text === value ? text : `${text.trim()}…`;
      };

      const buildShareCard = cards => {
        const canvas = document.createElement("canvas");
        canvas.width = 1200;
        canvas.height = 630;
        const context = canvas.getContext("2d");
        const background = context.createLinearGradient(0, 0, 1200, 630);
        background.addColorStop(0, "#766cff");
        background.addColorStop(0.48, "#4a42c8");
        background.addColorStop(1, "#17152b");
        context.fillStyle = background;
        context.fillRect(0, 0, 1200, 630);

        context.globalAlpha = 0.12;
        context.fillStyle = "#ffffff";
        context.beginPath(); context.arc(1080, 40, 250, 0, Math.PI * 2); context.fill();
        context.beginPath(); context.arc(80, 650, 290, 0, Math.PI * 2); context.fill();
        context.globalAlpha = 1;

        context.fillStyle = "#ffffff";
        roundedRect(context, 64, 48, 48, 48, 13);
        context.fillStyle = "#6c63ff";
        context.font = "700 22px sans-serif";
        context.textAlign = "center";
        context.fillText("S", 88, 80);
        context.textAlign = "left";
        context.fillStyle = "#ffffff";
        context.font = "700 30px sans-serif";
        context.fillText("Shuffl", 128, 82);

        context.font = "700 58px sans-serif";
        context.fillText("My Shuffl Stack", 64, 177);
        const annualValue = Math.round(cards.reduce((sum, card) => sum + (Math.max(...Object.values(card.rewards || { value: 0 })) * 62) - Number(card.annualFee || 0), 0));
        context.fillStyle = "rgba(255,255,255,.78)";
        context.font = "500 24px sans-serif";
        context.fillText(`${cards.length} cards • $${annualValue.toLocaleString()} projected annual value`, 68, 220);

        const cardWidth = 320;
        const cardHeight = 228;
        const gap = 28;
        const cardColors = [["#8179ff", "#5147d8"], ["#20c9a8", "#087863"], ["#a09cb8", "#57536f"]];
        cards.slice(0, 3).forEach((card, index) => {
          const x = 64 + index * (cardWidth + gap);
          const y = 270;
          const gradient = context.createLinearGradient(x, y, x + cardWidth, y + cardHeight);
          gradient.addColorStop(0, cardColors[index][0]);
          gradient.addColorStop(1, cardColors[index][1]);
          context.shadowColor = "rgba(0,0,0,.22)";
          context.shadowBlur = 25;
          context.shadowOffsetY = 12;
          context.fillStyle = gradient;
          roundedRect(context, x, y, cardWidth, cardHeight, 22);
          context.shadowColor = "transparent";

          context.fillStyle = "rgba(255,255,255,.78)";
          context.font = "600 15px sans-serif";
          context.fillText(String(card.issuer || "SHUFFL").toUpperCase(), x + 24, y + 38);
          context.textAlign = "right";
          context.fillText(card.cardNetwork || "", x + cardWidth - 24, y + 38);
          context.textAlign = "left";
          context.fillStyle = "#ffffff";
          context.font = "700 25px sans-serif";
          context.fillText(fitText(context, card.name || "Recommended card", cardWidth - 48), x + 24, y + 145);
          context.fillStyle = "rgba(255,255,255,.62)";
          context.font = "500 17px monospace";
          context.fillText(`•••• ${4829 + index * 813}`, x + 24, y + 194);
        });

        context.fillStyle = "rgba(255,255,255,.72)";
        context.font = "500 19px sans-serif";
        context.fillText("Built with shuffl.app", 64, 579);
        return canvas;
      };

      shareButton.addEventListener("click", () => {
        const cards = [...results.querySelectorAll(".result-card")].map(card => JSON.parse(card.dataset.card));
        const canvas = buildShareCard(cards);
        const shareSupported = typeof navigator.share === "function" && typeof navigator.canShare === "function" && navigator.canShare({ files: [new File([""], "shuffl-stack.png", { type: "image/png" })] });
        const previewWindow = shareSupported ? null : window.open("", "_blank");
        const originalLabel = shareButton.textContent;
        shareButton.disabled = true;
        shareButton.textContent = "Creating image…";

        canvas.toBlob(async blob => {
          if (!blob) {
            previewWindow?.close();
            shareButton.disabled = false;
            shareButton.textContent = originalLabel;
            return;
          }

          const imageUrl = URL.createObjectURL(blob);
          try {
            if (shareSupported) {
              const file = new File([blob], "my-shuffl-stack.png", { type: "image/png" });
              await navigator.share({ title: "My Shuffl Stack", text: "Here’s my recommended card stack from Shuffl.", files: [file] });
              URL.revokeObjectURL(imageUrl);
            } else if (previewWindow) {
              previewWindow.location.href = imageUrl;
            } else {
              window.open(imageUrl, "_blank");
            }
          } catch (error) {
            URL.revokeObjectURL(imageUrl);
            if (error.name !== "AbortError") console.error("Unable to share stack", error);
          } finally {
            shareButton.disabled = false;
            shareButton.textContent = originalLabel;
          }
        }, "image/png");
      });
    }
  }

  const comparison = document.querySelector("[data-compare]");
  if (comparison) {
    const walletButtons = [...comparison.querySelectorAll(".add-compare-wallet")];
    const cards = walletButtons.map(button => JSON.parse(button.dataset.card));
    const scoreCard = card => {
      const rewards = Object.values(card.rewards || {}).map(value => Number(value) || 0);
      const topReward = rewards.length ? Math.max(...rewards) : 0;
      const perksCount = Array.isArray(card.perks) ? card.perks.length : 0;
      const transferPartnersCount = Array.isArray(card.transferPartners) ? card.transferPartners.length : 0;
      const annualFee = Number(card.annualFee) || 0;
      const signUpBonus = Number(card.signUpBonus?.amount) || 0;

      return (topReward * 2) + perksCount + transferPartnersCount - (annualFee / 100) + (signUpBonus / 10000);
    };

    if (cards.length) {
      const scores = cards.map(scoreCard);
      const bestCardIndex = scores.indexOf(Math.max(...scores));
      const table = comparison.querySelector(".compare-table");
      const header = table?.tHead?.rows[0]?.cells[bestCardIndex + 1];

      table?.querySelectorAll(".compare-best-column").forEach(cell => cell.classList.remove("compare-best-column"));
      table?.querySelectorAll(".compare-best-badge").forEach(badge => badge.remove());
      table?.querySelectorAll("tr").forEach(row => {
        if (row.cells.length === cards.length + 1) row.cells[bestCardIndex + 1]?.classList.add("compare-best-column");
      });

      if (header) {
        const formattedScore = Number(scores[bestCardIndex].toFixed(2)).toLocaleString();
        const badge = document.createElement("span");
        badge.className = "compare-best-badge";
        badge.textContent = "Best Overall";
        badge.dataset.scoreTooltip = `Score: ${formattedScore}`;
        badge.setAttribute("aria-label", `Best Overall, score ${formattedScore}`);
        badge.tabIndex = 0;
        header.appendChild(badge);
      }
    }

    walletButtons.forEach(button => {
      const card = JSON.parse(button.dataset.card);
      const refresh = () => {
        const added = readWallet().some(item => item.id === card.id);
        button.textContent = added ? "✓ In wallet" : "＋ Add to wallet";
        button.classList.toggle("added", added);
      };
      button.addEventListener("click", () => {
        const wallet = readWallet();
        if (!wallet.some(item => item.id === card.id)) writeWallet([...wallet, card]);
        refresh();
      });
      refresh();
    });
  }

  // ── Wallet: interactive card spread ──
  const walletPage = document.querySelector("[data-wallet]");
  if (walletPage) {
    const spread = walletPage.querySelector("[data-wallet-spread]");
    const emptyState = walletPage.querySelector("[data-wallet-empty]");
    const countEl = walletPage.querySelector("[data-wallet-count]");
    const detailPanel = walletPage.querySelector("[data-wallet-detail-panel]");
    const navLinks = walletPage.querySelector(".wallet-nav-links");
    const walletHeader = walletPage.querySelector(".wallet-header");

    const tones = ["var(--tone-1)", "var(--tone-2)", "var(--tone-3)", "var(--tone-4)", "var(--tone-5)", "var(--tone-6)"];

    let activeCardId = null;

    const priorityHelp = document.createElement("p");
    priorityHelp.className = "wallet-priority-help";
    priorityHelp.textContent = "Priority: Card 1 = Primary, Card 2 = Secondary, etc.";
    walletHeader?.appendChild(priorityHelp);

    spread.innerHTML = '<div class="wallet-skeletons" aria-hidden="true"><div class="skeleton skeleton-card"></div><div class="skeleton skeleton-card"></div><div class="skeleton skeleton-card"></div></div>';
    countEl.textContent = "Loading your wallet…";
    if (navLinks) navLinks.hidden = true;

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
      const nameLink = document.createElement("a");
      nameLink.href = "/cards/" + encodeURIComponent(card.id);
      nameLink.textContent = card.name;
      nameLink.className = "wallet-card-name-link";
      nameLink.addEventListener("click", event => event.stopPropagation());
      name.appendChild(nameLink);

      const dots = document.createElement("span");
      dots.className = "spread-dots";
      dots.textContent = dotsFor(card.id, cards);

      const reorderControls = document.createElement("div");
      reorderControls.className = "card-reorder-controls";
      [
        ["up", "↑", "Move up"],
        ["down", "↓", "Move down"]
      ].forEach(([direction, symbol, label]) => {
        const button = document.createElement("button");
        button.type = "button";
        button.className = "card-reorder-button";
        button.dataset.moveCard = direction;
        button.textContent = symbol;
        button.setAttribute("aria-label", `${label}: ${card.name}`);
        button.title = label;
        button.addEventListener("click", event => {
          event.stopPropagation();
          moveCard(card.id, direction === "up" ? -1 : 1);
        });
        reorderControls.appendChild(button);
      });

      el.appendChild(topRow);
      el.appendChild(name);
      el.appendChild(dots);
      el.appendChild(reorderControls);

      el.addEventListener("click", () => selectCard(card));
      return el;
    }

    function moveCard(cardId, offset) {
      const cards = readWallet();
      const currentIndex = cards.findIndex(card => card.id === cardId);
      const nextIndex = currentIndex + offset;
      if (currentIndex < 0 || nextIndex < 0 || nextIndex >= cards.length) return;

      [cards[currentIndex], cards[nextIndex]] = [cards[nextIndex], cards[currentIndex]];
      writeWallet(cards);
      renderWallet();
      if (activeCardId) {
        const activeCard = cards.find(card => card.id === activeCardId);
        if (activeCard) showDetail(activeCard);
      }
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
        const cardIndex = cards.findIndex(walletCard => walletCard.id === card.id);
        const upButton = el.querySelector('[data-move-card="up"]');
        const downButton = el.querySelector('[data-move-card="down"]');
        if (upButton) upButton.disabled = cardIndex === 0;
        if (downButton) downButton.disabled = cardIndex === cards.length - 1;

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
      const detailName = detailPanel.querySelector("[data-detail-name]");
      detailName.textContent = card.name;
      detailName.href = "/cards/" + encodeURIComponent(card.id);
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
        window.shufflToast(`${card.name} removed from wallet`, "info");
      };
    }

    setTimeout(() => {
      if (!walletPage.isConnected) return;
      spread.innerHTML = "";
      renderWallet();
    }, 300);
  }

  // Explore: all searching, filtering, sorting, and wallet updates stay client-side.
  const explore = document.querySelector("[data-explore]");
  if (explore) {
    const cards = JSON.parse(explore.dataset.cards || "[]");
    const grid = explore.querySelector("[data-card-grid]");
    const search = explore.querySelector("[data-card-search]");
    const sort = explore.querySelector("[data-card-sort]");
    const count = explore.querySelector("[data-result-count]");
    const empty = explore.querySelector("[data-empty-state]");
    const clear = explore.querySelector("[data-clear-filters]");
    const dialog = explore.querySelector("[data-card-dialog]");
    const activeFilters = new Set();
    const tones = ["tone-1", "tone-2", "tone-3", "tone-4", "tone-5", "tone-6"];

    const topReward = card => Math.max(...Object.values(card.rewards));
    const matchesFilter = (card, filter) => {
      if (filter === "no-annual-fee") return card.annualFee === 0;
      if (filter === "no-foreign-fee") return card.foreignTransactionFee === false;
      return card.categories.includes(filter);
    };

    const syncWalletButtons = () => {
      const saved = new Set(readWallet().map(card => card.id));
      grid.querySelectorAll("[data-add-card]").forEach(button => {
        const isSaved = saved.has(button.dataset.addCard);
        button.textContent = isSaved ? "✓ In wallet" : "Add to wallet";
        button.classList.toggle("saved", isSaved);
      });
    };

    const addToWallet = card => {
      const wallet = readWallet();
      const exists = wallet.some(saved => saved.id === card.id);
      writeWallet(exists ? wallet.filter(saved => saved.id !== card.id) : [...wallet, card]);
      syncWalletButtons();
    };

    const showCard = card => {
      const rewards = Object.entries(card.rewards).sort((a, b) => b[1] - a[1]);
      dialog.querySelector("[data-dialog-content]").innerHTML = `
        <div class="dialog-card-visual ${tones[cards.indexOf(card) % tones.length]}"><span>${card.issuer}</span><strong>${card.name}</strong><small>${card.cardNetwork}</small></div>
        <div class="dialog-body"><span class="kicker">CARD DETAILS</span><h2>${card.name}</h2><p>${card.issuer} · ${card.cardNetwork}</p>
        <div class="dialog-stats"><div><span>Annual fee</span><strong>${card.annualFee === 0 ? "$0" : `$${card.annualFee}`}</strong></div><div><span>Sign-up bonus</span><strong>${card.signUpBonus.amount.toLocaleString()} pts</strong></div><div><span>Top reward</span><strong>${topReward(card)}×</strong></div></div>
        <div class="dialog-rewards">${rewards.map(([name, value]) => `<span><b>${value}×</b> ${name}</span>`).join("")}</div>
        <button type="button" class="button dialog-wallet-button" data-dialog-wallet>Add to wallet</button></div>`;
      dialog.querySelector("[data-dialog-wallet]").onclick = () => { addToWallet(card); dialog.close(); };
      dialog.showModal();
    };

    const buildTile = (card, index) => {
      const article = document.createElement("article");
      const rewards = Object.entries(card.rewards).sort((a, b) => b[1] - a[1]).slice(0, 3);
      const highestReward = rewards[0]?.[1] || 1;
      const bonusAmount = Number(card.signUpBonus?.amount) || 0;
      article.className = "explore-card";
      article.tabIndex = 0;
      article.setAttribute("role", "button");
      article.setAttribute("aria-label", `View ${card.name} details`);
      article.style.setProperty("--card-delay", `${Math.min(index, 12) * 35}ms`);
      article.innerHTML = `
        <div class="explore-card-inner">
          <div class="explore-card-face explore-card-front">
            <div class="explore-card-visual ${tones[cards.indexOf(card) % tones.length]}"><span class="mini-chip"></span><b>${card.issuer}</b><strong>${card.name}</strong><small>${card.cardNetwork}</small></div>
            <div class="explore-card-body"><p class="explore-issuer">${card.issuer}</p><h2>${card.name}</h2>
            <div class="explore-card-meta"><span>Top reward <b>${topReward(card)}×</b></span><span>Annual fee <b>${card.annualFee === 0 ? "$0" : `$${card.annualFee}`}</b></span></div>
            <button type="button" class="button explore-add" data-add-card="${card.id}">Add to wallet</button></div>
          </div>
          <div class="explore-card-face explore-card-back" aria-hidden="true">
            <div><p class="explore-back-kicker">TOP REWARDS</p><h2>${card.name}</h2></div>
            <div class="explore-reward-bars">${rewards.map(([name, value]) => `
              <div class="explore-reward-row"><span>${name}</span><b>${value}×</b><i><span style="width:${(value / highestReward) * 100}%"></span></i></div>`).join("")}</div>
            <div class="explore-back-stats"><span>Perks <b>${card.perks?.length || 0}</b></span><span>Sign-up bonus <b>${bonusAmount ? `${bonusAmount.toLocaleString()} ${card.pointsCurrency || "pts"}` : "None"}</b></span></div>
            <button type="button" class="button explore-add explore-back-add" data-add-card="${card.id}">Add to wallet</button>
          </div>
        </div>
        <button type="button" class="explore-flip-button" data-flip-card aria-label="Show ${card.name} quick details" aria-pressed="false">ℹ</button>`;
      article.addEventListener("click", event => {
        if (event.target.closest("[data-add-card], [data-flip-card]")) return;
        window.location.assign(`/cards/${encodeURIComponent(card.id)}`);
      });
      article.addEventListener("keydown", event => {
        if ((event.key === "Enter" || event.key === " ") && event.target === article) { event.preventDefault(); window.location.assign(`/cards/${encodeURIComponent(card.id)}`); }
      });
      article.querySelectorAll("[data-add-card]").forEach(button => button.addEventListener("click", event => {
        event.stopPropagation();
        addToWallet(card);
      }));
      article.querySelector("[data-flip-card]").addEventListener("click", event => {
        event.stopPropagation();
        const isFlipped = article.classList.toggle("is-flipped");
        event.currentTarget.textContent = isFlipped ? "✕" : "ℹ";
        event.currentTarget.setAttribute("aria-pressed", String(isFlipped));
        event.currentTarget.setAttribute("aria-label", `${isFlipped ? "Hide" : "Show"} ${card.name} quick details`);
        article.querySelector(".explore-card-front").setAttribute("aria-hidden", String(isFlipped));
        article.querySelector(".explore-card-back").setAttribute("aria-hidden", String(!isFlipped));
      });
      return article;
    };

    const render = () => {
      const query = search.value.trim().toLowerCase();
      const filtered = cards.filter(card =>
        (!query || `${card.name} ${card.issuer}`.toLowerCase().includes(query)) &&
        [...activeFilters].every(filter => matchesFilter(card, filter))
      ).sort((a, b) => {
        if (sort.value === "fee") return a.annualFee - b.annualFee || topReward(b) - topReward(a);
        if (sort.value === "bonus") return b.signUpBonus.amount - a.signUpBonus.amount;
        return topReward(b) - topReward(a) || a.annualFee - b.annualFee;
      });
      grid.replaceChildren(...filtered.map(buildTile));
      count.textContent = `${filtered.length} card${filtered.length === 1 ? "" : "s"}`;
      empty.hidden = filtered.length > 0;
      clear.hidden = !query && activeFilters.size === 0;
      syncWalletButtons();
    };

    search.addEventListener("input", render);
    sort.addEventListener("change", render);
    explore.querySelectorAll("[data-filter]").forEach(chip => chip.addEventListener("click", () => {
      activeFilters.has(chip.dataset.filter) ? activeFilters.delete(chip.dataset.filter) : activeFilters.add(chip.dataset.filter);
      chip.setAttribute("aria-pressed", activeFilters.has(chip.dataset.filter));
      render();
    }));
    clear.addEventListener("click", () => {
      search.value = ""; activeFilters.clear();
      explore.querySelectorAll("[data-filter]").forEach(chip => chip.setAttribute("aria-pressed", "false"));
      render();
    });
    explore.querySelector("[data-dialog-close]").addEventListener("click", () => dialog.close());
    dialog.addEventListener("click", event => { if (event.target === dialog) dialog.close(); });
    render();
  }

  const cardDetail = document.querySelector("[data-card-detail]");
  if (cardDetail) {
    const card = JSON.parse(cardDetail.dataset.card);
    const buttons = document.querySelectorAll("[data-add-to-wallet]");
    const stickyBar = document.querySelector("[data-card-sticky]");
    const hero = cardDetail.querySelector(".card-product-hero");
    const detailGrid = cardDetail.querySelector(".product-detail-grid");
    const rewardBars = [...cardDetail.querySelectorAll(".product-reward-track span")];

    if (detailGrid && !window.matchMedia("(prefers-reduced-motion: reduce)").matches && "IntersectionObserver" in window) {
      const counters = [...detailGrid.querySelectorAll("strong")].flatMap(element => {
        const finalText = element.textContent.trim();
        const match = finalText.match(/-?\d[\d,]*(?:\.\d+)?/);
        if (!match) return [];

        const numericText = match[0];
        return [{
          element,
          finalText,
          finalValue: Number(numericText.replaceAll(",", "")),
          prefix: finalText.slice(0, match.index),
          suffix: finalText.slice(match.index + numericText.length),
          decimalPlaces: (numericText.split(".")[1] || "").length
        }];
      });

      const renderCounter = (counter, value) => {
        const formatted = value.toLocaleString(undefined, {
          minimumFractionDigits: counter.decimalPlaces,
          maximumFractionDigits: counter.decimalPlaces
        });
        counter.element.textContent = `${counter.prefix}${formatted}${counter.suffix}`;
      };

      counters.forEach(counter => renderCounter(counter, 0));
      rewardBars.forEach((bar, index) => bar.style.setProperty("--reward-delay", `${index * 80}ms`));
      cardDetail.classList.add("detail-animation-ready");

      const observer = new IntersectionObserver((entries, currentObserver) => {
        entries.forEach(entry => {
          if (!entry.isIntersecting) return;

          currentObserver.unobserve(entry.target);
          cardDetail.classList.add("detail-animation-played");
          const duration = 800;
          let startedAt;

          const animateCounters = timestamp => {
            startedAt ??= timestamp;
            const progress = Math.min((timestamp - startedAt) / duration, 1);
            const easedProgress = progress === 1 ? 1 : 1 - Math.pow(2, -10 * progress);

            counters.forEach(counter => renderCounter(counter, counter.finalValue * easedProgress));
            if (progress < 1) requestAnimationFrame(animateCounters);
            else counters.forEach(counter => { counter.element.textContent = counter.finalText; });
          };

          requestAnimationFrame(animateCounters);
        });
      }, { threshold: 0.3 });

      observer.observe(detailGrid);
    }

    const renderButton = () => {
      const kept = readWallet().some(walletCard => walletCard.id === card.id);
      buttons.forEach(button => {
        button.textContent = kept ? "✓ In your wallet" : "♡ Add to wallet";
        button.classList.toggle("kept", kept);
      });
    };
    buttons.forEach(button => button.addEventListener("click", () => {
      const wallet = readWallet();
      const kept = wallet.some(walletCard => walletCard.id === card.id);
      writeWallet(kept ? wallet.filter(walletCard => walletCard.id !== card.id) : [...wallet, card]);
      renderButton();
    }));

    const setStickyVisibility = visible => {
      stickyBar.classList.toggle("is-visible", visible);
      stickyBar.setAttribute("aria-hidden", String(!visible));
      stickyBar.toggleAttribute("inert", !visible);
    };
    const stickyObserver = new IntersectionObserver(([entry]) => {
      setStickyVisibility(!entry.isIntersecting && entry.boundingClientRect.bottom <= 0);
    });
    stickyObserver.observe(hero);
    document.addEventListener("turbo:before-cache", () => stickyObserver.disconnect(), { once: true });
    renderButton();
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

  const formatMessage = text => {
    const escaped = document.createElement("div");
    escaped.textContent = text;
    return escaped.innerHTML.replace(/\*\*(.+?)\*\*/g, "<strong>$1</strong>").replace(/\n/g, "<br>");
  };

  const addMessage = async (role, text) => {
    const div = document.createElement("div");
    div.className = `chat-msg chat-msg-${role === "user" ? "user" : "bot"}`;

    const avatar = document.createElement("span");
    avatar.className = "chat-msg-avatar";
    avatar.textContent = role === "user" ? "N" : "S";

    const bubble = document.createElement("div");
    bubble.className = "chat-msg-bubble";
    div.appendChild(avatar);
    div.appendChild(bubble);
    messagesEl.appendChild(div);

    if (role === "user" || window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      bubble.innerHTML = formatMessage(text);
      scrollBottom();
      return;
    }

    const words = text.match(/\S+\s*/g) || [];
    for (const word of words) {
      bubble.textContent += word;
      scrollBottom();
      await new Promise(resolve => setTimeout(resolve, 20));
    }
    bubble.innerHTML = formatMessage(text);
    scrollBottom();
  };

  const addTyping = () => {
    panel.classList.add("is-waiting");
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
    panel.classList.remove("is-waiting");
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
      await addMessage("assistant", reply);
      history.push({ role: "assistant", content: reply });
    } catch (err) {
      removeTyping();
      await addMessage("assistant", "Sorry, I couldn't connect. Please try again.");
    }
  });
});

// ── Ready-made stack reveal ─────────────────────────────────
document.addEventListener("turbo:load", () => {
  const stackCards = document.querySelectorAll(".stack-card");
  if (!stackCards.length) return;

  const stackCardObserver = new IntersectionObserver((entries, observer) => {
    entries.forEach(entry => {
      if (!entry.isIntersecting) return;
      entry.target.classList.add("visible");
      observer.unobserve(entry.target);
    });
  }, { threshold: 0.15 });

  stackCards.forEach(card => stackCardObserver.observe(card));
  document.addEventListener("turbo:before-cache", () => stackCardObserver.disconnect(), { once: true });
});
