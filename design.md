# design.md

## Game Summary
This project is a action game that combines horde-survival combat with RPG-style boss encounters.

The core appeal of the game is:
- clearing large groups of enemies quickly and satisfyingly
- feeling rapid growth through frequent level-ups
- strengthening skills during the run
- using learned skills deliberately in boss fights through dodge, guard, and attack timing

This is not meant to be a pure survivors-like auto-battler, and not a pure slow action RPG.
The game must preserve both:
- the thrill of crowd-clearing and fast growth
- the satisfaction of skill-based boss combat

A short summary of the intended player experience:
Normal stages should feel like becoming stronger quickly.
Boss stages should feel like proving what the player learned.

## Core Gameplay Loop
1. Enter a stage and fight through large enemy waves
2. Level up quickly through combat
3. Choose skill upgrades that visibly change combat performance
4. Build a stronger combat kit during the stage
5. Face a boss that requires active use of dodge, guard, movement, and attack timing
6. Defeat the boss through both growth and player execution

## Core Combat Identity
The game has two different combat moods:

### Normal Stages
- fast
- explosive
- satisfying
- growth-driven
- focused on crowd clearing and repeated level-ups

### Boss Stages
- tense
- readable
- skill-based
- pattern-driven
- focused on dodge, guard, attack timing, and correct response

The player should feel stronger before the boss, but still need to play well to win.

Bosses should not be defeated by passive damage alone.
The player must actively use the tools learned during the run.

## Design Priorities
- Strong growth feeling during normal stages
- Frequent and satisfying level-up moments
- Upgrades must create visible gameplay changes
- Bosses must reward mastery of dodge, guard, movement, and attack timing
- Character combat styles must feel clearly different
- 2.5D quarter-view readability must be preserved over visual complexity
- Combat clarity is more important than decorative visuals

## Avoid
- characters being functionally identical
- boss fights that can be won by passive damage only
- slow or dull early-game pacing
- upgrades that do not noticeably affect gameplay
- overly flashy effects that hurt combat readability
- stage design that ignores the strengths of quarter-view gameplay

## Character Direction
Characters must differ in actual combat identity, not just visuals.

Character differences must be mechanical, not cosmetic.
Each character should encourage a different combat rhythm, upgrade preference, and boss response pattern.

### Mage
A classic fantasy mage character.

Combat identity:
- ranged magical combat
- stronger area control
- spell-based attacks
- emphasis on positioning and cast timing
- can lean toward zone control, area damage, and magical bursts

Expected feel:
- elegant
- mystical
- controlled
- tactical at mid-to-long range

### Hunter
An urban fantasy sword user.

Combat identity:
- close or mid-range combat
- stronger direct action feeling
- mobility, slashing, guard timing, and aggressive boss response are important
- should feel more immediate and hands-on than the mage

Expected feel:
- sharp
- fast
- aggressive
- deliberate in timing and movement

## Character Identity Goal
The mage and hunter should not feel like the same character with different visuals.

The mage should feel like a character who controls space.
The hunter should feel like a character who breaks through timing windows.

## Hunter Sprite Production Goal
For the hunter combat sprite work, prioritize a 2D slightly tilted top-down game-sprite read over the broader 2.5D design language in this document.

The final deliverables must be immediately testable in Godot:
- transparent PNG files
- unified frame size across all directions and actions
- consistent direction/action filename rules
- shared pivot/anchor rules
- readable in-game silhouettes rather than illustration-sheet polish

The sprite camera is locked to a slightly tilted top-down view. It is not a vertical top-down view, front-facing concept art, portrait art, or poster-style character sheet.

The character identity must stay consistent across every frame:
- short black bob hair
- red hair-tip accents and a small white hair section
- cold, sharp expression
- black outfit with red lining or red accents
- white shirt detail
- skirt, thigh garter belts, gloves, and high-heel boot silhouette
- long, sleek black sword with red glowing accents

The production goal is not to redraw a new character for every frame. The goal is to make one consistent character appear to move naturally in-game.

### Hunter Sprite Export Rules
Use a single frame size for the entire hunter combat set.

