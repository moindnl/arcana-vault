# BananaSprocket — Cycling Nutrition Planner

Precision carbohydrate and fluid targets for endurance cyclists, calculated from FTP and ride power output.

## Features

- **Power-based carb formula** — piecewise model by Intensity Factor (Jeukendrup / ACSM). Two riders at the same watts get different recommendations based on their FTP.
- **Zone detection** — Recovery → Endurance → Tempo → Threshold → VO₂max+, driven by % FTP
- **Weight-scaled fluids** — larger athletes sweat more; fluid targets scale accordingly
- **Energy expenditure** — kcal/h via `power × 3.6` (cycling mechanical efficiency standard)
- **Speed + animal badge** — average pace with Wikipedia-linked animal comparison
- **Mobile sticky bar** — liquid glass overlay showing carbs/fluids/kcal per hour, always visible while scrolling
- **Zone-reactive banana** — pendulum idle animation, color shifts yellow → red with intensity
- **WCAG 2.1 AA** — 100/100 accessibility score

## Science

| Zone | % FTP | Carbs |
|---|---|---|
| Recovery | < 55% | 0–20 g/h |
| Endurance | 55–75% | 20–40 g/h |
| Tempo | 75–90% | 40–60 g/h |
| Threshold | 90–105% | 60–90 g/h |
| VO₂max+ | > 105% | 90–120 g/h (glucose+fructose 2:1 required) |

## Tech Stack

- **Framework**: Svelte 5 + Vite (plain, no SvelteKit)
- **Styling**: Tailwind CSS v4 with Nike design tokens
- **Icons**: Tabler Icons (`@tabler/icons-svelte-runes`)
- **Animations**: `svelte/motion` tweened stores, CSS keyframes

## Installation

```bash
pnpm install
pnpm dev
```

## Project Structure

```
├── src/
│   ├── App.svelte    # Single-component app
│   ├── app.css       # Nike design tokens + animations + liquid glass
│   └── main.js       # Entry point
├── vite.config.js
└── index.html
```

## License

MIT
