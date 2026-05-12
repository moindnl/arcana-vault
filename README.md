# BananaSprocket - Nutrition Planner for Endurance Cyclists

A web application for calculating optimal carbohydrate and fluid intake during long endurance cycling tours.

## Features

- **Personalized Calculations**: Enter your distance, duration, and weight to get tailored nutrition recommendations
- **Intensity Levels**: Choose from Low, Moderate, High, or Extreme intensity
- **Speed Tracking**: View your average speed with fun animal-themed descriptions
- **Responsive Design**: Works on mobile and desktop devices
- **Animated UI**: Smooth number transitions and interactive elements

## Design System

This application uses the **Nike Design System** as documented at:
- https://getdesign.md/nike/design-md

The styling follows Nike's design tokens for colors, typography, spacing, and components.

## Tech Stack

- **Framework**: SvelteKit with Svelte 5
- **Styling**: Tailwind CSS with custom Nike design tokens
- **Icons**: Tabler Icons (svelte-runes)
- **Animations**: Svelte Motion for number animations

## Usage

1. Enter your ride distance (km)
2. Enter your expected duration (hours)
3. Enter your weight (kg)
4. Select your training intensity
5. View your recommended carbohydrate and fluid intake per hour
6. See your average speed with a clickable animal badge that links to Wikipedia

## Speed Slogans

The app displays fun animal-themed slogans based on your speed:

| Speed Range | Animal Slogan | Wikipedia Link |
|-------------|---------------|----------------|
| < 10 km/h | Turtle pace | [Turtle](https://en.wikipedia.org/wiki/Turtle) |
| 10-15 km/h | Penguin cruise | [Penguin](https://en.wikipedia.org/wiki/Penguin) |
| 15-20 km/h | Gazelle pace | [Gazelle](https://en.wikipedia.org/wiki/Gazelle) |
| 20-25 km/h | Cheetah chase | [Cheetah](https://en.wikipedia.org/wiki/Cheetah) |
| 25-30 km/h | Falcon flight | [Falcon](https://en.wikipedia.org/wiki/Falcon) |
| 30-40 km/h | Peregrine speed | [Peregrine falcon](https://en.wikipedia.org/wiki/Peregrine_falcon) |
| 40+ km/h | Greyhound sprint | [Greyhound](https://en.wikipedia.org/wiki/Greyhound) |

## Project Structure

```
stryx-engine/
├── src/
│   ├── App.svelte          # Main application
│   ├── app.css            # Nike design tokens + custom styles
│   └── main.js            # Entry point
├── package.json
├── README.md
└── .gitignore
```

## Installation

```bash
npm install
npm run dev
```

## License

MIT

## References

- [Nike Design System - DESIGN.md](https://getdesign.md/nike/design-md)
- [Svelte](https://svelte.dev/)
- [Tabler Icons](https://tabler-icons.io/)
