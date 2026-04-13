# Copilot Instructions — Digitex POS Terminal (Flutter)

## Project Overview
Native Flutter POS (Point of Sale) terminal application for Windows + macOS. Replaces the previous WebView wrapper with a fully native UI. Connects to the Digitex Django REST backend (`/api/`) with JWT authentication and multi-tenant support.

## Tech Stack
- **Framework**: Flutter 3.x (desktop: Windows + macOS)
- **State Management**: BLoC / Cubit (`flutter_bloc`)
- **HTTP**: Dio with interceptors (auth, tenant, retry)
- **Models**: `freezed` + `json_serializable` for immutable data classes
- **DI**: `get_it` service locator
- **Routing**: `go_router` with auth redirect guards
- **Storage**: `shared_preferences` (settings and tokens)
- **Localization**: Flutter `intl` with ARB files (uz, ru, en)
- **Window**: `window_manager` for desktop window control

## Architecture — Feature-First Clean Architecture

```
lib/
├── main.dart                    # Entry: DI init, window setup, runApp
├── app.dart                     # MaterialApp.router, theme, BLoC providers
├── core/                        # Cross-cutting infrastructure
│   ├── constants/               # Colors, theme, endpoints, keyboard shortcuts
│   ├── di/                      # get_it registrations
│   ├── network/                 # Dio client, auth interceptor, error types
│   ├── router/                  # GoRouter config with auth redirect
│   └── utils/                   # Formatters (currency, date)
├── features/                    # Feature modules (self-contained)
│   ├── auth/                    # Login, PIN lock, token management
│   │   ├── data/                # Repository + local storage
│   │   ├── domain/              # Models (User, AuthState)
│   │   └── presentation/        # BLoC + screens
│   ├── sale/                    # POS sale (cart, checkout, payment)
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   └── settings/                # App settings, printer config
├── shared/                      # Shared widgets + services
│   ├── widgets/                 # POS numpad, buttons, status bar
│   └── services/                # Printer, secure storage
└── l10n/                        # ARB localization files
```

Each feature is self-contained: `data/` (API calls, local storage), `domain/` (models, entities), `presentation/` (BLoC + UI).

## POS UX/UI Design Standards

### Core Principles
- **Minimalistic**: No decorative elements. Every pixel serves a function.
- **Speed-first**: Maximum 2 taps/clicks from idle to completing any sale action.
- **Touch + keyboard hybrid**: All actions accessible via both touch and keyboard shortcuts.
- **Dark mode default**: POS terminals often operate in dim environments; dark reduces eye strain and screen burn.

### Layout & Spacing
- **Minimum resolution**: 1024×768. Scale up gracefully for larger displays.
- **Tap targets**: Minimum 48×48dp; prefer 56dp+ for primary actions (Add to Cart, Pay, etc.).
- **Grid system**: 8dp base unit. All spacing in multiples of 8 (8, 16, 24, 32, 48).
- **Content density**: High — POS needs to show many products and cart items without scrolling. Use compact list items (48-56dp height) but keep tap targets generous.

### Color System
```dart
// Primary palette — dark-first
static const background    = Color(0xFF121212);  // Main background
static const surface       = Color(0xFF1E1E1E);  // Cards, panels
static const surfaceLight  = Color(0xFF2A2A2A);  // Elevated surfaces, hover
static const border        = Color(0xFF333333);  // Subtle borders

// Text
static const textPrimary   = Color(0xFFFFFFFF);  // Primary text
static const textSecondary = Color(0xFFB0B0B0);  // Labels, hints
static const textMuted     = Color(0xFF666666);  // Disabled text

// Accent & semantic
static const accent        = Color(0xFF2563EB);  // Primary CTA (blue)
static const accentHover   = Color(0xFF3B82F6);  // Hover state
static const success       = Color(0xFF22C55E);  // Paid, confirmed, in-stock
static const danger        = Color(0xFFEF4444);  // Delete, void, error
static const warning       = Color(0xFFF59E0B);  // Low stock, pending
static const info          = Color(0xFF06B6D4);  // Informational badges
```

