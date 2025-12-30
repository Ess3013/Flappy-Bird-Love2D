-- Game States
-- simple state machine to manage game flow
local states = { START = "start", PLAYING = "playing", GAMEOVER = "gameover" }
local gameState = states.START

-- Bird Properties
-- Defines the player character's physics and animation state
local bird = {
    x = 100,
    y = 300,
    radius = 20,
    velocity = 0,
    gravity = 1200,      -- Gravity pulls the bird down
    jumpStrength = -400, -- Upward velocity applied on jump
    sprites = {},        -- Stores loaded animation frames
    currentFrame = 1,
    animTimer = 0,
    animSpeed = 0.05,    -- Time between frames
    isAnimating = false,
    angle = 0            -- Rotation based on velocity
}

-- Pipe Properties
-- Manages the obstacles
local pipes = {}
local pipeWidth = 80
local pipeGap = 180      -- Vertical space between top and bottom pipes
local pipeSpeed = 250    -- Speed at which pipes move left
local spawnTimer = 0
local spawnInterval = 1.8 -- Time in seconds between pipe spawns

-- Background
-- Parallax scrolling effect variables
local backgroundScroll = 0
local backgroundSpeed = 30 -- Parallax speed (slower than pipes to create depth)

-- Score
-- Tracks player progress and persistence
local score = 0
local highscore = 0
local highscoreFile = "highscore.txt"

-- Loads the highscore from the save directory if it exists
function loadHighscore()
    if love.filesystem.getInfo(highscoreFile) then
        local content = love.filesystem.read(highscoreFile)
        highscore = tonumber(content) or 0
    end
end

-- Saves the current highscore to the save directory
function saveHighscore()
    love.filesystem.write(highscoreFile, tostring(highscore))
end

function love.load()
    -- Load Bird Sprites into memory
    for i = 1, 5 do
        bird.sprites[i] = love.graphics.newImage("Sprites/Bird/frame-" .. i .. ".png")
    end
    loadHighscore()
    resetGame()
end

-- Resets all game variables to their initial state for a new game
function resetGame()
    bird.y = 300
    bird.velocity = 0
    bird.currentFrame = 1
    bird.animTimer = 0
    bird.isAnimating = false
    bird.angle = 0
    pipes = {}
    spawnTimer = 0
    score = 0
    gameState = states.START
end

-- Creates a new pipe pair with random height
function spawnPipe()
    local minHeight = 100
    local maxHeight = love.graphics.getHeight() - pipeGap - minHeight
    local topHeight = math.random(minHeight, maxHeight)
    
    table.insert(pipes, {
        x = love.graphics.getWidth(),
        top = topHeight,
        scored = false -- Track if the player has passed this pipe
    })
end

-- Handles game over logic and highscore updating
function gameOver()
    gameState = states.GAMEOVER
    if score > highscore then
        highscore = score
        saveHighscore()
    end
end

function love.update(dt)
    -- Scroll background independently of game state for visual continuity
    backgroundScroll = (backgroundScroll + backgroundSpeed * dt) % 80 -- Modulo 80 (2 * cellSize) to keep numbers small

    if gameState == states.PLAYING then
        -- Bird Physics: Apply gravity
        bird.velocity = bird.velocity + bird.gravity * dt
        bird.y = bird.y + bird.velocity * dt

        -- Rotation logic: Tilt up when jumping, down when falling
        bird.angle = math.min(math.pi / 2, math.max(-math.pi / 4, bird.velocity * 0.002))

        -- Animation Logic: Cycle through frames
        if bird.isAnimating then
            bird.animTimer = bird.animTimer + dt
            if bird.animTimer >= bird.animSpeed then
                bird.animTimer = 0
                bird.currentFrame = bird.currentFrame + 1
                if bird.currentFrame > #bird.sprites then
                    bird.currentFrame = 1
                    bird.isAnimating = false
                end
            end
        else
            bird.currentFrame = 1 -- Reset to idle frame
        end

        -- Collision (Floor/Ceiling): Game over if bird goes out of bounds
        if bird.y - bird.radius < 0 or bird.y + bird.radius > love.graphics.getHeight() then
            gameOver()
        end

        -- Spawning Pipes
        spawnTimer = spawnTimer + dt
        if spawnTimer > spawnInterval then
            spawnPipe()
            spawnTimer = 0
        end

        -- Pipes Update Loop
        for i = #pipes, 1, -1 do
            local p = pipes[i]
            p.x = p.x - pipeSpeed * dt

            -- Collision Detection (AABB vs Circle approximation)
            -- Check horizontal overlap
            if bird.x + bird.radius > p.x and bird.x - bird.radius < p.x + pipeWidth then
                -- Check vertical overlap (hit top or bottom pipe)
                if bird.y - bird.radius < p.top or bird.y + bird.radius > p.top + pipeGap then
                    gameOver()
                end
            end

            -- Scoring: Increment score when passing a pipe
            if not p.scored and p.x + pipeWidth < bird.x then
                score = score + 1
                p.scored = true
                -- Update highscore live for player feedback
                if score > highscore then
                    highscore = score
                end
            end

            -- Cleanup: Remove pipes that have gone off-screen
            if p.x + pipeWidth < 0 then
                table.remove(pipes, i)
            end
        end
    end
