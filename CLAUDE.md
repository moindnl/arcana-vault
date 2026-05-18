# Project Context

## Role
Native iOS developer. Target: latest iOS (iOS 18+). All implementation decisions judged against Apple HIG.

## iOS Design & UX Rules (always apply)

### Layout & Spacing
- Touch targets: min 44×44pt
- Content margins: 16pt from edge (safe area aware)
- Section separators: inset 16pt from leading edge
- Form rows: 44–56pt tall (UITableViewCell standard)

### Typography
- Section headers: .footnote (13pt), secondary label color, often uppercase
- Body/labels: .body (17pt) or .callout (16pt)
- Captions: .caption1 (12pt), .caption2 (11pt)
- No decorative bold on structural UI elements

### Components
- Cards/grouped sections: 16pt corner radius (UITableView inset grouped)
- Text fields: filled background (.roundedRect), no visible border
- Segmented controls: sliding pill, equal-width segments, iOS spring curve
- Buttons: full-width in sheets, primary on RIGHT in two-button rows
- Destructive/reset: small × in header, not large pill at bottom

### Sheets / Modals
- Bottom sheets: rounded top corners (~20pt), safe-area-inset-bottom padding
- Sheet buttons: `env(safe-area-inset-bottom)` clearance
- Drag handle: 36×4pt pill, centered at top

### Navigation
- No web-style footer in native app
- App icon / logo tap → About sheet
- Back/close: top-left (or swipe down for sheets)

### Color & Theming
- Semantic colors: primary label, secondary label, system background, grouped background
- Dark mode: test every surface; hardcoded colors forbidden on interactive elements
- CTA buttons: semantic var, not hardcoded hex

### Interaction
- Haptics on meaningful actions
- Spring animations: `cubic-bezier(0.35, 0, 0.25, 1)` (iOS UIKit spring approx)
- No hover states on mobile (touch-only)

### Accessibility
- WCAG 2.1 AA minimum
- `aria-label` on all icon-only buttons
- Dynamic Type support where feasible
