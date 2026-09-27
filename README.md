# SkateCity

An arcade street-skating game for iPhone and iPad — built entirely in Swift with SceneKit and SwiftUI. No image or model files needed. Every texture, mesh, and character is generated in code at runtime.

---

## How to Run

1. Open `SkateCity.xcodeproj` in Xcode 15+
2. Target › **General** → Minimum Deployments: **iOS 17.0**, Orientation: **Landscape Left + Right**, tick **Requires full screen**
3. Target › **Info** → add `CADisableMinimumFrameDurationOnPhone = YES` for 120 Hz on ProMotion iPhones
4. Plug in a real iPhone or iPad and press **Run**
   - For best performance: **Product › Scheme › Edit Scheme › Run › Build Configuration: Release**
   - Simulator works but is slower with Ultra graphics

> If Xcode shows Swift 6 concurrency warnings, set Build Settings › **Swift Language Version** to **Swift 5**.

---

## Controls

| Action | Touch | Gamepad | Keyboard |
|---|---|---|---|
| Push / steer / spin in air | Left stick | Left stick | WASD / arrows |
| Ollie (hold = crouch, release = pop) | OLLIE | A | Space |
| Flip trick (+ direction) | FLIP | X | J |
| Grab (hold + direction) | GRAB | Y | K |
| Grind (near a rail or ledge) | GRIND | B | L |
| Manual (tap as you land) | MANUAL | R1 | I |

**Flips:** neutral/left = Kickflip · right = Heelflip · up = Impossible · down = Pop Shove-It · up-left = 360 Flip · up-right = Hardflip · down-left = Varial Kickflip · down-right = Varial Heelflip

**Grabs:** neutral = Melon · left = Indy · right = Method · up = Nosegrab · down = Tailgrab

**Grinds:** neutral = 50-50 · up = Nosegrind · down = 5-0 · sideways = Boardslide — keep the balance meter centered

**Combos:** each trick multiplies points. Tap MANUAL to keep the combo alive on landing. Bail = lose combo.

---

## Game Content

- **Modes:** 2-minute Session (high score) and Free Skate
- **Goals:** Score 15k · Collect S-K-A-T-E · Land a 540 · 5-trick combo · 5k combo · 4-second grind
- **Plaza:** 2 kickers · funbox with banks · flat bar · manual pad · 2 granite ledges · raised platform with 3-stair · 2 handrails · 2 banks · 3 quarter pipes with grindable coping · graffiti wall · planters
- **City life:** traffic that loops the block (knocks you down) · pedestrians · streetlights · windowed skyline
- **Skaters:** Omari, Nova, Dre, Kenji — edit `SkaterStyle.roster` in `Skater.swift` to add more

---

## Onboarding & Create-A-Skater

A 5-step mobile-first onboarding flow in the style of classic console skate games:

1. **Title** — dark street aesthetic, large left-aligned menu
2. **Create-A-Skater** — three-column layout: category icon strip · BrickWallCanvas character preview · form panel with LOOK / HAIR / FACIAL / STANCE tabs
3. **CURBSIDE Store** — left dark item list with prices · right character preview on brick wall
4. **Board Room** — DECK / GRIP / TRUCKS / WHEELS tabs · board art preview · bottom horizontal carousel
5. **Review** — full outfit/board summary · DROP IN CTA

The selected wardrobe profile is saved to `UserDefaults` and applied to the in-game character via `AvatarModel` + `SkateboardModel`.

---

## Architecture

