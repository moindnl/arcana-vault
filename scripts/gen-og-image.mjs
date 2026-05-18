/**
 * Generate public/og-image.png (1200×630) for social sharing
 *
 * Usage: node scripts/gen-og-image.mjs
 */

import pkg from '/Users/daniel/.claude/skills/lighthouse-runner/node_modules/playwright-core/index.js';
const { chromium } = pkg;
import { readFileSync, writeFileSync } from 'fs';
import { resolve, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dir = dirname(fileURLToPath(import.meta.url));
const ROOT   = resolve(__dir, '..');
const PUBLIC = resolve(ROOT, 'public');

const svgSrc = readFileSync(resolve(PUBLIC, 'favicon.svg'), 'utf8');
const W = 1200, H = 630;

const htmlContent = `<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <link href="https://fonts.googleapis.com/css2?family=DM+Sans:ital,opsz,wght@0,9..40,400;0,9..40,500;0,9..40,700;0,9..40,800;1,9..40,700;1,9..40,800&display=swap" rel="stylesheet">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    html, body { width: ${W}px; height: ${H}px; overflow: hidden; }
    body {
      font-family: 'DM Sans', -apple-system, sans-serif;
      display: flex;
      align-items: center;
      padding: 0 100px;
      gap: 80px;
      background: radial-gradient(ellipse at 25% 45%, #23232e 0%, #0f0f14 60%);
    }
    .icon-wrap { flex-shrink: 0; width: 220px; height: 220px; }
    .icon-wrap svg { width: 220px; height: 220px; display: block; }
    .text { display: flex; flex-direction: column; gap: 22px; }
    .wordmark {
      font-size: 96px;
      font-weight: 800;
      line-height: 0.9;
      letter-spacing: -0.035em;
    }
    .bonk  { color: #f4f4f5; font-style: italic; }
    .proof { color: #f73b20; }
    .tagline {
      font-size: 30px;
      font-weight: 500;
      color: #71717a;
      letter-spacing: -0.01em;
    }
    .pills { display: flex; gap: 10px; }
    .pill {
      background: rgba(247,59,32,0.10);
      border: 1px solid rgba(247,59,32,0.28);
      color: #f73b20;
      border-radius: 999px;
      padding: 7px 18px;
      font-size: 16px;
      font-weight: 600;
    }
  </style>
</head>
<body>
  <div class="icon-wrap">${svgSrc}</div>
  <div class="text">
    <div class="wordmark">
      <span class="bonk">bonk</span><span class="proof">proof!</span>
    </div>
    <div class="tagline">Cycling Nutrition Planner</div>
    <div class="pills">
      <span class="pill">FTP-based carbs</span>
      <span class="pill">Fluid targets</span>
      <span class="pill">Fueling schedule</span>
    </div>
  </div>
</body>
</html>`;

const browser = await chromium.launch({
  executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  args: ['--no-sandbox'],
});
const page = await browser.newPage();
await page.setViewportSize({ width: W, height: H });
await page.setContent(htmlContent, { waitUntil: 'networkidle' });

const buf = await page.screenshot({
  type: 'png',
  clip: { x: 0, y: 0, width: W, height: H },
  omitBackground: false,
});

writeFileSync(resolve(PUBLIC, 'og-image.png'), buf);
console.log(`✓ public/og-image.png (${W}×${H})`);

await browser.close();
