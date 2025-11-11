# SmartSplit Logo Design Specifications

## Logo Concept
The SmartSplit logo represents the core concept of splitting expenses between people in a smart, modern way.

## Visual Elements

### 1. Main Icon (Rounded Square)
- **Shape**: Rounded square container
- **Size**: Flexible (100x100px default)
- **Corner Radius**: 20% of size
- **Background**: Linear gradient
  - Start Color: `#2196F3` (Blue)
  - End Color: `#1976D2` (Darker Blue)
  - Direction: Top-left to bottom-right
- **Shadow**: 
  - Color: `#2196F3` at 30% opacity
  - Blur: 20px
  - Offset: 0px, 10px

### 2. Central Elements (White on Blue)

#### Vertical Split Line
- **Position**: Center of icon
- **Height**: 70% of container
- **Stroke Width**: 8% of container width
- **Color**: White (#FFFFFF)
- **Cap**: Round

#### Left Side - Dollar Symbol
- **Position**: Left of center line
- **Style**: Stylized "S" shape representing currency
- **Stroke**: White, rounded
- **Represents**: Money/expenses

#### Right Side - Sharing Arrow
- **Position**: Right of center line
- **Style**: Arrow pointing right
- **Meaning**: Sharing/splitting concept

#### People Symbols
- **Two circles** at the top representing people
- **Position**: One on left, one on right
- **Style**: Circle outlines (white stroke)
- **Meaning**: Multiple people splitting expenses

## Color Palette

### Primary Colors
- **Blue**: `#2196F3` - Trust, reliability, financial
- **Dark Blue**: `#1976D2` - Depth and professionalism
- **White**: `#FFFFFF` - Clean, simple icons

### Theme Variations
- **Light Theme**: Use gradient blue background
- **Dark Theme**: Same gradient, white icons stand out more
- **System Default**: Soft blue tones with gradient

## Typography (When showing text)

### App Name: "SmartSplit"
- **Font Weight**: Bold (700)
- **Size**: 25% of logo size
- **Color**: 
  - Light mode: `#263238` (Dark grey)
  - Dark mode: `#FFFFFF` (White)
- **Letter Spacing**: 1.5px

### Tagline: "Split Expenses, Stay Smart"
- **Font Weight**: Regular (400)
- **Size**: 12% of logo size
- **Color**: 
  - Light mode: Grey 600
  - Dark mode: Grey 400
- **Letter Spacing**: 0.5px

## Usage Guidelines

### 1. Logo Sizes

#### Large (Splash/Login Screen)
- Size: 120x120px
- Show text: Yes
- Use case: Welcome screens, branding

#### Medium (App Bar)
- Size: 40-50px
- Show text: No
- Use case: Navigation bars, headers

#### Small (Icons)
- Size: 24-32px
- Show text: No
- Use case: Notifications, list items

### 2. Clear Space
- Minimum clear space around logo: 10% of logo size
- Don't place other elements within this space

### 3. Don'ts
- ❌ Don't change the gradient colors
- ❌ Don't rotate or skew the logo
- ❌ Don't add additional effects or shadows beyond specified
- ❌ Don't use on busy backgrounds (ensure contrast)
- ❌ Don't stretch or distort proportions

## File Formats (For External Design Tools)

### Vector Formats (Recommended)
- **SVG**: Scalable, best for web and app
- **AI/EPS**: For Adobe Illustrator

### Raster Formats
- **PNG**: With transparent background
  - 512x512px (Google Play)
  - 1024x1024px (App Store)
  - 192x192px (Web)
  - 96x96px (Standard)
- **WebP**: For optimized web delivery

## Design Tool Instructions

### Figma/Adobe XD
1. Create 100x100px artboard
2. Draw rounded rectangle (20px radius)
3. Apply gradient: `#2196F3` to `#1976D2` (diagonal)
4. Add drop shadow (blur: 20px, #2196F3 30%)
5. Draw white elements:
   - Vertical line (center, 70px high, 8px stroke)
   - Dollar "S" shape (left side)
   - Arrow (right side)
   - Two circles (top, 8px radius each)

### Export Settings
- Format: PNG with transparency
- Resolutions: 1x, 2x, 3x (for mobile)
- Color Space: sRGB

## Implementation in Flutter
The logo is implemented as a custom Flutter widget:
- **Widget**: `AppLogo` (full logo with text)
- **Widget**: `AppLogoIcon` (icon only)
- **Location**: `lib/widgets/app_logo.dart`

## Brand Guidelines
- The logo represents trustworthiness, ease of use, and smart financial management
- Use consistently across all platforms
- Maintain the blue color scheme for brand recognition
- The split line represents fair division
- The people symbols represent collaboration
