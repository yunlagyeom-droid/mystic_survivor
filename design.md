# design.md

## Game Summary
This project is a 2.5D quarter-view action game that combines horde-survival combat with RPG-style boss encounters.

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

## Long-Term Direction
As the project grows, it should continue to reinforce these pillars:
- satisfying wave clear
- rapid growth
- skill-based boss combat
- clear character identity
- strong stage identity
- quarter-view readability

Whenever a new feature is added, it should support at least one of these pillars and should not weaken the others.