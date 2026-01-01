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
    vx = 0,              -- Velocity X
    vy = 0,              -- Velocity Y (formerly 'velocity')
    gravity = 1000,      -- Gravity pulls the bird down
    sprites = {},        -- Stores loaded animation frames
    currentFrame = 1,
    animTimer = 0,
    animSpeed = 0.05,    -- Time between frames
    isAnimating = false,
    angle = 0,            -- Rotation based on velocity
    jumpCount = 0         -- Track jumps between pipes
}

-- Slingshot / Aiming Properties
local aiming = {
    active = false,
    startX = 0,
    startY = 0,
    currentX = 0,
    currentY = 0,
    powerMultiplier = 3.0, -- Multiplier for launch force
    maxPull = 200          -- Cap the pull distance
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

-- Floating Text for Score Feedback
local floatingTexts = {}

-- Audio
local sounds = {}

-- Loads the highscore from the local file
function loadHighscore()
    local f = io.open(highscoreFile, "r")
    if f then
        local content = f:read("*all")
        highscore = tonumber(content) or 0
        f:close()
    end
end

-- Saves the current highscore to the local file
function saveHighscore()
    local f = io.open(highscoreFile, "w")
    if f then
        f:write(tostring(highscore))
        f:close()
        print("Saved highscore: " .. highscore)
    else
        print("Error: Could not save highscore to " .. highscoreFile)
    end
end

function love.load()
    -- Load Bird Sprites into memory
    for i = 1, 5 do
        bird.sprites[i] = love.graphics.newImage("Sprites/Bird/frame-" .. i .. ".png")
    end

    -- Load Audio
    sounds.jump = love.audio.newSource("Audio/sfx_movement_ladder1b.wav", "static")
    sounds.score = love.audio.newSource("Audio/sfx_sounds_powerup6.wav", "static")
    sounds.music = love.audio.newSource("Audio/BGM.wav", "stream")
    
    sounds.music:setLooping(true)
    sounds.music:play()

    loadHighscore()
    resetGame()
end

-- Resets all game variables to their initial state for a new game
function resetGame()
    bird.x = 100
    bird.y = 300
    bird.vx = 0
    bird.vy = 0
    bird.currentFrame = 1
    bird.animTimer = 0
    bird.isAnimating = false
    bird.angle = 0
    bird.jumpCount = 0
    pipes = {}
    floatingTexts = {}
    spawnTimer = 0
    score = 0
    gameState = states.START
    aiming.active = false
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
    if score >= highscore then
        highscore = score
        saveHighscore()
    end
end

function love.update(dt)
    -- Input handling for aiming
    local isAiming = aiming.active
    
    -- Time Dilation: Slow down everything if aiming
    local timeScale = isAiming and 0.1 or 1.0
    local gameDt = dt * timeScale

    -- Scroll background independently of game state for visual continuity
    backgroundScroll = (backgroundScroll + backgroundSpeed * gameDt) % 80

    if gameState == states.PLAYING then
        -- Update Floating Texts
        for i = #floatingTexts, 1, -1 do
            local ft = floatingTexts[i]
            ft.timer = ft.timer + gameDt
            if ft.timer > ft.duration then
                table.remove(floatingTexts, i)
            end
        end

        -- Bird Physics
        bird.vy = bird.vy + bird.gravity * gameDt
        bird.y = bird.y + bird.vy * gameDt
        bird.x = bird.x + bird.vx * gameDt

        -- Friction/Drag on X velocity to gradually stop horizontal movement
        local drag = 2.0 -- Friction coefficient
        bird.vx = bird.vx - (bird.vx * drag * gameDt)

        -- Clamp Bird to Screen Boundaries
        if bird.x < bird.radius then bird.x = bird.radius; bird.vx = 0 end
        if bird.x > love.graphics.getWidth() - bird.radius then bird.x = love.graphics.getWidth() - bird.radius; bird.vx = 0 end

        -- Rotation logic: Tilt up when jumping, down when falling
        bird.angle = math.min(math.pi / 2, math.max(-math.pi / 4, bird.vy * 0.002))

        -- Animation Logic: Cycle through frames
        if bird.isAnimating or math.abs(bird.vx) > 10 or math.abs(bird.vy) > 10 then
            bird.animTimer = bird.animTimer + gameDt
            if bird.animTimer >= bird.animSpeed then
                bird.animTimer = 0
                bird.currentFrame = bird.currentFrame + 1
                if bird.currentFrame > #bird.sprites then
                    bird.currentFrame = 1
                    bird.isAnimating = false -- Stop loop if strictly one-shot, but we probably want loop
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
        spawnTimer = spawnTimer + gameDt
        if spawnTimer > spawnInterval then
            spawnPipe()
            spawnTimer = 0
        end

        -- Pipes Update Loop
        for i = #pipes, 1, -1 do
            local p = pipes[i]
            p.x = p.x - pipeSpeed * gameDt

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
                local points = 1
                -- Bonus for long jumps/fast moves could be added here
                
                score = score + points
                p.scored = true
                
                sounds.score:stop()
                sounds.score:play()
                
                -- Spawn floating text
                table.insert(floatingTexts, {
                    x = bird.x,
                    y = bird.y - 30,
                    text = "+" .. points,
                    timer = 0,
                    duration = 0.8
                })
                
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

function love.mousepressed(x, y, button)
    if button == 1 then
        if gameState == states.GAMEOVER then
            resetGame()
        else
            -- Start aiming
            aiming.active = true
            aiming.startX = x
            aiming.startY = y
            aiming.currentX = x
            aiming.currentY = y
            
            -- If first start
            if gameState == states.START then
                gameState = states.PLAYING
            end
        end
    end
end

function love.mousemoved(x, y)
    if aiming.active then
        aiming.currentX = x
        aiming.currentY = y
    end
end

function love.mousereleased(x, y, button)
    if button == 1 and aiming.active then
        aiming.active = false
        
        -- Calculate vector (Start - End) for "Pull back" mechanic
        local dx = aiming.startX - x
        local dy = aiming.startY - y
        
        -- Cap the magnitude
        local len = math.sqrt(dx*dx + dy*dy)
        if len > aiming.maxPull then
            local scale = aiming.maxPull / len
            dx = dx * scale
            dy = dy * scale
        end
        
        -- Apply Impulse
        bird.vx = dx * aiming.powerMultiplier
        bird.vy = dy * aiming.powerMultiplier
        
        sounds.jump:stop()
        sounds.jump:play()
        bird.isAnimating = true
    end
end

function love.keypressed(key)
    -- Global input handling
    if key == "escape" then
        love.event.quit()
    end
    -- Removed SPACE jump to enforce slingshot only
end

function love.draw()
    -- Draw Checkerboard Background
    local cellSize = 40
    for y = 0, love.graphics.getHeight(), cellSize do
        for x = -cellSize * 2, love.graphics.getWidth() + cellSize, cellSize do
            if (math.floor(x / cellSize) + math.floor(y / cellSize)) % 2 == 0 then
                love.graphics.setColor(0.96, 0.96, 0.86)
            else
                love.graphics.setColor(0.93, 0.91, 0.82)
            end
            love.graphics.rectangle("fill", x - backgroundScroll, y, cellSize, cellSize)
        end
    end

    -- Draw Pipes
    for _, p in ipairs(pipes) do
        love.graphics.setColor(0.2, 0.8, 0.2)
        love.graphics.rectangle("fill", p.x, 0, pipeWidth, p.top)
        love.graphics.rectangle("fill", p.x, p.top + pipeGap, pipeWidth, love.graphics.getHeight() - (p.top + pipeGap))
        love.graphics.setColor(0, 0, 0)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", p.x, 0, pipeWidth, p.top)
        love.graphics.rectangle("line", p.x, p.top + pipeGap, pipeWidth, love.graphics.getHeight() - (p.top + pipeGap))
    end

    -- Draw Bird
    love.graphics.setColor(1, 1, 1)
    local sprite = bird.sprites[bird.currentFrame]
    local bScaleX = (bird.radius * 2) / sprite:getWidth()
    local bScaleY = (bird.radius * 2) / sprite:getHeight()
    love.graphics.draw(sprite, bird.x, bird.y, bird.angle, bScaleX, bScaleY, sprite:getWidth()/2, sprite:getHeight()/2)

    -- Draw Slingshot Visualization
    if aiming.active then
        -- Calculate clamped end point
        local dx = aiming.currentX - aiming.startX
        local dy = aiming.currentY - aiming.startY
        local len = math.sqrt(dx*dx + dy*dy)
        if len > aiming.maxPull then
            local scale = aiming.maxPull / len
            dx = dx * scale
            dy = dy * scale
        end
        
        -- Draw line from Bird in the direction of the launch (Opposite to drag)
        -- Visual 1: Draw the "String" being pulled
        love.graphics.setColor(0, 0, 0, 0.5)
        love.graphics.setLineWidth(4)
        love.graphics.line(bird.x, bird.y, bird.x + dx, bird.y + dy)
        
        -- Visual 2: Draw the projected launch direction (optional, but helpful)
        love.graphics.setColor(1, 0, 0, 0.5)
        love.graphics.setLineWidth(2)
        love.graphics.line(bird.x, bird.y, bird.x - dx, bird.y - dy)
        
        -- Draw circle at end of pull
        love.graphics.setColor(0, 0, 0, 0.5)
        love.graphics.circle("fill", bird.x + dx, bird.y + dy, 10)
    end

    -- Draw Floating Texts
    for _, ft in ipairs(floatingTexts) do
        local progress = ft.timer / ft.duration
        local scale = math.sin(progress * math.pi) * 2
        local alpha = 1 - progress
        
        love.graphics.setColor(0, 0, 0, alpha)
        love.graphics.print(ft.text, ft.x + 2, ft.y + 2, 0, scale, scale, 10, 10)
        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.print(ft.text, ft.x, ft.y, 0, scale, scale, 10, 10)
    end

    -- UI
    love.graphics.setColor(0, 0, 0)
    if gameState == states.START then
        love.graphics.printf("Click and Drag to Launch!\nHighscore: " .. highscore, 0, love.graphics.getHeight()/2 - 20, love.graphics.getWidth(), "center")
    elseif gameState == states.GAMEOVER then
        love.graphics.printf("GAME OVER\nScore: " .. score .. "\nHighscore: " .. highscore .. "\nClick to Restart", 0, love.graphics.getHeight()/2 - 40, love.graphics.getWidth(), "center")
    else
        love.graphics.setFont(love.graphics.newFont(24))
        love.graphics.print("Score: " .. score, 20, 20)
        love.graphics.print("Best: " .. highscore, 20, 50)
    end
end