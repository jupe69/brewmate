# Reddit Post for r/macapps

**Title:** I built a native Homebrew GUI because the existing options frustrated me

**Body:**

Hey r/macapps,

I've been using Homebrew for years and always wanted a proper GUI for it. I tried the existing options:

- **Cakebrew** - Last updated in 2019, basically abandoned
- **Cork** - Nice but missing features I wanted
- Various **Electron apps** - Slow, resource-heavy, don't feel like Mac apps

So I built **Taphouse** - a fully native macOS app in SwiftUI. Here's what makes it different:

**Actually native**
- Pure SwiftUI, no Electron, no web views
- ~15MB vs 150MB+ for Electron apps
- Instant launch, uses minimal resources
- Follows Apple HIG, supports Dark Mode, feels like a real Mac app

**Complete feature set in one app**
- Package management (browse, search, install, uninstall, upgrade)
- Services management (start/stop/restart brew services)
- Taps management (add/remove repositories)
- Brewfile import/export (migrate your setup to a new Mac)
- Quarantine management (fix "app is damaged" issues)
- Diagnostics (brew doctor, disk usage, cache cleanup)
- Dependency tree visualization

**Quality of life features**
- Menu bar icon with update badge
- Background update checks with notifications
- Bulk operations (select multiple packages)
- Favorites and notes on packages
- Installation history

**Business model**
Free version does the basics (install, uninstall, upgrade, services). Pro is $4.99 one-time (not a subscription) for power user features. 14-day trial included.

I know "developer builds app" posts can be hit or miss here, but I genuinely use this daily and built it because I wanted it to exist. Happy to answer any questions or take feedback.

**Website:** https://taphouse.multimodalsolutions.gr