Recommended working frame:
- 192x192 px per frame for source cleanup and Godot testing

Allowed final downscale:
- 128x128 px only after the full set is visually stable

Every exported frame must:
- use transparent PNG
- keep the character fully inside the frame with attack-safe padding
- preserve the same body scale across all frames
- keep the sword length stable
- keep hands and sword grip/contact readable
- avoid background, shadows, motion blur, excessive effects, and decorative framing

### Pivot And Anchor Rules
Use one common pivot rule for all hunter frames.

Primary pivot:
- bottom-center foot anchor
- Godot Sprite2D.offset or import positioning should align the character's ground contact point consistently

Recommended pivot position in a 192x192 frame:
- x = 96
- y = 150 to 160, depending on final foot placement

The pivot should represent the character's gameplay position, not the visual center of the sword or coat.

Keep this pivot stable across:
- idle
- walk
- slash
- dash preparation
- dash recovery
- hit
- parry

Large sword swings may extend inside the frame, but they must not move the gameplay pivot.

### Direction Naming Rules
Use these exact direction keys:
- down
- down_right
- right
- up_right
- up
- up_left
- left
- down_left

Do not mix abbreviations such as dr, ne, south, or front in final filenames.

### Action Naming Rules
Use these exact action keys:
- idle
- walk
- slash
- dash_ready
- dash_recover
- hit
- parry

### File Naming Rules
Individual frame filenames:

```text
hunter_<action>_<direction>_<frame>.png
```

Examples:

```text
hunter_idle_down_000.png
hunter_walk_down_003.png
hunter_slash_down_right_004.png
hunter_dash_ready_right_001.png
hunter_dash_recover_up_002.png
hunter_hit_left_000.png
hunter_parry_up_left_001.png
```

Optional sprite sheet filenames:

```text
hunter_<action>_<direction>_sheet.png
```

Examples:

```text
hunter_idle_down_sheet.png
hunter_walk_down_right_sheet.png
hunter_slash_right_sheet.png
```

### Recommended Frame Counts
Start with key poses before filling in-between frames.

Recommended final counts:
- idle: 4 frames per direction
- walk: 6 or 8 frames per direction
- slash: 5 to 7 frames per direction
- dash_ready: 3 to 4 frames per direction
- dash_recover: 3 to 4 frames per direction
- hit: 2 to 3 frames per direction
- parry: 3 to 4 frames per direction

Do not generate a complete 8-direction animation set in one image-generation pass. First lock the base pose and key poses, then create the in-between frames.

### Godot Test Setup
For quick testing in Godot, each action/direction should be importable into AnimatedSprite2D or an equivalent SpriteFrames resource.

Suggested animation names:

```text
idle_down
idle_down_right
idle_right
idle_up_right
idle_up
idle_up_left
idle_left
idle_down_left
walk_down
walk_down_right
slash_down
dash_ready_down
dash_recover_down
hit_down
parry_down
```

Use the same naming pattern for all actions and directions:

```text
<action>_<direction>
```

Suggested playback speeds:
- idle: 4 to 6 fps
- walk: 8 to 12 fps
- slash: 12 to 16 fps
- dash_ready: 10 to 14 fps
- dash_recover: 10 to 14 fps
- hit: 10 to 12 fps
- parry: 10 to 14 fps

During testing, verify:
- frame-to-frame scale stability
- pivot stability
- readable direction changes
- natural hand-to-sword contact
- no frame popping in coat, hair, shoes, or sword length
- no unwanted background pixels after transparency cleanup
## Theme Structure
The game contains multiple world themes, such as:
- fantasy regions with mystical forests, grasslands, ruins, and dungeons
- dark urban regions with rainy night streets, cyberpunk mood, and mechanized city spaces

These world themes are not locked to specific characters.

Characters and stages are separate axes:
- characters define combat identity and playstyle
- stages define environment, enemy theme, and atmosphere

Some characters may feel more naturally suited to certain stages, but any character should be playable in any stage.

A mage can enter an urban stage.
A hunter can enter a fantasy stage.

The goal is not strict pairing, but strong thematic support:
- characters have strong combat identities
- stages have strong environmental and enemy identities
- these can align naturally, but do not need to be exclusive

