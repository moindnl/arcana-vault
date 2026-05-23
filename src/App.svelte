<script lang="ts">
  import { Zap, Droplet, ChevronDown, ChevronRight, ChevronLeft, X, Wheat, Check, RefreshCw, ExternalLink, Moon, Sun, SlidersHorizontal, Smartphone } from 'lucide-svelte';
  import { tweened } from 'svelte/motion';
  import { linear, cubicOut, cubicIn, quintOut } from 'svelte/easing';
  import { fly, fade } from 'svelte/transition';
  import { onMount, onDestroy, tick } from 'svelte';
  import { registerSW } from 'virtual:pwa-register';
  import { t, lang } from './i18n';
  import { Keyboard } from '@capacitor/keyboard';

  const VERSION = '1.0';

  let updateAvailable = false;
  let updateDismissed = false;
  let doUpdateSW: () => Promise<void> = async () => {};

  // Injected at build time by vite.config.js versionPlugin
  const BUILD_HASH = __BUILD_HASH__;

  // Skip SW registration in Capacitor (native app, no service worker)
  if (!(window as any).Capacitor) {
    const swUpdate = registerSW({
      async onNeedRefresh() {
        try {
          const res = await fetch(`/version.json?_=${Date.now()}`);
          if (!res.ok) { updateAvailable = true; return; }
          const data = await res.json();
          if (data.hash !== BUILD_HASH) {
            updateAvailable = true;
          } else {
            swUpdate(false);
          }
        } catch {
          updateAvailable = true;
        }
      },
      onOfflineReady() {},
    });
    doUpdateSW = swUpdate;
  }

  let showAboutSheet = false;
  let showSettingsSheet = false;
  let showHowToSheet = false;
  let settingsView: 'main' | 'products' = 'main';
  let settingsNavDir = 0;
  let aboutView: 'main' | 'math' = 'main';
  let aboutNavDir = 0;
  let howToSlide = 0;
  let _tourDir = 1; // 1 = forward, -1 = backward

  function tourNext() {
    if (howToSlide >= 3) { showHowToSheet = false; howToSlide = 0; return; }
    _tourDir = 1; howToSlide++;
  }
  function tourBack() {
    if (howToSlide <= 0) return;
    _tourDir = -1; howToSlide--;
  }

  let _tourSwipeStartX = 0;
  let _tourSwipeStartY = 0;
  function onTourSwipeStart(e: TouchEvent) {
    _tourSwipeStartX = e.touches[0].clientX;
    _tourSwipeStartY = e.touches[0].clientY;
  }
  function onTourSwipeEnd(e: TouchEvent) {
    const dx = e.changedTouches[0].clientX - _tourSwipeStartX;
    const dy = Math.abs(e.changedTouches[0].clientY - _tourSwipeStartY);
    if (Math.abs(dx) > 52 && Math.abs(dx) > dy * 1.5) {
      if (dx < 0) tourNext(); else tourBack();
    }
  }

  // Dark / light / system mode
  type Theme = 'light' | 'dark' | 'system';
  let theme: Theme = (localStorage.getItem('bp-theme') as Theme) || 'system';
  let isDark: boolean = false; // reflects actual rendered state (used for tempColor)
  let _sysMq: MediaQueryList | null = null;

  function _resolveAndApply(t: Theme) {
    const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
    const dark = t === 'dark' || (t === 'system' && prefersDark);
    document.documentElement.setAttribute('data-theme', dark ? 'dark' : 'light');
    isDark = dark;
  }
  function applyTheme(t: Theme) {
    localStorage.setItem('bp-theme', t);
    _resolveAndApply(t);
  }
  function _onSysChange(e: MediaQueryListEvent) {
    if (theme === 'system') { isDark = e.matches; document.documentElement.setAttribute('data-theme', e.matches ? 'dark' : 'light'); }
  }


  // Piecewise linear carb oxidation by IF (Jeukendrup 2004 / ACSM guidelines)
  function carbsFromIF(if_val: number): number {
    if (if_val <= 0)    return 0;
    if (if_val < 0.55)  return Math.round((if_val / 0.55) * 20);            // 0–20 g/h
    if (if_val < 0.75)  return Math.round(20 + (if_val - 0.55) / 0.20 * 20); // 20–40 g/h
    if (if_val < 0.90)  return Math.round(40 + (if_val - 0.75) / 0.15 * 20); // 40–60 g/h
    if (if_val < 1.05)  return Math.round(60 + (if_val - 0.90) / 0.15 * 30); // 60–90 g/h
    return Math.min(120, Math.round(90 + (if_val - 1.05) / 0.15 * 30));      // 90–120 g/h
  }

  const CARB_RANGES = {
    low:      { min: 30,  max: 45  },
    moderate: { min: 45,  max: 60  },
    high:     { min: 60,  max: 90  },
    extreme:  { min: 90,  max: 120 }
  } as const;

  const FLUID_RANGES = {
    low:      { min: 0.4, max: 0.5 },
    moderate: { min: 0.5, max: 0.7 },
    high:     { min: 0.7, max: 1.0 },
    extreme:  { min: 1.0, max: 1.2 }
  } as const;

  // Per-ride inputs (reset on Reset)
  let distance: number | undefined = undefined;
  let durationRaw = ''; // what user types — e.g. "1.30" or "1:30" or "1.5"
  let power: number | undefined = undefined;
  let temperature = 20; // °C — no heat bonus below 20°C; resets with ride

  // Parse "1:30", "1.30" (dot = minutes when 2+ digits), or "1.5" → decimal hours
  function parseDuration(raw: string): number {
    const s = raw.trim().replace(',', '.'); // normalize European comma separator
    if (!s) return 0;
    if (s.includes(':')) {
      const [hPart, mPart] = s.split(':');
      const h = parseFloat(hPart) || 0;
      const m = parseFloat(mPart) || 0;
      return Math.max(0, h + m / 60);
    }
    const dot = s.indexOf('.');
    if (dot !== -1) {
      const dec = s.slice(dot + 1);
      if (dec.length >= 2) {
        // "1.30" → 1h 30m
        const h = parseInt(s.slice(0, dot), 10) || 0;
        const m = Math.min(59, parseInt(dec.slice(0, 2), 10) || 0);
        return Math.max(0, h + m / 60);
      }
    }
    return Math.max(0, parseFloat(s) || 0);
  }

  // Display decimal hours as "1:30 h" in badges/labels
  function formatDuration(h: number): string {
    if (h <= 0) return '';
    const hrs = Math.floor(h);
    const mins = Math.round((h - hrs) * 60);
    return mins === 0 ? `${hrs} h` : `${hrs}:${String(mins).padStart(2, '0')} h`;
  }

  $: duration = parseDuration(durationRaw);

  // Rider profile (persists via localStorage — read synchronously so guide renders correctly on first paint)
  let _savedProfile: Record<string, any> = {};
  try { _savedProfile = JSON.parse(localStorage.getItem('bp-profile') || '{}'); } catch { /* ignore */ }
  let weight: number | undefined = _savedProfile.weight > 0 ? _savedProfile.weight : undefined;
  let ftp: number | undefined = _savedProfile.ftp > 0 ? _savedProfile.ftp : undefined;
  let imperial: boolean = typeof _savedProfile.imperial === 'boolean' ? _savedProfile.imperial : false;
  let sweatRate: 'light' | 'moderate' | 'heavy' = _savedProfile.sweatRate || 'moderate';

  const isCapacitor = !!(window as any).Capacitor;

  // UI state
  let onboardingStep: number = localStorage.getItem('bp-onboarding-done') ? -1 : 0;
  let disclaimerAccepted: boolean = !!localStorage.getItem('bp-disclaimer-accepted');
  let _onboardingStartTour = false;
  // Ride card swipe-to-reset
  let rideSwipeX = 0;
  let _rideSwipeStartX = 0;
  let _rideSwipeStartY = 0;
  let _rideSwipeLocked: boolean | null = null;

  function onRideSwipeStart(e: TouchEvent) {
    if ((e.target as HTMLElement).closest('input, button')) return;
    _rideSwipeStartX = e.touches[0].clientX;
    _rideSwipeStartY = e.touches[0].clientY;
    _rideSwipeLocked = null;
    if (rideSwipeX > 0) { rideSwipeX = 0; }
  }
  function onRideSwipeMove(e: TouchEvent) {
    if (_rideSwipeLocked === false) return;
    const dx = _rideSwipeStartX - e.touches[0].clientX;
    const dy = Math.abs(e.touches[0].clientY - _rideSwipeStartY);
    if (_rideSwipeLocked === null) {
      if (Math.abs(dx) < 6 && dy < 6) return;
      _rideSwipeLocked = Math.abs(dx) > dy;
      if (!_rideSwipeLocked) return;
    }
    rideSwipeX = Math.max(0, Math.min(92, dx));
  }
  function onRideSwipeEnd() {
    if (_rideSwipeLocked !== true) { _rideSwipeLocked = null; return; }
    _rideSwipeLocked = null;
    rideSwipeX = rideSwipeX >= 48 ? 80 : 0;
  }

  function finishOnboarding() {
    localStorage.setItem('bp-onboarding-done', '1');
    localStorage.setItem('bp-disclaimer-accepted', '1');
    disclaimerAccepted = true;
    _guideSeen = true;
    localStorage.setItem('bp-guide-seen', '1');
    onboardingStep = -1;
  }

  function acceptDisclaimer() {
    localStorage.setItem('bp-disclaimer-accepted', '1');
    disclaimerAccepted = true;
  }
  let neuralizer = false;        // easter egg F: neuralyzer flash
  let holdTimer: ReturnType<typeof setTimeout> | null = null;
  let totalsTab: 'summary' | 'pack' = 'summary';
  let tabCard: HTMLElement;
  let showSolidDropdown = false;
  function switchTab(tab: typeof totalsTab) {
    totalsTab = tab;
    setTimeout(() => {
      if (!tabCard) return;
      const y = tabCard.getBoundingClientRect().top + window.scrollY - 76; // 64px header + 12px gap
      window.scrollTo({ top: y, behavior: 'smooth' });
    }, 0);
  }
  function closeSettings() {
    showSettingsSheet = false;
    setTimeout(() => { settingsView = 'main'; settingsNavDir = 0; }, 400);
  }
  function closeAbout() {
    showAboutSheet = false;
    setTimeout(() => { aboutView = 'main'; aboutNavDir = 0; }, 400);
  }

  let checkedPack: Set<string> = new Set();
  function togglePack(id: string) {
    if (checkedPack.has(id)) checkedPack.delete(id); else checkedPack.add(id);
    checkedPack = checkedPack;
  }
  function resetPack() { checkedPack.clear(); checkedPack = checkedPack; }

  const SWEAT_LEVELS = [
    { value: 'light',    drops: 1 },
    { value: 'moderate', drops: 2 },
    { value: 'heavy',    drops: 3 },
  ] as const;

  // Bottle planner
  let bottleSize = 750; // ml

  // Nutrition products
  interface SolidProduct { id: string; label: string; carbs: number }
  const BASE_SOLID_PRODUCTS: SolidProduct[] = [
    { id: 'gel',  label: 'Gel',  carbs: 22 },
    { id: 'bar',  label: 'Bar',  carbs: 40 },
    { id: 'chew', label: 'Chew', carbs: 10 },
  ];

  const DRINK_PRODUCTS = [
    { id: 'water',    label: 'Water only',  carbsPer500: 0  },
    { id: 'mix',      label: 'Carb mix',    carbsPer500: 36 },
    { id: 'isotonic', label: 'Isotonic',    carbsPer500: 30 },
  ] as const;
  type DrinkId = typeof DRINK_PRODUCTS[number]['id'];

  let solidProduct: string = (() => {
    try { const s = localStorage.getItem('bp-solid-product'); if (s) return s; } catch {}
    return 'gel';
  })();
  // Custom products
  let customProducts: SolidProduct[] = (() => {
    try { return JSON.parse(localStorage.getItem('bp-custom-products') || '[]'); }
    catch { return []; }
  })();
  $: allSolidProducts = [...BASE_SOLID_PRODUCTS, ...customProducts];
  $: { try { localStorage.setItem('bp-solid-product', solidProduct); } catch {} }
  $: { try { localStorage.setItem('bp-drink-product', drinkProduct); } catch {} }

  let _newProductName = '';
  let _newProductCarbs: number | undefined = undefined;
  let _obProductName = '';
  let _obProductCarbs: number | undefined = undefined;

  function saveCustomProducts() {
    try { localStorage.setItem('bp-custom-products', JSON.stringify(customProducts)); } catch {}
    customProducts = customProducts;
  }
  function addCustomProduct(label: string, carbs: number) {
    if (!label.trim() || !carbs || carbs <= 0) return;
    customProducts = [...customProducts, { id: 'custom-' + Date.now(), label: label.trim(), carbs }];
    saveCustomProducts();
  }
  function removeCustomProduct(id: string) {
    if (solidProduct === id) solidProduct = 'gel';
    customProducts = customProducts.filter(p => p.id !== id);
    saveCustomProducts();
  }
  let drinkProduct: DrinkId = (() => {
    try {
      const s = localStorage.getItem('bp-drink-product') as DrinkId;
      if (s && DRINK_PRODUCTS.some(p => p.id === s)) return s;
    } catch {}
    return 'water';
  })();

  // PWA install bottom sheet (null = hidden)
  let installPlatform: 'ios' | 'android' | null = null;
  let installSheetTimer: ReturnType<typeof setTimeout> | null = null;
  let _installOS: 'ios' | 'android' | null = null; // set in onMount if eligible
  let _installFired = false;

  // Fire install prompt on first meaningful engagement (profile complete)
  $: if (_installOS && !_installFired && weight > 0 && ftp > 0) {
    _installFired = true;
    installSheetTimer = setTimeout(() => { installPlatform = _installOS!; }, 800);
  }
  let deferredInstallPrompt: any = null;
  const onBeforeInstallPrompt = (e: Event) => { e.preventDefault(); deferredInstallPrompt = e; };
  const onAppInstalled = () => { installPlatform = null; };
  let keyboardHeight = 0; // px — set by Capacitor keyboardWillShow, drives sheet padding
  let sheetDragStartY = 0;
  let sheetDragOffsetY = 0;
  let sheetIsDragging = false;
  let _sheetDismiss: (() => void) | null = null;

  function onSheetDragStart(e: TouchEvent, dismiss: () => void) {
    _sheetDismiss = dismiss;
    sheetDragStartY = e.touches[0].clientY;
    sheetDragOffsetY = 0;
    sheetIsDragging = true;
  }
  function onSheetDragMove(e: TouchEvent) {
    if (!sheetIsDragging) return;
    e.preventDefault();
    sheetDragOffsetY = Math.max(0, e.touches[0].clientY - sheetDragStartY);
  }
  function onSheetDragEnd() {
    if (!sheetIsDragging) return;
    sheetIsDragging = false;
    if (sheetDragOffsetY > 80) {
      sheetDragOffsetY = window.innerHeight;
      setTimeout(() => {
        _sheetDismiss?.();
        _sheetDismiss = null;
        sheetDragOffsetY = 0;
      }, 260);
    } else {
      sheetDragOffsetY = 0;
    }
  }

  onMount(() => {
    // Apply persisted theme and wire system-preference listener
    applyTheme(theme);
    _sysMq = window.matchMedia('(prefers-color-scheme: dark)');
    _sysMq.addEventListener('change', _onSysChange);

    // Easter egg: console greeting
    console.log('bonkproof — Cycling Nutrition Planner\n\nPsst. You\'re looking at the source.\nWhy are you not riding your bike?\n\nBuilt by Daniel Muschinski\nhttps://github.com/moindnl');

    const isMobile = window.innerWidth < 768;
    const standalone = window.matchMedia('(display-mode: standalone)').matches
      || (navigator as any).standalone === true;
    const isIos = /iphone|ipad|ipod/i.test(navigator.userAgent);
    const isAndroid = /android/i.test(navigator.userAgent);
    if (isMobile && !standalone && !isCapacitor && (isIos || isAndroid) && !localStorage.getItem('bp-install-dismissed')) {
      _installOS = isIos ? 'ios' : 'android'; // reactive block fires when profile complete
    }

    window.addEventListener('beforeinstallprompt', onBeforeInstallPrompt);
    window.addEventListener('appinstalled', onAppInstalled);
    _profileReady = true;

    // Keyboard: only in Capacitor context
    if (isCapacitor) {
      Keyboard.setAccessoryBarVisible({ isVisible: true }).catch(() => {});
      Keyboard.addListener('keyboardWillShow', (info) => {
        keyboardHeight = info.keyboardHeight;
        // focusInput already scrolls into view — no duplicate scroll here
      }).catch(() => {});
      Keyboard.addListener('keyboardWillHide', () => { keyboardHeight = 0; }).catch(() => {});
    }
  });

  onDestroy(() => {
    if (_sysMq) _sysMq.removeEventListener('change', _onSysChange);
    if (installSheetTimer) clearTimeout(installSheetTimer);
    if (_saveTimer) clearTimeout(_saveTimer);
    if (holdTimer) clearTimeout(holdTimer);
    window.removeEventListener('beforeinstallprompt', onBeforeInstallPrompt);
    window.removeEventListener('appinstalled', onAppInstalled);
    if (isCapacitor) Keyboard.removeAllListeners().catch(() => {});
    if (_shakeMotionSetup) window.removeEventListener('devicemotion', _onDeviceMotion);
  });

  function dismissInstallSheet() {
    installPlatform = null;
    // Do NOT reset sheetDragOffsetY/sheetIsDragging here — onSheetDragEnd owns
    // drag state cleanup. Resetting unconditionally would corrupt an active drag
    // on any other sheet (all sheets share the same drag state variables).
    localStorage.setItem('bp-install-dismissed', '1');
  }
  async function triggerInstall() {
    if (!deferredInstallPrompt) return;
    deferredInstallPrompt.prompt();
    const { outcome } = await deferredInstallPrompt.userChoice;
    deferredInstallPrompt = null;
    if (outcome === 'accepted') installPlatform = null;
  }
  // Only save after initial load — debounced to avoid writing on every keystroke
  let _profileReady = false;
  let _saveTimer: ReturnType<typeof setTimeout> | null = null;
  $: if (_profileReady) {
    if (_saveTimer) clearTimeout(_saveTimer);
    _saveTimer = setTimeout(() => {
      localStorage.setItem('bp-profile', JSON.stringify({ weight, ftp, imperial, sweatRate }));
    }, 600);
  }

  // Guide: hide permanently once both weight + ftp set; persisted so it never re-shows
  let _guideSeen = localStorage.getItem('bp-guide-seen') === '1';
  $: if (weight > 0 && ftp > 0 && !_guideSeen) { _guideSeen = true; localStorage.setItem('bp-guide-seen', '1'); }

  // Reset per-ride inputs only; profile persists
  function resetInputs() {
    distance = undefined; durationRaw = ''; power = undefined; temperature = 20;
    rideSwipeX = 0;
  }

  // Easter egg F: hold Reset 3s → neuralyzer flash
  function startHold() {
    holdTimer = setTimeout(() => {
      resetInputs();
      neuralizer = true;
      setTimeout(() => { neuralizer = false; }, 2900);
    }, 2000);
  }
  function cancelHold() {
    if (holdTimer) { clearTimeout(holdTimer); holdTimer = null; }
  }

  // Shake-to-reset
  let _shakeMotionSetup = false;
  let _motionRequested = false;
  let _shakeLast = { t: 0, x: 0, y: 0, z: 0 };

  function _onDeviceMotion(e: DeviceMotionEvent) {
    const acc = e.accelerationIncludingGravity;
    if (!acc) return;
    const now = Date.now();
    if (now - _shakeLast.t < 100) return;
    const dx = Math.abs((acc.x ?? 0) - _shakeLast.x);
    const dy = Math.abs((acc.y ?? 0) - _shakeLast.y);
    const dz = Math.abs((acc.z ?? 0) - _shakeLast.z);
    _shakeLast = { t: now, x: acc.x ?? 0, y: acc.y ?? 0, z: acc.z ?? 0 };
    if (dx + dy + dz > 28 && (distance !== undefined || durationRaw !== '' || power !== undefined)) {
      resetInputs();
    }
  }

  function _setupShake() {
    if (_shakeMotionSetup) return;
    _shakeMotionSetup = true;
    window.addEventListener('devicemotion', _onDeviceMotion);
  }

  async function _requestMotionPermission() {
    if (_motionRequested) return;
    _motionRequested = true;
    if (typeof (DeviceMotionEvent as any).requestPermission === 'function') {
      try {
        const perm = await (DeviceMotionEvent as any).requestPermission();
        if (perm === 'granted') _setupShake();
      } catch { /* denied or not available */ }
    } else {
      _setupShake(); // Android / non-gated
    }
  }

  // Imperial ↔ metric: convert displayed values on toggle
  function toggleImperial() {
    if (!imperial) {
      if (weight != null && weight > 0)   weight   = Math.round(weight * 2.20462);
      if (distance != null && distance > 0) distance = Math.round(distance * 0.621371 * 10) / 10;
    } else {
      if (weight != null && weight > 0)   weight   = Math.round(weight / 2.20462);
      if (distance != null && distance > 0) distance = Math.round(distance * 1.60934);
    }
    imperial = !imperial;
  }

  // Metric-normalised values used in all calculations
  $: weightKg   = imperial ? (weight ?? 0) / 2.20462 : (weight ?? 0);
  $: distanceKm = imperial ? (distance ?? 0) * 1.60934 : (distance ?? 0);
  $: speedKmh   = distanceKm > 0 && duration > 0 ? distanceKm / duration : 0;
  $: speedUnit  = imperial ? 'mph' : 'km/h';
  $: heatBonus  = temperature > 20 ? Math.round((temperature - 20) / 5 * 0.3 * 10) / 10 : 0;
  $: sweatMultiplier = sweatRate === 'light' ? 0.8 : sweatRate === 'heavy' ? 1.3 : 1.0;
  $: themeIdx = theme === 'light' ? 0 : theme === 'system' ? 1 : 2;
  $: sweatIdx = sweatRate === 'light' ? 0 : sweatRate === 'moderate' ? 1 : 2;
  $: tabIdx = totalsTab === 'summary' ? 0 : 1;
  $: solidIdx = allSolidProducts.findIndex(p => p.id === solidProduct);
  $: drinkIdx = DRINK_PRODUCTS.findIndex(p => p.id === drinkProduct);
  $: bottleSizeIdx = bottleSize === 500 ? 0 : bottleSize === 750 ? 1 : 2;

  // Temperature slider: track fill color neutral → #f73b20 above 20°C
  function tempColor(t: number, dark: boolean): string {
    if (t <= 20) return dark ? '#f4f4f5' : '#09090b';
    const p = Math.min((t - 20) / 25, 1);
    // Light: near-black → bright red. Dark: visible red → bright red (same endpoint).
    const r0 = dark ? 160 : 9;
    const g0 = dark ?  40 : 9;
    const b0 = dark ?  30 : 11;
    return `rgb(${Math.round(r0 + (247 - r0) * p)},${Math.round(g0 + (59 - g0) * p)},${Math.round(b0 + (32 - b0) * p)})`;
  }
  $: tempFillColor = tempColor(temperature, isDark);

  // Ping value display when crossing 20°C threshold
  let heatPing = false;
  async function triggerHeatPing() {
    heatPing = false;
    await tick();
    heatPing = true;
  }
  let _prevHeatActive = false;
  $: {
    const nowActive = temperature > 20;
    if (nowActive !== _prevHeatActive) {
      triggerHeatPing();
      _prevHeatActive = nowActive;
    }
  }


  // Power-derived zone
  $: intensityFactor = ftp > 0 && power > 0 ? power / ftp : 0;

  // 🥚 Easter egg B: Tadej mode at ≥500W
  $: tadejMode = power >= 500;


  $: zoneLabel = intensityFactor === 0 ? '' :
    tadejMode ? $t.zoneTadej :
    intensityFactor < 0.55 ? $t.zoneRecovery :
    intensityFactor < 0.75 ? $t.zoneEndurance :
    intensityFactor < 0.90 ? $t.zoneTempo :
    intensityFactor < 1.05 ? $t.zoneThreshold :
    $t.zoneVO2;

  $: zoneBadgeStyle = intensityFactor === 0 ? '' :
    tadejMode
      ? 'background:#f0c000;color:#111111;transition:background 0.35s ease,color 0.35s ease'
      : intensityFactor < 0.55
        ? 'background:var(--c-surface-soft);color:var(--c-on-surface-2);transition:background 0.35s ease,color 0.35s ease'
        : intensityFactor < 0.90
          ? 'background:var(--c-on-surface);color:var(--c-bg);transition:background 0.35s ease,color 0.35s ease'
          : 'background:#f73b20;color:var(--color-on-primary);transition:background 0.35s ease,color 0.35s ease';


  $: intensity = (intensityFactor === 0 ? 'moderate' :
    intensityFactor < 0.65 ? 'low' :
    intensityFactor <= 0.80 ? 'moderate' :
    intensityFactor < 0.95 ? 'high' :
    'extreme') as keyof typeof CARB_RANGES;

  // Fluid: weight-scaled + sweat rate + heat adjustment
  $: baseFluid = (FLUID_RANGES[intensity].min + FLUID_RANGES[intensity].max) / 2;
  $: fluidPerHour = weight > 0 && duration > 0 ? baseFluid * (weightKg / 70) * sweatMultiplier + heatBonus : 0;

  // Carbs: IF-based piecewise when power available, zone midpoint fallback
  $: carbsPerHour = !duration || !(weight > 0) ? 0 :
    intensityFactor > 0
      ? carbsFromIF(intensityFactor)
      : Math.round((CARB_RANGES[intensity].min + CARB_RANGES[intensity].max) / 2);

  // Energy: kJ mechanical ≈ kcal (cycling standard: 1W × 1h = 3.6 kJ ≈ 3.6 kcal)
  $: kcalPerHour = intensityFactor > 0 ? Math.round(power * 3.6) : 0;

  // Speed (display unit depends on imperial; animal thresholds always km/h)
  $: speedDisplay = Math.round(imperial ? speedKmh * 0.621371 : speedKmh);

  // Totals
  $: totalCarbs = Math.round(carbsPerHour * duration);
  $: totalFluid = fluidPerHour * duration;
  $: totalKcal  = Math.round(kcalPerHour * duration);

  // Animations
  const TWEEN = { duration: 400, easing: linear };
  const animatedCarbs       = tweened(carbsPerHour, TWEEN);
  const animatedFluid       = tweened(fluidPerHour, TWEEN);
  const animatedSpeed       = tweened(speedDisplay,  TWEEN);
  const animatedTotalCarbs  = tweened(totalCarbs,    TWEEN);
  const animatedTotalFluid  = tweened(totalFluid,    TWEEN);
  const animatedTotalKcal   = tweened(totalKcal,     TWEEN);
  const animatedKcalPerHour = tweened(kcalPerHour,   TWEEN);

  $: animatedCarbs.set(carbsPerHour);
  $: animatedFluid.set(fluidPerHour);
  $: animatedSpeed.set(speedDisplay);
  $: animatedTotalCarbs.set(totalCarbs);
  $: animatedTotalFluid.set(totalFluid);
  $: animatedTotalKcal.set(totalKcal);
  $: animatedKcalPerHour.set(kcalPerHour);

  const SPEED_LEVELS = [
    { minKmh: 0,   maxKmh: 10,  key: 'turtle',      tKey: 'turtlePace',        wikiSlug: 'Turtle',           wikiSlugDe: 'Landschildkröten' },
    { minKmh: 10,  maxKmh: 15,  key: 'penguin',     tKey: 'penguinCruise',     wikiSlug: 'Penguin',          wikiSlugDe: 'Pinguine' },
    { minKmh: 15,  maxKmh: 20,  key: 'gazelle',     tKey: 'gazellePace',       wikiSlug: 'Gazelle',          wikiSlugDe: 'Gazellen' },
    { minKmh: 20,  maxKmh: 25,  key: 'cheetah',     tKey: 'cheetahChase',      wikiSlug: 'Cheetah',          wikiSlugDe: 'Gepard' },
    { minKmh: 25,  maxKmh: 30,  key: 'falcon',      tKey: 'falconFlight',      wikiSlug: 'Falcon',           wikiSlugDe: 'Falken' },
    { minKmh: 30,  maxKmh: 40,  key: 'peregrine',   tKey: 'peregrineSpeed',    wikiSlug: 'Peregrine_falcon', wikiSlugDe: 'Wanderfalke' },
    { minKmh: 40,  maxKmh: 55,  key: 'greyhound',   tKey: 'greyhoundSprint',   wikiSlug: 'Greyhound',        wikiSlugDe: 'Greyhound' },
    { minKmh: 55,  maxKmh: 75,  key: 'downhill',    tKey: 'downhillRecord',    wikiSlug: '%C3%89ric_Barone', wikiSlugDe: '%C3%89ric_Barone' },
    { minKmh: 75,  maxKmh: 100, key: 'motorcycle',  tKey: 'motorcycleTerritory', wikiSlug: 'Motorcycle',     wikiSlugDe: 'Motorrad' },
    { minKmh: 100, maxKmh: Infinity, key: 'ambulance', tKey: 'callAmbulance',  wikiSlug: 'Ambulance',        wikiSlugDe: 'Krankenwagen' },
  ] as const;

  $: speedLevel = speedKmh === 0 ? null :
    SPEED_LEVELS.find(s => speedKmh < s.maxKmh) ?? SPEED_LEVELS[SPEED_LEVELS.length - 1];

  $: speedSloganText = speedLevel ? ($t[speedLevel.tKey] as string) : '';
  $: speedSloganUrl  = speedLevel ? `https://${$lang === 'de' ? 'de' : 'en'}.wikipedia.org/wiki/${$lang === 'de' ? speedLevel.wikiSlugDe : speedLevel.wikiSlug}` : '';

  $: multiCarbNote = intensityFactor >= 0.90;

  // Active products
  $: activeSolid = allSolidProducts.find(p => p.id === solidProduct) ?? BASE_SOLID_PRODUCTS[0];
  $: activeDrink = DRINK_PRODUCTS.find(p => p.id === drinkProduct)!;
  $: solidLabel = activeSolid.label.toLowerCase();

  // Bottle planner
  $: bottleCount        = weight > 0 && duration > 0 && totalFluid > 0 ? Math.ceil(totalFluid * 1000 / bottleSize) : 0;
  $: mlPerBottle        = bottleCount > 0 ? Math.round(totalFluid * 1000 / bottleCount) : 0;
  $: drinkCarbsPerHour  = fluidPerHour > 0 ? Math.round(activeDrink.carbsPer500 * (fluidPerHour * 1000 / 500)) : 0;
  $: drinkCarbsPerBottle = bottleCount > 0 ? Math.round(activeDrink.carbsPer500 * mlPerBottle / 500) : 0;

  // Solid food covers carbs not met by drink
  $: solidCarbsPerHour = Math.max(0, carbsPerHour - drinkCarbsPerHour);
  $: carbsPerBottle    = bottleCount > 0 ? Math.round((totalCarbs - drinkCarbsPerHour * duration) / bottleCount) : 0;
  $: totalSolidUnits = duration > 0 && activeSolid.carbs > 0 ? Math.ceil(solidCarbsPerHour * duration / activeSolid.carbs) : 0;

  $: heatWarning = temperature >= 28; // isolated so packItems doesn't recompute on every slider tick

  $: packItems = (() => {
    if (!duration || !weight) return [] as { id: string; label: string }[];
    const items: { id: string; label: string }[] = [];
    if (totalSolidUnits > 0) {
      const withEmergency = duration >= 2;
      const count = withEmergency ? totalSolidUnits + 1 : totalSolidUnits;
      const suffix = withEmergency ? $t.packItemEmergency : '';
      items.push({ id: 'fuel', label: $t.packItemSolid(count, solidLabel, activeSolid.carbs, suffix) });
    }
    if (bottleCount > 0)
      items.push({ id: 'bottles', label: $t.packItemBottle(bottleCount, bottleSize) });
    if (drinkProduct !== 'water' && bottleCount > 0)
      items.push({ id: 'carbdrink', label: $t.packItemCarbDrink(activeDrink.label, bottleCount) });
    if (heatWarning)
      items.push({ id: 'electrolytes', label: $t.packItemElectrolytes });
    if (duration >= 3)
      items.push({ id: 'cash', label: $t.packItemCash });
    items.push({ id: 'computer', label: $t.packItemComputer });
    items.push({ id: 'phone', label: $t.packItemPhone });
    return items;
  })();

  // Prune checked state for items that no longer exist
  $: {
    if (checkedPack.size > 0) {
      const validIds = new Set(packItems.map(i => i.id));
      let pruned = false;
      checkedPack.forEach(id => { if (!validIds.has(id)) { checkedPack.delete(id); pruned = true; } });
      if (pruned) checkedPack = checkedPack;
    }
  }

  // Fueling schedule: 20-min intake slots (solid food only)
  $: fuelingEvents = (() => {
    if (!duration || !(weight > 0)) return [] as { time: string; carbs: number; units: number }[];
    const events: { time: string; carbs: number; units: number }[] = [];
    const totalMins = Math.round(duration * 60);
    const carbsPerSlot = Math.round(solidCarbsPerHour / 3);
    const units = carbsPerSlot > 0 ? Math.max(0, Math.round(carbsPerSlot / activeSolid.carbs)) : 0;
    const actualCarbs = units * activeSolid.carbs; // actual carbs delivered (self-consistent with unit count)
    for (let t = 20; t <= totalMins; t += 20) {
      const h = Math.floor(t / 60);
      const m = t % 60;
      events.push({ time: `${h}:${String(m).padStart(2, '0')}`, carbs: actualCarbs, units });
    }
    return events;
  })();

  $: allSlotsIdentical = fuelingEvents.length > 0 &&
    fuelingEvents.every(e => e.carbs === fuelingEvents[0].carbs && e.units === fuelingEvents[0].units);

  // Scroll input into view after keyboard appears (mobile)
  function focusInput(e: FocusEvent) {
    const el = e.target as HTMLInputElement;
    el.select();
    setTimeout(() => el.scrollIntoView({ behavior: 'smooth', block: 'center' }), 180);
  }

  // Dismiss keyboard on Enter / Return key
  function blurOnEnter(e: KeyboardEvent) {
    if (e.key === 'Enter') {
      (e.target as HTMLElement).blur();
      Keyboard.hide().catch(() => {});
    }
  }

  // Dismiss keyboard on tap outside any input; request motion permission on first touch
  function onWindowTouchStart(e: TouchEvent) {
    if (!(e.target as HTMLElement).closest('input, textarea')) {
      (document.activeElement as HTMLElement)?.blur();
      Keyboard.hide().catch(() => {});
    }
    if (isCapacitor && !_motionRequested) _requestMotionPermission();
  }


  const HOW_TO_STEPS = [
    { n: '1', tTitle: 'step1Title', tBody: 'step1Body' },
    { n: '2', tTitle: 'step2Title', tBody: 'step2Body' },
    { n: '3', tTitle: 'step3Title', tBody: 'step3Body' },
  ] as const;


