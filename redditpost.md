
 Title:
  Show HN: Taphouse – A native macOS GUI for Homebrew

  Body:
  I built a SwiftUI app to manage Homebrew packages visually. Pure native, ~15MB, no Electron.

  Core features:
  - Package management (search, install, uninstall, upgrade)
  - Services dashboard (start/stop/restart brew services, auto-refresh)
  - Taps management
  - Brewfile import/export
  - Diagnostics (brew doctor, disk usage, cleanup)
  - Mac App Store integration via mas CLI

  The Services view was the main thing I wanted - I run PostgreSQL, Redis, and nginx through Homebrew and got tired of typing `brew services list`. Now I can see status at a glance and control everything with one click.

  Also added mas integration, which I haven't seen in other Homebrew GUIs. If you use `brew install mas`, Taphouse can manage App Store apps too - unified package management.

  Free version covers basics. Pro is $4.99 one-time for bulk operations, menu bar icon, auto-updates, etc.

  Built with SwiftUI, targets macOS 14+. First Swift project after years away from coding (was in management). Would appreciate any feedback.

  https://taphouse.multimodalsolutions.gr# Reddit Post for r/macapps

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
- Services management with auto-refresh (monitor and control all your brew services)
- Taps management (add/remove repositories)
- Brewfile import/export (migrate your setup to a new Mac)
- Quarantine management (fix "app is damaged" issues)
- Diagnostics (brew doctor, disk usage, cache cleanup)
- Dependency tree visualization
- **Mac App Store integration** (via `mas` CLI) - first Homebrew GUI with this!

**Quality of life features**
- Menu bar icon with update badge
- Background update checks with notifications
- Bulk operations (select multiple packages)
- Favorites and notes on packages
- Installation history

**Services dashboard**
If you run things like MySQL, PostgreSQL, Redis, or nginx through Homebrew, you'll love the Services view. See all your services at a glance with running/stopped/error counts, start/stop/restart with one click, and enable auto-refresh to monitor status changes in real-time (configurable from 10 seconds to 5 minutes). No more typing `brew services list` constantly.

**Mac App Store integration**
Something I haven't seen in any other Homebrew GUI - if you have [mas](https://github.com/mas-cli/mas) installed (`brew install mas`), Taphouse can manage your App Store apps too. Browse installed apps, check for updates, search and install new ones, upgrade all with one click. Your Brewfile exports can even include MAS apps, so you can restore your entire setup (Homebrew + App Store) on a new Mac. It's the unified package manager experience I always wanted.

**Business model**
Free version does the basics (install, uninstall, upgrade, services). Pro is $4.99 one-time (not a subscription) for power user features. 14-day trial included.

I know "developer builds app" posts can be hit or miss here, but I genuinely use this daily and built it because I wanted it to exist. Happy to answer any questions or take feedback.

**Website:** https://taphouse.multimodalsolutions.gr
