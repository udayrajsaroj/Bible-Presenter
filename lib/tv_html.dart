const String tvHtmlContent = r'''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
  <title>BiblePresenter — TV</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link href="https://fonts.googleapis.com/css2?family=Cinzel:wght@400;700;900&family=Crimson+Pro:ital,wght@0,300;0,600;1,300;1,600&family=Tiro+Devanagari+Hindi:ital@0;1&display=swap" rel="stylesheet">
  <script src="https://cdn.tailwindcss.com"></script>
  <script src="https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174/pdf.min.js"></script>
  <style>
    :root {
      --gold: #c9a96e;
      --gold-light: #e8d5a3;
      --ink: #0a0a0f;
    }
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      background: var(--ink);
      font-family: 'Crimson Pro', Georgia, serif;
      overflow: hidden;
      width: 100vw; height: 100vh;
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

    .anim-aurora {
      background: linear-gradient(135deg, #0a0a2e 0%, #1a0a3e 25%, #0a2a4e 50%, #1a0a3e 75%, #0a0a2e 100%);
      background-size: 400% 400%;
      animation: aurora 12s ease infinite;
    }
    @keyframes aurora {
      0%   { background-position: 0% 50%; }
      50%  { background-position: 100% 50%; }
      100% { background-position: 0% 50%; }
    }
    .anim-aurora::after {
      content: '';
      position: absolute; inset: 0;
      background: radial-gradient(ellipse at 30% 50%, rgba(14,165,233,0.15) 0%, transparent 60%),
                  radial-gradient(ellipse at 70% 30%, rgba(99,102,241,0.12) 0%, transparent 50%),
                  radial-gradient(ellipse at 50% 80%, rgba(201,169,110,0.08) 0%, transparent 40%);
      animation: auroraGlow 8s ease infinite;
    }
    @keyframes auroraGlow {
      0%, 100% { opacity: 0.8; } 50% { opacity: 1.2; }
    }

    .anim-divine {
      background: radial-gradient(ellipse at 50% 50%, #1a1a0a 0%, #0a0a0f 100%);
    }
    .anim-divine::before {
      content: '';
      position: absolute; inset: -50%;
      background: conic-gradient(from 0deg at 50% 50%, transparent 0deg, rgba(201,169,110,0.06) 60deg, transparent 120deg, rgba(201,169,110,0.04) 180deg, transparent 240deg, rgba(201,169,110,0.06) 300deg, transparent 360deg);
      animation: divineRotate 30s linear infinite;
    }
    @keyframes divineRotate { to { transform: rotate(360deg); } }
    .anim-divine::after {
      content: '';
      position: absolute; inset: 0;
      background: radial-gradient(circle at 50% 50%, rgba(201,169,110,0.12) 0%, transparent 40%);
      animation: divinePulse 6s ease-in-out infinite;
    }
    @keyframes divinePulse {
      0%, 100% { opacity: 0.6; transform: scale(1); }
      50% { opacity: 1; transform: scale(1.1); }
    }

    .anim-sunset {
      background: linear-gradient(180deg, #1a0a0a 0%, #2a1a0a 30%, #1a0a1a 60%, #0a0a2a 100%);
      background-size: 100% 200%;
      animation: sunset 10s ease infinite;
    }
    @keyframes sunset {
      0%   { background-position: 50% 0%; }
      50%  { background-position: 50% 100%; }
      100% { background-position: 50% 0%; }
    }
    .anim-sunset::after {
      content: '';
      position: absolute; inset: 0;
      background: radial-gradient(ellipse at 50% 70%, rgba(220,120,50,0.1) 0%, transparent 50%),
                  radial-gradient(ellipse at 30% 40%, rgba(201,169,110,0.06) 0%, transparent 40%);
    }

    .anim-ocean {
      background: linear-gradient(160deg, #0a1a2a 0%, #0a2a3a 30%, #0a1a3a 60%, #0a0a2a 100%);
      background-size: 300% 300%;
      animation: ocean 15s ease infinite;
    }
    @keyframes ocean {
      0%   { background-position: 0% 0%; }
      50%  { background-position: 100% 100%; }
      100% { background-position: 0% 0%; }
    }
    .anim-ocean::after {
      content: '';
      position: absolute; inset: 0;
      background: radial-gradient(ellipse at 60% 60%, rgba(14,165,233,0.1) 0%, transparent 50%),
                  radial-gradient(ellipse at 30% 30%, rgba(56,189,248,0.06) 0%, transparent 40%);
    }

    .anim-fire {
      background: #0a0a0a;
    }
    .anim-fire::before {
      content: '';
      position: absolute; inset: 0;
      background: radial-gradient(ellipse at 50% 100%, rgba(220,80,20,0.12) 0%, transparent 50%),
                  radial-gradient(ellipse at 30% 90%, rgba(201,169,110,0.08) 0%, transparent 40%),
                  radial-gradient(ellipse at 70% 95%, rgba(180,60,10,0.06) 0%, transparent 35%);
      animation: fireFlicker 4s ease-in-out infinite alternate;
    }
    @keyframes fireFlicker {
      0%   { opacity: 0.7; transform: scaleY(1); }
      50%  { opacity: 1; transform: scaleY(1.05); }
      100% { opacity: 0.8; transform: scaleY(0.98); }
    }

    #stage {
      position: fixed; inset: 0; z-index: 10;
      display: flex; flex-direction: column;
      justify-content: center; align-items: center;
      text-align: center;
      padding: 3vh 3vw;
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
      font-family: 'Tiro Devanagari Hindi', 'Crimson Pro', serif;
      font-weight: 400;
      color: #ffffff;
      line-height: 1.5;
      text-shadow: 0 2px 40px rgba(0,0,0,0.9), 0 0 60px rgba(255,255,255,0.08);
      transition: font-size 0.4s ease;
      text-align: center;
    }
    .verse-en {
      font-family: 'Crimson Pro', serif;
      font-weight: 300;
      font-style: italic;
      color: #ffffff;
      line-height: 1.6;
      text-shadow: 0 2px 30px rgba(0,0,0,0.95);
      transition: font-size 0.4s ease;
      text-align: center;
    }
    .verse-ref {
      font-family: 'Cinzel', serif;
      font-weight: 700;
      color: var(--gold);
      letter-spacing: 0.35em;
      text-transform: uppercase;
      font-size: clamp(13px, 1.6vw, 22px);
      text-shadow: 0 0 30px rgba(201,169,110,0.4);
      text-align: center;
    }

    /* ── Song specific styles ── */
    .song-title {
      font-family: 'Cinzel', serif;
      font-weight: 700;
      color: var(--gold);
      letter-spacing: 0.2em;
      text-transform: uppercase;
      font-size: clamp(14px, 2vw, 24px);
      text-shadow: 0 0 30px rgba(201,169,110,0.3);
      text-align: center;
      margin-bottom: 16px;
      opacity: 0.7;
    }
    .song-stanza-counter {
      font-family: 'Cinzel', serif;
      font-size: 11px;
      letter-spacing: 0.3em;
      color: rgba(255,255,255,0.25);
      text-transform: uppercase;
      margin-top: 12px;
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

    /* ── Logo styles ── */
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
      padding: 2vh 2vw;
    }
    .logo-container img {
      width: 100%;
      height: 100%;
      object-fit: contain;
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

    #idle-screen {
      display: flex; flex-direction: column;
      align-items: center; gap: 24px;
    }
    .idle-cross {
      width: 64px; height: 64px;
      position: relative;
      opacity: 0.25;
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
    }

    #status-badge {
      position: fixed; top: 24px; right: 24px;
      z-index: 50;
      display: flex; align-items: center; gap: 8px;
      font-family: 'Cinzel', serif;
      font-size: 9px;
      letter-spacing: 0.25em;
      text-transform: uppercase;
      color: rgba(255,255,255,0.3);
      background: rgba(10,10,15,0.7);
      border: 1px solid rgba(255,255,255,0.06);
      backdrop-filter: blur(12px);
      padding: 6px 14px;
      border-radius: 100px;
    }
    #status-dot {
      width: 7px; height: 7px;
      border-radius: 50%;
      background: #ef4444;
      animation: pulse-dot 2s ease-in-out infinite;
    }
    #status-dot.online {
      background: #22c55e;
      box-shadow: 0 0 8px #22c55e;
      animation: none;
    }
    @keyframes pulse-dot {
      0%,100% { opacity:1; } 50% { opacity:0.3; }
    }

    #brand-badge {
      position: fixed; top: 24px; left: 24px;
      z-index: 50;
      font-family: 'Cinzel', serif;
      font-size: 9px;
      letter-spacing: 0.3em;
      text-transform: uppercase;
      color: rgba(201,169,110,0.35);
      display: flex; align-items: center; gap: 8px;
    }
    #brand-badge::before {
      content: '';
      width: 6px; height: 6px;
      border-radius: 50%;
      background: #22c55e;
      box-shadow: 0 0 6px #22c55e;
      animation: pulse-dot 3s ease-in-out infinite;
    }

    .fade-in {
      animation: fadeUp 0.7s cubic-bezier(0.22, 1, 0.36, 1) forwards;
    }
    @keyframes fadeUp {
      from { opacity: 0; transform: translateY(24px); }
      to   { opacity: 1; transform: translateY(0); }
    }

    /* ── PDF / PPTX Viewer ── */
    #doc-viewer {
      position: fixed; inset: 0; z-index: 40;
      display: none;
      background: #000;
      justify-content: center;
      align-items: center;
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
  <div id="page-indicator"></div>
  <div id="doc-loading">
    <div class="loading-spinner"></div>
    <p class="loading-text">Loading document...</p>
  </div>

<script>
  let ws, reconnectTimer;
  let state = { type: 'idle', content: null, fontSize: 44 };
  let currentAnimBg = '';

  // ── PDF state ──
  let pdfDoc = null;
  let pdfPage = 1;
  let pdfTotalPages = 0;
  let pdfRendering = false;
  let currentPdfUrl = '';

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
    const scale = total>350?0.5 : total>250?0.64 : total>160?0.78 : total>90?0.92 : 1;
    return Math.max(16, Math.round((base||44) * scale));
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

      document.getElementById('page-indicator').textContent = num + ' / ' + pdfTotalPages;
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

    // Handle background: animated or image
    const bgUrl = state.background?.url || '';
    if (bgUrl.startsWith('animated:')) {
      bgLayer.style.backgroundImage = '';
      bgLayer.style.opacity = '0';
      setAnimatedBg(bgUrl);
    } else if (bgUrl) {
      setAnimatedBg('');
      bgLayer.style.backgroundImage = 'url(' + bgUrl + ')';
      bgLayer.style.opacity = '0.45';
    } else {
      setAnimatedBg('');
      bgLayer.style.backgroundImage = '';
      bgLayer.style.opacity = '0';
    }

    stage.innerHTML = '';

    if (state.type === 'idle') {
      closeDocViewer();
      stage.innerHTML = `
        <div id="idle-screen" class="fade-in">
          <div class="idle-cross"></div>
          <p class="idle-label">BiblePresenter</p>
        </div>`;

    } else if (state.type === 'verse') {
      closeDocViewer();
      const c = state.content || {};
      const fsPx = fontSize(c, state.fontSize);
      const hiPx  = fsPx + 'px';
      const enPx  = fsPx + 'px';
      const hasHi = !!c.textHi;
      const hasEn = !!c.textEn;

      stage.innerHTML = `
        <div class="verse-container fade-in" style="max-width:1400px;width:100%">
          ${hasHi ? `<p class="verse-hi" style="font-size:${hiPx};margin-bottom:${hasEn?'12px':'20px'}">${c.textHi}</p>` : ''}<br/>
          ${hasEn ? `<p class="verse-en" style="font-size:${enPx};margin-bottom:16px">${c.textEn}</p>` : ''}
          ${!hasHi && c.text ? `<p class="verse-hi" style="font-size:${hiPx};margin-bottom:16px">"${c.text}"</p>` : ''}
          ${hasHi && hasEn ? `<div class="ornament">&#10022;</div>` : ''}
          <p class="verse-ref">${c.book || ''} ${c.chapter || ''}:${c.verse || ''}</p>
        </div>`;

    } else if (state.type === 'slide') {
      closeDocViewer();
      const c = state.content || {};

      if (c.image && c.showText === false) {
        const docViewer = document.getElementById('doc-viewer');
        const imgEl = document.createElement('img');
        imgEl.src = c.image;
        imgEl.style.cssText = 'width:100%;height:100%;object-fit:contain;position:fixed;inset:0;z-index:40;background:#000;';
        document.body.appendChild(imgEl);
        return;
      }

      const fsPx  = Math.round((state.fontSize||40) * 1.15) + 'px';
      const bodyPx = Math.round((state.fontSize||40) * 0.78) + 'px';

      if (c.image) {
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
      } else {
        stage.innerHTML = `
          <div class="slide-container fade-in" style="max-width:1300px;width:100%">
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
      const songTitle = c.title || '';
      const currentStanza = stanzas[currentIdx] || '';
      const stanzaText = currentStanza.replace(/\\n/g, '<br/>').replace(/\n/g, '<br/>');
      const textLen = currentStanza.length;
      const baseFs = state.fontSize || 44;
      const scale = textLen > 300 ? 0.55 : textLen > 200 ? 0.68 : textLen > 120 ? 0.82 : textLen > 60 ? 0.95 : 1.1;
      const stanzaFs = Math.max(18, Math.round(baseFs * scale)) + 'px';

      stage.innerHTML = `
        <div class="verse-container fade-in" style="max-width:1500px;width:100%">
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
        if (targetPage !== pdfPage && targetPage >= 1 && targetPage <= pdfTotalPages) {
          pdfPage = targetPage;
          renderPdfPage(pdfPage);
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
  }

  // ── Keyboard navigation for PDF ──
  document.addEventListener('keydown', (e) => {
    if (state.type !== 'pdf' || !pdfDoc) return;

    if (e.key === 'ArrowRight' || e.key === 'ArrowDown' || e.key === 'PageDown') {
      if (pdfPage < pdfTotalPages) {
        pdfPage++;
        renderPdfPage(pdfPage);
        ws.send(JSON.stringify({ event: 'pdf-page', data: { page: pdfPage } }));
      }
    } else if (e.key === 'ArrowLeft' || e.key === 'ArrowUp' || e.key === 'PageUp') {
      if (pdfPage > 1) {
        pdfPage--;
        renderPdfPage(pdfPage);
        ws.send(JSON.stringify({ event: 'pdf-page', data: { page: pdfPage } }));
      }
    }
  });

  // ── Window resize: re-render PDF ──
  window.addEventListener('resize', () => {
    if (state.type === 'pdf' && pdfDoc) {
      renderPdfPage(pdfPage);
    }
  });

  connect();
  render();
</script>
</body>
</html>
''';
