/**
 * Generate all app icons from public/favicon.svg
 *
 * PWA icons  → public/  (rounded corners preserved from SVG)
 * App Store  → public/appstore/  (rx="0", Apple applies its own corner mask)
 *
 * Usage: node scripts/gen-icons.mjs
 */

import pkg from '/Users/daniel/.claude/skills/lighthouse-runner/node_modules/playwright-core/index.js';
const { chromium } = pkg;
import { readFileSync, mkdirSync, writeFileSync } from 'fs';
import { resolve, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dir  = dirname(fileURLToPath(import.meta.url));
const ROOT   = resolve(__dir, '..');
const PUBLIC = resolve(ROOT, 'public');
const AS_DIR = resolve(PUBLIC, 'appstore');
mkdirSync(AS_DIR, { recursive: true });

const svgSrc  = readFileSync(resolve(PUBLIC, 'favicon.svg'), 'utf8');
// App Store variant: flat corners (Apple applies squircle mask itself)
const svgFlat = svgSrc.replace(/rx="90"/, 'rx="0"');

// PWA / home-screen icons (rounded corners from SVG)
const PWA = [
  { size: 512,  file: 'icon-512x512.png' },
  { size: 192,  file: 'icon-192x192.png' },
  { size: 180,  file: 'apple-touch-icon.png' },
];

// App Store — all required sizes
// https://developer.apple.com/design/human-interface-guidelines/app-icons
const APP_STORE = [
  { size: 1024, note: 'App Store submission' },
  { size: 512,  note: 'iTunes artwork' },
  { size: 256,  note: 'macOS @2x 128pt' },
  { size: 180,  note: 'iPhone @3x 60pt' },
  { size: 167,  note: 'iPad Pro @2x 83.5pt' },
  { size: 152,  note: 'iPad @2x 76pt' },
  { size: 120,  note: 'iPhone @3x 40pt / @2x 60pt' },
  { size: 87,   note: 'iPhone @3x 29pt (Settings)' },
  { size: 80,   note: 'Spotlight @2x 40pt' },
  { size: 76,   note: 'iPad @1x 76pt' },
  { size: 58,   note: 'Settings @2x 29pt' },
  { size: 40,   note: 'Spotlight @1x 40pt' },
  { size: 29,   note: 'Settings @1x 29pt' },
  { size: 20,   note: 'Notification @1x 20pt' },
];

function html(svg, size) {
  return `<!DOCTYPE html><html><head><meta charset="utf-8">
<style>*{margin:0;padding:0}html,body{width:${size}px;height:${size}px;overflow:hidden;background:transparent}svg{width:${size}px;height:${size}px;display:block}</style>
</head><body>${svg}</body></html>`;
}

const browser = await chromium.launch({
  executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  args: ['--no-sandbox'],
});
const page = await browser.newPage();

async function render(svg, size, outPath) {
  await page.setViewportSize({ width: size, height: size });
  await page.setContent(html(svg, size), { waitUntil: 'networkidle' });
  const buf = await page.screenshot({
    type: 'png',
    clip: { x: 0, y: 0, width: size, height: size },
    omitBackground: false,
  });
  writeFileSync(outPath, buf);
  const rel = outPath.replace(ROOT + '/', '');
  console.log(`  ✓  ${String(size).padStart(4)}×${size}  →  ${rel}`);
}

console.log('\n📱  PWA / Home Screen icons:');
for (const { size, file } of PWA) {
  await render(svgSrc, size, resolve(PUBLIC, file));
}

console.log('\n🍎  App Store icons (flat corners):');
for (const { size, note } of APP_STORE) {
  await render(svgFlat, size, resolve(AS_DIR, `icon-${size}x${size}.png`));
  console.log(`       └─ ${note}`);
}

await browser.close();

console.log('\n✅  Done.');
console.log('   PWA icons updated in public/');
console.log('   App Store icons in public/appstore/');
console.log('   → Submit public/appstore/icon-1024x1024.png to App Store Connect\n');
