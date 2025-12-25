# Taphouse Marketing Plan

## Executive Summary

Taphouse is a native macOS GUI for Homebrew package management. It targets Mac developers and power users who want a visual interface for managing their development tools without memorizing terminal commands.

**Business Model:** Freemium with $4.99 one-time Pro upgrade
**Target Revenue:** $5,000-10,000/year passive income

---

## Target Audience

### Primary: Mac Developers
- **Demographics:** 25-45 years old, software developers, work on macOS daily
- **Pain Points:**
  - Forget brew commands (`brew outdated`, `brew cleanup`, etc.)
  - Don't know what packages they have installed
  - Want to clean up disk space but unsure what's safe to remove
- **Where They Hang Out:** Twitter/X, Reddit (r/macapps, r/macOS, r/webdev), Hacker News, Dev.to, GitHub

### Secondary: Mac Power Users
- **Demographics:** 30-55 years old, designers, system administrators, tech enthusiasts
- **Pain Points:**
  - Intimidated by terminal
  - Installed Homebrew for one app, now have outdated packages
  - Want GUI control over their system
- **Where They Hang Out:** Reddit (r/macapps, r/apple), Mac forums, YouTube

### Tertiary: New Mac Developers
- **Demographics:** 18-30 years old, bootcamp graduates, CS students
- **Pain Points:**
  - Learning Homebrew for the first time
  - Overwhelmed by terminal commands
  - Want visual feedback on what's happening
- **Where They Hang Out:** Discord servers, Reddit, YouTube tutorials

---

## Value Proposition

### Free Version
> "See and manage all your Homebrew packages without touching the terminal."

**Key Benefits:**
- Visual package browser (no more `brew list | grep`)
- One-click install/uninstall
- See what's outdated at a glance
- Manage background services visually

### Pro Version ($4.99)
> "Power-user features for developers who live in Homebrew."

**Key Benefits:**
- Bulk operations save time
- Brewfile backup protects your setup
- Auto-updates keep you current without thinking
- Menu bar access for quick checks

---

## Competitive Landscape

| Competitor | Price | Pros | Cons |
|------------|-------|------|------|
| **Terminal (brew)** | Free | Full power, scriptable | Requires memorization, no visual feedback |
| **Cakebrew** | Free | Open source, simple | Abandoned (last update 2019), limited features |
| **Cork** | Free | Modern UI, active development | Feature overlap, no business model |

### Taphouse Differentiation
1. **Freemium model** - Sustainable development, regular updates
2. **Native SwiftUI** - Fast, modern, follows Apple HIG
3. **Complete feature set** - Services, taps, cleanup, Brewfile all in one
4. **14-day trial** - Try everything before buying

---

## Marketing Channels

### 1. Reddit (Primary - Free)
**Target Subreddits:**
- r/macapps (180k members) - Primary launch target
- r/macOS (800k members) - For major updates
- r/homebrew (25k members) - Niche but perfect fit
- r/webdev, r/programming - When relevant

**Strategy:**
- Post launch announcement to r/macapps
- Engage authentically in Homebrew discussions
- Share useful tips, mention Taphouse when relevant
- Post major feature updates

**Sample Post Title:**
> "I built a native macOS GUI for Homebrew - free to use, would love feedback"

### 2. Hacker News (High Impact - Free)
**Strategy:**
- "Show HN" post at launch
- Post on weekday morning (10am EST = best engagement)
- Respond to every comment quickly
- Be humble, ask for feedback

**Sample Post:**
> Show HN: Taphouse - A native macOS app for managing Homebrew packages

### 3. Product Hunt (Launch Boost - Free)
**Strategy:**
- Prepare assets: icon, screenshots, demo GIF, tagline
- Schedule for Tuesday-Thursday launch
- Rally existing users to upvote
- Respond to all comments

**Tagline Options:**
- "The missing GUI for Homebrew"
- "Homebrew management that doesn't require a terminal"
- "Finally see what Homebrew has installed"

### 4. Twitter/X (Ongoing - Free)
**Strategy:**
- Post development updates with screenshots/videos
- Use hashtags: #macOS #SwiftUI #macdev #buildinpublic
- Engage with Mac developer community
- Share tips about Homebrew with Taphouse screenshots

