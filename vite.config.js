import { defineConfig } from 'vite';
import { svelte } from '@sveltejs/vite-plugin-svelte';
import tailwindcss from '@tailwindcss/vite';
import { VitePWA } from 'vite-plugin-pwa';
import { writeFileSync } from 'fs';
import { execSync } from 'child_process';

// Auto-generate public/version.json at build time using git commit hash
let _buildHash = '';
function versionPlugin() {
  return {
    name: 'version-json',
    config() {
      _buildHash = (() => {
        try { return execSync('git rev-parse --short HEAD').toString().trim(); }
        catch { return Date.now().toString(36); }
      })();
      writeFileSync('public/version.json', JSON.stringify({ hash: _buildHash }));
      return { define: { __BUILD_HASH__: JSON.stringify(_buildHash) } };
    },
  };
}

const isCapacitor = process.env.CAPACITOR_BUILD === '1';

export default defineConfig({
  plugins: [
    versionPlugin(),
    tailwindcss(),
    svelte(),
    VitePWA(isCapacitor ? { disable: true } : ({
      registerType: 'prompt',
      includeAssets: ['favicon.svg', 'apple-touch-icon.png', 'icon-192x192.png', 'icon-512x512.png', 'og-image.png'],
      manifest: {
        name: 'bonkproof — Cycling Nutrition',
        short_name: 'bonkproof',
        description: 'Precise carb & fluid targets from your FTP and ride data.',
        theme_color: '#111111',
        background_color: '#111111',
        display: 'standalone',
        orientation: 'portrait',
        scope: '/',
        start_url: '/',
        icons: [
          { src: 'apple-touch-icon.png', sizes: '180x180', type: 'image/png' },
          { src: 'icon-192x192.png',     sizes: '192x192', type: 'image/png' },
          { src: 'icon-512x512.png',     sizes: '512x512', type: 'image/png' },
          { src: 'icon-512x512.png',     sizes: '512x512', type: 'image/png', purpose: 'maskable' },
        ],
      },
      workbox: {
        globPatterns: ['**/*.{js,css,html,svg,png,woff2}'],
        globIgnores: ['appstore/**'],
        runtimeCaching: [
          {
            urlPattern: /^https:\/\/fonts\.googleapis\.com\/.*/i,
            handler: 'CacheFirst',
            options: {
              cacheName: 'google-fonts-cache',
              expiration: { maxEntries: 10, maxAgeSeconds: 60 * 60 * 24 * 365 },
              cacheableResponse: { statuses: [0, 200] },
            },
          },
        ],
      },
    })),
  ],
});