end

function love.keypressed(key)
    -- Global input handling
    if key == "escape" then
        love.event.quit()
    end

    if key == "space" then
        if gameState == states.START then
            gameState = states.PLAYING
            bird.isAnimating = true
        elseif gameState == states.PLAYING then
            -- Jump action
            bird.velocity = bird.jumpStrength
            bird.isAnimating = true
            bird.currentFrame = 1
            bird.animTimer = 0
        elseif gameState == states.GAMEOVER then
            resetGame()
        end
    end
end

function love.draw()
    -- Draw Checkerboard Background
    -- Renders a grid pattern that scrolls to simulate movement
    local cellSize = 40
    -- We draw a bit wider than the screen to handle the scrolling shift
    for y = 0, love.graphics.getHeight(), cellSize do
        for x = -cellSize * 2, love.graphics.getWidth() + cellSize, cellSize do
            -- Determine color based on the logical grid position
            if (math.floor(x / cellSize) + math.floor(y / cellSize)) % 2 == 0 then
                love.graphics.setColor(0.96, 0.96, 0.86) -- Beige 1
            else
                love.graphics.setColor(0.93, 0.91, 0.82) -- Beige 2
            end
            
            -- Draw at the scrolled position
            -- We subtract backgroundScroll to move left
            -- backgroundScroll is already modulo'd in update, but we rely on the loop's 'x' being aligned to grid
            love.graphics.rectangle("fill", x - backgroundScroll, y, cellSize, cellSize)
        end
    end

    -- Draw Pipes
    for _, p in ipairs(pipes) do
        love.graphics.setColor(0.2, 0.8, 0.2) -- Green
        love.graphics.rectangle("fill", p.x, 0, pipeWidth, p.top) -- Top pipe body
        love.graphics.rectangle("fill", p.x, p.top + pipeGap, pipeWidth, love.graphics.getHeight() - (p.top + pipeGap)) -- Bottom pipe body
        
        -- Draw outlines for better visibility
        love.graphics.setColor(0, 0, 0)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", p.x, 0, pipeWidth, p.top)
        love.graphics.rectangle("line", p.x, p.top + pipeGap, pipeWidth, love.graphics.getHeight() - (p.top + pipeGap))
    end

    -- Draw Bird
    love.graphics.setColor(1, 1, 1)
    local sprite = bird.sprites[bird.currentFrame]
    -- Calculate scale to fit the sprite into the collision radius
    local bScaleX = (bird.radius * 2) / sprite:getWidth()
    local bScaleY = (bird.radius * 2) / sprite:getHeight()
    -- Draw centered on position with rotation
    love.graphics.draw(sprite, bird.x, bird.y, bird.angle, bScaleX, bScaleY, sprite:getWidth()/2, sprite:getHeight()/2)

    -- UI
    love.graphics.setColor(0, 0, 0)
    if gameState == states.START then
        love.graphics.printf("Press SPACE to Start\nHighscore: " .. highscore, 0, love.graphics.getHeight()/2 - 20, love.graphics.getWidth(), "center")
    elseif gameState == states.GAMEOVER then
        love.graphics.printf("GAME OVER\nScore: " .. score .. "\nHighscore: " .. highscore .. "\nPress SPACE to Restart", 0, love.graphics.getHeight()/2 - 40, love.graphics.getWidth(), "center")
    else
        -- HUD during gameplay
        love.graphics.setFont(love.graphics.newFont(24))
        love.graphics.print("Score: " .. score, 20, 20)
        love.graphics.print("Best: " .. highscore, 20, 50)
    end
end