### Typography
- **Prices & totals**: Monospace font (`RobotoMono` or system monospace). Right-aligned.
- **Labels & UI text**: System sans-serif (default Material font).
- **Font sizes**: 
  - Cart total: 28-32sp
  - Product price: 18-20sp
  - Body/labels: 14-16sp
  - Caption/badge: 12sp
- **Number formatting**: Always use locale-aware formatting. UZS amounts with space separator: `1 250 000 сўм`.

### Animation & Transitions
- **Maximum duration**: 150ms for any transition. No decorative animations.
- **Allowed animations**: Page fade (100ms), button press scale (50ms), error shake (200ms, 3 cycles).
- **Forbidden**: Slide transitions, hero animations, loading spinners longer than needed. Use skeleton placeholders for loading states instead.

### Keyboard Shortcuts (Desktop POS Standard)
```
F1–F12    → Quick category switch
Enter     → Add selected product to cart / Confirm action
Esc       → Cancel current operation / Close modal
F9        → Open payment dialog
F10       → Hold/park current sale
F11       → Recall held sale
Delete    → Remove selected cart item
+/-       → Increase/decrease quantity
Ctrl+F    → Focus search bar
Ctrl+L    → Lock screen (show PIN)
```

### Screen Layout Patterns

**Main Sale Screen** (split layout):
```
┌──────────────────────────────────────────────────────────┐
│ [Status Bar: User | Warehouse | Clock | Connection]      │
├────────────────────────────────┬─────────────────────────┤
│                                │                         │
│   Product Grid / Search        │   Cart (receipt-style)  │
│   (60-65% width)              │   (35-40% width)        │
│                                │                         │
│   ┌─────┐ ┌─────┐ ┌─────┐    │   Item 1   2×10,000    │
│   │Img  │ │ Img │ │ Img │    │   Item 2   1×25,000    │
│   │Name │ │Name │ │Name │    │   ──────────────────    │
│   │Price│ │Price│ │Price│    │   Subtotal:  45,000    │
│   └─────┘ └─────┘ └─────┘    │   Discount:  -5,000    │
│                                │   TOTAL:     40,000    │
│                                ├─────────────────────────┤
│   [Category tabs / filter]     │  [PAY] [HOLD] [CLEAR]  │
└────────────────────────────────┴─────────────────────────┘
```

**Payment Modal** (full-screen overlay):
```
┌──────────────────────────────────────────────────────────┐
│                    Payment                         [✕]   │
│                                                          │
│   Total Due:     40,000 сўм                              │
│                                                          │
│   [Cash]  [Card]  [Transfer]  [Mixed]                    │
│                                                          │
│   ┌──────────────────────────┐                           │
│   │    Amount: 50,000        │   Quick amounts:          │
│   └──────────────────────────┘   [50K] [100K] [200K]     │
│                                                          │
│   Change:  10,000 сўм                                    │
│                                                          │
│   [7] [8] [9]                                            │
│   [4] [5] [6]       [COMPLETE SALE]                      │
│   [1] [2] [3]                                            │
│   [0] [00] [C]                                           │
└──────────────────────────────────────────────────────────┘
```

**PIN Lock Screen** (full-screen):
```
┌──────────────────────────────────────────────────────────┐
│                                                          │
│                    🔒                                     │
│               Cashier Name                               │
│                                                          │
│              ● ● ● ○ ○ ○                                │
│                                                          │
│            [1] [2] [3]                                   │
│            [4] [5] [6]                                   │
│            [7] [8] [9]                                   │
│            [⌫] [0] [✓]                                   │
│                                                          │
│           Switch User                                    │
└──────────────────────────────────────────────────────────┘
```

### Error & Feedback Patterns
- **Success**: Brief inline toast (bottom-center, 2s auto-dismiss, green accent).
- **Warning**: Amber toast, stays until dismissed or 5s.
- **Error**: Red toast with action button (e.g., "Retry"). Non-blocking.
- **Critical error** (connection lost, auth expired): Full-screen modal with clear action.
- **Validation**: Inline under the field, red text, immediate (on change).
- **Loading**: Skeleton shimmer for lists; disabled button with subtle pulse for actions.