**Content Ideas:**
- "TIL you can pin packages in Homebrew to prevent updates. Here's how in Taphouse..."
- "Just cleaned up 15GB with Taphouse's cleanup tool. Here's what it found..."
- Development progress threads

### 5. YouTube (Long-term SEO - Free)
**Video Ideas:**
- "How to Manage Homebrew Without Terminal" (tutorial)
- "Taphouse Demo - Homebrew GUI for Mac" (product demo)
- "Clean Up Your Mac: Homebrew Edition" (value content)

**Strategy:**
- Target keywords: "homebrew gui mac", "homebrew manager", "mac developer tools"
- Keep videos under 5 minutes
- Include download link in description

### 6. Dev.to / Hashnode (SEO - Free)
**Article Ideas:**
- "Why Every Mac Developer Needs a Homebrew GUI"
- "How I Built a Native macOS App with SwiftUI"
- "Managing 100+ Homebrew Packages Without Losing Your Mind"

### 7. GitHub (Credibility - Free)
**Strategy:**
- Star/watch homebrew/brew repo for visibility
- Contribute to discussions
- Create useful Homebrew-related gists
- Link to Taphouse in profile

### 8. Website (SEO Hub)
**Purpose:** Central landing page, SEO, credibility

**Domain Options:**
- taphouse.app (preferred)
- gettaphouse.com
- taphouseapp.com

**Pages to Create:**
1. **Home** - Hero, features, screenshots, download CTA
2. **Features** - Detailed feature breakdown with screenshots
3. **Pricing** - Free vs Pro comparison table
4. **Download** - Direct download link, system requirements
5. **FAQ** - Common questions, troubleshooting

**SEO Keywords to Target:**
- "homebrew gui mac" (primary)
- "homebrew manager"
- "brew cleanup tool"
- "mac package manager gui"
- "homebrew visual interface"

**Tech Stack (Free/Cheap):**
- Static site: Astro, Next.js, or Hugo
- Hosting: Vercel or Netlify (free tier)
- Analytics: Plausible ($9/mo) or Umami (free self-hosted)

**Website Content:**
```
Hero: "The Missing GUI for Homebrew"
Subhead: "Manage your Mac packages visually. No terminal required."
CTA: "Download Free" | "View on GitHub"
```

---

## Launch Strategy

### Pre-Launch (1 week before)
- [ ] Finalize app, test thoroughly
- [ ] Create landing page (if desired)
- [ ] Prepare screenshots (light + dark mode)
- [ ] Record demo GIF/video
- [ ] Write Reddit/HN post drafts
- [ ] Set up LemonSqueezy checkout
- [ ] Create Twitter thread draft

### Launch Day
- [ ] Post to r/macapps (morning)
- [ ] Post to Hacker News (10am EST)
- [ ] Tweet announcement thread
- [ ] Monitor and respond to all comments
- [ ] Fix any critical bugs immediately

### Post-Launch (Week 1)
- [ ] Collect user feedback
- [ ] Fix bugs, ship updates
- [ ] Thank users publicly
- [ ] Share download/revenue milestones

### Ongoing
- [ ] Weekly Twitter updates
- [ ] Monthly feature releases
- [ ] Quarterly Reddit updates for major versions

---

## Content Calendar

### Week 1-2: Launch
| Day | Platform | Content |
|-----|----------|---------|
| Mon | Twitter | Teaser screenshot |
| Tue | Reddit | Launch post r/macapps |
| Tue | HN | Show HN post |
| Wed | Twitter | Thank you + stats thread |
| Thu | Dev.to | "Why I Built Taphouse" article |
| Fri | Twitter | Feature highlight (cleanup) |

### Ongoing Weekly Schedule
| Day | Content |
|-----|---------|
| Mon | Development update / behind-the-scenes |
| Wed | Tip/tutorial with Taphouse screenshot |
| Fri | Feature highlight or user testimonial |

---

## Pricing Psychology

### Why $4.99 Works
1. **Impulse buy threshold** - Under $5 = easy yes
2. **Coffee price anchor** - "Less than a latte"
3. **One-time = no friction** - No subscription fatigue
4. **14-day trial** - Risk-free, builds trust