```
SkateCity/
│
│  ── GAME ENGINE ──────────────────────────────────────────────
├── GameEngine.swift            Arcade physics at 120 Hz fixed timestep — raycast ground
│                               follower, ollie/flip/grab/grind/manual/bail state machine,
│                               vert assist on quarter pipes, snap-to-rail grinding, chase
│                               camera, HDR bloom, SSAO, soft shadows, physical sky + IBL
│
├── World.swift                 Procedural downtown plaza (kickers, funbox, flat bar, manual
│                               pad, ledges, handrails, 3-stair, quarter pipes with coping,
│                               graffiti wall) + traffic, pedestrians, streetlights, skyline
│
├── Skater.swift                IK-driven skater rig: hips/knees/elbows solved every frame
│                               from a RigPose struct. Roster of 4 named characters.
│
├── Tricks.swift                Complete trick table — 8 flips, 5 grabs, 4 grind types.
│                               Combo scoring with direction-based trick selection.
│
├── MeshBuilder.swift           Custom SCNGeometry: kickers, curved quarter-pipe sections
│
├── TextureFactory.swift        Procedural PBR textures — asphalt, concrete, ramps, facades,
│                               graffiti, deck art — all generated at runtime, no image files
│
│  ── GAME STATE ────────────────────────────────────────────────
├── GameModel.swift             SwiftUI ObservableObject — score, combo, S-K-A-T-E letters,
│                               timer, balance meter, goals, session lifecycle
│
├── InputState.swift            Unified input: merges touch, MFi game controller, and
│                               keyboard into one source of truth
│
│  ── AVATAR & WARDROBE ─────────────────────────────────────────
├── AvatarModel.swift           Procedural SceneKit character with skinned geometry and
│                               wardrobe profile application
│
├── SkateboardModel.swift       Procedural deck / truck / wheel geometry with PBR materials
│                               and real-time wheel spin
│
├── AnimationController.swift   12-state avatar state machine using CAKeyframeAnimation
│                               on euler angles; analytical two-bone leg IK
│
├── CharacterLODManager.swift   Distance-based 3-tier LOD — hides detail nodes and
│                               removes shader modifiers at medium/low distance
│
├── WardrobeCatalog.swift       Full wardrobe catalog: skins, hairstyles, tops, bottoms,
│                               shoes, hats, decks, trucks, wheels — with coin pricing
│
│  ── HUD & VIEWS ───────────────────────────────────────────────
├── Views.swift                 All game screens: title menu, loading screen with tips,
│                               in-game HUD, touch joystick + action buttons, pause overlay
│                               with goals checklist, session results screen
│
├── OnboardingView.swift        5-step street-aesthetic onboarding — BrickWallCanvas
│                               character previews, CURBSIDE store, Board Room carousel
│
├── ContentView.swift           Root view — onboarding gate → RootView (game)
│
│  ── GRAPHICS ──────────────────────────────────────────────────
├── UltraGraphicsManager.swift  Per-scene HDR / SSAO / shadow / bloom quality tiers
├── RemasteredGraphicsManager.swift  Node-name-driven PBR texture routing
├── MaterialLibrary.swift       Shared SCNMaterial factory + UIColor hex helpers
├── DeckShader.metal            Dual-UV lightmap fragment shader for deck graphics
├── TruckPBR.metal              GGX NDF specular + scratch layering for trucks
├── ScratchShader.metal         Wear/scratch compute overlay
├── PostFX.metal                Post-processing pipeline (bloom, vignette, grain)
│
│  ── AUDIO & PERSISTENCE ───────────────────────────────────────
├── SeshFMAudioEngine.swift     AVAudioEngine graph: background music, spatial trick SFX,
│                               grind loop with fade in/out
├── ProfilePersistenceManager.swift  SwiftData PlayerProfile + top-10 SkateComboRecord
├── GrindBalanceSystem.swift    Real-time balance offset with wipeout detection
├── SkaterRagdollController.swift    Capsule bone rigging + bail physics detonation
│
│  ── SUPPORT ───────────────────────────────────────────────────
├── GameViewController.swift    Original UIKit SceneKit host
├── SkateCitySimulator.swift    SwiftUI Canvas preview simulator
├── SkateCityMapBuilder.swift   GLB-first city obstacle placement
├── SkateParkBuilder.swift      Bay Area skatepark builder (SoMa + Lake Cunningham)
├── TrickRegistry.swift         Swipe gesture trick registry
├── SkateInputView.swift        Touch gesture recognizer
├── SkateComboManager.swift     Combo state machine
├── SkateComboHUD.swift         SpriteKit HUD overlay
└── GLBAssetLoader.swift        Async GLB / SCN asset cache
```

---

## Trick Point Reference

| Trick | Type | Points |
|---|---|---|
| Kickflip | Flip | 300 |
| Heelflip | Flip | 300 |
| Pop Shove-It | Flip | 250 |
| Impossible | Flip | 420 |
| 360 Flip | Flip | 800 |
| Hardflip | Flip | 600 |
| Varial Kickflip | Flip | 500 |
| Varial Heelflip | Flip | 500 |
| Melon | Grab | 350 |
| Indy | Grab | 350 |
| Method | Grab | 500 |
| Nosegrab | Grab | 400 |
| Tailgrab | Grab | 350 |
| 50-50 | Grind | 200/s |
| Nosegrind | Grind | 300/s |
| 5-0 | Grind | 300/s |
| Boardslide | Grind | 250/s |

---

## Requirements

| Requirement | Version |
|---|---|
| iOS | 17.0+ |
| Xcode | 15.0+ |
| Swift | 5.9+ |
| Recommended device | iPhone with ProMotion (120 Hz) |

---

## License

Private — all rights reserved.
