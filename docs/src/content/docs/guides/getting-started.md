---
title: Getting Started with JulGame
description: Learn how to install and set up JulGame for your first project
---

# Getting Started with JulGame

This guide will walk you through the process of installing JulGame, setting up your development environment, and creating your first project.

## Installation

JulGame is available as a Julia package. You can install it using Julia's package manager:

### Stable Release (Recommended)

```julia
using Pkg
Pkg.add("JulGame")
```

Or from the package manager prompt (`]`):

```
] add JulGame
```

### Development Version

If you want the latest features and improvements, you can install directly from the GitHub repository:

```
] add https://github.com/Kyjor/JulGame.jl
```

For bleeding-edge features that may be less stable:

```
] add https://github.com/Kyjor/JulGame.jl#develop
```

## Setting Up the Editor

JulGame comes with a built-in editor that helps you design your games visually.

### Option 1: Download the Editor

You can download the latest release of the editor from the [GitHub releases page](https://github.com/Kyjor/JulGame.jl/releases).

### Option 2: Run the Editor from Source

Alternatively, you can run the editor directly from the source:

1. Navigate to the editor directory:
   ```
   cd ~/.julia/packages/JulGame/[version]/src/editor/Editor/src/
   ```
   (Replace `[version]` with your installed version)

2. Run the editor:
   ```
   julia Editor.jl
   ```

## Creating Your First Project

1. Open the JulGame Editor
2. Click on "New Project" or open an existing project
3. Download the [example project](https://github.com/Kyjor/JulGame-Example) to see a working game

## Project Structure

A typical JulGame project has the following structure:

```
MyGame/
├── assets/
│   ├── images/
│   ├── audio/
│   └── fonts/
├── scenes/
│   └── MainScene.json
├── scripts/
│   └── PlayerController.jl
└── Run.jl
```

- `assets/`: Contains all your game assets
- `scenes/`: Contains your game scenes saved as JSON files
- `scripts/`: Contains Julia script files for game logic
- `Run.jl`: The main entry point to run your game

## Running Your Game

To run your game, navigate to your project directory and execute the `Run.jl` file:

```bash
cd path/to/your/project
julia Run.jl
```

## Next Steps

- Check out the [Tutorials](/JulGame.jl/guides/tutorials/) for step-by-step guides
- Explore the [Examples](/JulGame.jl/guides/examples/) to learn by example
- Learn about the [Core Concepts](/JulGame.jl/general/core-concepts/) behind JulGame 