# SkateCity

An AAA-quality iOS skateboarding game built with SceneKit, Metal, AVAudioEngine, and SwiftData — targeting 120 FPS on iPhone.

---

## Features

### Gameplay
- **Physics-driven skateboard** with dynamic mass, friction, restitution, and angular damping via SceneKit
- **11-trick gesture registry** — swipe combos mapped to Ollie, Kickflip, Heelflip, Pop Shuvit, Impossible, Double Kickflip, Varial Kickflip, Varial Heelflip, 360 Shuvit, 360 Flip, and Hardflip
- **Grind balance system** — real-time balance meter with bail detection when the player falls off a rail
- **Ragdoll bail physics** — kinematic bones switch to dynamic on bail, inheriting board velocity with torque chaos
- **Combo scoring** — multiplier system with a 0.13s gesture buffer window and SwiftData-backed top-10 leaderboard

### Maps
- **SoMa Street Zone** — SF-inspired ledges, granite bench, 3-step stair set, Hubba rail, and kicker
- **Lake Cunningham Vert Zone** — full-pipe cylinder with flanking quarter-pipe ramps
- **City Map Builder** — procedural GLB-first obstacle placement with SceneKit primitive fallbacks

### Audio
- **SeshFM Audio Engine** — AVAudioEngine graph with background music cycling, spatial trick SFX, and grind loop with fade in/out
- Trick-specific SFX dispatch (ollie, kickflip, heelflip, pop shuvit)

### Graphics
- **Metal PBR pipeline** — GGX NDF specular, dual-UV lightmap blending on the deck, truck PBR with scratch layering
- **Remastered Graphics Manager** — per-node PBR texture routing driven by node names
- **120 FPS render loop** with motion blur, HDR bloom, and 4x MSAA

### Onboarding
- **THPS2-inspired 6-step onboarding** — Welcome splash, Skater Card, Outfit, Board Setup, Kicks, and Drop In confirmation
- Live Canvas character preview updates in real time as you select clothing, deck graphics, and shoes
- Crimson red grunge banner headers, city skyline backdrop, and pulsing CTA animations

### Persistence
- **SwiftData** models for `PlayerProfile` and `SkateComboRecord`
- Career score accumulation and top-10 combo leaderboard with cascade-delete pruning
- `SkaterDraftProfile` saved to `UserDefaults` after onboarding

---

## Architecture

```
SkateCity/
├── GameViewController.swift       # Root UIViewController — scene setup, HUD, render loop
├── SkateCityMapBuilder.swift      # City obstacle placement (GLB-first + primitive fallback)
├── SkateParkBuilder.swift         # Bay Area skatepark (SoMa + Lake Cunningham)
├── TrickRegistry.swift            # 11-trick gesture table with base points
├── SkateInputView.swift           # Touch gesture recognizer → TrickGesture dispatch
├── SkateComboManager.swift        # Combo state machine (idle → tricking → balancing → land/bail)
├── GrindBalanceSystem.swift       # Real-time balance offset with wipeout detection
├── SkaterRagdollController.swift  # Capsule bone rigging + bail detonation
├── SeshFMAudioEngine.swift        # AVAudioEngine music/SFX/grind graph
├── SkateComboHUD.swift            # SpriteKit overlay — trick names, multiplier, bail flash
├── GLBAssetLoader.swift           # Async GLB/SCN asset cache via SCNScene(url:)
├── SkateMapLoader.swift           # On-Demand Resources loader for .scn map packets
├── RemasteredGraphicsManager.swift# Metal PBR pipeline setup per node
├── ProfilePersistenceManager.swift# SwiftData career profile + combo leaderboard
├── SkaterCustomizer.swift         # Outfit/board/shoe SCNNode material swapping
├── OnboardingView.swift           # 6-step THPS2-style SwiftUI onboarding
├── SkateCitySimulator.swift       # SwiftUI 2D Canvas preview simulator (Xcode Canvas)
├── ContentView.swift              # Root view — onboarding gate → game
├── DeckShader.metal               # Dual-UV lightmap fragment shader
├── TruckPBR.metal                 # GGX truck PBR vertex/fragment shaders
└── ScratchShader.metal            # Scratch/wear overlay compute shader
```

---

## Requirements

| Requirement | Version |
|---|---|
| iOS | 17.0+ |
| Xcode | 15.0+ |
| Swift | 5.9+ |
| Device | iPhone with ProMotion (120 Hz) recommended |

---

## Getting Started

1. Clone the repo and open `SkateCity.xcodeproj` in Xcode
2. Select your target device or simulator (iPhone 15 Pro recommended)
3. Build and run — the THPS2-inspired onboarding launches on first open
4. After onboarding, the SceneKit game loop starts immediately

> Audio assets (`seshfm_track1.mp3`, `sfx_ollie.wav`, etc.) and GLB obstacle models are not included in this repo. Add them to the Xcode project bundle or tag them as On-Demand Resources matching the keys in `GLBAssetLoader.swift` and `SkateMapLoader.swift`.

---

## Trick Gesture Reference

| Swipe | Trick | Points |
|---|---|---|
| Up | Ollie | 60 |
| Left | Kickflip | 300 |
| Right | Heelflip | 300 |
| Down | Pop Shuvit | 250 |
| Up → Up | Impossible | 420 |
| Left → Left | Double Kickflip | 650 |
| Down → Left | Varial Kickflip | 500 |
| Down → Right | Varial Heelflip | 500 |
| Down → Down | 360 Shuvit | 450 |
| Up → Down | 360 Flip | 800 |
| Up → Left | Hardflip | 600 |

---

## License

Private — all rights reserved.
