# Project Context: Flappy Bird (Love2D)

## Project Overview
This directory is the workspace for a Flappy Bird clone game developed using the [LÖVE (Love2D)](https://love2d.org/) framework.

*   **Project Name:** Flappy Bird
*   **Framework:** LÖVE (Lua)
*   **Current State:** Initialization Phase (New Project)

## Directory Structure
The project is currently empty. The following structure is recommended for development:

*   `main.lua`: The main entry point containing the standard LÖVE callbacks (`love.load`, `love.update`, `love.draw`).
*   `conf.lua`: Configuration file for setting up the window (dimensions, title, fullscreen) and enabling/disabling modules.
*   `assets/`: Directory containing game assets.
    *   `images/`: Sprites and background textures.
    *   `sounds/`: Audio effects and music.
    *   `fonts/`: Custom fonts.
*   `src/`: (Optional) Source code for game logic separation (e.g., `Bird.lua`, `Pipe.lua`, `StateMachine.lua`).

## Development Guidelines

### Prerequisites
*   **LÖVE Framework:** Installed and available in the system `PATH`.
*   **Sublime Text:** Used for code editing.

### Running the Game
To run the game, open a terminal in this directory and execute:

```powershell
love .
```

*Note: This assumes `love.exe` is in your system's PATH. If not, use the full path to the executable.*

### Conventions
*   **Naming:** PascalCase for classes/files (e.g., `Bird.lua`), camelCase for variables and functions.
*   **Class System:** Use a Lua class library (like `classic` or a simple closure-based approach) for entity management.
*   **Version Control:** Make a Git commit for every change or feature implemented in the game.

## Roadmap
1.  Initialize `main.lua` and `conf.lua`.
2.  Implement the basic Game Loop.
3.  Create the `Bird` class with gravity and jump physics.
4.  Implement scrolling background and ground.
5.  Create `Pipe` generation and movement logic.
6.  Implement collision detection.
7.  Add Game Over state and Scoring.

## Gemini Added Memories
- Commit every change made to the codebase to the git repository.
- Run the game (`love .`) after edits and commits to verify changes.