</script>

<svelte:window
  on:click={() => { showSolidDropdown = false; }}
  on:touchstart={onWindowTouchStart}
/>

<main class="min-h-screen">

  <!-- Update toast — bottom bar, neutral, dismissible -->
  {#if updateAvailable && !updateDismissed}
    <div class="fixed bottom-0 left-0 right-0 z-[1000] flex justify-center pointer-events-none"
      style="padding:0 16px max(calc(env(safe-area-inset-bottom,0px) + 16px),20px);"
      transition:fly={{ y: 80, duration: 320, easing: cubicOut }}>
      <div class="inline-flex items-center pointer-events-auto"
        style="border-radius:999px;background:var(--c-nav-bg);backdrop-filter:blur(20px) saturate(180%);-webkit-backdrop-filter:blur(20px) saturate(180%);border:0.5px solid var(--c-nav-border);box-shadow:0 4px 24px rgba(0,0,0,0.14);">
        <button on:click={() => doUpdateSW()}
          class="inline-flex items-center gap-sm active:scale-95 transition-transform"
          style="padding:11px 14px 11px 16px;background:transparent;border:none;cursor:pointer;border-radius:999px 0 0 999px;"
          aria-label={$t.updateAvailable}>
          <RefreshCw class="w-4 h-4 flex-shrink-0" style="color:var(--c-on-surface-2);" />
          <span class="text-body-strong" style="color:var(--c-on-surface);">{$t.updateAvailable}</span>
        </button>
        <div style="width:0.5px;height:20px;background:var(--c-nav-border);flex-shrink:0;"></div>
        <button on:click={() => updateDismissed = true}
          class="inline-flex items-center justify-center active:scale-95 transition-transform"
          style="padding:11px 14px;background:transparent;border:none;cursor:pointer;border-radius:0 999px 999px 0;"
          aria-label="Dismiss">
          <X class="w-4 h-4" style="color:var(--c-on-surface-2);" />
        </button>
      </div>
    </div>
  {/if}

  <!-- App Header — iOS UINavigationBar style -->
  <header style="position:sticky;top:0;z-index:995;background:var(--c-nav-bg);backdrop-filter:blur(20px) saturate(180%);-webkit-backdrop-filter:blur(20px) saturate(180%);border-bottom:0.5px solid var(--c-nav-border);padding-top:env(safe-area-inset-top,0px);">
    <div style="height:44px;max-width:640px;margin:0 auto;padding:0 4px;display:flex;align-items:center;justify-content:space-between;">
      <!-- Left: logo + wordmark → opens About sheet -->
      <button class="flex items-center gap-sm" style="height:44px;padding:0 12px;background:transparent;border:none;cursor:pointer;flex-shrink:0;" on:click={() => showAboutSheet = true} aria-label="About bonkproof!">
        <img src="/favicon.svg" alt="" class="icon-anim" style="width:28px;height:28px;display:block;flex-shrink:0;border-radius:20%;" />
        <h1 style="margin:0;font-size:17px;font-weight:700;letter-spacing:-0.02em;line-height:1;"><span class="bonk-nudge" style="color:var(--c-on-surface);font-style:italic;font-size:17px;font-weight:700;vertical-align:baseline;">bonk</span><span class="proof-crash" style="color:#f73b20;font-size:17px;font-weight:700;vertical-align:baseline;">proof!</span></h1>
      </button>
      <!-- Right: settings icon -->
      <button
        on:click={() => showSettingsSheet = true}
        style="width:44px;height:44px;display:flex;align-items:center;justify-content:center;background:transparent;border:none;cursor:pointer;flex-shrink:0;"
        aria-label="Settings">
        <SlidersHorizontal class="w-5 h-5" style="color:var(--c-on-surface);" />
      </button>
    </div>
  </header>


  <div class="max-w-6xl mx-auto p-sm md:p-md lg:p-lg" style="padding-top:12px;">

    <!-- 3-step how-to — shown on first visit or on demand -->
    {#if !_guideSeen}
    <div transition:fade={{ duration: 200 }} class="mb-lg md:mb-section card-enter card-enter-1">
      <!-- Mobile: horizontal swipe cards -->
      <div class="flex md:hidden overflow-x-auto snap-x snap-mandatory gap-sm pb-sm -mx-sm px-sm" style="scrollbar-width:none;-webkit-overflow-scrolling:touch;" tabindex="0" role="region" aria-label="Result cards">
        {#each HOW_TO_STEPS as step, i}
          <div class="snap-center shrink-0 w-[78%] overflow-hidden shimmer-once flex" style="background:var(--c-surface-soft);border-radius:12px;--shimmer-delay:{0.5 + i * 0.1}s"
            in:fly={{ y: 18, duration: 320, delay: 80 + i * 70, easing: cubicOut }}>
            <div class="flex items-center justify-center flex-shrink-0" style="background:var(--c-seg-active);min-width:56px;padding:0 18px 0 14px;clip-path:polygon(0 0, 100% 0, calc(100% - 16px) 100%, 0 100%);">
              <span class="text-lg font-bold" style="color:var(--c-seg-active-text);">{step.n}</span>
            </div>
            <div class="p-lg space-y-xs">
              <h2 class="text-body-strong font-bold text-[--c-on-surface]">{$t[step.tTitle]}</h2>
              <p class="text-caption-md text-[--c-on-surface-3]">{$t[step.tBody]}</p>
            </div>
          </div>
        {/each}
      </div>
      <!-- Desktop: 3-column grid -->
      <div class="hidden md:grid grid-cols-3 gap-lg overflow-hidden" style="background:var(--c-surface-soft);border-radius:12px;">
        {#each HOW_TO_STEPS as step, i}
          <div class="flex flex-col"
            in:fly={{ y: 18, duration: 320, delay: 80 + i * 70, easing: cubicOut }}>
            <div class="flex items-center justify-center py-md" style="background:var(--c-seg-active);">
              <span class="text-lg font-bold" style="color:var(--c-seg-active-text);">{step.n}</span>
            </div>
            <div class="p-lg space-y-xs flex-1">
              <h2 class="text-body-strong font-bold text-[--c-on-surface]">{$t[step.tTitle]}</h2>
              <p class="text-caption-md text-[--c-on-surface-3]">{$t[step.tBody]}</p>
            </div>
          </div>
        {/each}
      </div>
    </div>
    {/if}

    <!-- Ride card — always open, swipe left to reveal reset -->
    <div class="mb-lg card-enter card-enter-2"
      style="position:relative;border-radius:16px;box-shadow:var(--c-shadow-card);overflow:hidden;">

      <!-- Swipe-to-reset action zone (revealed behind card on left-swipe) -->
      {#if duration > 0 || distance > 0 || power > 0}
        <div style="position:absolute;right:0;top:0;bottom:0;width:80px;background:#f73b20;display:flex;flex-direction:column;align-items:center;justify-content:center;">
          <button
            on:click={resetInputs}
            style="display:flex;flex-direction:column;align-items:center;gap:4px;background:transparent;border:none;cursor:pointer;padding:16px 8px;min-height:64px;"
            aria-label={$t.resetRide}>
            <RefreshCw class="w-5 h-5" style="color:#ffffff;" />
            <span style="color:#ffffff;font-size:11px;font-weight:600;">{$t.reset}</span>
          </button>
        </div>
      {/if}

      <!-- Sliding card surface -->
      <div style="background:var(--c-surface);border-radius:16px;transform:translateX(-{rideSwipeX}px);transition:{_rideSwipeLocked === true ? 'none' : 'transform 0.3s cubic-bezier(0.35,0,0.25,1)'};"
        on:touchstart={onRideSwipeStart}
        on:touchmove={onRideSwipeMove}
        on:touchend={onRideSwipeEnd}
        on:touchcancel={onRideSwipeEnd}>

        <!-- Card header -->
        <div class="flex items-center justify-between p-lg">
          <span style="font-size:17px;font-weight:400;color:var(--c-on-surface);">{$t.rideLabel}</span>
          {#if duration > 0 || distance > 0 || power > 0}
            <button
              on:click|stopPropagation={resetInputs}
              on:mousedown={startHold} on:mouseup={cancelHold} on:mouseleave={cancelHold}
              on:touchstart|preventDefault={startHold}
              on:touchend|stopPropagation={(e) => { if (holdTimer) { cancelHold(); resetInputs(); } else { cancelHold(); } }}
              on:touchcancel={cancelHold}
              on:contextmenu|preventDefault
              class="flex items-center justify-center flex-shrink-0"
              style="width:44px;height:44px;border-radius:50%;background:transparent;border:none;cursor:pointer;touch-action:manipulation;user-select:none;-webkit-user-select:none;"
              aria-label="Reset ride inputs">
              <span style="width:28px;height:28px;border-radius:50%;background:var(--c-surface-soft);display:flex;align-items:center;justify-content:center;pointer-events:none;"><X class="w-3.5 h-3.5 text-[--c-on-surface]" /></span>
            </button>
          {/if}
        </div>

        <!-- Always-visible form fields -->
        <div class="px-lg" style="padding-bottom:24px;">

          <!-- Distance -->
          <div class="flex items-center justify-between py-sm">
            <label for="distance" class="text-caption-md font-bold text-[--c-on-surface]">
              {$t.distance} <span class="text-caption-sm text-[--c-on-surface-2] font-normal">{$t.distanceOptional}</span>
            </label>
            <div class="flex items-center gap-xs">
              <input id="distance" type="number" inputmode="numeric" bind:value={distance} min="1" max="500" step="1" placeholder="0"
                class="w-24 text-right text-body-strong text-[--c-on-surface] focus:outline-none"
                style="height:44px;border-radius:14px;padding:0 14px;background:var(--c-surface-input);"
                enterkeyhint="next"
                on:focus={focusInput} on:keydown={blurOnEnter} />
              <span class="text-caption-sm text-[--c-on-surface-2] w-5">{imperial ? 'mi' : 'km'}</span>
            </div>
          </div>

          <!-- Duration -->
          <div class="flex items-center justify-between py-sm row-sep">
            <div>
              <label for="duration" class="text-caption-md font-bold text-[--c-on-surface] block">{$t.durationLabel}</label>
              <p class="text-utility-xs text-[--c-on-surface-2] mt-xxs">{$t.durationHint}</p>
            </div>
            <div class="flex items-center gap-xs">
              <input id="duration" type="text" inputmode="decimal" bind:value={durationRaw}
                placeholder="1:30"
                class="w-24 text-right text-body-strong text-[--c-on-surface] focus:outline-none"
                style="height:44px;border-radius:14px;padding:0 14px;background:var(--c-surface-input);"
                enterkeyhint="next"
                on:focus={focusInput} on:keydown={blurOnEnter} />
              <span class="text-caption-sm text-[--c-on-surface-2] w-5">h</span>
            </div>
          </div>

          <!-- Power -->
          <div class="flex items-center justify-between py-sm row-sep">
            <div>
              <label for="power" class="text-caption-md font-bold text-[--c-on-surface] block">{$t.ridePower}</label>
              <span class="text-caption-sm text-[--c-on-surface-2]">{$t.ridePowerSub}</span>
            </div>
            <div class="flex items-center gap-xs">
              <input id="power" type="number" inputmode="numeric" bind:value={power} min="0" max="600" step="1" placeholder="200"
                class="w-24 text-right text-body-strong text-[--c-on-surface] focus:outline-none"
                style="height:44px;border-radius:14px;padding:0 14px;background:var(--c-surface-input);"
                enterkeyhint="done"
                on:focus={focusInput} on:keydown={blurOnEnter} />
              <span class="text-caption-sm text-[--c-on-surface-2] w-5">W</span>
            </div>
          </div>

          <!-- Zone (derived) -->
          <div class="flex items-center justify-between py-md row-sep">
            <span class="text-caption-md font-bold text-[--c-on-surface]">{$t.zoneLabel}</span>
            <div class="flex items-center">
              {#if intensityFactor > 0 && zoneLabel}
                <span class="badge" style={zoneBadgeStyle}>{zoneLabel} · {Math.round(intensityFactor * 100)}%</span>
              {:else if !(ftp > 0)}
                <button class="text-caption-sm flex items-center gap-xxs text-[--c-on-surface-2]"
                  on:click={() => { showSettingsSheet = true; }}>
                  {$t.setFtpFirst} <ChevronRight class="w-3 h-3" />
                </button>
              {:else}
                <span class="text-caption-sm text-[--c-on-surface-2]">{$t.enterPower}</span>
              {/if}
            </div>
          </div>

          <!-- Temperature -->
          <div class="py-md row-sep">
            <div class="flex items-center justify-between mb-sm">
              <label for="temperature" class="text-caption-md font-bold text-[--c-on-surface]">{$t.temperature}</label>
              <!-- °C intentional — heat formula is Celsius-based regardless of unit preference -->
              <span class="text-caption-md font-bold {heatPing ? 'heat-ping' : ''}"
                on:animationend={() => heatPing = false}
                style="color:{tempFillColor};">{temperature}°C</span>
            </div>
            <input id="temperature" type="range" bind:value={temperature} min="0" max="45" step="1"
              class="temp-slider w-full"
              style="--fill:{(temperature / 45 * 100).toFixed(1)}%;--temp-color:{tempFillColor}" />
            <p class="text-caption-sm mt-md {heatBonus > 0 ? 'text-[--color-accent]' : 'text-[--c-on-surface-2]'}">
              {heatBonus > 0 ? $t.heatActive(heatBonus.toFixed(1)) : $t.heatInactive}
            </p>
          </div>

        </div>
      </div>
    </div><!-- /Ride card -->

    {#if duration > 0 && (weight > 0)}

    <!-- Results Row 1: Carbs + Fluids (primary output) -->
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-lg mb-lg card-enter card-enter-3">

      <!-- Carbs card -->
      <div class="p-lg" style="background:var(--c-surface);border-radius:16px;box-shadow:var(--c-shadow-card);">
        <div class="flex items-start gap-md mb-lg">
          <div class="w-12 h-12 flex items-center justify-center flex-shrink-0" style="background:var(--c-surface-soft);border-radius:14px;">
            <Wheat class="w-7 h-7 text-[--c-on-surface]" />
          </div>
          <div class="min-w-0">
            <h2 class="text-heading-lg font-bold text-[--c-on-surface]">{$t.carbohydrates}</h2>
            <p class="text-caption-sm text-[--c-on-surface-2]">{$t.carbsSub}</p>
          </div>
        </div>
        <div class="mb-sm">
          <div class="flex items-baseline gap-sm" aria-live="polite" aria-atomic="true">
            {#key carbsPerHour}
              <span class="text-7xl md:text-8xl font-extra-bold {carbsPerHour > 0 ? 'num-flash' : ''}" style="color:{carbsPerHour > 0 ? 'var(--color-ink)' : 'var(--c-num-empty)'};transition:color 0.3s ease;">{Math.round($animatedCarbs)}</span>
            {/key}
            <span class="text-3xl text-[--c-on-surface-2]">g/h</span>
          </div>
        </div>
        <p class="text-caption-md text-[--c-on-surface-3]">
          {#if intensityFactor > 0}
            {$t.carbsFromPower(power, Math.round(intensityFactor * 100))}
          {:else}
            {$t.carbsEstimated}
          {/if}
        </p>
        {#if multiCarbNote}
          <p class="text-caption-sm text-[--c-on-surface-2] mt-sm">{$t.carbsMultiNote}</p>
        {/if}
      </div>

      <!-- Fluids card -->
      <div class="p-lg" style="background:var(--c-surface);border-radius:16px;box-shadow:var(--c-shadow-card);">
        <div class="flex items-start gap-md mb-lg">
          <div class="w-12 h-12 flex items-center justify-center flex-shrink-0" style="background:var(--c-surface-soft);border-radius:14px;">
            <Droplet class="w-7 h-7 text-[--c-on-surface]" />
          </div>
          <div class="min-w-0">
            <h2 class="text-heading-lg font-bold text-[--c-on-surface]">{$t.fluids}</h2>
            <p class="text-caption-sm text-[--c-on-surface-2]">{$t.fluidsSub}</p>
          </div>
        </div>
        <div class="mb-sm">
          <div class="flex items-baseline gap-sm" aria-live="polite" aria-atomic="true">
            {#key fluidPerHour}
              <span class="text-7xl md:text-8xl font-extra-bold {fluidPerHour > 0 ? 'num-flash' : ''}" style="color:{fluidPerHour > 0 ? 'var(--color-ink)' : 'var(--c-num-empty)'};transition:color 0.3s ease;">{$animatedFluid.toFixed(1)}</span>
            {/key}
            <span class="text-3xl text-[--c-on-surface-2]">L/h</span>
          </div>
        </div>
        <p class="text-caption-md text-[--c-on-surface-3]">{$t.fluidsBased}</p>
        {#if sweatRate !== 'moderate'}
          <p class="text-caption-sm text-[--c-on-surface-2] mt-xs">{sweatRate === 'light' ? $t.fluidsLightNote('−20%') : $t.fluidsHeavyNote('+30%')}</p>
        {/if}
        {#if heatBonus > 0}
          <p class="text-caption-sm text-[--color-accent] mt-xs">{$t.fluidsHeatNote(heatBonus.toFixed(1), temperature)}</p>
        {/if}
      </div>
    </div>

    <!-- Results Row 2: Power (+ speed when available) -->
    <div class="p-lg mb-lg card-enter card-enter-4" style="background:var(--c-surface);border-radius:16px;box-shadow:var(--c-shadow-card);">
      <div class="flex items-start gap-md mb-lg">
        <div class="w-12 h-12 flex items-center justify-center flex-shrink-0" style="background:var(--c-surface-soft);border-radius:14px;">
          <Zap class="w-7 h-7 text-[--c-on-surface]" />
        </div>
        <div class="min-w-0">
          <h2 class="text-heading-lg font-bold text-[--c-on-surface]">{$t.powerLabel}</h2>
          <p class="text-caption-sm text-[--c-on-surface-2]">{$t.powerSub}</p>
        </div>
      </div>
      <div class="mb-md">
        <div class="flex items-baseline gap-sm">
          <span class="text-7xl md:text-8xl font-extra-bold" style="color:{power > 0 ? 'var(--c-on-surface)' : 'var(--c-num-empty)'};transition:color 0.3s ease;">{power ?? 0}</span>
          <span class="text-3xl text-[--c-on-surface-2]">W</span>
        </div>
      </div>
      {#if intensityFactor > 0}
        <div class="flex items-center gap-sm flex-wrap">
          <span class="badge" style={zoneBadgeStyle}>{zoneLabel} · {Math.round(intensityFactor * 100)}% FTP</span>
          <span class="badge" style="background:var(--color-accent);color:var(--color-on-primary);">~{Math.round($animatedKcalPerHour)} kcal/h</span>
        </div>
      {:else}
        <p class="text-caption-sm text-[--c-on-surface-2]">{$t.powerEnterHint}</p>
      {/if}
      {#if speedKmh > 0}
        <div class="flex items-center justify-between mt-md pt-md row-sep">
          <div class="flex items-baseline gap-sm">
            <span class="text-heading-md font-bold text-[--c-on-surface]">{Math.round($animatedSpeed)}</span>
            <span class="text-caption-md text-[--c-on-surface-2]">{speedUnit}</span>
          </div>
          {#if speedSloganText}
            <a href={speedSloganUrl} target="_blank" rel="noopener noreferrer">
              <span class="badge inline-flex items-center gap-xs">
                {speedSloganText}
                <ExternalLink class="w-3 h-3" />
              </span>
            </a>
          {/if}
        </div>
      {/if}
    </div>

    <!-- Totals + Fueling Schedule + Bottle Planner — tabbed dark card -->
    <div bind:this={tabCard} class="card-campaign rounded-sm p-lg md:p-xl mb-xl card-enter card-enter-5">

      <!-- Tab bar — 2 tabs -->
      <div role="tablist" style="position:relative;display:grid;grid-template-columns:repeat(2,1fr);gap:0;margin-bottom:18px;background:rgba(255,255,255,0.08);border-radius:14px;border:1px solid rgba(255,255,255,0.12);padding:3px;">
        <div aria-hidden="true" style="position:absolute;left:3px;top:3px;bottom:3px;width:calc((100% - 6px) / 2);border-radius:10px;background:rgba(255,255,255,0.92);box-shadow:0 1px 3px rgba(0,0,0,0.3);transform:translateX(calc({tabIdx} * 100%));transition:transform 0.22s cubic-bezier(0.35,0,0.25,1);pointer-events:none;will-change:transform;"></div>
        <button role="tab"
          style="position:relative;flex:1;padding:6px 10px;border-radius:10px;font-size:13px;font-weight:500;white-space:nowrap;color:{totalsTab === 'summary' ? 'var(--c-dark-pill-active-text)' : 'rgba(255,255,255,0.55)'};transition:color 0.22s cubic-bezier(0.35,0,0.25,1);background:transparent;border:none;"
          aria-selected={totalsTab === 'summary'} on:click={() => switchTab('summary')}>{$t.tabTotals}</button>
        <button role="tab"
          style="position:relative;flex:1;padding:6px 10px;border-radius:10px;font-size:13px;font-weight:500;white-space:nowrap;color:{totalsTab === 'pack' ? 'var(--c-dark-pill-active-text)' : 'rgba(255,255,255,0.55)'};transition:color 0.22s cubic-bezier(0.35,0,0.25,1);background:transparent;border:none;"
          aria-selected={totalsTab === 'pack'} on:click={() => switchTab('pack')}>{$t.tabPack}</button>
      </div>

      <!-- Tab 1: Overview — totals + fueling schedule -->
      {#if totalsTab === 'summary'}
        <div in:fade={{ duration: 250 }}>
          <!-- 3 totals -->
          <h2 class="text-caption-md mb-lg text-[--color-on-primary]">{$t.totalNeeds(formatDuration(duration))}</h2>
          <div class="grid grid-cols-3 gap-md mb-lg">
            <div class="rounded-md p-md text-center">
              <div class="text-4xl md:text-5xl font-extra-bold mb-xs" style="color:#ffffff;">{Math.round($animatedTotalCarbs)}g</div>
              <div class="text-caption-sm" style="color:rgba(255,255,255,0.70);">{$t.carbsLabel}</div>
            </div>
            <div class="rounded-md p-md text-center">
              <div class="text-4xl md:text-5xl font-extra-bold mb-xs flex items-center justify-center" style="color:#ffffff;min-height:1.2em;">
                {intensityFactor > 0 ? Math.round($animatedTotalKcal) : '—'}
              </div>
              <div class="text-caption-sm" style="color:rgba(255,255,255,0.70);">{$t.kcal}</div>
            </div>
            <div class="rounded-md p-md text-center">
              <div class="text-4xl md:text-5xl font-extra-bold mb-xs" style="color:#ffffff;">{$animatedTotalFluid.toFixed(1)}L</div>
              <div class="text-caption-sm" style="color:rgba(255,255,255,0.70);">{$t.fluidsLabel}</div>
            </div>
          </div>

          <!-- Divider -->
          <div style="border-top:1px solid rgba(255,255,255,0.12);margin-bottom:16px;"></div>

          <!-- Fueling schedule — product chevron dropdown (scales to any number of products) -->
          <div class="flex items-center justify-between mb-md">
            <span style="color:rgba(255,255,255,0.7);font-size:13px;">{$t.solidFood}</span>
            <div style="position:relative;">
              <button
                on:click|stopPropagation={() => showSolidDropdown = !showSolidDropdown}
                style="display:flex;align-items:center;gap:6px;padding:7px 12px 7px 14px;border-radius:12px;border:1px solid rgba(255,255,255,0.15);background:rgba(255,255,255,0.08);font-size:13px;font-weight:500;color:#ffffff;cursor:pointer;white-space:nowrap;">
                <span>{activeSolid.label} ({activeSolid.carbs}g)</span>
                <ChevronDown size={14} style="color:rgba(255,255,255,0.55);transition:transform 0.18s cubic-bezier(0.35,0,0.25,1);transform:rotate({showSolidDropdown ? 180 : 0}deg);flex-shrink:0;" />
              </button>
              {#if showSolidDropdown}
                <div
                  on:click|stopPropagation
                  style="position:absolute;right:0;bottom:calc(100% + 6px);background:#1c1c22;border:1px solid rgba(255,255,255,0.15);border-radius:14px;overflow:hidden;min-width:170px;z-index:9999;box-shadow:0 -4px 24px rgba(0,0,0,0.5);">
                  {#each allSolidProducts as p, idx}
                    <button
                      on:click|stopPropagation={() => { solidProduct = p.id; showSolidDropdown = false; }}
                      style="display:flex;align-items:center;justify-content:space-between;width:100%;padding:12px 16px;font-size:14px;font-weight:{p.id === solidProduct ? '600' : '400'};color:{p.id === solidProduct ? '#ffffff' : 'rgba(255,255,255,0.65)'};background:{p.id === solidProduct ? 'rgba(255,255,255,0.06)' : 'transparent'};border:none;cursor:pointer;text-align:left;{idx < allSolidProducts.length - 1 ? 'border-bottom:1px solid rgba(255,255,255,0.08);' : ''}">
                      <span>{p.label}</span>
                      <span style="color:rgba(255,255,255,0.4);font-size:12px;margin-left:12px;">{p.carbs}g</span>
                    </button>
                  {/each}
                </div>
              {/if}
            </div>
          </div>
          {#if fuelingEvents.length === 0}
            <p style="color:rgba(255,255,255,0.70);font-size:14px;">{$t.rideTooShort}</p>
          {:else if fuelingEvents[0].carbs === 0}
            <p style="color:rgba(255,255,255,0.70);font-size:14px;">{$t.drinkCoversAll}</p>
          {:else if allSlotsIdentical}
            <!-- Compact summary — all slots identical, one-liner -->
            <div style="border-radius:14px;border:1px solid rgba(255,255,255,0.12);padding:14px 18px;display:flex;align-items:center;justify-content:space-between;gap:16px;">
              <div>
                <div style="color:#ffffff;font-weight:700;font-size:15px;">{fuelingEvents[0].units}× {activeSolid.label} <span style="font-weight:400;color:rgba(255,255,255,0.50);font-size:13px;">({activeSolid.carbs}g)</span></div>
                <div style="color:rgba(255,255,255,0.50);font-size:12px;margin-top:3px;">{$t.scheduleEvery20min}</div>
              </div>
              <div style="text-align:right;flex-shrink:0;">
                <div style="color:rgba(255,255,255,0.70);font-size:13px;font-variant-numeric:tabular-nums;">{fuelingEvents[0].time} – {fuelingEvents[fuelingEvents.length - 1].time}</div>
                <div style="color:rgba(255,255,255,0.50);font-size:12px;margin-top:3px;">{$t.solidUnitsTotal(totalSolidUnits, solidLabel)}</div>
              </div>
            </div>
            {#if drinkCarbsPerHour > 0}
              <p style="color:rgba(255,255,255,0.70);font-size:11px;margin-top:8px;">{$t.reducedByDrink(drinkCarbsPerHour)}</p>
            {/if}
          {:else}
            <!-- Full list — slots vary -->
            <div role="list" style="border-radius:14px;overflow:hidden;border:1px solid rgba(255,255,255,0.12);">
              {#each fuelingEvents as event, i}
                <div role="listitem" class="flex items-center justify-between px-lg py-md"
                  style="{i < fuelingEvents.length - 1 ? 'border-bottom:1px solid rgba(255,255,255,0.08);' : ''}">
                  <span style="color:rgba(255,255,255,0.70);font-size:13px;font-variant-numeric:tabular-nums;min-width:2.6rem;">{event.time}</span>
                  <span style="color:#ffffff;font-weight:700;font-size:15px;">{event.carbs}g</span>
                  <span style="color:rgba(255,255,255,0.70);font-size:12px;">{event.units}× {solidLabel}</span>
                </div>
              {/each}
            </div>
            <div class="flex items-center justify-between mt-md">
              <p style="color:rgba(255,255,255,0.70);font-size:12px;">{$t.firstFuel}</p>
              <p style="color:rgba(255,255,255,0.70);font-size:12px;font-weight:600;">{$t.solidUnitsTotal(totalSolidUnits, solidLabel)}</p>
            </div>
            {#if drinkCarbsPerHour > 0}
              <p style="color:rgba(255,255,255,0.70);font-size:11px;margin-top:6px;">{$t.reducedByDrink(drinkCarbsPerHour)}</p>
            {/if}
          {/if}
        </div>

      <!-- Tab 2: Checklist — pickers + pack list -->
      {:else}
        <div in:fade={{ duration: 250 }}>
          {#if bottleCount === 0}
            <p style="color:rgba(255,255,255,0.70);font-size:14px;">{$t.noBottles}</p>
          {:else}
            <!-- Compact pickers row -->
            <div style="display:flex;gap:10px;margin-bottom:14px;flex-wrap:wrap;align-items:center;">
              <!-- Drink type -->
              <div style="position:relative;display:grid;grid-template-columns:repeat(3,1fr);border-radius:12px;border:1px solid rgba(255,255,255,0.15);background:rgba(255,255,255,0.08);padding:3px;flex:1;min-width:160px;">
                <div style="position:absolute;left:3px;top:3px;bottom:3px;width:calc((100% - 6px) / 3);border-radius:8px;background:rgba(255,255,255,0.92);box-shadow:0 1px 3px rgba(0,0,0,0.3);transform:translateX(calc({drinkIdx} * 100%));transition:transform 0.22s cubic-bezier(0.35,0,0.25,1);pointer-events:none;will-change:transform;"></div>
                {#each DRINK_PRODUCTS as p}
                  <button style="position:relative;padding:5px 6px;min-height:44px;font-size:12px;font-weight:500;text-align:center;white-space:nowrap;color:{drinkProduct === p.id ? 'var(--c-dark-pill-active-text)' : 'rgba(255,255,255,0.55)'};transition:color 0.22s cubic-bezier(0.35,0,0.25,1);background:transparent;border:none;"
                    aria-pressed={drinkProduct === p.id} on:click={() => (drinkProduct = p.id)}>{p.label}</button>
                {/each}
              </div>
              <!-- Bottle size -->
              <div style="position:relative;display:grid;grid-template-columns:repeat(3,1fr);border-radius:12px;border:1px solid rgba(255,255,255,0.15);background:rgba(255,255,255,0.08);padding:3px;flex-shrink:0;">
                <div style="position:absolute;left:3px;top:3px;bottom:3px;width:calc((100% - 6px) / 3);border-radius:8px;background:rgba(255,255,255,0.92);box-shadow:0 1px 3px rgba(0,0,0,0.3);transform:translateX(calc({bottleSizeIdx} * 100%));transition:transform 0.22s cubic-bezier(0.35,0,0.25,1);pointer-events:none;will-change:transform;"></div>
                <button style="position:relative;padding:5px 10px;min-height:44px;font-size:12px;font-weight:500;text-align:center;color:{bottleSize === 500 ? 'var(--c-dark-pill-active-text)' : 'rgba(255,255,255,0.55)'};transition:color 0.22s;background:transparent;border:none;" aria-pressed={bottleSize === 500} on:click={() => (bottleSize = 500)}>500ml</button>
                <button style="position:relative;padding:5px 10px;min-height:44px;font-size:12px;font-weight:500;text-align:center;color:{bottleSize === 750 ? 'var(--c-dark-pill-active-text)' : 'rgba(255,255,255,0.55)'};transition:color 0.22s;background:transparent;border:none;" aria-pressed={bottleSize === 750} on:click={() => (bottleSize = 750)}>750ml</button>
                <button style="position:relative;padding:5px 10px;min-height:44px;font-size:12px;font-weight:500;text-align:center;color:{bottleSize === 1000 ? 'var(--c-dark-pill-active-text)' : 'rgba(255,255,255,0.55)'};transition:color 0.22s;background:transparent;border:none;" aria-pressed={bottleSize === 1000} on:click={() => (bottleSize = 1000)}>1L</button>
              </div>
            </div>

            <!-- Checklist -->
            {#if packItems.length > 0}
              <div style="display:flex;flex-direction:column;gap:2px;">
                {#each packItems as item}
                  {@const checked = checkedPack.has(item.id)}
                  <button
                    class="flex items-center gap-md text-left"
                    style="min-height:44px;padding:2px 0;"
                    aria-pressed={checked}
                    aria-label="{item.label}"
                    on:click={() => togglePack(item.id)}>
                    <div style="width:22px;height:22px;border-radius:6px;border:1.5px solid {checked ? '#ffffff' : 'rgba(255,255,255,0.25)'};background:{checked ? '#ffffff' : 'transparent'};flex-shrink:0;display:flex;align-items:center;justify-content:center;transition:all 0.15s;">
                      {#if checked}
                        <Check class="w-3 h-3" style="color:var(--c-dark-pill-active-text);" />
                      {/if}
                    </div>
                    <span style="font-size:14px;color:{checked ? 'rgba(255,255,255,0.45)' : 'rgba(255,255,255,0.85)'};text-decoration:{checked ? 'line-through' : 'none'};transition:color 0.15s;">{item.label}</span>
                  </button>
                {/each}
              </div>
              {#if checkedPack.size > 0}
                <button style="color:rgba(255,255,255,0.50);font-size:12px;min-height:44px;padding:0;display:flex;align-items:center;margin-top:4px;" on:click={resetPack}>{$t.reset}</button>
              {/if}
            {/if}
          {/if}
        </div>
      {/if}
    </div>

    {:else}
    <!-- Results empty state — iOS HIG: no card, icon + title + body, centered -->
    <div class="card-enter card-enter-3"
      style="display:flex;flex-direction:column;align-items:center;text-align:center;padding:48px 32px 32px;"
      transition:fade={{ duration: 200 }}>
      <div style="width:56px;height:56px;border-radius:16px;background:var(--c-surface-soft);display:flex;align-items:center;justify-content:center;margin-bottom:16px;">
        <Zap size={26} style="color:var(--c-on-surface-3);" />
      </div>
      <p style="font-size:17px;font-weight:600;color:var(--c-on-surface);margin:0 0 6px;">{$t.emptyTitle}</p>
      <p style="font-size:15px;color:var(--c-on-surface-2);margin:0;line-height:1.45;max-width:260px;">{$t.emptyState}</p>
    </div>
    {/if}

    <!-- bottom safe-area spacer -->
    <div style="padding-bottom:max(24px, env(safe-area-inset-bottom));"></div>

  </div>

  <!-- Settings sheet — with in-sheet navigation to products view -->
  {#if showSettingsSheet}
    <div class="fixed inset-0 z-[996] bg-black/55"
      on:click={closeSettings} role="presentation"
      transition:fade={{ duration: 300 }}></div>
    <div class="fixed bottom-0 left-0 right-0 z-[998] rounded-t-[20px] px-6 pt-5 max-w-lg mx-auto overflow-y-auto"
      style="background:var(--c-surface);color:var(--c-on-surface);box-shadow:var(--c-shadow-sheet);padding-bottom:{keyboardHeight > 0 ? keyboardHeight + 16 + 'px' : 'max(32px,calc(env(safe-area-inset-bottom,0px) + 16px))'};max-height:90vh;transform:translateY({sheetDragOffsetY}px);transition:{sheetIsDragging ? 'none' : 'transform 0.4s cubic-bezier(0.22,1,0.36,1)'};"
      on:touchstart={(e) => onSheetDragStart(e, closeSettings)}
      on:touchmove|preventDefault={onSheetDragMove}
      on:touchend={onSheetDragEnd}
      in:fly={{ y: 500, duration: 420, easing: quintOut }}
      out:fly={{ y: 500, duration: 240, easing: cubicIn }}>
      <div class="w-10 h-1 rounded-full mx-auto mb-5" style="background:var(--c-drag-handle);"></div>

      <!-- Navigation header -->
      {#if settingsView === 'main'}
        <p class="text-heading-md font-bold mb-lg" style="color:var(--c-on-surface);">{$t.settings}</p>
      {:else}
        <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:20px;">
          <button on:click={() => { settingsNavDir = -1; settingsView = 'main'; }}
            aria-label={$t.settings}
            style="width:44px;height:44px;border-radius:50%;background:transparent;border:none;cursor:pointer;display:flex;align-items:center;justify-content:center;flex-shrink:0;margin:-6px;">
            <span style="width:32px;height:32px;border-radius:50%;background:var(--c-surface-soft);display:flex;align-items:center;justify-content:center;color:var(--c-on-surface-2);pointer-events:none;">
              <ChevronLeft size={18} />
            </span>
          </button>
          <p style="font-size:17px;font-weight:700;color:var(--c-on-surface);">{$t.customProducts}</p>
          <div style="width:32px;"></div>
        </div>
      {/if}

      <!-- Animated content area -->
      <div style="overflow-x:hidden;">
        {#if settingsView === 'main'}
          <div in:fly={{ x: settingsNavDir * -300, duration: settingsNavDir === 0 ? 0 : 280, easing: quintOut }}>

            <!-- Appearance + Language -->
            <div style="border-radius:14px;overflow:hidden;border:1px solid var(--c-border);margin-bottom:16px;">
              <div class="flex items-center justify-between px-lg py-md" style="border-bottom:1px solid var(--c-border);">
                <span style="color:var(--c-on-surface);font-size:15px;">{$t.appearance}</span>
                <div style="position:relative;display:grid;grid-template-columns:repeat(3,1fr);border-radius:14px;border:1px solid var(--c-border-input);background:var(--c-surface-seg);padding:3px;min-height:50px;">
                  <div style="position:absolute;left:3px;top:3px;bottom:3px;width:calc((100% - 6px) / 3);border-radius:10px;background:var(--c-seg-active);box-shadow:0 1px 3px rgba(0,0,0,0.15);transform:translateX(calc({themeIdx} * 100%));transition:transform 0.22s cubic-bezier(0.35,0,0.25,1);pointer-events:none;will-change:transform;"></div>
                  <button style="position:relative;display:flex;align-items:center;justify-content:center;min-height:44px;padding:0 12px;background:transparent;border:none;color:{theme === 'light' ? 'var(--c-seg-active-text)' : 'var(--c-on-surface-2)'};transition:color 0.22s cubic-bezier(0.35,0,0.25,1);" aria-label="Light theme" aria-pressed={theme === 'light'} on:click={() => { theme = 'light'; applyTheme('light'); }}><Sun class="w-4 h-4" /></button>
                  <button style="position:relative;display:flex;align-items:center;justify-content:center;min-height:44px;padding:0 12px;background:transparent;border:none;color:{theme === 'system' ? 'var(--c-seg-active-text)' : 'var(--c-on-surface-2)'};transition:color 0.22s cubic-bezier(0.35,0,0.25,1);" aria-label="System theme" aria-pressed={theme === 'system'} on:click={() => { theme = 'system'; applyTheme('system'); }}><Smartphone class="w-4 h-4" /></button>
                  <button style="position:relative;display:flex;align-items:center;justify-content:center;min-height:44px;padding:0 12px;background:transparent;border:none;color:{theme === 'dark' ? 'var(--c-seg-active-text)' : 'var(--c-on-surface-2)'};transition:color 0.22s cubic-bezier(0.35,0,0.25,1);" aria-label="Dark theme" aria-pressed={theme === 'dark'} on:click={() => { theme = 'dark'; applyTheme('dark'); }}><Moon class="w-4 h-4" /></button>
                </div>
              </div>
              <div class="flex items-center justify-between px-lg py-md">
                <span style="color:var(--c-on-surface);font-size:15px;">{$t.language}</span>
                <div style="position:relative;display:flex;border-radius:14px;border:1px solid var(--c-border-input);background:var(--c-surface-seg);padding:3px;">
                  <div style="position:absolute;top:3px;bottom:3px;width:calc(50% - 3px);border-radius:10px;background:var(--c-seg-active);box-shadow:0 1px 3px rgba(0,0,0,0.15);transform:translateX({$lang === 'de' ? 'calc(100% + 3px)' : '0'});transition:transform 0.22s cubic-bezier(0.35,0,0.25,1);pointer-events:none;will-change:transform;"></div>
                  <button on:click={() => lang.update(() => 'en')} style="position:relative;flex:1;padding:6px 16px;font-size:13px;font-weight:500;color:{$lang === 'en' ? 'var(--c-seg-active-text)' : 'var(--c-on-surface-2)'};transition:color 0.22s cubic-bezier(0.35,0,0.25,1);background:transparent;border:none;">EN</button>
                  <button on:click={() => lang.update(() => 'de')} style="position:relative;flex:1;padding:6px 16px;font-size:13px;font-weight:500;color:{$lang === 'de' ? 'var(--c-seg-active-text)' : 'var(--c-on-surface-2)'};transition:color 0.22s cubic-bezier(0.35,0,0.25,1);background:transparent;border:none;">DE</button>
                </div>
              </div>
            </div>

            <!-- Profile section -->
            <p style="font-size:13px;font-weight:600;text-transform:uppercase;letter-spacing:0.06em;color:var(--c-on-surface-2);margin:16px 0 6px 4px;">{$t.profile}</p>
            <div style="border-radius:14px;overflow:hidden;border:1px solid var(--c-border);margin-bottom:16px;">

              <!-- Weight row -->
              <div class="flex items-center justify-between px-lg py-sm" style="border-bottom:1px solid var(--c-border);">
                <label for="settings-weight" style="font-size:15px;color:var(--c-on-surface);">{$t.bodyWeight}</label>
                <div class="flex items-center gap-xs">
                  <input id="settings-weight" type="number" inputmode="decimal" bind:value={weight} min="1" max="400" step="1" placeholder="75"
                    class="w-24 text-right text-body-strong text-[--c-on-surface] focus:outline-none"
                    style="height:44px;border-radius:14px;padding:0 14px;background:var(--c-surface-input);"
                    enterkeyhint="next"
                    on:focus={focusInput} on:keydown={blurOnEnter} />
                  <span class="text-caption-sm text-[--c-on-surface-2] w-5">{imperial ? 'lbs' : 'kg'}</span>
                </div>
              </div>

              <!-- FTP row -->
              <div class="flex items-center justify-between px-lg py-sm" style="border-bottom:1px solid var(--c-border);">
                <div>
                  <label for="settings-ftp" style="font-size:15px;color:var(--c-on-surface);display:block;">{$t.ftpLabel}</label>
                  <span class="text-caption-sm text-[--c-on-surface-2]">{$t.ftpSub}</span>
                </div>
                <div class="flex items-center gap-xs">
                  <input id="settings-ftp" type="number" inputmode="numeric" bind:value={ftp} min="0" max="600" step="1" placeholder="280"
                    class="w-24 text-right text-body-strong text-[--c-on-surface] focus:outline-none"
                    style="height:44px;border-radius:14px;padding:0 14px;background:var(--c-surface-input);"
                    enterkeyhint="done"
                    on:focus={focusInput} on:keydown={blurOnEnter} />
                  <span class="text-caption-sm text-[--c-on-surface-2] w-5">W</span>
                </div>
              </div>

              <!-- Units row -->
              <div class="flex items-center justify-between px-lg py-md gap-md flex-wrap" style="border-bottom:1px solid var(--c-border);">
                <span style="font-size:15px;color:var(--c-on-surface);">{$t.units}</span>
                <div style="position:relative;display:flex;border-radius:14px;border:1px solid var(--c-border-input);background:var(--c-surface-seg);padding:3px;">
                  <div style="position:absolute;top:3px;bottom:3px;width:calc(50% - 3px);border-radius:10px;background:var(--c-seg-active);box-shadow:0 1px 3px rgba(0,0,0,0.15);transform:translateX({imperial ? 'calc(100% + 3px)' : '0'});transition:transform 0.22s cubic-bezier(0.35,0,0.25,1);pointer-events:none;will-change:transform;"></div>
                  <button
                    style="position:relative;flex:1;padding:6px 18px;font-size:13px;font-weight:500;white-space:nowrap;color:{!imperial ? 'var(--c-seg-active-text)' : 'var(--c-on-surface-2)'};transition:color 0.22s cubic-bezier(0.35,0,0.25,1);background:transparent;border:none;"
                    on:click={() => { if (imperial) toggleImperial(); }}>{$t.kmKg}</button>
                  <button
                    style="position:relative;flex:1;padding:6px 18px;font-size:13px;font-weight:500;white-space:nowrap;color:{imperial ? 'var(--c-seg-active-text)' : 'var(--c-on-surface-2)'};transition:color 0.22s cubic-bezier(0.35,0,0.25,1);background:transparent;border:none;"
                    on:click={() => { if (!imperial) toggleImperial(); }}>{$t.miLbs}</button>
                </div>
              </div>

              <!-- Sweat Rate row -->
              <div class="flex items-center justify-between px-lg py-md gap-md">
                <div class="flex-shrink-0">
                  <span style="font-size:15px;color:var(--c-on-surface);display:block;">{$t.sweatRate}</span>
                  <span class="text-caption-sm text-[--c-on-surface-2]">
                    {sweatRate === 'light' ? $t.sweatLight : sweatRate === 'heavy' ? $t.sweatHeavy : $t.sweatBaseline}
                  </span>
                </div>
                <div style="position:relative;display:grid;grid-template-columns:repeat(3,1fr);border-radius:14px;border:1px solid var(--c-border-input);background:var(--c-surface-seg);padding:3px;flex-shrink:0;">
                  <div style="position:absolute;left:3px;top:3px;bottom:3px;width:calc((100% - 6px) / 3);border-radius:10px;background:var(--c-seg-active);box-shadow:0 1px 3px rgba(0,0,0,0.15);transform:translateX(calc({sweatIdx} * 100%));transition:transform 0.22s cubic-bezier(0.35,0,0.25,1);pointer-events:none;will-change:transform;"></div>
                  {#each SWEAT_LEVELS as { value, drops }}
                    <button
                      class="flex items-center justify-center gap-[2px]"
                      style="position:relative;padding:6px 12px;min-height:44px;color:{sweatRate === value ? 'var(--c-seg-active-text)' : 'var(--c-on-surface-2)'};transition:color 0.22s cubic-bezier(0.35,0,0.25,1);background:transparent;border:none;"
                      aria-label="{value === 'light' ? $t.sweatLightAria : value === 'moderate' ? $t.sweatModerateAria : $t.sweatHeavyAria}"
                      aria-pressed={sweatRate === value}
                      on:click={() => (sweatRate = value)}>
                      {#each { length: drops } as _}<Droplet class="w-3.5 h-3.5" />{/each}
                    </button>
                  {/each}
                </div>
              </div>

            </div>

            <!-- Custom Products nav row -->
            <p class="text-caption-sm font-semibold uppercase tracking-wide text-[--c-on-surface-2] mb-xs mt-lg">{$t.customProducts}</p>
            <div style="border-radius:14px;overflow:hidden;border:1px solid var(--c-border);margin-bottom:16px;">
              <button
                on:click={() => { settingsNavDir = 1; settingsView = 'products'; }}
                style="width:100%;display:flex;align-items:center;justify-content:space-between;padding:0 16px;min-height:44px;background:transparent;border:none;cursor:pointer;">
                <span style="font-size:15px;color:var(--c-on-surface);">{$t.customProducts}</span>
                <div style="display:flex;align-items:center;gap:8px;">
                  <span style="font-size:14px;color:var(--c-on-surface-2);">{allSolidProducts.find(p => p.id === solidProduct)?.label ?? ''}</span>
                  <ChevronRight size={16} style="color:var(--c-on-surface-3);" />
                </div>
              </button>
            </div>

            <button on:click={closeSettings}
              class="w-full rounded-full text-button-md font-extra-bold"
              style="min-height:44px;background:var(--c-surface-soft);color:var(--c-on-surface);border:none;cursor:pointer;">
              {$t.close}
            </button>
          </div>

        {:else}
          <div in:fly={{ x: settingsNavDir * 300, duration: 280, easing: quintOut }}>
            <!-- Products view -->
            <div style="display:flex;flex-direction:column;gap:8px;margin-bottom:8px;">
              <input
                type="text"
                bind:value={_newProductName}
                placeholder={$t.productNamePlaceholder}
                style="width:100%;height:44px;border-radius:12px;padding:0 14px;background:var(--c-surface-input);border:none;font-size:15px;color:var(--c-on-surface);box-sizing:border-box;"
                enterkeyhint="next"
                on:focus={focusInput} on:keydown={blurOnEnter} />
              <div style="display:flex;gap:8px;align-items:center;">
                <input
                  type="number"
                  inputmode="numeric"
                  bind:value={_newProductCarbs}
                  placeholder="25"
                  min="1" max="200"
                  style="width:72px;height:44px;border-radius:12px;padding:0 12px;background:var(--c-surface-input);border:none;font-size:15px;color:var(--c-on-surface);text-align:center;flex-shrink:0;"
                  enterkeyhint="done"
                  on:focus={focusInput} on:keydown={blurOnEnter} />
                <span style="font-size:13px;color:var(--c-on-surface-2);white-space:nowrap;flex-shrink:0;">{$t.productCarbsUnit}</span>
                <button
                  on:click={() => { addCustomProduct(_newProductName, _newProductCarbs ?? 0); _newProductName = ''; _newProductCarbs = undefined; }}
                  style="flex:1;height:44px;border-radius:12px;background:var(--c-seg-active);color:var(--c-seg-active-text);border:none;cursor:pointer;font-size:15px;font-weight:600;opacity:{_newProductName.trim() && _newProductCarbs > 0 ? '1' : '0.4'};pointer-events:{_newProductName.trim() && _newProductCarbs > 0 ? 'auto' : 'none'};transition:opacity 0.15s;">
                  {$t.addProduct}
                </button>
              </div>
            </div>
            <p style="font-size:13px;color:var(--c-on-surface-3);margin:0 0 20px;line-height:1.4;">{$t.productCarbsHint}</p>

            <div style="border-radius:14px;overflow:hidden;border:1px solid var(--c-border);margin-bottom:20px;">
              {#each allSolidProducts as p, i (p.id)}
                {@const isActive = p.id === solidProduct}
                {@const isCustom = !['gel','bar','chew'].includes(p.id)}
                <div style="display:flex;align-items:center;min-height:44px;{i < allSolidProducts.length - 1 ? 'border-bottom:1px solid var(--c-border);' : ''}">
                  <button
                    on:click={() => solidProduct = p.id}
                    style="flex:1;display:flex;align-items:center;gap:10px;padding:0 16px;min-height:44px;background:transparent;border:none;cursor:pointer;text-align:left;">
                    <div style="width:20px;flex-shrink:0;color:{isActive ? 'var(--c-seg-active)' : 'transparent'};">
                      <Check size={18} />
                    </div>
                    <span style="font-size:15px;color:var(--c-on-surface);flex:1;">{p.label}</span>
                    <span style="font-size:14px;color:var(--c-on-surface-2);">{p.carbs}g KH</span>
                  </button>
                  {#if isCustom}
                    <button
                      on:click={() => removeCustomProduct(p.id)}
                      style="width:44px;height:44px;display:flex;align-items:center;justify-content:center;background:transparent;border:none;cursor:pointer;color:var(--c-on-surface-3);flex-shrink:0;"
                      aria-label={$t.deleteProduct}>
                      <X size={16} />
                    </button>
                  {:else}
                    <div style="width:44px;flex-shrink:0;"></div>
                  {/if}
                </div>
              {/each}
            </div>
          </div>
        {/if}
      </div>
    </div>
  {/if}

  <!-- About sheet — with in-sheet navigation to math and impressum views -->
  {#if showAboutSheet}
    <div class="fixed inset-0 z-[996] bg-black/55"
      on:click={closeAbout} role="presentation"
      transition:fade={{ duration: 300 }}></div>
    <div class="fixed bottom-0 left-0 right-0 z-[998] rounded-t-[28px] px-6 pt-5 max-w-lg mx-auto"
      style="background:var(--c-surface);color:var(--c-on-surface);box-shadow:var(--c-shadow-sheet);padding-bottom:max(32px,calc(env(safe-area-inset-bottom,0px) + 16px));transform:translateY({sheetDragOffsetY}px);transition:{sheetIsDragging ? 'none' : 'transform 0.4s cubic-bezier(0.22,1,0.36,1)'};"
      on:touchstart={(e) => onSheetDragStart(e, closeAbout)}
      on:touchmove|preventDefault={onSheetDragMove}
      on:touchend={onSheetDragEnd}
      in:fly={{ y: 500, duration: 420, easing: quintOut }}
      out:fly={{ y: 500, duration: 240, easing: cubicIn }}>
      <div class="w-10 h-1 rounded-full mx-auto mb-5" style="background:var(--c-drag-handle);"></div>

      <!-- Navigation header -->
      {#if aboutView === 'main'}
        <!-- App identity -->
        <div class="flex items-center gap-md mb-lg">
          <img src="/favicon.svg" alt="" class="w-10 h-10 flex-shrink-0" style="border-radius:18%;" />
          <div>
            <p class="text-heading-md font-extra-bold" style="color:var(--c-on-surface);"><span style="font-style:italic;">bonk</span><span style="color:#f73b20;">proof!</span></p>
            <p class="text-caption-sm" style="color:var(--c-on-surface-2);">v{VERSION}</p>
          </div>
        </div>
      {:else}
        <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:20px;">
          <button on:click={() => { aboutNavDir = -1; aboutView = 'main'; }}
            aria-label={$t.about}
            style="width:44px;height:44px;border-radius:50%;background:transparent;border:none;cursor:pointer;display:flex;align-items:center;justify-content:center;flex-shrink:0;margin:-6px;">
            <span style="width:32px;height:32px;border-radius:50%;background:var(--c-surface-soft);display:flex;align-items:center;justify-content:center;color:var(--c-on-surface-2);pointer-events:none;">
              <ChevronLeft size={18} />
            </span>
          </button>
          <p style="font-size:17px;font-weight:700;color:var(--c-on-surface);">{$t.howMathWorks}</p>
          <div style="width:32px;"></div>
        </div>
      {/if}

      <!-- Animated content area -->
      <div style="overflow-x:hidden;">
        {#if aboutView === 'main'}
          <div in:fly={{ x: aboutNavDir * -300, duration: aboutNavDir === 0 ? 0 : 280, easing: quintOut }}>

            <p class="text-body-md mb-lg" style="color:var(--c-on-surface-3);">{$t.aboutDesc}</p>

            <div style="border-radius:14px;overflow:hidden;border:1px solid var(--c-border);margin-bottom:24px;">
              <div class="flex items-center justify-between px-lg py-md" style="border-bottom:1px solid var(--c-border);">
                <span style="color:var(--c-on-surface-2);font-size:14px;">{$t.dataStorage}</span>
                <span style="color:var(--c-on-surface);font-weight:600;font-size:14px;">{$t.dataStorageVal}</span>
              </div>
              <div class="flex items-center justify-between px-lg py-md" style="border-bottom:1px solid var(--c-border);">
                <span style="color:var(--c-on-surface-2);font-size:14px;">{$t.serverRequests}</span>
                <span style="color:var(--c-on-surface);font-weight:600;font-size:14px;">{$t.serverRequestsVal}</span>
              </div>
              <div class="flex items-center justify-between px-lg py-md">
                <span style="color:var(--c-on-surface-2);font-size:14px;">{$t.worksOffline}</span>
                <span style="color:var(--c-on-surface);font-weight:600;font-size:14px;">{$t.worksOfflineVal}</span>
              </div>
            </div>

            <div style="border-radius:14px;overflow:hidden;border:1px solid var(--c-border);margin-bottom:16px;">
              <button class="flex items-center justify-between w-full px-lg py-md" style="background:transparent;border:none;border-bottom:1px solid var(--c-border);" on:click={() => { closeAbout(); setTimeout(() => { howToSlide = 0; showHowToSheet = true; }, 60); }}>
                <span style="color:var(--c-on-surface);font-size:15px;">{$t.tourReplay}</span>
                <ChevronRight size={16} style="color:var(--c-on-surface-2);flex-shrink:0;" />
              </button>
              <button class="flex items-center justify-between w-full px-lg py-md" style="background:transparent;border:none;" on:click={() => { aboutNavDir = 1; aboutView = 'math'; }}>
                <span style="color:var(--c-on-surface);font-size:15px;">{$t.howItWorks}</span>
                <ChevronRight size={16} style="color:var(--c-on-surface-2);flex-shrink:0;" />
              </button>
            </div>

            <div class="flex gap-sm">
              <button on:click={closeAbout}
                class="flex-1 rounded-full text-button-md font-extra-bold"
                style="min-height:44px;background:var(--c-surface-soft);color:var(--c-on-surface);border:1px solid var(--c-border-input);">
                {$t.close}
              </button>
              <a href="mailto:moindnl@proton.me"
                class="flex-1 rounded-full text-button-md font-extra-bold text-center"
                style="min-height:44px;display:flex;align-items:center;justify-content:center;background:var(--c-seg-active);color:var(--c-seg-active-text);text-decoration:none;">
                E-Mail <ExternalLink size={14} style="display:inline;vertical-align:middle;margin-left:4px;" />
              </a>
            </div>
          </div>

        {:else if aboutView === 'math'}
          <div in:fly={{ x: aboutNavDir * 300, duration: 280, easing: quintOut }}>
            <div class="mb-lg" style="border-radius:14px;overflow:hidden;border:1px solid var(--c-border);">
              <div class="grid text-caption-sm font-extra-bold uppercase" style="grid-template-columns:16px 1fr 68px 88px;background:var(--c-surface-soft);padding:8px 14px;gap:8px;color:var(--c-on-surface-2);letter-spacing:0.05em;">
                <span></span><span>{$t.zoneCol}</span><span class="text-right">{$t.ftpCol}</span><span class="text-right">{$t.carbsCol}</span>
              </div>
              {#each $t.mathZones as row, i}
                {@const dotColor = i === 0 ? '#a1a1aa' : i < 3 ? '#3f3f46' : '#f73b20'}
                <div class="grid text-caption-sm items-center" style="grid-template-columns:16px 1fr 68px 88px;padding:10px 14px;gap:8px;border-top:1px solid var(--c-border);">
                  <span style="width:8px;height:8px;border-radius:50%;background:{dotColor};display:block;flex-shrink:0;"></span>
                  <span style="color:var(--c-on-surface);font-weight:500;">{row.zone}</span>
                  <span class="text-right" style="color:var(--c-on-surface-2);">{row.ftp}</span>
                  <span class="text-right" style="color:var(--c-on-surface-3);font-weight:600;">{row.carbs}</span>
                </div>
              {/each}
            </div>

            <p class="text-caption-sm mb-sm" style="color:var(--c-on-surface-2);">{$t.mathFluidNote}</p>
            <p class="text-caption-sm mb-sm" style="color:var(--c-on-surface-2);">{$t.mathHeatNote}</p>
            <p class="text-caption-sm mb-lg" style="color:var(--c-on-surface-2);">{$t.mathElectroNote}</p>

            <!-- Scientific sources -->
            <p class="text-caption-sm font-extra-bold uppercase mb-sm" style="color:var(--c-on-surface-2);letter-spacing:0.05em;">{$t.mathSourcesLabel}</p>
            <div style="border-radius:12px;border:1px solid var(--c-border);overflow:hidden;">
              <a href="https://doi.org/10.1007/s40279-014-0148-z" target="_blank" rel="noopener noreferrer"
                style="display:flex;flex-direction:column;padding:12px 14px;border-bottom:1px solid var(--c-border);text-decoration:none;background:transparent;">
                <span class="text-caption-sm font-extra-bold" style="color:var(--c-on-surface);margin-bottom:2px;">Jeukendrup (2014)</span>
                <span class="text-caption-sm" style="color:var(--c-on-surface-3);">A Step Towards Personalized Sports Nutrition: Carbohydrate Intake During Exercise · Sports Medicine</span>
              </a>
              <a href="https://doi.org/10.1249/mss.0b013e31802ca597" target="_blank" rel="noopener noreferrer"
                style="display:flex;flex-direction:column;padding:12px 14px;border-bottom:1px solid var(--c-border);text-decoration:none;background:transparent;">
                <span class="text-caption-sm font-extra-bold" style="color:var(--c-on-surface);margin-bottom:2px;">Sawka et al. (2007)</span>
                <span class="text-caption-sm" style="color:var(--c-on-surface-3);">ACSM Position Stand: Exercise and Fluid Replacement · Medicine & Science in Sports & Exercise</span>
              </a>
              <a href="https://doi.org/10.1016/j.jand.2015.12.006" target="_blank" rel="noopener noreferrer"
                style="display:flex;flex-direction:column;padding:12px 14px;text-decoration:none;background:transparent;">
                <span class="text-caption-sm font-extra-bold" style="color:var(--c-on-surface);margin-bottom:2px;">Thomas et al. (2016)</span>
                <span class="text-caption-sm" style="color:var(--c-on-surface-3);">Nutrition and Athletic Performance · Academy of Nutrition and Dietetics / ACSM</span>
              </a>
            </div>
          </div>

        {/if}
      </div>
    </div>
  {/if}

  <!-- PWA install bottom sheet -->
  {#if installPlatform}
    <div class="fixed inset-0 z-[996] bg-black/55"
      on:click={dismissInstallSheet} role="presentation" transition:fade={{ duration: 300 }}>
    </div>
    <div class="fixed bottom-0 left-0 right-0 z-[998] rounded-t-[28px] px-6 pt-5 max-w-lg mx-auto"
      style="background:var(--c-surface);color:var(--c-on-surface);box-shadow:var(--c-shadow-sheet);padding-bottom:max(32px,calc(env(safe-area-inset-bottom,0px) + 16px));transform:translateY({sheetDragOffsetY}px);transition:{sheetIsDragging ? 'none' : 'transform 0.4s cubic-bezier(0.22,1,0.36,1)'};"
      on:touchstart={(e) => onSheetDragStart(e, dismissInstallSheet)}
      on:touchmove|preventDefault={onSheetDragMove}
      on:touchend={onSheetDragEnd}
      in:fly={{ y: 500, duration: 420, easing: quintOut }}
      out:fly={{ y: 500, duration: 240, easing: cubicIn }}>
      <!-- Drag handle -->
      <div class="w-10 h-1 rounded-full mx-auto mb-5" style="background:var(--c-drag-handle);"></div>

      <div class="mb-4">
        <p class="text-heading-md font-extra-bold" style="color:var(--c-on-surface);">{$t.installTitle}</p>
        <p class="text-caption-md mt-1" style="color:var(--c-on-surface-2);">{$t.installSub}</p>
      </div>

      {#if installPlatform === 'ios'}
        <ol class="space-y-3 text-body-md">
          <li class="flex items-start gap-3">
            <span class="badge text-xs shrink-0 mt-0.5">1</span>
            <span>{@html $t.iosStep1}</span>
          </li>
          <li class="flex items-start gap-3">
            <span class="badge text-xs shrink-0 mt-0.5">2</span>
            <span>{@html $t.iosStep2}</span>
          </li>
          <li class="flex items-start gap-3">
            <span class="badge text-xs shrink-0 mt-0.5">3</span>
            <span>{@html $t.iosStep3}</span>
          </li>
        </ol>
        <p class="text-caption-sm mt-4" style="color:var(--c-on-surface-2);">{$t.iosSafariNote}</p>
      {:else}
        {#if deferredInstallPrompt}
          <button on:click={triggerInstall}
            class="w-full py-3 rounded-full text-button-md font-extra-bold mb-4"
            style="background:var(--c-seg-active);color:var(--c-seg-active-text);">
            {$t.installNow}
          </button>
        {:else}
          <ol class="space-y-3 text-body-md">
            <li class="flex items-start gap-3">
              <span class="badge text-xs shrink-0 mt-0.5">1</span>
              <span>{@html $t.androidStep1}</span>
            </li>
            <li class="flex items-start gap-3">
              <span class="badge text-xs shrink-0 mt-0.5">2</span>
              <span>{@html $t.androidStep2}</span>
            </li>
          </ol>
          <p class="text-caption-sm mt-4" style="color:var(--c-on-surface-2);">{$t.androidNote}</p>
        {/if}
      {/if}

      <button on:click={dismissInstallSheet}
        class="mt-6 w-full py-3 rounded-full text-button-md font-extra-bold"
        style="background:var(--c-surface-soft);color:var(--c-on-surface);border:1px solid var(--c-border-input);">
        {$t.notNow}
      </button>
    </div>
  {/if}

  <!-- Easter egg F: neuralyzer flash -->
  {#if neuralizer}
    <div class="fixed inset-0 z-[999] flex flex-col items-center justify-center"
      style="background:rgba(0,0,0,0.88);animation:neuralizer-flash 2.9s ease forwards;">
      <p style="font-size:clamp(14px,3vw,18px);font-weight:700;color:#ffffff;text-align:center;max-width:420px;padding:0 24px;line-height:1.6;opacity:0;animation:neuralizer-text 2.9s ease forwards;">
        {$t.neuralyzerText}
      </p>
    </div>
  {/if}


  <!-- Onboarding wizard — fullscreen, first-launch only -->
  {#if onboardingStep >= 0}
    <div
      class="fixed inset-0 z-[2000] flex flex-col"
      style="background:var(--c-bg);padding-top:env(safe-area-inset-top,44px);padding-bottom:max(40px,env(safe-area-inset-bottom,24px));"
      role="dialog"
      aria-modal="true"
      aria-label="Getting started">

      <!-- Step 0: Welcome -->
      {#if onboardingStep === 0}
        <!-- Language toggle top-right -->
        <div style="display:flex;justify-content:flex-end;padding:0 20px 0;">
          <div style="position:relative;display:flex;border-radius:12px;border:1px solid var(--c-border-input);background:var(--c-surface-seg);padding:3px;">
            <div style="position:absolute;top:3px;bottom:3px;width:calc(50% - 3px);border-radius:8px;background:var(--c-seg-active);box-shadow:0 1px 3px rgba(0,0,0,0.15);transform:translateX({$lang === 'de' ? 'calc(100% + 3px)' : '0'});transition:transform 0.22s cubic-bezier(0.35,0,0.25,1);pointer-events:none;"></div>
            <button on:click={() => lang.update(() => 'en')} style="position:relative;padding:5px 14px;font-size:13px;font-weight:600;color:{$lang === 'en' ? 'var(--c-seg-active-text)' : 'var(--c-on-surface-2)'};transition:color 0.22s;background:transparent;border:none;min-height:36px;">EN</button>
            <button on:click={() => lang.update(() => 'de')} style="position:relative;padding:5px 14px;font-size:13px;font-weight:600;color:{$lang === 'de' ? 'var(--c-seg-active-text)' : 'var(--c-on-surface-2)'};transition:color 0.22s;background:transparent;border:none;min-height:36px;">DE</button>
          </div>
        </div>
        <div class="flex flex-col flex-1 items-center justify-center px-8"
          in:fly={{ x: 40, duration: 280, easing: cubicOut }}>
          <img src="/favicon.svg" alt="bonkproof!" style="width:72px;height:72px;border-radius:18%;margin-bottom:24px;display:block;" />
          <h1 style="font-size:28px;font-weight:700;letter-spacing:-0.02em;margin:0 0 10px;text-align:center;color:var(--c-on-surface);">
            <span style="font-style:italic;color:var(--c-on-surface);">bonk</span><span style="color:#f73b20;">proof!</span>
          </h1>
          <p style="font-size:17px;color:var(--c-on-surface-2);text-align:center;max-width:300px;line-height:1.5;margin:0;">{$t.onboardingTagline}</p>
        </div>
        <div class="px-6" style="padding-bottom:8px;">
          <button
            on:click={() => { onboardingStep = 1; }}
            style="width:100%;height:52px;border-radius:14px;background:var(--c-seg-active);color:var(--c-seg-active-text);font-size:17px;font-weight:600;border:none;cursor:pointer;transition:opacity 0.15s;">
            {$t.onboardingStart} →
          </button>
        </div>
        <!-- Progress dots -->
        <div class="flex items-center justify-center gap-2 pt-4">
          <span style="width:8px;height:8px;border-radius:50%;background:var(--c-seg-active);display:block;"></span>
          <span style="width:8px;height:8px;border-radius:50%;background:var(--c-border-input);display:block;"></span>
          <span style="width:8px;height:8px;border-radius:50%;background:var(--c-border-input);display:block;"></span>
          <span style="width:8px;height:8px;border-radius:50%;background:var(--c-border-input);display:block;"></span>
        </div>

      <!-- Step 1: Profile -->
      {:else if onboardingStep === 1}
        <div class="flex flex-col flex-1 px-6 pt-2"
          in:fly={{ x: 40, duration: 280, easing: cubicOut }}>
          <!-- Back button -->
          <button
            on:click={() => { onboardingStep = 0; }}
            style="align-self:flex-start;height:44px;padding:0 4px;background:transparent;border:none;cursor:pointer;font-size:15px;font-weight:500;color:var(--c-on-surface-2);display:flex;align-items:center;gap:4px;margin-bottom:8px;">
            ← {$t.onboardingStart}
          </button>

          <h2 style="font-size:22px;font-weight:700;color:var(--c-on-surface);margin:0 0 8px;">{$t.onboardingProfileTitle}</h2>
          <p style="font-size:15px;color:var(--c-on-surface-2);margin:0 0 28px;line-height:1.5;">{$t.onboardingProfileSub}</p>

          <!-- Weight field -->
          <div class="flex items-center justify-between py-sm" style="margin-bottom:4px;">
            <label for="ob-weight" style="font-size:15px;font-weight:600;color:var(--c-on-surface);">{$t.bodyWeight}</label>
            <div class="flex items-center gap-xs">
              <input id="ob-weight" type="number" inputmode="decimal" bind:value={weight} min="1" max="400" step="1" placeholder="75"
                class="w-24 text-right text-body-strong text-[--c-on-surface] focus:outline-none"
                style="height:44px;border-radius:14px;padding:0 14px;background:var(--c-surface-input);"
                enterkeyhint="next"
                on:focus={focusInput} on:keydown={blurOnEnter} />
              <span class="text-caption-sm text-[--c-on-surface-2] w-5">{imperial ? 'lbs' : 'kg'}</span>
            </div>
          </div>

          <!-- FTP field -->
          <div class="flex items-center justify-between py-sm" style="margin-bottom:4px;">
            <div>
              <label for="ob-ftp" style="font-size:15px;font-weight:600;color:var(--c-on-surface);display:block;">{$t.ftpLabel}</label>
              <span style="font-size:13px;color:var(--c-on-surface-2);">{$t.ftpSub}</span>
            </div>
            <div class="flex items-center gap-xs">
              <input id="ob-ftp" type="number" inputmode="numeric" bind:value={ftp} min="0" max="600" step="1" placeholder="280"
                class="w-24 text-right text-body-strong text-[--c-on-surface] focus:outline-none"
                style="height:44px;border-radius:14px;padding:0 14px;background:var(--c-surface-input);"
                enterkeyhint="done"
                on:focus={focusInput} on:keydown={blurOnEnter} />
              <span class="text-caption-sm text-[--c-on-surface-2] w-5">W</span>
            </div>
          </div>

          <!-- Units toggle -->
          <div class="flex items-center justify-between py-md gap-md flex-wrap" style="margin-bottom:4px;">
            <span style="font-size:15px;font-weight:600;color:var(--c-on-surface);">{$t.units}</span>
            <div style="position:relative;display:flex;border-radius:14px;border:1px solid var(--c-border-input);background:var(--c-surface-seg);padding:3px;">
              <div style="position:absolute;top:3px;bottom:3px;width:calc(50% - 3px);border-radius:10px;background:var(--c-seg-active);box-shadow:0 1px 3px rgba(0,0,0,0.15);transform:translateX({imperial ? 'calc(100% + 3px)' : '0'});transition:transform 0.22s cubic-bezier(0.35,0,0.25,1);pointer-events:none;will-change:transform;"></div>
              <button
                style="position:relative;flex:1;padding:6px 18px;font-size:13px;font-weight:500;white-space:nowrap;color:{!imperial ? 'var(--c-seg-active-text)' : 'var(--c-on-surface-2)'};transition:color 0.22s cubic-bezier(0.35,0,0.25,1);background:transparent;border:none;"
                on:click={() => { if (imperial) toggleImperial(); }}>{$t.kmKg}</button>
              <button
                style="position:relative;flex:1;padding:6px 18px;font-size:13px;font-weight:500;white-space:nowrap;color:{imperial ? 'var(--c-seg-active-text)' : 'var(--c-on-surface-2)'};transition:color 0.22s cubic-bezier(0.35,0,0.25,1);background:transparent;border:none;"
                on:click={() => { if (!imperial) toggleImperial(); }}>{$t.miLbs}</button>
            </div>
          </div>

          <div class="flex-1"></div>
        </div>

        <div class="px-6" style="padding-bottom:8px;">
          <button
            on:click={() => { if (weight > 0 && ftp > 0) onboardingStep = 2; }}
            style="width:100%;height:52px;border-radius:14px;background:var(--c-seg-active);color:var(--c-seg-active-text);font-size:17px;font-weight:600;border:none;cursor:pointer;opacity:{weight > 0 && ftp > 0 ? '1' : '0.4'};pointer-events:{weight > 0 && ftp > 0 ? 'auto' : 'none'};transition:opacity 0.2s;">
            {$t.onboardingNext} →
          </button>
        </div>
        <!-- Progress dots -->
        <div class="flex items-center justify-center gap-2 pt-4">
          <span style="width:8px;height:8px;border-radius:50%;background:var(--c-border-input);display:block;"></span>
          <span style="width:8px;height:8px;border-radius:50%;background:var(--c-seg-active);display:block;"></span>
          <span style="width:8px;height:8px;border-radius:50%;background:var(--c-border-input);display:block;"></span>
          <span style="width:8px;height:8px;border-radius:50%;background:var(--c-border-input);display:block;"></span>
        </div>

      <!-- Step 2: Products (optional) -->
      {:else if onboardingStep === 2}
        <div class="flex flex-col flex-1 px-6 pt-2"
          in:fly={{ x: 40, duration: 280, easing: cubicOut }}>
          <!-- Nav row -->
          <div class="flex items-center justify-between" style="margin-bottom:8px;">
            <button
              on:click={() => { onboardingStep = 1; }}
              style="height:44px;padding:0 4px;background:transparent;border:none;cursor:pointer;font-size:15px;font-weight:500;color:var(--c-on-surface-2);display:flex;align-items:center;gap:4px;">
              ← {$t.onboardingProfileTitle}
            </button>
            <button
              on:click={() => { onboardingStep = 3; }}
              style="height:44px;padding:0 4px;background:transparent;border:none;cursor:pointer;font-size:15px;font-weight:500;color:var(--c-on-surface-2);">
              {$t.onboardingSkip} →
            </button>
          </div>

          <h2 style="font-size:22px;font-weight:700;color:var(--c-on-surface);margin:0 0 8px;">{$t.onboardingProductsTitle}</h2>
          <p style="font-size:15px;color:var(--c-on-surface-2);margin:0 0 24px;line-height:1.5;">{$t.onboardingProductsSub}</p>

          <!-- Add product form — 2-row layout for narrow screens -->
          <div style="display:flex;flex-direction:column;gap:8px;margin-bottom:8px;">
            <input
              type="text"
              bind:value={_obProductName}
              placeholder={$t.productNamePlaceholder}
              style="width:100%;height:44px;border-radius:12px;padding:0 14px;background:var(--c-surface-input);border:none;font-size:15px;color:var(--c-on-surface);box-sizing:border-box;"
              enterkeyhint="next"
              on:focus={focusInput} on:keydown={blurOnEnter} />
            <div style="display:flex;gap:8px;align-items:center;">
              <input
                type="number"
                inputmode="numeric"
                bind:value={_obProductCarbs}
                placeholder="25"
                min="1" max="200"
                style="width:72px;height:44px;border-radius:12px;padding:0 12px;background:var(--c-surface-input);border:none;font-size:15px;color:var(--c-on-surface);text-align:center;flex-shrink:0;"
                enterkeyhint="done"
                on:focus={focusInput} on:keydown={blurOnEnter} />
              <span style="font-size:13px;color:var(--c-on-surface-2);white-space:nowrap;flex-shrink:0;">{$t.productCarbsUnit}</span>
              <button
                on:click={() => { addCustomProduct(_obProductName, _obProductCarbs ?? 0); _obProductName = ''; _obProductCarbs = undefined; }}
                style="flex:1;height:44px;border-radius:12px;background:var(--c-seg-active);color:var(--c-seg-active-text);border:none;cursor:pointer;font-size:15px;font-weight:600;opacity:{_obProductName.trim() && _obProductCarbs > 0 ? '1' : '0.4'};pointer-events:{_obProductName.trim() && _obProductCarbs > 0 ? 'auto' : 'none'};transition:opacity 0.15s;">
                {$t.addProduct}
              </button>
            </div>
          </div>

          <p style="font-size:13px;color:var(--c-on-surface-3);margin:0 0 16px;line-height:1.4;">{$t.productCarbsHint}</p>

          <!-- Added products list -->
          {#each customProducts as p (p.id)}
            <div class="flex items-center justify-between" style="border-bottom:1px solid var(--c-border);min-height:44px;">
              <span style="font-size:15px;color:var(--c-on-surface);">{p.label}</span>
              <div class="flex items-center gap-2">
                <span style="font-size:14px;color:var(--c-on-surface-2);">{p.carbs}g</span>
                <button
                  on:click={() => removeCustomProduct(p.id)}
                  style="width:44px;height:44px;display:flex;align-items:center;justify-content:center;background:transparent;border:none;cursor:pointer;color:var(--c-on-surface-2);"
                  aria-label={$t.deleteProduct}>
                  <X size={16} />
                </button>
              </div>
            </div>
          {/each}

          {#if customProducts.length === 0}
            <p style="font-size:14px;color:var(--c-on-surface-3);margin:8px 0 0;">{$t.noCustomProducts}</p>
          {/if}

          <div class="flex-1"></div>
        </div>

        <div class="px-6" style="padding-bottom:8px;">
          <button
            on:click={() => { onboardingStep = 3; }}
            style="width:100%;height:52px;border-radius:14px;background:var(--c-seg-active);color:var(--c-seg-active-text);font-size:17px;font-weight:600;border:none;cursor:pointer;transition:opacity 0.15s;">
            {$t.onboardingNext} →
          </button>
        </div>
        <!-- Progress dots (4) -->
        <div class="flex items-center justify-center gap-2 pt-4">
          <span style="width:8px;height:8px;border-radius:50%;background:var(--c-border-input);display:block;"></span>
          <span style="width:8px;height:8px;border-radius:50%;background:var(--c-border-input);display:block;"></span>
          <span style="width:8px;height:8px;border-radius:50%;background:var(--c-seg-active);display:block;"></span>
          <span style="width:8px;height:8px;border-radius:50%;background:var(--c-border-input);display:block;"></span>
        </div>

      <!-- Step 3: Done -->
      {:else if onboardingStep === 3}
        <div class="flex flex-col flex-1 items-center justify-center px-8"
          in:fly={{ x: 40, duration: 280, easing: cubicOut }}>
          <div style="width:72px;height:72px;border-radius:50%;background:var(--c-seg-active);color:var(--c-seg-active-text);display:flex;align-items:center;justify-content:center;margin-bottom:24px;">
            <Check class="w-9 h-9" />
          </div>
          <h2 style="font-size:24px;font-weight:700;color:var(--c-on-surface);margin:0 0 12px;text-align:center;">{$t.onboardingReadyTitle}</h2>
          <p style="font-size:15px;color:var(--c-on-surface-2);text-align:center;max-width:300px;line-height:1.5;margin:0;">{$t.onboardingReadySub}</p>
        </div>
        <div class="px-6" style="padding-bottom:8px;display:flex;flex-direction:column;gap:10px;">
          <button
            on:click={() => { _onboardingStartTour = true; onboardingStep = 4; }}
            style="width:100%;height:52px;border-radius:14px;background:var(--c-seg-active);color:var(--c-seg-active-text);font-size:17px;font-weight:600;border:none;cursor:pointer;transition:opacity 0.15s;">
            {$t.tourStartTour}
          </button>
          <button
            on:click={() => { _onboardingStartTour = false; onboardingStep = 4; }}
            style="width:100%;height:44px;border-radius:14px;background:transparent;color:var(--c-on-surface-2);font-size:15px;border:none;cursor:pointer;">
            {$t.tourSkipTour}
          </button>
        </div>
        <!-- Progress dots (5) -->
        <div class="flex items-center justify-center gap-2 pt-4">
          <span style="width:8px;height:8px;border-radius:50%;background:var(--c-border-input);display:block;"></span>
          <span style="width:8px;height:8px;border-radius:50%;background:var(--c-border-input);display:block;"></span>
          <span style="width:8px;height:8px;border-radius:50%;background:var(--c-border-input);display:block;"></span>
          <span style="width:8px;height:8px;border-radius:50%;background:var(--c-seg-active);display:block;"></span>
          <span style="width:8px;height:8px;border-radius:50%;background:var(--c-border-input);display:block;"></span>
        </div>
      {:else if onboardingStep === 4}
        <div class="flex flex-col flex-1 px-8 pt-6"
          in:fly={{ x: 40, duration: 280, easing: cubicOut }}>
          <div style="width:52px;height:52px;border-radius:50%;background:rgba(255,180,0,0.15);color:#f59e0b;display:flex;align-items:center;justify-content:center;margin-bottom:20px;flex-shrink:0;">
            <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg>
          </div>
          <h2 style="font-size:22px;font-weight:700;color:var(--c-on-surface);margin:0 0 16px;">{$t.onboardingDisclaimerTitle}</h2>
          <p style="font-size:15px;color:var(--c-on-surface-2);line-height:1.6;margin:0 0 12px;white-space:pre-line;">{$t.onboardingDisclaimerBody}</p>
          <p style="font-size:12px;color:var(--c-on-surface-3);margin:0;">{$t.onboardingDisclaimerSources}</p>
        </div>
        <div class="px-6" style="padding-bottom:8px;">
          <button
            on:click={() => { finishOnboarding(); if (_onboardingStartTour) setTimeout(() => { howToSlide = 0; showHowToSheet = true; }, 250); }}
            style="width:100%;height:52px;border-radius:14px;background:var(--c-seg-active);color:var(--c-seg-active-text);font-size:17px;font-weight:600;border:none;cursor:pointer;transition:opacity 0.15s;">
            {$t.onboardingDisclaimerAccept}
          </button>
        </div>
        <!-- Progress dots (5) -->
        <div class="flex items-center justify-center gap-2 pt-4">
          <span style="width:8px;height:8px;border-radius:50%;background:var(--c-border-input);display:block;"></span>
          <span style="width:8px;height:8px;border-radius:50%;background:var(--c-border-input);display:block;"></span>
          <span style="width:8px;height:8px;border-radius:50%;background:var(--c-border-input);display:block;"></span>
          <span style="width:8px;height:8px;border-radius:50%;background:var(--c-border-input);display:block;"></span>
          <span style="width:8px;height:8px;border-radius:50%;background:var(--c-seg-active);display:block;"></span>
        </div>
      {/if}

    </div>
  {/if}

  <!-- ── Disclaimer modal for existing users (already onboarded, no disclaimer yet) ── -->
  {#if onboardingStep < 0 && !disclaimerAccepted}
    <div class="fixed inset-0 z-[999] flex flex-col items-center justify-end"
      style="background:rgba(0,0,0,0.6);"
      transition:fade={{ duration: 200 }}>
      <div class="w-full max-w-lg rounded-t-[28px] px-6 pt-6"
        style="background:var(--c-surface);color:var(--c-on-surface);padding-bottom:max(32px,calc(env(safe-area-inset-bottom,0px) + 16px));"
        in:fly={{ y: 400, duration: 380, easing: quintOut }}>
        <div style="width:36px;height:4px;border-radius:2px;background:var(--c-border-input);margin:0 auto 24px;"></div>
        <div style="width:52px;height:52px;border-radius:50%;background:rgba(255,180,0,0.15);color:#f59e0b;display:flex;align-items:center;justify-content:center;margin-bottom:20px;">
          <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg>
        </div>
        <h2 style="font-size:22px;font-weight:700;margin:0 0 16px;">{$t.onboardingDisclaimerTitle}</h2>
        <p style="font-size:15px;color:var(--c-on-surface-2);line-height:1.6;margin:0 0 8px;white-space:pre-line;">{$t.onboardingDisclaimerBody}</p>
        <p style="font-size:12px;color:var(--c-on-surface-3);margin:0 0 24px;">{$t.onboardingDisclaimerSources}</p>
        <button
          on:click={acceptDisclaimer}
          style="width:100%;height:52px;border-radius:14px;background:var(--c-seg-active);color:var(--c-seg-active-text);font-size:17px;font-weight:600;border:none;cursor:pointer;">
          {$t.onboardingDisclaimerAccept}
        </button>
      </div>
    </div>
  {/if}

  <!-- ── How-To Tour sheet ──────────────────────────────── -->
  {#if showHowToSheet}
    <div class="fixed inset-0 z-[996] bg-black/55"
      on:click={() => { showHowToSheet = false; howToSlide = 0; }} role="presentation"
      transition:fade={{ duration: 220 }}></div>

    <div class="fixed bottom-0 left-0 right-0 z-[998] rounded-t-[28px] max-w-lg mx-auto"
      style="background:var(--c-surface);box-shadow:var(--c-shadow-sheet);padding-bottom:max(32px,calc(env(safe-area-inset-bottom,0px) + 16px));"
      in:fly={{ y: 480, duration: 420, easing: quintOut }}
      out:fly={{ y: 480, duration: 240, easing: cubicIn }}>

      <!-- Drag handle -->
      <div class="w-10 h-1 rounded-full mx-auto mt-3 mb-1" style="background:var(--c-drag-handle);"></div>

      <!-- Slide area — fixed height, overflow hidden for key-transition -->
      <div style="position:relative;overflow:hidden;height:248px;margin:8px 24px 0;"
        on:touchstart={onTourSwipeStart}
        on:touchend={onTourSwipeEnd}
        role="region" aria-label="Tour slides">

        {#key howToSlide}
          <div style="position:absolute;inset:0;display:flex;flex-direction:column;"
            in:fly={{ x: _tourDir * 72, duration: 300, easing: cubicOut }}
            out:fly={{ x: -_tourDir * 72, duration: 200, easing: cubicIn }}>

            <!-- Illustration — flex:1 so it fills available space above text -->
            <div style="flex:1;display:flex;align-items:center;justify-content:center;min-height:0;">

              {#if howToSlide === 0}
                <!-- Slide 0: Two inputs → result badge -->
                <div style="display:flex;flex-direction:column;align-items:center;gap:6px;">
                  <div style="width:250px;height:44px;border-radius:12px;background:var(--c-surface-soft);display:flex;align-items:center;justify-content:space-between;padding:0 16px;animation:tour-slide-in 0.35s both 0.05s;">
                    <span style="font-size:14px;color:var(--c-on-surface-2);">{$lang === 'de' ? 'Dauer' : 'Duration'}</span>
                    <span style="font-size:15px;font-weight:600;color:var(--c-on-surface);">1:30 h</span>
                  </div>
                  <div style="width:250px;height:44px;border-radius:12px;background:var(--c-surface-soft);display:flex;align-items:center;justify-content:space-between;padding:0 16px;animation:tour-slide-in 0.35s both 0.18s;">
                    <span style="font-size:14px;color:var(--c-on-surface-2);">Power</span>
                    <span style="font-size:15px;font-weight:600;color:var(--c-on-surface);">220 W</span>
                  </div>
                  <div style="font-size:16px;color:var(--c-on-surface-3);animation:tour-fade-up 0.25s both 0.38s;line-height:1;">↓</div>
                  <div style="background:#f73b20;color:#ffffff;border-radius:20px;padding:7px 20px;font-size:15px;font-weight:700;animation:tour-pop 0.42s both 0.52s;">Tempo · 60 g/h</div>
                </div>

              {:else if howToSlide === 1}
                <!-- Slide 1: Zone bars -->
                <div style="display:flex;flex-direction:column;align-items:center;gap:10px;">
                  <div style="display:flex;gap:3px;height:64px;width:288px;border-radius:12px;overflow:hidden;">
                    <div style="flex:1;background:#94a3b8;display:flex;align-items:flex-end;padding:0 0 6px 6px;animation:tour-zone-rise 0.3s both 0.08s;">
                      <span style="font-size:9px;font-weight:600;color:#fff;">R</span>
                    </div>
                    <div style="flex:1;background:#477ee9;display:flex;align-items:flex-end;padding:0 0 6px 5px;animation:tour-zone-rise 0.3s both 0.18s;">
                      <span style="font-size:9px;font-weight:600;color:#fff;">E</span>
                    </div>
                    <div style="flex:1;background:#f59e0b;display:flex;align-items:flex-end;padding:0 0 6px 5px;animation:tour-zone-rise 0.3s both 0.28s;">
                      <span style="font-size:9px;font-weight:600;color:#fff;">T</span>
                    </div>
                    <div style="flex:1.3;background:#f73b20;border-radius:0;display:flex;align-items:flex-end;padding:0 0 6px 6px;animation:tour-zone-rise 0.35s both 0.38s,tour-zone-pulse 1.4s ease-in-out 0.8s 3;">
                      <span style="font-size:10px;font-weight:700;color:#fff;">S</span>
                    </div>
                    <div style="flex:1;background:#be185d;display:flex;align-items:flex-end;padding:0 0 6px 4px;animation:tour-zone-rise 0.3s both 0.48s;">
                      <span style="font-size:9px;font-weight:600;color:#fff;">V</span>
                    </div>
                  </div>
                  <div style="display:flex;gap:3px;width:288px;animation:tour-fade-up 0.28s both 0.62s;">
                    <span style="flex:1;font-size:9px;color:var(--c-on-surface-3);text-align:center;">0–20</span>
                    <span style="flex:1;font-size:9px;color:var(--c-on-surface-3);text-align:center;">20–40</span>
                    <span style="flex:1;font-size:9px;color:var(--c-on-surface-3);text-align:center;">40–60</span>
                    <span style="flex:1.3;font-size:11px;font-weight:700;color:#f73b20;text-align:center;">60–90</span>
                    <span style="flex:1;font-size:9px;color:var(--c-on-surface-3);text-align:center;">90+</span>
                  </div>
                  <span style="font-size:12px;color:var(--c-on-surface-2);animation:tour-fade-up 0.28s both 0.78s;">g {$lang === 'de' ? 'Kohlenhydrate' : 'carbs'} / h</span>
                </div>

              {:else if howToSlide === 2}
                <!-- Slide 2: Schedule timeline — labels in separate row so dot center is exact -->
                {@const COL = 50}
                {@const TIMES = ['0:20','0:40','1:00','1:20','1:40']}
                <div style="display:flex;flex-direction:column;gap:5px;width:{COL * 5}px;">
                  <!-- Icon + dot row (line at bottom:5px → center at 6px = dot center) -->
                  <div style="position:relative;">
                    <div style="position:absolute;bottom:5px;left:{COL / 2}px;right:{COL / 2}px;height:2px;background:var(--c-border);border-radius:2px;overflow:hidden;">
                      <div style="height:100%;background:var(--c-on-surface-2);border-radius:2px;transform-origin:left;animation:tour-line-draw 0.55s cubic-bezier(0.4,0,0.2,1) both 0.1s;"></div>
                    </div>
                    <div style="display:flex;justify-content:space-between;">
                      {#each [0,1,2,3,4] as i}
                        <div style="width:{COL}px;display:flex;flex-direction:column;align-items:center;gap:6px;">
                          <div style="width:28px;height:28px;border-radius:50%;background:var(--c-surface-soft);display:flex;align-items:center;justify-content:center;animation:tour-dot-pop 0.3s both {0.1 + i * 0.12}s;">
                            <Wheat size={13} style="color:#f73b20;" />
                          </div>
                          <div style="width:12px;height:12px;border-radius:50%;background:var(--c-seg-active);animation:tour-dot-pop 0.26s both {0.48 + i * 0.1}s;"></div>
                        </div>
                      {/each}
                    </div>
                  </div>
                  <!-- Time labels row — separate so they don't affect dot position -->
                  <div style="display:flex;justify-content:space-between;">
                    {#each TIMES as label, i}
                      <span style="width:{COL}px;text-align:center;font-size:10px;color:var(--c-on-surface-2);animation:tour-fade-up 0.24s both {1.0 + i * 0.05}s;">{label}</span>
                    {/each}
                  </div>
                </div>

              {:else}
                <!-- Slide 3: Products only -->
                <div style="display:flex;flex-direction:column;align-items:center;gap:14px;">
                  <!-- Product pill selector mockup -->
                  <div style="display:flex;gap:4px;background:var(--c-surface-soft);border-radius:14px;padding:4px;animation:tour-slide-in 0.35s both 0.05s;">
                    {#each ['Gel','Bar', customProducts.length > 0 ? customProducts[0].label : ($lang === 'de' ? 'Eigenes' : 'Custom')] as label, i}
                      <div style="padding:7px 14px;border-radius:10px;font-size:14px;font-weight:{i === 2 ? '700' : '500'};background:{i === 2 ? 'var(--c-seg-active)' : 'transparent'};color:{i === 2 ? 'var(--c-seg-active-text)' : 'var(--c-on-surface-2)'};animation:tour-pop 0.32s both {0.1 + i * 0.14}s;">
                        {label}
                      </div>
                    {/each}
                  </div>
                  <!-- Checkmark + carbs label for active product -->
                  <div style="display:flex;align-items:center;gap:8px;animation:tour-fade-up 0.3s both 0.55s;">
                    <div style="width:24px;height:24px;border-radius:50%;background:var(--c-seg-active);display:flex;align-items:center;justify-content:center;">
                      <Check size={14} style="color:var(--c-seg-active-text);" />
                    </div>
                    <span style="font-size:14px;color:var(--c-on-surface-2);">{customProducts.length > 0 ? customProducts[0].carbs : 22}g {$lang === 'de' ? 'KH pro Portion' : 'carbs per serving'}</span>
                  </div>
                  <!-- Settings hint -->
                  <div style="display:flex;align-items:center;gap:6px;animation:tour-fade-up 0.3s both 0.8s;">
                    <SlidersHorizontal size={14} style="color:var(--c-on-surface-3);" />
                    <span style="font-size:12px;color:var(--c-on-surface-3);">{$lang === 'de' ? 'Einstellungen → Eigene Produkte' : 'Settings → Custom Products'}</span>
                  </div>
                </div>
              {/if}

            </div>

            <!-- Title + body text — fixed height anchored at bottom -->
            <div style="flex-shrink:0;text-align:center;padding:0 8px 4px;">
              <h3 style="font-size:17px;font-weight:700;color:var(--c-on-surface);margin:0 0 6px;">
                {[$t.tourSlide0Title,$t.tourSlide1Title,$t.tourSlide2Title,$t.tourSlide3Title][howToSlide]}
              </h3>
              <p style="font-size:14px;color:var(--c-on-surface-2);margin:0;line-height:1.45;">
                {[$t.tourSlide0Body,$t.tourSlide1Body,$t.tourSlide2Body,$t.tourSlide3Body][howToSlide]}
              </p>
            </div>

          </div>
        {/key}
      </div>

      <!-- Dots + nav -->
      <div style="padding:16px 24px 0;display:flex;flex-direction:column;gap:12px;">
        <!-- Dot indicators -->
        <div style="display:flex;align-items:center;justify-content:center;gap:6px;">
          {#each [0,1,2,3] as i}
            <button on:click={() => { _tourDir = i > howToSlide ? 1 : -1; howToSlide = i; }}
              aria-label="Slide {i + 1}"
              style="width:{i === howToSlide ? 20 : 7}px;height:7px;border-radius:4px;background:{i === howToSlide ? 'var(--c-seg-active)' : 'var(--c-border-input)'};border:none;cursor:pointer;transition:width 0.25s,background 0.2s;padding:0;"></button>
          {/each}
        </div>
        <!-- Buttons -->
        <div style="display:flex;gap:8px;">
          {#if howToSlide > 0}
            <button on:click={tourBack}
              style="flex:1;height:48px;border-radius:14px;background:var(--c-surface-soft);color:var(--c-on-surface);font-size:15px;font-weight:600;border:1px solid var(--c-border-input);cursor:pointer;">
              ←
            </button>
          {/if}
          <button on:click={tourNext}
            style="flex:3;height:48px;border-radius:14px;background:var(--c-seg-active);color:var(--c-seg-active-text);font-size:15px;font-weight:600;border:none;cursor:pointer;">
            {howToSlide < 3 ? $t.tourNext : $t.tourDone}
          </button>
        </div>
      </div>

    </div>
  {/if}

</main>