### Component Design Rules
- **Buttons**: Filled for primary actions, outlined for secondary, text for tertiary. Always include keyboard shortcut hint in tooltip.
- **Cards**: 1dp elevation, 8dp border radius, no shadows in dark mode — use subtle border instead.
- **Inputs**: 48dp height, 12dp horizontal padding, border on focus only (accent color).
- **Modals**: Full-screen on mobile-sized windows, centered dialog (max 600dp width) on larger screens. Always have a close affordance (X button + Esc key).
- **Lists**: Alternate row shading (`surface` / `surfaceLight`) for readability. No dividers.

## API Integration

### Multi-Tenant
Every API request includes the tenant subdomain. Tenant is determined at login from the server URL (e.g., `https://demo.digitex.uz/` → tenant `demo`). Sent as `X-Tenant` header on all requests after login or derived from the subdomain.

### Authentication Flow
1. Login: `POST /api/auth/token/` → `{access, refresh}` JWT tokens
2. Auto-refresh: Dio interceptor catches 401, calls `POST /api/auth/token/refresh/`
3. Daily PIN: `POST /api/auth/verify-pin/` — verified against backend
4. Token storage: `flutter_secure_storage` (encrypted at OS level)

### Key POS Endpoints
```
GET  /api/pos/search/?q=&warehouse=     # Product search
GET  /api/pos/scan/?barcode=             # Barcode lookup
POST /api/pos/checkout/                  # Complete sale
GET  /api/pos/dashboard/                 # Daily stats
GET  /api/pos/exchange-rate/             # USD/UZS rate
POST /api/pos/quick-sale/                # Quick sale
GET  /api/sales/                         # Sale history
GET  /api/customers/                     # Customer lookup
```

## Naming Conventions

### Files
- `snake_case.dart` for all files
- BLoC files: `{feature}_bloc.dart`, `{feature}_event.dart`, `{feature}_state.dart`
- Screens: `{name}_screen.dart`
- Widgets: descriptive name, e.g., `pos_numpad.dart`, `cart_item_tile.dart`
- Models: `{entity}_model.dart`
- Repositories: `{feature}_repository.dart`

### Classes
- `PascalCase` for all classes
- BLoC: `SaleBloc`, `SaleEvent`, `SaleState`
- Cubit: `CartCubit`, `CartState` (use Cubit when events aren't needed)
- Models: `UserModel`, `ProductModel`, `SaleModel`
- Repositories: `AuthRepository`, `SaleRepository`

### Constants
- `camelCase` for color/theme constants within a class
- `SCREAMING_SNAKE` only for environment variables

## BLoC Conventions
```dart
// Events — past tense
sealed class SaleEvent {}
class SaleProductAdded extends SaleEvent { final ProductModel product; }
class SaleProductRemoved extends SaleEvent { final int index; }
class SaleCheckoutRequested extends SaleEvent {}

// States — adjective/noun
sealed class SaleState {}
class SaleInitial extends SaleState {}
class SaleInProgress extends SaleState { final List<CartItem> items; final int total; }
class SaleCompleted extends SaleState { final SaleModel sale; }
class SaleError extends SaleState { final String message; }
```

## Development Commands
```bash
flutter run -d windows        # Run on Windows
flutter run -d macos           # Run on macOS
flutter analyze                # Static analysis
flutter test                   # Run tests
dart run build_runner build    # Generate freezed/json_serializable code
```

## Do NOT
- Add decorative animations or transitions
- Use `setState` for anything beyond trivial local widget state (toggle visibility, etc.)
- Create God-widgets. Extract when a widget exceeds ~150 lines.
- Use hardcoded strings in UI — always use localization keys.
- Store secrets in plain SharedPreferences — use `flutter_secure_storage`.
- Import from `presentation/` layer in `data/` or `domain/` layers.
- Use `print()` — use `dart:developer` `log()` or the `logging` package.
