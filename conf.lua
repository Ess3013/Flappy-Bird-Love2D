-- Configuration file for the Love2D game
-- This file is loaded before the main game loop to set up the environment.

function love.conf(t)
    -- Unique identity for the game (used for save directories)
    t.identity = "flappy_bird_simple"
    
    -- Window Configuration
    t.window.title = "Flappy Bird - Simple" -- Text in the window title bar
    t.window.width = 800                    -- Window width in pixels
    t.window.height = 600                   -- Window height in pixels
    t.window.resizable = false              -- Disable window resizing to keep logic simple
    
    -- Module Configuration
    -- We disable the physics module as we are implementing custom simple physics
    t.modules.physics = false
    
    -- Debugging
    t.console = true -- Enable the external console window for print() output debugging
end
