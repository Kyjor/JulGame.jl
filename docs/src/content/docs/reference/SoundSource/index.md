---
title: SoundSource Component
description: Add audio playback to your game objects in JulGame
---

# SoundSource Component

The SoundSource component allows you to add audio playback to your game entities. It supports both sound effects and music playback with various control options.

## Overview

The SoundSource component handles:
- Playing sound effects and music
- Volume control
- Looping audio
- Automatic playback on entity creation

## Adding a SoundSource Component

```julia
# Create a new entity
entity = Entity("AudioPlayer")

# Create and add a sound source component
soundSource = SoundSourceModule.create("music.mp3", true)  # path, isMusic
entity.addComponent(soundSource)

# Add to scene
scene.addEntity(entity)
```

## Function Reference

### create()

```julia
SoundSourceModule.create(
    path::String,                         # Path to audio file (relative to assets/sounds/)
    isMusic::Bool = false,                # Whether this is music (true) or a sound effect (false)
    volume::Integer = 128,                # Volume (0-128)
    channel::Integer = -1,                # Audio channel (-1 for automatic)
    playOnStart::Bool = false             # Whether to play automatically on creation
)
```

### playSoundOnce()

A static function for playing one-off sounds without creating a SoundSource component:

```julia
SoundSourceModule.playSoundOnce(
    path::String,                         # Path to audio file
    volume::Float64 = 1.0                 # Volume (0.0-1.0)
)
```

## Properties

| Property | Type | Description |
|----------|------|-------------|
| `path` | `String` | Path to the audio file |
| `isMusic` | `Bool` | Whether this is music (true) or a sound effect (false) |
| `volume` | `Int32` | Volume level (0-128) |
| `channel` | `Int32` | Audio channel (-1 for automatic) |
| `playOnStart` | `Bool` | Whether the sound plays automatically when created |
| `isPlaying` | `Bool` | Whether the sound is currently playing (read-only) |

## Audio Control Methods

### play()

```julia
# Play the sound
SoundSourceModule.play(soundSource)
```

### pause()

```julia
# Pause the sound
SoundSourceModule.pause(soundSource)
```

### stop()

```julia
# Stop the sound
SoundSourceModule.stop(soundSource)
```

### setVolume()

```julia
# Set the volume
SoundSourceModule.setVolume(soundSource, 64)  # Half volume (0-128)
```

## Examples

### Background Music

```julia
# Create background music that starts automatically
music = SoundSourceModule.create(
    "music/background.mp3",    # Path
    true,                      # Is music
    96,                        # Volume (75%)
    -1,                        # Auto channel
    true                       # Play on start
)
entity.addComponent(music)
```

### Sound Effect with Script Control

```julia
# Create a sound effect that will be triggered from a script
soundEffect = SoundSourceModule.create(
    "sfx/explosion.wav",       # Path
    false,                     # Is sound effect (not music)
    128,                       # Full volume
    1,                         # Channel 1
    false                      # Don't play on start
)
entity.addComponent(soundEffect)

# Play the sound in a script
function onCollisionEnter(script::YourScript, entity, other)
    if other.name == "Enemy"
        soundSource = entity.getComponent("SoundSource")
        SoundSourceModule.play(soundSource)
    end
end
```

### One-Off Sound Effects

For simple sound effects that don't need a dedicated component:

```julia
function onCollisionEnter(script::YourScript, entity, other)
    if other.name == "Coin"
        # Play a sound without creating a component
        SoundSourceModule.playSoundOnce("sfx/coin.wav", 1.0)
    end
end
```

## Music vs. Sound Effects

JulGame treats music and sound effects differently:

| Feature | Music | Sound Effects |
|---------|-------|---------------|
| **File Types** | MP3, OGG, FLAC | WAV, MP3, OGG |
| **Channels** | Single music channel | Multiple channels |
| **Use Case** | Background music, long tracks | Short effects, multiple instances |
| **Looping** | Usually loops | Usually plays once |
| **Memory Usage** | Streaming (low memory) | Loaded entirely (higher memory) |

## Audio Formats

JulGame supports various audio formats:

- **WAV**: Best for short sound effects
- **MP3**: Good compression, works for music and sounds
- **OGG**: Better compression than MP3, open format
- **FLAC**: Lossless quality but larger file size

## Performance Considerations

- **Limit Simultaneous Sounds**: Too many sounds at once can cause audio distortion
- **Use Appropriate Formats**: WAV for short effects, MP3/OGG for music
- **Channel Management**: Use specific channels for important sounds to prevent them from being interrupted
- **Volume Balance**: Keep a good balance between music (lower) and sound effects (higher)

## See Also

- [UI Components](/JulGame.jl/reference/UI/) - For user interface elements
- [Animator](/JulGame.jl/reference/Animator/) - For visual animations
- [Scene Management](/JulGame.jl/general/core-concepts/#scene-management) - For scene organization 