## Enemy Theme Direction
Enemy design should primarily follow the stage/world theme, not the selected character.

Fantasy-themed stages should feature enemies such as:
- fantasy beasts
- monsters
- undead
- dungeon guardians
- mystical creatures

Urban-themed stages should feature enemies such as:
- mechanized units
- cybernetic enemies
- hostile city-night threats
- industrial or surveillance-based enemies

The selected character may contrast with the stage theme, and that contrast is allowed.

## Stage Identity
Each stage theme should feel like a package made of:
- environment and atmosphere
- enemy set
- boss identity
- visual language
- combat rhythm

This means stage identity is not just background art.
A fantasy stage and an urban stage should also feel different through enemy behavior and boss design.

### Fantasy Stage Feel
Examples:
- mystical forest
- grassland
- ruins
- dungeon

Possible mood:
- mysterious
- ancient
- magical
- natural but dangerous

Possible enemy/boss direction:
- monsters
- beasts
- undead
- summoned creatures
- heavy magical or ancient guardian bosses

### Urban Stage Feel
Examples:
- rainy night city
- dark alleyways
- neon-lit cyberpunk streets
- mechanized industrial districts

Possible mood:
- cold
- tense
- sharp
- industrial
- hostile modern-night atmosphere

Possible enemy/boss direction:
- drones
- mechanized hounds
- cybernetic enemies
- armed or enhanced humanoid threats
- fast, sharp, technological bosses

## Boss Design Principle
Bosses must act as execution checks, not just stat checks.

The player should be rewarded for:
- reading patterns
- dodging correctly
- guarding at the right moment
- attacking during safe openings
- understanding the strengths of their current build

A strong build should help, but should not replace proper play.

## Growth Design Principle
Growth should feel fast and noticeable during normal stages.

Level-up upgrades should:
- increase power in a way the player can feel immediately
- create meaningful combat variation
- support different character identities
- help prepare the player for boss combat

Growth should not become abstract.
Whenever possible, upgrades should create visible changes in combat rhythm, area coverage, damage pattern, or survivability.

## Camera and Readability Principle
Because this is a 2.5D quarter-view game:
- character silhouettes must remain readable
- enemy attack direction must remain readable
- player movement direction must remain readable
- hit timing and danger zones must be readable at a glance

Readability must be prioritized over excessive detail, clutter, or flashy effects.

## Urban Map Sheet Direction
The rainy city stage should eventually move from a repeated full background image to a composable tile sheet.

The base urban tile sheet should use 512x256 diamond tiles for 2.5D quarter-view readability.

The sheet should be grouped by map-building purpose:
- road base tiles: 2-3 wet asphalt variants
- road centerline tiles: straight dashed centerline and a broken/worn variant
- crosswalk tiles: start, middle, and end pieces
- sidewalk base tiles: 2-3 wet concrete variants
- curb tiles: upper road edge and lower road edge
- road-sidewalk corner tiles: upper-left, upper-right, lower-left, and lower-right corners
- intersection tiles: wider road crossing pieces and crosswalk intersection pieces
- floor detail tiles: manholes, drains, puddles, cracked asphalt, and worn concrete

The intended composition rules are:
- build wide roads by repeating road base tiles and centerline tiles in a continuous row
- place curb tiles as one continuous row above and below road bands
- fill outside the curb rows with sidewalk base tiles
- build crosswalks from start, middle, and end pieces at specific columns
- use intersection tile groups for road crossings instead of random road tile scattering

Direction matters for both floor tiles and future obstacles.
Road tiles that run horizontally and road tiles that run diagonally should be separate assets.
Future obstacle sprites such as cars and barricades should eventually have direction variants, but the first obstacle pass can use one direction per prop while the map sheet structure is stabilized.

## Long-Term Direction
As the project grows, it should continue to reinforce these pillars:
- satisfying wave clear
- rapid growth
- skill-based boss combat
- clear character identity
- strong stage identity
- quarter-view readability

Whenever a new feature is added, it should support at least one of these pillars and should not weaken the others.