### Messaging
- "One-time purchase, yours forever"
- "Less than a coffee, saves hours"
- "Try free for 14 days"
- "No subscription, no recurring fees"

---

## Metrics & Goals

### Launch Goals (First Month)
| Metric | Target |
|--------|--------|
| Downloads | 1,000 |
| Pro conversions | 50 (5%) |
| Revenue | $250 |
| Reddit upvotes | 100+ |
| HN points | 50+ |

### Year 1 Goals
| Metric | Target |
|--------|--------|
| Total downloads | 10,000 |
| Pro conversions | 500 (5%) |
| Revenue | $2,500 |
| Twitter followers | 500 |

### Key Conversion Metrics
- **Trial → Pro:** Target 5-10%
- **Download → Trial Start:** Track via analytics
- **Feature usage:** Which Pro features drive conversions?

---

## Growth Tactics

### 1. Referral Program (Future)
- "Give $1, Get $1" - Friends get $1 off, you get $1 credit
- Share link in app after purchase

### 2. Seasonal Promotions
- **Black Friday:** 40% off ($2.99)
- **New Year:** "Clean up your Mac for 2025"
- **Back to School:** Student discount

### 3. Bundle Opportunities
- Partner with other Mac indie developers
- Create "Mac Developer Essentials" bundle
- BundleHunt, Setapp (long-term goal)

### 4. Testimonials & Social Proof
- Collect user quotes
- Display download count in app/website
- "Trusted by X developers"

### 5. SEO Long Game
- Target: "homebrew gui", "homebrew manager mac", "brew cleanup tool"
- Create landing page with these keywords
- Dev.to articles for backlinks

---

## Budget

**Total Budget:** $0 (organic only) + website hosting

### Free Marketing Channels
| Channel | Cost | Time Investment |
|---------|------|-----------------|
| Reddit | $0 | 2 hrs/week |
| Twitter/X | $0 | 1 hr/week |
| Hacker News | $0 | 1 hr (launch) |
| Dev.to | $0 | 2 hrs/month |
| Product Hunt | $0 | 4 hrs (launch) |
| YouTube | $0 | 2 hrs/video |
| GitHub presence | $0 | 1 hr/week |

### Website (Only Expense)
| Item | Cost | Notes |
|------|------|-------|
| Domain | ~$12/year | taphouse.app or similar |
| Hosting | $0-5/month | Vercel, Netlify, or GitHub Pages (free) |

**Total Annual Cost:** ~$12-72/year

---

## Assets Needed

### Visual Assets
- [ ] App icon (1024x1024)
- [ ] Screenshots (5-6, light + dark mode)
- [ ] Demo GIF (30 seconds)
- [ ] Demo video (2 minutes)
- [ ] Social preview image (1200x630)

### Copy Assets
- [ ] One-liner tagline
- [ ] 50-word description
- [ ] 150-word description
- [ ] Feature bullet points
- [ ] FAQ

### Tagline Options
1. "The missing GUI for Homebrew"
2. "Homebrew, without the terminal"
3. "See what's brewing on your Mac"
4. "Your Homebrew packages, visualized"

---

## Risk Mitigation

### Risk: Cork (Free Competitor)
**Mitigation:** Focus on Pro features, sustainability message, better polish

### Risk: Low Conversion Rate
**Mitigation:** A/B test paywall messaging, add more Pro value, adjust price

### Risk: Negative Reviews
**Mitigation:** Respond quickly, fix bugs fast, be transparent about limitations

### Risk: Homebrew Changes Break App
**Mitigation:** Monitor Homebrew releases, maintain compatibility, communicate delays

---

## Success Metrics

### This is working if:
- 5%+ trial-to-paid conversion
- Positive Reddit/HN reception
- Organic mentions on Twitter
- Users requesting features (engagement)

### This needs adjustment if:
- <2% conversion rate
- Negative feedback on value proposition
- No organic growth after launch spike
- High refund rate

---

## Next Steps

1. **Immediate:** Finalize app, create screenshots
2. **This Week:** Draft Reddit/HN posts, prepare launch assets
3. **Launch Day:** Execute launch plan, monitor closely
4. **Week 1:** Respond to feedback, iterate quickly
5. **Month 1:** Evaluate metrics, adjust strategy

---

*Last Updated: December 2024*
