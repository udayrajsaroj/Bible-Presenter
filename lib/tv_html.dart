const String tvHtmlContent = r'''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no"/>
  <title>BiblePresenter — TV</title>
  <!-- Non-blocking font loading with comprehensive offline system fallbacks -->
  <link rel="preconnect" href="https://fonts.googleapis.com" crossorigin>
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Cinzel:wght@400;700;900&family=Crimson+Pro:ital,wght@0,300;0,600;1,300;1,600&family=Tiro+Devanagari+Hindi:ital@0;1&display=swap" media="print" onload="this.media='all'">
  <noscript>
    <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Cinzel:wght@400;700;900&family=Crimson+Pro:ital,wght@0,300;0,600;1,300;1,600&family=Tiro+Devanagari+Hindi:ital@0;1&display=swap">
  </noscript>
  <script defer src="https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174/pdf.min.js"></script>
  <style>
    :root {
      --gold: #c9a96e;
      --gold-light: #e8d5a3;
      --ink: #0a0a0f;
    }
    * { margin: 0; padding: 0; box-sizing: border-box; -webkit-tap-highlight-color: transparent; }
    body {
      background: var(--ink);
      font-family: 'Crimson Pro', Georgia, serif;
      overflow: hidden;
      width: 100vw; height: 100vh;
      touch-action: manipulation;
    }

    body::before {
      content: '';
      position: fixed; inset: 0; z-index: 0;
      background-image: url("data:image/svg+xml,%3Csvg viewBox='0 0 256 256' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='noise'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.9' numOctaves='4' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23noise)' opacity='0.04'/%3E%3C/svg%3E");
      opacity: 0.35; pointer-events: none;
    }

    #bg-layer {
      position: fixed; inset: 0; z-index: 1;
      background-size: cover; background-position: center;
      transition: background-image 1.2s ease, opacity 1s ease;
      opacity: 0.45;
    }
    #bg-overlay {
      position: fixed; inset: 0; z-index: 2;
      background: radial-gradient(ellipse at center, transparent 0%, rgba(10,10,15,0.5) 60%, rgba(10,10,15,0.92) 100%);
    }

    /* ── Animated Backgrounds ── */
    .anim-bg {
      position: fixed; inset: 0; z-index: 1;
      opacity: 0; transition: opacity 1s ease;
      pointer-events: none;
    }
    .anim-bg.active { opacity: 1; }

    /* 1. Celestial Nebula (Deep Midnight Sapphire & Cosmic Aurora) */
    .anim-aurora {
      background: radial-gradient(ellipse at 50% 100%, #03030c 0%, #020205 100%);
    }
    .anim-aurora::before {
      content: ''; position: absolute; inset: -20%;
      background: linear-gradient(135deg, #03030c 0%, #080d24 25%, #150d30 50%, #04201c 75%, #03030c 100%);
      background-size: 300% 300%;
      animation: auroraShift 18s ease-in-out infinite;
      filter: blur(20px);
    }
    @keyframes auroraShift {
      0%   { background-position: 0% 50%; }
      50%  { background-position: 100% 50%; }
      100% { background-position: 0% 50%; }
    }
    .anim-aurora::after {
      content: ''; position: absolute; inset: 0;
      background: radial-gradient(ellipse at 35% 45%, rgba(14,165,233,0.18) 0%, transparent 60%),
                  radial-gradient(ellipse at 75% 35%, rgba(139,92,246,0.15) 0%, transparent 55%),
                  radial-gradient(ellipse at 50% 75%, rgba(16,185,129,0.10) 0%, transparent 50%);
      animation: auroraPulse 10s ease-in-out infinite alternate;
    }
    @keyframes auroraPulse {
      0% { opacity: 0.7; transform: scale(0.98); }
      100% { opacity: 1.1; transform: scale(1.03); }
    }

    /* 2. Divine Glory (Sacred Rotating Golden Rays & Breathing Halo) */
    .anim-divine {
      background: radial-gradient(circle at 50% 50%, #0d0c07 0%, #040403 100%);
    }
    .anim-divine::before {
      content: ''; position: absolute; inset: -60%;
      background: conic-gradient(from 0deg at 50% 50%,
        transparent 0deg, rgba(201,169,110,0.08) 35deg, transparent 70deg,
        rgba(245,158,11,0.05) 120deg, transparent 160deg,
        rgba(201,169,110,0.07) 210deg, transparent 250deg,
        rgba(245,158,11,0.06) 300deg, transparent 340deg);
      animation: divineRotate 45s linear infinite;
    }
    @keyframes divineRotate { to { transform: rotate(360deg); } }
    .anim-divine::after {
      content: ''; position: absolute; inset: 0;
      background: radial-gradient(circle at 50% 50%, rgba(201,169,110,0.18) 0%, rgba(245,158,11,0.06) 45%, transparent 70%);
      animation: divineBreath 7s ease-in-out infinite alternate;
    }
    @keyframes divineBreath {
      0% { opacity: 0.55; transform: scale(0.95); }
      100% { opacity: 1.0; transform: scale(1.08); }
    }

    /* 3. Midnight Sanctuary (Royal Amethyst & Sacred Velvet Prism) */
    .anim-sunset {
      background: radial-gradient(ellipse at 50% 40%, #07030f 0%, #020106 100%);
    }
    .anim-sunset::before {
      content: ''; position: absolute; inset: -15%;
      background: linear-gradient(145deg, #07020e 0%, #1c0533 30%, #28041a 60%, #070b24 100%);
      background-size: 250% 250%;
      animation: sanctuaryShift 20s ease-in-out infinite;
      filter: blur(15px);
    }
    @keyframes sanctuaryShift {
      0%   { background-position: 0% 0%; }
      50%  { background-position: 100% 100%; }
      100% { background-position: 0% 0%; }
    }
    .anim-sunset::after {
      content: ''; position: absolute; inset: 0;
      background: radial-gradient(ellipse at 50% 50%, rgba(168,85,247,0.15) 0%, transparent 60%),
                  radial-gradient(ellipse at 25% 70%, rgba(236,72,153,0.09) 0%, transparent 45%),
                  radial-gradient(ellipse at 80% 30%, rgba(99,102,241,0.11) 0%, transparent 50%);
      animation: sanctuaryGlow 9s ease-in-out infinite alternate;
    }
    @keyframes sanctuaryGlow {
      0% { opacity: 0.6; }
      100% { opacity: 1.0; }
    }

    /* 4. Living Waters (Deep Abyssal Ocean & Bioluminescent Swell) */
    .anim-ocean {
      background: radial-gradient(ellipse at 50% 60%, #020914 0%, #010408 100%);
    }
    .anim-ocean::before {
      content: ''; position: absolute; inset: -20%;
      background: linear-gradient(160deg, #020914 0%, #041d33 35%, #021221 65%, #01080e 100%);
      background-size: 250% 250%;
      animation: oceanSwell 22s ease-in-out infinite;
      filter: blur(15px);
    }
    @keyframes oceanSwell {
      0%   { background-position: 20% 0%; }
      50%  { background-position: 80% 100%; }
      100% { background-position: 20% 0%; }
    }
    .anim-ocean::after {
      content: ''; position: absolute; inset: 0;
      background: radial-gradient(ellipse at 65% 55%, rgba(6,182,212,0.16) 0%, transparent 55%),
                  radial-gradient(ellipse at 30% 35%, rgba(14,165,233,0.11) 0%, transparent 50%),
                  radial-gradient(ellipse at 50% 85%, rgba(2,132,199,0.08) 0%, transparent 40%);
      animation: oceanRipples 8s ease-in-out infinite alternate;
    }
    @keyframes oceanRipples {
      0% { opacity: 0.6; transform: translateY(-5px); }
      100% { opacity: 1.0; transform: translateY(5px); }
    }

    /* 5. Altar Flame (Sacred Holy Fire & Glowing Embers) */
    .anim-fire {
      background: radial-gradient(ellipse at 50% 100%, #090302 0%, #020101 100%);
    }
    .anim-fire::before {
      content: ''; position: absolute; inset: 0;
      background: radial-gradient(ellipse at 50% 100%, rgba(239,68,68,0.18) 0%, transparent 60%),
                  radial-gradient(ellipse at 30% 95%, rgba(245,158,11,0.14) 0%, transparent 50%),
                  radial-gradient(ellipse at 70% 95%, rgba(180,83,9,0.10) 0%, transparent 45%);
      animation: firePulse 5s ease-in-out infinite alternate;
    }
    @keyframes firePulse {
      0%   { opacity: 0.65; transform: scaleY(0.97); }
      50%  { opacity: 1.0; transform: scaleY(1.06); }
      100% { opacity: 0.75; transform: scaleY(1.0); }
    }
    .anim-fire::after {
      content: ''; position: absolute; inset: 0;
      background: radial-gradient(circle at 50% 85%, rgba(251,191,36,0.12) 0%, transparent 35%),
                  radial-gradient(circle at 40% 70%, rgba(239,68,68,0.06) 0%, transparent 25%);
      animation: emberShimmer 3.5s ease-in-out infinite alternate;
    }
    @keyframes emberShimmer {
      0% { opacity: 0.5; transform: translateY(4px); }
      100% { opacity: 0.95; transform: translateY(-6px); }
    }

    #stage {
      position: fixed; inset: 0; z-index: 10;
      display: flex; flex-direction: column;
      justify-content: center; align-items: center;
      text-align: center;
      padding: 3vh 3vw;
      transition: opacity 0.35s ease;
    }

    .ornament {
      display: flex; align-items: center; justify-content: center; gap: 16px;
      width: 100%;
      margin: 20px 0;
      color: var(--gold);
      opacity: 0.6;
      font-size: 18px;
      letter-spacing: 0.3em;
    }
    .ornament::before, .ornament::after {
      content: '';
      display: block;
      height: 1px;
      flex: 1;
      max-width: 120px;
      background: linear-gradient(to right, transparent, var(--gold), transparent);
    }

    .verse-container {
      display: flex; flex-direction: column;
      align-items: center; justify-content: center;
      text-align: center;
      width: 100%;
    }
    .verse-hi {
      font-family: 'Crimson Pro', 'Tiro Devanagari Hindi', 'Nirmala UI', 'Mangal', Georgia, 'Times New Roman', serif;
      font-weight: 400;
      color: #ffffff;
      line-height: 1.5;
      text-shadow: 0 2px 40px rgba(0,0,0,0.9), 0 0 60px rgba(255,255,255,0.08);
      transition: font-size 0.4s ease;
      text-align: center;
    }
    .verse-en {
      font-family: 'Crimson Pro', 'Tiro Devanagari Hindi', 'Nirmala UI', Georgia, 'Times New Roman', serif;
      font-weight: 300;
      font-style: italic;
      color: #ffffff;
      line-height: 1.6;
      text-shadow: 0 2px 30px rgba(0,0,0,0.95);
      transition: font-size 0.4s ease;
      text-align: center;
    }
    .verse-ref {
      font-family: 'Cinzel', Georgia, 'Times New Roman', serif;
      font-weight: 700;
      color: var(--gold);
      letter-spacing: 0.35em;
      text-transform: uppercase;
      font-size: clamp(13px, 1.6vw, 22px);
      text-shadow: 0 0 30px rgba(201,169,110,0.4);
      text-align: center;
    }

    /* ── Song specific styles ── */
    .song-stanza-counter {
      font-family: 'Cinzel', serif;
      font-size: 11px;
      letter-spacing: 0.3em;
      color: rgba(255,255,255,0.25);
      text-transform: uppercase;
      margin-top: 12px;
    }
    .song-title {
      font-family: 'Cinzel', serif;
      font-weight: 400;
      color: rgba(255,255,255,0.2);
      font-size: 12px;
      letter-spacing: 0.2em;
      text-transform: uppercase;
    }

    .slide-container {
      display: flex; flex-direction: column;
      align-items: center; justify-content: center;
      text-align: center;
      width: 100%;
    }
    .slide-title {
      font-family: 'Cinzel', serif;
      font-weight: 900;
      color: #ffffff;
      text-transform: uppercase;
      letter-spacing: 0.12em;
      line-height: 1.15;
      text-shadow: 0 4px 40px rgba(0,0,0,1), 0 0 60px rgba(201,169,110,0.1);
      text-align: center;
    }
    .slide-subtitle {
      font-family: 'Cinzel', serif;
      font-weight: 400;
      font-size: clamp(10px, 1.1vw, 15px);
      color: var(--gold);
      letter-spacing: 0.4em;
      text-transform: uppercase;
      margin-bottom: 18px;
      text-align: center;
    }
    .slide-text {
      font-family: 'Crimson Pro', serif;
      font-weight: 300;
      color: #ccc4b0;
      line-height: 1.7;
      text-align: center;
    }

    /* ── Logo styles (CHANGE #1: true full-screen logo) ── */
    .logo-container {
      position: fixed;
      inset: 0;
      z-index: 100;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      width: 100vw;
      height: 100vh;
      padding: 0;
      background: #000;
    }
    .logo-container img {
      width: 100vw;
      height: 100vh;
      object-fit: cover;
      filter: drop-shadow(0 4px 30px rgba(0,0,0,0.8));
    }
    .logo-glow {
      position: absolute;
      width: 60vw;
      height: 60vh;
      border-radius: 50%;
      background: radial-gradient(circle, rgba(201,169,110,0.08) 0%, transparent 70%);
      pointer-events: none;
    }

    /* ── Welcome screen styles (CHANGE #3) ── */
    .welcome-screen {
      position: fixed;
      inset: 0;
      z-index: 100;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      background: #ffffff;
      padding: 4vh 4vw;
      gap: 3vh;
    }
    .welcome-screen img {
      max-width: 45vw;
      max-height: 45vh;
      object-fit: contain;
      transition: all 0.5s ease;
    }
    .welcome-screen.has-message {
      justify-content: flex-end;
      padding-bottom: 12vh;
    }
    .welcome-screen.has-message img {
      max-width: 35vw;
      max-height: 35vh;
    }
    .welcome-message {
      font-family: 'Cinzel', serif;
      font-size: clamp(18px, 3vw, 36px);
      color: #2a2a2a;
      text-align: center;
      letter-spacing: 0.15em;
      font-weight: 400;
      animation: welcomeFadeIn 1s cubic-bezier(0.22, 1, 0.36, 1) forwards;
    }
    @keyframes welcomeFadeIn {
      from { opacity: 0; transform: translateY(16px); }
      to { opacity: 1; transform: translateY(0); }
    }

    /* ── Idle screen (CHANGE #5: improved elegance) ── */
    #idle-screen {
      display: flex; flex-direction: column;
      align-items: center; gap: 24px;
    }
    .idle-cross {
      width: 64px; height: 64px;
      position: relative;
      opacity: 0.25;
      animation: idleCrossPulse 4s ease-in-out infinite;
    }
    @keyframes idleCrossPulse {
      0%, 100% { opacity: 0.18; transform: scale(1); filter: drop-shadow(0 0 0px rgba(201,169,110,0)); }
      50% { opacity: 0.4; transform: scale(1.08); filter: drop-shadow(0 0 18px rgba(201,169,110,0.25)); }
    }
    .idle-cross::before, .idle-cross::after {
      content: ''; position: absolute;
      background: var(--gold);
      border-radius: 2px;
    }
    .idle-cross::before { width: 8px; height: 100%; left: 50%; transform: translateX(-50%); }
    .idle-cross::after  { width: 100%; height: 8px; top: 28%; left: 0; }
    .idle-label {
      font-family: 'Cinzel', serif;
      font-size: clamp(10px, 1.2vw, 14px);
      letter-spacing: 0.4em;
      color: rgba(255,255,255,0.2);
      text-transform: uppercase;
      text-shadow: 0 0 24px rgba(201,169,110,0.15), 0 0 60px rgba(201,169,110,0.08);
      animation: idleLabelGlow 4s ease-in-out infinite;
    }
    @keyframes idleLabelGlow {
      0%, 100% { text-shadow: 0 0 24px rgba(201,169,110,0.1), 0 0 60px rgba(201,169,110,0.05); }
      50% { text-shadow: 0 0 30px rgba(201,169,110,0.25), 0 0 70px rgba(201,169,110,0.12); }
    }

    /* ── Status badge (CHANGE #6: more subtle) ── */
    #status-badge {
      position: fixed; top: 24px; right: 24px;
      z-index: 50;
      display: flex; align-items: center; gap: 8px;
      font-family: 'Cinzel', serif;
      font-size: 8px;
      letter-spacing: 0.25em;
      text-transform: uppercase;
      color: rgba(255,255,255,0.2);
      background: rgba(10,10,15,0.5);
      border: 1px solid rgba(255,255,255,0.04);
      backdrop-filter: blur(12px);
      padding: 5px 12px;
      border-radius: 100px;
      transition: opacity 0.5s ease;
    }
    #status-dot {
      width: 6px; height: 6px;
      border-radius: 50%;
      background: #ef4444;
      animation: pulse-dot 2s ease-in-out infinite;
    }
    #status-dot.online {
      background: #22c55e;
      box-shadow: 0 0 6px rgba(34,197,94,0.5);
      animation: none;
    }
    @keyframes pulse-dot {
      0%,100% { opacity:1; } 50% { opacity:0.3; }
    }

    #brand-badge {
      position: fixed; top: 24px; left: 24px;
      z-index: 50;
      font-family: 'Cinzel', serif;
      font-size: 8px;
      letter-spacing: 0.3em;
      text-transform: uppercase;
      color: rgba(201,169,110,0.25);
      display: flex; align-items: center; gap: 8px;
      transition: opacity 0.5s ease;
    }
    #brand-badge::before {
      content: '';
      width: 5px; height: 5px;
      border-radius: 50%;
      background: #22c55e;
      box-shadow: 0 0 5px rgba(34,197,94,0.4);
      animation: pulse-dot 3s ease-in-out infinite;
    }

    /* ── Fade-in animation (CHANGE #6: improved) ── */
    .fade-in {
      animation: fadeUp 0.8s cubic-bezier(0.16, 1, 0.3, 1) forwards;
    }
    @keyframes fadeUp {
      from { opacity: 0; transform: translateY(18px); }
      to   { opacity: 1; transform: translateY(0); }
    }

    /* ── State transition helper ── */
    .state-transitioning {
      opacity: 0;
      transition: opacity 0.25s ease;
    }

    /* ── PDF / PPTX Viewer ── */
    #doc-viewer {
      position: fixed; inset: 0; z-index: 40;
      display: none;
      background: #000;
      justify-content: center;
      align-items: center;
      transition: opacity 0.4s ease;
    }
    #doc-viewer.active {
      display: flex;
    }
    #pdf-canvas {
      max-width: 100vw;
      max-height: 100vh;
      object-fit: contain;
    }
    #pptx-iframe {
      width: 100vw;
      height: 100vh;
      border: none;
    }
    #page-indicator {
      position: fixed; bottom: 24px; left: 50%; transform: translateX(-50%);
      z-index: 55;
      font-family: 'Cinzel', serif;
      font-size: 11px;
      letter-spacing: 0.3em;
      color: rgba(255,255,255,0.4);
      background: rgba(10,10,15,0.6);
      border: 1px solid rgba(255,255,255,0.06);
      backdrop-filter: blur(12px);
      padding: 6px 18px;
      border-radius: 100px;
      display: none;
    }
    #page-indicator.active {
      display: block;
      animation: pageIndicatorFade 3s ease forwards;
    }
    @keyframes pageIndicatorFade {
      0%   { opacity: 1; }
      70%  { opacity: 1; }
      100% { opacity: 0; pointer-events: none; }
    }
    #page-indicator.peek {
      animation: pageIndicatorPeek 2s ease forwards;
    }
    @keyframes pageIndicatorPeek {
      0%   { opacity: 0; }
      10%  { opacity: 1; }
      70%  { opacity: 1; }
      100% { opacity: 0; pointer-events: none; }
    }
    #doc-loading {
      position: fixed; inset: 0; z-index: 56;
      display: none;
      background: rgba(0,0,0,0.9);
      justify-content: center;
      align-items: center;
      flex-direction: column;
      gap: 20px;
    }
    #doc-loading.active {
      display: flex;
    }
    .loading-spinner {
      width: 40px; height: 40px;
      border: 3px solid rgba(201,169,110,0.2);
      border-top-color: var(--gold);
      border-radius: 50%;
      animation: spin 0.8s linear infinite;
    }
    @keyframes spin {
      to { transform: rotate(360deg); }
    }
    .loading-text {
      font-family: 'Cinzel', serif;
      font-size: 12px;
      letter-spacing: 0.3em;
      color: rgba(255,255,255,0.3);
      text-transform: uppercase;
    }

    /* ════════════════════════════════════════════════════════
       MOBILE RESPONSIVE — screens below 768px
       ════════════════════════════════════════════════════════ */
    @media (max-width: 768px) {
      body {
        -webkit-text-size-adjust: 100%;
      }

      #stage {
        padding: 2vh 4vw;
      }

      #status-badge {
        top: 10px; right: 10px;
        font-size: 7px;
        padding: 3px 8px;
        gap: 4px;
        color: rgba(255,255,255,0.15);
      }
      #status-dot {
        width: 4px; height: 4px;
      }
      #brand-badge {
        top: 10px; left: 10px;
        font-size: 7px;
        gap: 5px;
        color: rgba(201,169,110,0.2);
      }
      #brand-badge::before {
        width: 4px; height: 4px;
      }

      .ornament {
        margin: 12px 0;
        font-size: 14px;
        gap: 10px;
      }
      .ornament::before, .ornament::after {
        max-width: 60px;
      }

      .verse-ref {
        font-size: clamp(10px, 3.5vw, 16px);
        letter-spacing: 0.2em;
      }

      .song-stanza-counter {
        font-size: 9px;
        margin-top: 8px;
      }

      .slide-subtitle {
        font-size: clamp(8px, 2.5vw, 12px);
        margin-bottom: 10px;
      }

      .idle-cross {
        width: 44px; height: 44px;
      }
      .idle-cross::before { width: 6px; }
      .idle-cross::after  { height: 6px; }
      .idle-label {
        font-size: clamp(8px, 2.5vw, 12px);
        letter-spacing: 0.25em;
      }

      #page-indicator {
        display: none !important;
      }

      .loading-spinner {
        width: 30px; height: 30px;
        border-width: 2px;
      }
      .loading-text {
        font-size: 10px;
      }

      .logo-container {
        padding: 0;
      }
      .logo-glow {
        width: 80vw;
        height: 50vh;
      }

      .verse-container {
        max-width: 100%;
      }

      /* Welcome screen mobile (CHANGE #4) */
      .welcome-screen img {
        max-width: 70vw;
        max-height: 40vh;
      }
      .welcome-screen.has-message img {
        max-width: 55vw;
        max-height: 30vh;
      }
      .welcome-message {
        font-size: clamp(14px, 4vw, 22px);
      }

      /* ── Mobile-specific nav buttons ── */
      #mobile-nav {
        position: fixed;
        bottom: 0; left: 0; right: 0;
        z-index: 60;
        display: flex;
        align-items: center;
        justify-content: center;
        gap: 16px;
        padding: 10px 20px;
        padding-bottom: max(10px, env(safe-area-inset-bottom));
        background: linear-gradient(to top, rgba(10,10,15,0.95) 0%, rgba(10,10,15,0.7) 70%, transparent 100%);
        opacity: 0;
        transform: translateY(10px);
        transition: opacity 0.3s ease, transform 0.3s ease;
        pointer-events: none;
      }
      #mobile-nav.visible {
        opacity: 1;
        transform: translateY(0);
        pointer-events: auto;
      }
      #mobile-nav button {
        width: 48px; height: 48px;
        border: 1px solid rgba(255,255,255,0.12);
        border-radius: 50%;
        background: rgba(201,169,110,0.1);
        color: rgba(255,255,255,0.7);
        font-size: 20px;
        display: flex; align-items: center; justify-content: center;
        cursor: pointer;
        transition: background 0.2s, transform 0.1s;
        -webkit-appearance: none;
        outline: none;
      }
      #mobile-nav button:active {
        background: rgba(201,169,110,0.3);
        transform: scale(0.92);
      }
      #mobile-nav .nav-info {
        font-family: 'Cinzel', serif;
        font-size: 11px;
        letter-spacing: 0.2em;
        color: rgba(255,255,255,0.4);
        min-width: 70px;
        text-align: center;
      }
    }

    /* ════════════════════════════════════════════════════════
       MOBILE LANDSCAPE — special tweaks
       ════════════════════════════════════════════════════════ */
    @media (max-width: 768px) and (orientation: landscape) {
      #stage {
        padding: 1vh 5vw;
      }
      .idle-cross {
        width: 32px; height: 32px;
      }
      .idle-cross::before { width: 5px; }
      .idle-cross::after  { height: 5px; }
      #mobile-nav {
        padding: 6px 20px;
        padding-bottom: max(6px, env(safe-area-inset-bottom));
      }
      #mobile-nav button {
        width: 40px; height: 40px;
        font-size: 16px;
      }
      #mobile-nav .nav-info {
        font-size: 9px;
        min-width: 55px;
      }
      .welcome-screen img {
        max-width: 40vw;
        max-height: 60vh;
      }
      .welcome-screen.has-message img {
        max-width: 30vw;
        max-height: 45vh;
      }
    }

    /* ── Desktop: hide mobile nav ── */
    @media (min-width: 769px) {
      #mobile-nav {
        display: none !important;
      }
    }

    /* ── Touch feedback ripple ── */
    .touch-ripple {
      position: fixed;
      width: 40px; height: 40px;
      border-radius: 50%;
      background: rgba(201,169,110,0.2);
      transform: translate(-50%, -50%) scale(0);
      animation: ripple 0.5s ease-out forwards;
      pointer-events: none;
      z-index: 999;
    }
    @keyframes ripple {
      to { transform: translate(-50%, -50%) scale(3); opacity: 0; }
    }
  </style>
</head>
<body>
  <div id="bg-layer"></div>
  <!-- Animated backgrounds -->
  <div id="anim-aurora" class="anim-bg anim-aurora"></div>
  <div id="anim-divine" class="anim-bg anim-divine"></div>
  <div id="anim-sunset" class="anim-bg anim-sunset"></div>
  <div id="anim-ocean" class="anim-bg anim-ocean"></div>
  <div id="anim-fire" class="anim-bg anim-fire"></div>
  <div id="bg-overlay"></div>

  <div id="status-badge">
    <span id="status-dot"></span>
    <span id="status-text">Connecting</span>
  </div>
  <div id="brand-badge">BiblePresenter Live</div>

  <div id="stage">
    <div id="idle-screen">
      <div class="idle-cross"></div>
      <p class="idle-label">BiblePresenter</p>
    </div>
  </div>

  <div id="doc-viewer">
    <canvas id="pdf-canvas"></canvas>
    <iframe id="pptx-iframe" src="" style="display:none"></iframe>
  </div>

  <!-- ── Video player (Feature 2: local video casting) ── -->
  <video id="video-player" style="display:none;position:fixed;inset:0;width:100vw;height:100vh;object-fit:contain;background:#000;z-index:45;"></video>

  <!-- ── YouTube player (Feature 3: IFrame API) ── -->
  <div id="yt-container" style="display:none;position:fixed;inset:0;width:100vw;height:100vh;background:#000;z-index:45;">
    <div id="yt-player"></div>
  </div>

  <div id="page-indicator"></div>
  <div id="doc-loading">
    <div class="loading-spinner"></div>
    <p class="loading-text">Loading document...</p>
  </div>

  <!-- Mobile navigation bar (only visible on small screens) -->
  <div id="mobile-nav">
    <button id="nav-prev" title="Previous">&#8249;</button>
    <span id="nav-info" class="nav-info"></span>
    <button id="nav-next" title="Next">&#8250;</button>
  </div>

<script>
  let ws, reconnectTimer;
  let state = { type: 'idle', content: null, fontSize: 44 };
  let currentAnimBg = '';
  let prevStateType = '';

  // ── PDF state ──
  let pdfDoc = null;
  let pdfPage = 1;
  let pdfTotalPages = 0;
  let pdfRendering = false;
  let currentPdfUrl = '';

  // ── Video state (Feature 2) ──
  const videoEl = document.getElementById('video-player');
  let videoUrl = '';
  let lastProgressSecond = -1;

  function sendToPhone(event, data) {
    if (ws && ws.readyState === WebSocket.OPEN) {
      ws.send(JSON.stringify({ event: event, data: data || {} }));
    }
  }

  function showVideo(url, autoPlay) {
    closeDocViewer();
    hideYouTube();
    const fullUrl = url.startsWith('http') ? url : (location.protocol + '//' + location.host + url);
    if (videoUrl !== fullUrl) {
      videoUrl = fullUrl;
      videoEl.src = videoUrl + (videoUrl.includes('?') ? '&' : '?') + 't=' + Date.now();
    }
    videoEl.style.display = 'block';
    if (autoPlay !== false) {
      videoEl.play().catch(() => {
        // Some TV browsers block autoplay with sound (risk R6): start muted
        // so playback still begins, and tell the phone to offer Unmute.
        videoEl.muted = true;
        videoEl.play().catch(() => {});
        sendToPhone('video-muted', {});
      });
    }
  }

  function hideVideo() {
    videoEl.pause();
    videoEl.removeAttribute('src');
    videoEl.load(); // reset media pipeline so the next cast starts clean
    videoEl.style.display = 'none';
    videoUrl = '';
    lastProgressSecond = -1;
  }

  // Periodic position report → phone seek slider (video-progress).
  videoEl.addEventListener('timeupdate', () => {
    const sec = Math.floor(videoEl.currentTime);
    if (sec === lastProgressSecond) return;
    lastProgressSecond = sec;
    sendToPhone('video-progress', {
      position: videoEl.currentTime || 0,
      duration: videoEl.duration || 0,
      playing: !videoEl.paused && !videoEl.ended
    });
  });
  videoEl.addEventListener('ended', () => sendToPhone('video-ended', {}));
  videoEl.addEventListener('error', () => {
    if (videoEl.style.display !== 'none' && videoUrl) {
      // MKV/AVI containers frequently fail on TV browsers (risk R10):
      // surface a friendly error instead of a black screen.
      sendToPhone('video-error', { code: videoEl.error ? videoEl.error.code : 0 });
    }
  });

  // ── Media events (phone → TV, pass-through of {event, data}) ──
  function handleMediaEvent(event, data) {
    data = data || {};
    switch (event) {
      case 'cast-video':
        showVideo(data.url || '');
        break;
      case 'video-control':
        if (data.action === 'pause') videoEl.pause();
        if (data.action === 'play') videoEl.play().catch(() => {});
        break;
      case 'video-seek':
        if (!isNaN(data.seconds)) videoEl.currentTime = data.seconds;
        break;
      case 'video-stop':
        hideVideo();
        break;
      case 'cast-youtube':
        if (typeof showYouTube === 'function') showYouTube(data.videoId || '');
        break;
      case 'yt-play':   if (yt) { yt.playVideo(); }  break;
      case 'yt-pause':  if (yt) { yt.pauseVideo(); } break;
      case 'yt-seek':   if (yt && !isNaN(data.seconds)) yt.seekTo(data.seconds, true); break;
      case 'yt-volume': if (yt) { yt.unMute(); yt.setVolume(data.value != null ? data.value : 100); } break;
      case 'yt-unmute': if (yt) { yt.unMute(); yt.setVolume(100); yt.playVideo(); } break;
    }
  }

  // ── YouTube (Feature 3, IFrame API) ──
  // The phone drives playback over the WebSocket: yt-play / yt-pause /
  // yt-seek / yt-volume / yt-unmute, while onStateChange reports yt-state
  // (playing | paused | ended | muted) so the controller reflects reality.
  // Videos that disable embedding surface as yt-error (risk R5) and the
  // TV never navigates away from the presenter page.
  let ytApiLoading = false;
  let ytPendingVideoId = '';
  let ytProgressTimer = null;
  let ytCurrentState = '';
  let yt = null;

  function loadYouTubeApi(onReady) {
    if (window.YT && window.YT.Player) { onReady(); return; }
    window.onYouTubeIframeAPIReady = () => onReady();
    if (ytApiLoading) return;
    ytApiLoading = true;
    const tag = document.createElement('script');
    tag.src = 'https://www.youtube.com/iframe_api';
    document.head.appendChild(tag);
  }

  function ytReport(state, extra) {
    if (state) ytCurrentState = state;
    sendToPhone('yt-state', Object.assign({
      state: ytCurrentState,
      position: yt ? (yt.getCurrentTime() || 0) : 0,
      duration: yt ? (yt.getDuration() || 0) : 0
    }, extra || {}));
  }

  function showYouTube(videoId) {
    if (!videoId) return;
    hideVideo();
    hideYouTube();
    document.getElementById('yt-container').style.display = 'block';
    loadYouTubeApi(() => {
      ytPendingVideoId = videoId;
      yt = new YT.Player('yt-player', {
        videoId: videoId,
        width: '100%',
        height: '100%',
        playerVars: { autoplay: 1, playsinline: 1, controls: 0, rel: 0 },
        events: {
          onReady: () => {
            yt.playVideo();
            // Some TV browsers block autoplay with sound (risk R6): if the
            // player refuses to start, begin muted and tell the phone.
            setTimeout(() => {
              if (yt && yt.getPlayerState() !== 1) {
                yt.mute();
                yt.playVideo();
                ytReport('muted');
                sendToPhone('video-muted', {});
              }
            }, 1500);
            if (ytProgressTimer) clearInterval(ytProgressTimer);
            ytProgressTimer = setInterval(() => {
              if (yt && yt.getPlayerState() === 1) ytReport('');
            }, 1000);
          },
          onStateChange: (e) => {
            const map = { 1: 'playing', 2: 'paused', 0: 'ended', 3: 'buffering', 5: 'cued' };
            ytReport(map[e.data] || '');
          },
          onError: (code) => {
            // 101/150: embedding disabled; 100: not found; 2/5: bad params.
            sendToPhone('yt-error', { reason: String(code) });
          }
        }
      });
    });
  }

  function hideYouTube() {
    if (ytProgressTimer) { clearInterval(ytProgressTimer); ytProgressTimer = null; }
    if (yt) { try { yt.destroy(); } catch (_) {} yt = null; }
    ytCurrentState = '';
    const c = document.getElementById('yt-container');
    if (c) {
      c.style.display = 'none';
      // Recreate the mount node: YT.Player replaces it with an iframe.
      c.innerHTML = '<div id="yt-player"></div>';
    }
  }

  // ── Mobile detection ──
  function isMobile() {
    return window.innerWidth <= 768 ||
           /Android|iPhone|iPad|iPod|webOS|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent);
  }

  // ── Animated background handler ──
  function setAnimatedBg(type) {
    document.querySelectorAll('.anim-bg').forEach(el => el.classList.remove('active'));
    currentAnimBg = type;
    if (type && type.startsWith('animated:')) {
      const animName = type.replace('animated:', '');
      const el = document.getElementById('anim-' + animName);
      if (el) el.classList.add('active');
    }
  }

  // ── Mobile nav update ──
  function updateMobileNav() {
    const nav = document.getElementById('mobile-nav');
    const navInfo = document.getElementById('nav-info');
    if (!isMobile() || state.type === 'idle' || state.type === 'logo' || state.type === 'welcome') {
      nav.classList.remove('visible');
      return;
    }

    nav.classList.add('visible');

    if (state.type === 'verse') {
      const c = state.content || {};
      const total = c.totalVerses || 1;
      const current = c.verseIndex !== undefined ? c.verseIndex + 1 : 1;
      navInfo.textContent = current + ' / ' + total;
    } else if (state.type === 'slide') {
      const c = state.content || {};
      const total = c.totalSlides || 1;
      const current = c.slideIndex !== undefined ? c.slideIndex + 1 : 1;
      navInfo.textContent = current + ' / ' + total;
    } else if (state.type === 'song') {
      const c = state.content || {};
      const current = (c.currentStanza || 0) + 1;
      const total = c.totalStanzas || (c.stanzas || []).length;
      navInfo.textContent = current + ' / ' + total;
    } else if (state.type === 'pdf') {
      navInfo.textContent = pdfPage + ' / ' + pdfTotalPages;
    } else if (state.type === 'pptx') {
      navInfo.textContent = 'PPTX';
    } else {
      navInfo.textContent = '';
    }
  }

  // ── WebSocket connect ──
  function connect() {
    clearTimeout(reconnectTimer);
    const wsUrl = 'ws://' + location.host + '/ws';
    ws = new WebSocket(wsUrl);

    ws.onopen = () => {
      setStatus(true);
      ws.send(JSON.stringify({ event: 'get-state' }));
    };
    ws.onclose = () => {
      setStatus(false);
      reconnectTimer = setTimeout(connect, 3000);
    };
    ws.onerror = () => { setStatus(false); };
    ws.onmessage = (e) => {
      try {
        const data = JSON.parse(e.data);
        // Media events (video / YouTube) arrive as raw {event, data}
        // pass-throughs; state broadcasts carry a `type` field.
        if (data && data.event) { handleMediaEvent(data.event, data.data); return; }
        if (data && data.type) { state = data; render(); }
      } catch(_) {}
    };
  }

  function setStatus(online) {
    document.getElementById('status-dot').className = online ? 'online' : '';
    document.getElementById('status-text').textContent = online ? 'Online' : 'Reconnecting...';
  }

  // ── Font sizing ──
  function fontSize(content, base) {
    const total = ((content?.textHi?.length||0) + (content?.textEn?.length||0)) || content?.text?.length || 0;
    const baseFs = Math.max(50, (base || 50));
    const scale = total > 500 ? 0.74 : total > 350 ? 0.84 : total > 200 ? 0.94 : 1.15;
    const mobileFactor = isMobile() ? 0.7 : 1;
    return Math.max(26, Math.round(baseFs * scale * mobileFactor));
  }

  // ── Mobile font sizing for songs ──
  function songFontSize(textLen, base) {
    const scale = textLen > 300 ? 0.55 : textLen > 200 ? 0.68 : textLen > 120 ? 0.82 : textLen > 60 ? 0.95 : 1.1;
    const mobileFactor = isMobile() ? 0.65 : 1;
    return Math.max(14, Math.round((base || 44) * scale * mobileFactor));
  }

  // ── Auto-fit: shrink rendered text until the stage stops overflowing ──
  // The count-based fontSize() estimate can still overflow for long verses;
  // this measures the real layout and steps the font down so the largest
  // readable size always fits the screen. Covers verse, song, slide and
  // welcome text alike.
  function fitStageText() {
    const stageEl = document.getElementById('stage');
    if (!stageEl) return;
    const targets = () => stageEl.querySelectorAll('.verse-hi, .verse-en, .slide-text, .slide-title, .welcome-message');
    if (!targets().length) return;
    let guard = 0;
    let shrank = false;
    while (stageEl.scrollHeight > stageEl.clientHeight && guard < 16) {
      let touched = false;
      targets().forEach(el => {
        const cur = parseFloat(getComputedStyle(el).fontSize);
        const next = Math.max(14, Math.round(cur * 0.9));
        if (next < cur) {
          el.style.transition = 'none';
          el.style.fontSize = next + 'px';
          touched = true;
        }
      });
      if (!touched) break;
      shrank = true;
      guard++;
    }
    if (shrank) {
      requestAnimationFrame(() => targets().forEach(el => { el.style.transition = ''; }));
    }
  }

  // ── PDF rendering ──
  async function loadPdf(url) {
    const docViewer = document.getElementById('doc-viewer');
    const docLoading = document.getElementById('doc-loading');
    const pdfCanvas = document.getElementById('pdf-canvas');
    const pptxIframe = document.getElementById('pptx-iframe');
    const pageInd = document.getElementById('page-indicator');

    docLoading.classList.add('active');

    try {
      pdfjsLib.GlobalWorkerOptions.workerSrc = 'https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174/pdf.worker.min.js';

      const fullUrl = url.startsWith('http') ? url : (location.protocol + '//' + location.host + url);
      const cacheBust = fullUrl + (fullUrl.includes('?') ? '&' : '?') + 't=' + Date.now();
      const loadingTask = pdfjsLib.getDocument({ url: cacheBust, useSystemFonts: true });
      pdfDoc = await loadingTask.promise;
      pdfTotalPages = pdfDoc.numPages;
      pdfPage = 1;
      currentPdfUrl = url;

      pdfCanvas.style.display = 'block';
      pptxIframe.style.display = 'none';
      docViewer.classList.add('active');
      pageInd.classList.add('active');

      await renderPdfPage(pdfPage);

      if (ws && ws.readyState === WebSocket.OPEN) {
        ws.send(JSON.stringify({ event: 'pdf-loaded', data: { totalPages: pdfTotalPages, currentPage: 1 } }));
      }

      docLoading.classList.remove('active');
      updateMobileNav();
    } catch (e) {
      console.error('[TV] PDF load error:', e);
      docLoading.classList.remove('active');
      pdfCanvas.style.display = 'none';
      pptxIframe.style.display = 'block';
      pptxIframe.src = url.startsWith('http') ? url : (location.protocol + '//' + location.host + url);
      docViewer.classList.add('active');
      pageInd.classList.add('active');
    }
  }

  async function renderPdfPage(num) {
    if (!pdfDoc || pdfRendering) return;
    pdfRendering = true;

    try {
      const page = await pdfDoc.getPage(num);
      const canvas = document.getElementById('pdf-canvas');
      const ctx = canvas.getContext('2d');

      const viewport = page.getViewport({ scale: 1 });
      const scaleX = window.innerWidth / viewport.width;
      const scaleY = window.innerHeight / viewport.height;
      const scale = Math.min(scaleX, scaleY);
      const scaledViewport = page.getViewport({ scale: scale * (window.devicePixelRatio || 1) });

      canvas.width = scaledViewport.width;
      canvas.height = scaledViewport.height;
      canvas.style.width = (scaledViewport.width / (window.devicePixelRatio || 1)) + 'px';
      canvas.style.height = (scaledViewport.height / (window.devicePixelRatio || 1)) + 'px';

      await page.render({ canvasContext: ctx, viewport: scaledViewport }).promise;

      const pageInd = document.getElementById('page-indicator');
      pageInd.textContent = num + ' / ' + pdfTotalPages;
      pageInd.classList.remove('peek');
      void pageInd.offsetWidth;
      pageInd.classList.add('peek');
    } catch (e) {
      console.error('[TV] PDF render error:', e);
    }

    pdfRendering = false;
  }

  // ── PPTX display ──
  function loadPptx(url) {
    const docViewer = document.getElementById('doc-viewer');
    const pdfCanvas = document.getElementById('pdf-canvas');
    const pptxIframe = document.getElementById('pptx-iframe');
    const pageInd = document.getElementById('page-indicator');

    pdfCanvas.style.display = 'none';
    pptxIframe.style.display = 'block';
    pptxIframe.src = url.startsWith('http') ? url : (location.protocol + '//' + location.host + url);
    docViewer.classList.add('active');
    pageInd.textContent = 'PPTX';
    pageInd.classList.add('active');
  }

  function closeDocViewer() {
    const docViewer = document.getElementById('doc-viewer');
    const pdfCanvas = document.getElementById('pdf-canvas');
    const pptxIframe = document.getElementById('pptx-iframe');
    const pageInd = document.getElementById('page-indicator');
    const docLoading = document.getElementById('doc-loading');

    docViewer.classList.remove('active');
    pageInd.classList.remove('active');
    docLoading.classList.remove('active');
    pdfCanvas.style.display = 'block';
    pptxIframe.style.display = 'none';
    pptxIframe.src = '';

    pdfDoc = null;
    pdfPage = 1;
    pdfTotalPages = 0;
    currentPdfUrl = '';
  }

  // ── Main render ──
  function render() {
    const stage = document.getElementById('stage');
    const bgLayer = document.getElementById('bg-layer');
    const mobile = isMobile();

    // One content at a time: any non-video state stops playback.
    if (state.type !== 'video' && state.type !== 'youtube') {
      hideVideo();
      hideYouTube();
    }

    // Handle background: animated or image
    const bgUrl = state.background?.url;
    if (bgUrl && bgUrl.startsWith('animated:')) {
      bgLayer.style.backgroundImage = '';
      bgLayer.style.opacity = '0';
      setAnimatedBg(bgUrl);
    } else if (bgUrl) {
      setAnimatedBg('');
      bgLayer.style.backgroundImage = 'url(' + bgUrl + ')';
      bgLayer.style.opacity = '0.45';
    } else if (state.background === null || state.type === 'idle') {
      setAnimatedBg('');
      bgLayer.style.backgroundImage = '';
      bgLayer.style.opacity = '0';
    }

    // Clean up any stray full-screen overlay image
    const oldOverlay = document.getElementById('fullscreen-overlay-img');
    if (oldOverlay) oldOverlay.remove();

    stage.innerHTML = '';

    if (state.type === 'idle') {
      closeDocViewer();
      hideVideo();
      hideYouTube();
      stage.innerHTML = `
        <div id="idle-screen" class="fade-in">
          <div class="idle-cross"></div>
          <p class="idle-label">BiblePresenter</p>
        </div>`;

    } else if (state.type === 'video') {
      closeDocViewer();
      hideYouTube();
      // Reconnecting TVs restore playback from the reported position.
      const c = state.content || {};
      showVideo(c.url || '', c.playing !== false);
      if (!isNaN(c.position) && Math.abs(videoEl.currentTime - c.position) > 2) {
        videoEl.currentTime = c.position;
      }

    } else if (state.type === 'youtube') {
      closeDocViewer();
      hideVideo();
      if (typeof showYouTube === 'function') {
        showYouTube((state.content || {}).videoId || '');
      }

    } else if (state.type === 'welcome') {
      closeDocViewer();
      hideVideo();
      hideYouTube();
      const c = state.content || {};
      const hasMessage = c.message && c.message.trim().length > 0;
      stage.innerHTML = `
        <div class="welcome-screen ${hasMessage ? 'has-message' : ''} fade-in">
          ${c.logo ? `<img src="${c.logo}" alt="Church Logo" />` : ''}
          ${hasMessage ? `<p class="welcome-message">${c.message}</p>` : ''}
        </div>`;

    } else if (state.type === 'verse') {
      closeDocViewer();
      const c = state.content || {};
      const fsPx = fontSize(c, state.fontSize);
      const hiPx  = fsPx + 'px';
      const enPx  = fsPx + 'px';
      const hasHi = !!c.textHi;
      const hasEn = !!c.textEn;
      const maxW = mobile ? '100%' : '1680px';
      const isDevanagari = (s) => /[\u0900-\u097F]/.test(s || '');
      const enStyle = isDevanagari(c.textEn) ? 'font-style:normal;' : 'font-style:italic;';

      stage.innerHTML = `
        <div class="verse-container fade-in" style="max-width:${maxW};width:100%">
          ${hasHi ? `<p class="verse-hi" style="font-size:${hiPx};margin-bottom:${hasEn?'12px':'20px'}">${c.textHi}</p>` : ''}
          ${hasHi && hasEn ? `<div class="ornament">&#10022;</div>` : ''}
          ${hasEn ? `<p class="verse-en" style="font-size:${enPx};${enStyle}margin-bottom:16px">${c.textEn}</p>` : ''}
          ${!hasHi && c.text ? `<p class="verse-hi" style="font-size:${hiPx};margin-bottom:16px">"${c.text}"</p>` : ''}
          <p class="verse-ref">${c.book || ''} ${c.chapter || ''}:${c.verse || ''}</p>
        </div>`;

    } else if (state.type === 'slide') {
      closeDocViewer();
      const c = state.content || {};

      if (c.image && c.showText === false) {
        const oldOverlay = document.getElementById('fullscreen-overlay-img');
        if (oldOverlay) oldOverlay.remove();
        const imgEl = document.createElement('img');
        imgEl.id = 'fullscreen-overlay-img';
        imgEl.src = c.image;
        imgEl.style.cssText = 'width:100%;height:100%;object-fit:contain;position:fixed;inset:0;z-index:40;background:#000;';
        document.body.appendChild(imgEl);
        updateMobileNav();
        return;
      }

      const fsPx  = Math.round((state.fontSize||40) * (mobile ? 0.8 : 1.15)) + 'px';
      const bodyPx = Math.round((state.fontSize||40) * (mobile ? 0.6 : 0.78)) + 'px';

      if (c.image) {
        if (mobile) {
          stage.innerHTML = `
            <div class="fade-in" style="display:flex;flex-direction:column;align-items:center;width:100%;gap:16px">
              <img src="${c.image}" style="max-height:40vh;object-fit:contain;border-radius:8px;border:1px solid rgba(255,255,255,0.08);width:100%"/>
              <div style="text-align:center;width:100%">
                ${c.subtitle ? `<p class="slide-subtitle">${c.subtitle}</p>` : ''}
                <p class="slide-title" style="font-size:${fsPx};margin-bottom:12px">${c.title||''}</p>
                <div style="width:40px;height:2px;background:var(--gold);margin:0 auto 12px;opacity:0.6"></div>
                <p class="slide-text" style="font-size:${bodyPx}">${c.text||''}</p>
              </div>
            </div>`;
        } else {
          stage.innerHTML = `
            <div class="fade-in" style="display:grid;grid-template-columns:1fr 1fr;gap:48px;align-items:center;width:100%;max-width:1400px">
              <img src="${c.image}" style="max-height:65vh;object-fit:contain;border-radius:12px;border:1px solid rgba(255,255,255,0.08)"/>
              <div style="text-align:left">
                ${c.subtitle ? `<p class="slide-subtitle">${c.subtitle}</p>` : ''}
                <p class="slide-title" style="font-size:${fsPx};margin-bottom:16px">${c.title||''}</p>
                <div style="width:40px;height:2px;background:var(--gold);margin-bottom:16px;opacity:0.6"></div>
                <p class="slide-text" style="font-size:${bodyPx}">${c.text||''}</p>
              </div>
            </div>`;
        }
      } else {
        const maxW = mobile ? '100%' : '1300px';
        stage.innerHTML = `
          <div class="slide-container fade-in" style="max-width:${maxW};width:100%">
            ${c.subtitle ? `<p class="slide-subtitle">${c.subtitle}</p>` : ''}
            <p class="slide-title" style="font-size:${fsPx};margin-bottom:24px">${c.title||''}</p>
            <div class="ornament">&#10022;</div>
            <p class="slide-text" style="font-size:${bodyPx};margin-top:8px">${c.text||''}</p>
          </div>`;
      }

    } else if (state.type === 'song') {
      closeDocViewer();
      const c = state.content || {};
      const stanzas = c.stanzas || [];
      const currentIdx = c.currentStanza || 0;
      const totalStanzas = c.totalStanzas || stanzas.length;
      const currentStanza = stanzas[currentIdx] || '';
      const stanzaText = currentStanza.replace(/\\n/g, '<br/>').replace(/\n/g, '<br/>');
      const textLen = currentStanza.length;
      const stanzaFs = songFontSize(textLen, state.fontSize) + 'px';
      const maxW = mobile ? '100%' : '1500px';

      // Song title is NEVER shown on TV — only lyrics and stanza counter
      stage.innerHTML = `
        <div class="verse-container fade-in" style="max-width:${maxW};width:100%">
          <p class="verse-hi" style="font-size:${stanzaFs};line-height:1.8;letter-spacing:0.01em;white-space:pre-line">${stanzaText}</p>
          <p class="song-stanza-counter">${currentIdx + 1} / ${totalStanzas}</p>
        </div>`;

    } else if (state.type === 'logo') {
      closeDocViewer();
      const c = state.content || {};
      stage.innerHTML = `
        <div class="logo-container fade-in">
          <div class="logo-glow"></div>
          <img src="${c.image || ''}" alt="Church Logo" />
        </div>`;

    } else if (state.type === 'pdf') {
      const c = state.content || {};
      const newUrl = c.url || '';
      const targetPage = c.currentPage || 1;

      if (newUrl && newUrl !== currentPdfUrl) {
        stage.innerHTML = '';
        closeDocViewer();
        loadPdf(newUrl);
      } else if (pdfDoc && pdfTotalPages > 0) {
        const clampedPage = Math.max(1, Math.min(targetPage, pdfTotalPages));
        if (clampedPage !== pdfPage) {
          pdfPage = clampedPage;
          renderPdfPage(pdfPage);
        }
        if (clampedPage !== targetPage && ws && ws.readyState === WebSocket.OPEN) {
          ws.send(JSON.stringify({ event: 'pdf-page', data: { page: clampedPage, totalPages: pdfTotalPages } }));
        }
      } else if (newUrl) {
        stage.innerHTML = '';
        loadPdf(newUrl);
      }

    } else if (state.type === 'pptx') {
      const c = state.content || {};
      const newUrl = c.url || '';

      if (newUrl) {
        stage.innerHTML = '';
        closeDocViewer();
        loadPptx(newUrl);
      }
    }

    // Auto-fit pass now, and once more after webfonts settle (Hindi serif
    // loads async and can re-wrap text taller than the first measure).
    fitStageText();
    setTimeout(fitStageText, 450);

    prevStateType = state.type;
    updateMobileNav();
  }

  // ── Keyboard navigation for PDF ──
  document.addEventListener('keydown', (e) => {
    if (state.type !== 'pdf' || !pdfDoc) return;

    if (e.key === 'ArrowRight' || e.key === 'ArrowDown' || e.key === 'PageDown') {
      if (pdfPage < pdfTotalPages) {
        pdfPage++;
        renderPdfPage(pdfPage);
        ws.send(JSON.stringify({ event: 'pdf-page', data: { page: pdfPage, totalPages: pdfTotalPages } }));
        updateMobileNav();
      }
    } else if (e.key === 'ArrowLeft' || e.key === 'ArrowUp' || e.key === 'PageUp') {
      if (pdfPage > 1) {
        pdfPage--;
        renderPdfPage(pdfPage);
        ws.send(JSON.stringify({ event: 'pdf-page', data: { page: pdfPage, totalPages: pdfTotalPages } }));
        updateMobileNav();
      }
    }
  });

  // ── Mobile navigation buttons ──
  document.getElementById('nav-prev').addEventListener('click', (e) => {
    e.preventDefault();
    handlePrev();
  });
  document.getElementById('nav-next').addEventListener('click', (e) => {
    e.preventDefault();
    handleNext();
  });

  function handlePrev() {
    if (state.type === 'pdf' && pdfDoc && pdfPage > 1) {
      pdfPage--;
      renderPdfPage(pdfPage);
      ws.send(JSON.stringify({ event: 'pdf-page', data: { page: pdfPage, totalPages: pdfTotalPages } }));
      updateMobileNav();
    }
  }

  function handleNext() {
    if (state.type === 'pdf' && pdfDoc && pdfPage < pdfTotalPages) {
      pdfPage++;
      renderPdfPage(pdfPage);
      ws.send(JSON.stringify({ event: 'pdf-page', data: { page: pdfPage, totalPages: pdfTotalPages } }));
      updateMobileNav();
    }
  }

  // ── Touch swipe navigation for mobile ──
  let touchStartX = 0;
  let touchStartY = 0;
  let touchStartTime = 0;

  document.addEventListener('touchstart', (e) => {
    touchStartX = e.changedTouches[0].screenX;
    touchStartY = e.changedTouches[0].screenY;
    touchStartTime = Date.now();
  }, { passive: true });

  document.addEventListener('touchend', (e) => {
    const touchEndX = e.changedTouches[0].screenX;
    const touchEndY = e.changedTouches[0].screenY;
    const diffX = touchStartX - touchEndX;
    const diffY = touchStartY - touchEndY;
    const elapsed = Date.now() - touchStartTime;

    if (Math.abs(diffX) > Math.abs(diffY) && Math.abs(diffX) > 50 && elapsed < 500) {
      if (diffX > 0) {
        handleNext();
      } else {
        handlePrev();
      }
    }
  }, { passive: true });

  // ── Window resize: re-render PDF + update mobile nav ──
  window.addEventListener('resize', () => {
    if (state.type === 'pdf' && pdfDoc) {
      renderPdfPage(pdfPage);
    }
    updateMobileNav();
  });

  connect();
  render();
</script>
</body>
</html>
''';
