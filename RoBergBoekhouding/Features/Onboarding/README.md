# Onboarding Feature

## Overview

The onboarding wizard guides first-time users through the initial setup of their business information in Uurwerker.

## Files

- `OnboardingView.swift` - Main onboarding wizard with 5 steps

## Integration Steps

### 1. Add File to Xcode Project

The `OnboardingView.swift` file has been created but needs to be added to the Xcode project:

1. Open `RoBergBoekhouding.xcodeproj` in Xcode
2. In the Project Navigator, locate the `Features/Onboarding` folder
3. Right-click on the `Onboarding` folder (or use Cmd+Option+A)
4. Select "Add Files to 'RoBergBoekhouding'..."
5. Navigate to `/Volumes/LaCie 2TB/RoBergBoekhouding/RoBergBoekhouding/Features/Onboarding/`
6. Select `OnboardingView.swift`
7. Ensure "Copy items if needed" is **unchecked** (file is already in the right location)
8. Ensure "Add to targets: RoBergBoekhouding" is **checked**
9. Click "Add"

### 2. Verify Integration

The following changes have already been made to integrate the onboarding:

#### ContentView.swift
- Added `@State private var showOnboarding = false`
- Added `.sheet(isPresented: $showOnboarding)` with `OnboardingView`
- Modified `checkOnboardingStatus()` to show onboarding if not completed

#### BusinessSettings.swift
- Added `hasCompletedOnboarding: Bool` property
- Added to initializer with default value `false`

## Onboarding Flow

### Step 1: Welcome
- Welcomes user to Uurwerker
- Explains the setup process

### Step 2: Business Information
- Bedrijfsnaam (Business name) - **required**
- Naam eigenaar (Owner name) - **required**
- KvK-nummer (Chamber of Commerce number) - optional

### Step 3: Contact Details
- Adres (Address)
- Postcode & Plaats (Postal code & City)
- E-mailadres (Email)
- Telefoonnummer (Phone)

### Step 4: Tax Settings
- BTW-plichtig (VAT liable) toggle
- BTW-tarief (VAT rate) picker - shown if VAT liable
- BTW-nummer (VAT number) - shown if VAT liable

### Step 5: Default Rates
- Uurtarief (Hourly rate) - defaults to €75
- Kilometervergoeding (Mileage rate) - defaults to €0.23
- Betalingstermijn (Payment term) - defaults to 14 days

## Features

### Design System Integration
- Uses existing `Colors.swift`, `Typography.swift`, and `Spacing.swift`
- Consistent with app's visual design
- Brand color: `.uurwerkerBlue`

### User Experience
- Progress indicator with animated dots
- Step-by-step navigation with "Terug" (Back) and "Volgende" (Next) buttons
- Form validation on Business Info step
- Smooth transitions between steps
- Can't skip onboarding (no dismiss button)

### Data Handling
- Validates required fields (business name, owner name)
- Combines postcode and plaats into `postcodeplaats` field
- Converts Dutch decimal format (comma) to system format (period)
- Sets `hasCompletedOnboarding = true` upon completion
- Saves all data to `BusinessSettings` via SwiftData

## Testing

To test the onboarding:

1. Delete the app's data:
   - In Xcode, select Product > Scheme > Edit Scheme
   - Under "Run" > "Options", enable "Reset SwiftData on Launch" (or manually delete app data)
2. Run the app
3. The onboarding wizard should appear automatically

To manually trigger onboarding after it's been completed:

```swift
// In SettingsView or elsewhere
let settings = BusinessSettings.ensureSettingsExist(in: modelContext)
settings.hasCompletedOnboarding = false
try? modelContext.save()
// Restart app or trigger checkOnboardingStatus()
```

## Customization

### Changing Default Values

Edit `OnboardingFormData` in `OnboardingView.swift`:

```swift
struct OnboardingFormData {
    var uurtarief: Decimal = 75  // Change default hourly rate
    var kmTarief: Decimal = 0.23 // Change default mileage rate
    var betalingstermijn = 14    // Change default payment term
    // ...
}
```

### Adding New Steps

1. Increment `totalSteps` constant
2. Add new step view to `TabView` with appropriate `.tag()`
3. Create step view following the pattern of existing steps
4. Update navigation in `completeOnboarding()` if needed

### Modifying Styling

All styling uses the design system:
- Colors: `Color.uurwerkerBlue`, `Color.cardBackground`, etc.
- Typography: `Font.uurwerkerTitle2`, `Font.uurwerkerBody`, etc.
- Spacing: `Spacing.lg`, `Spacing.md`, etc.

## Notes

- The onboarding is shown as a modal sheet and cannot be dismissed without completing it
- Once completed, `hasCompletedOnboarding` is set to `true` and the wizard won't show again
- All fields are optional except business name and owner name
- The wizard respects the existing `BusinessSettings` singleton pattern
- Postcode and plaats are stored as a combined `postcodeplaats` field
