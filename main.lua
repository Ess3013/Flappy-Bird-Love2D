-- Game States
-- Simple state machine to manage game flow between Start, Playing, and Game Over screens.
local states = { MENU = "menu", START = "start", PLAYING = "playing", GAMEOVER = "gameover" }
local gameState = states.MENU

-- Main Menu Properties
local menuTitleTimer = 0
local startButton = {
    x = 0, y = 0, width = 200, height = 60, text = "Start Game"
}

-- Bird Properties
-- Defines the player character's physics, position, and animation state.
local bird = {
    x = 100,             -- Initial X position
    y = 300,             -- Initial Y position
    radius = 20,         -- Collision radius
    vy = 0,              -- Velocity Y (vertical speed)
    gravity = 400,       -- Gravity acceleration (pixels/second^2)
    sprites = {},        -- Table to store loaded animation frames
    currentFrame = 1,    -- Current animation frame index
    animTimer = 0,       -- Timer for animation frame switching
    animSpeed = 0.05,    -- Time (in seconds) between animation frames
    isAnimating = false, -- Flag to check if the bird is currently animating (flapping)
    angle = 0,           -- Rotation angle based on velocity (for visual feedback)
    jumpCount = 0        -- Track jumps between pipes (unused in current logic but kept for future use)
}

-- World Movement Properties
-- Controls the scrolling of the world (pipes) relative to the bird.
-- Instead of the bird moving forward, the world moves backward.
local worldSpeed = 0       -- Current horizontal speed of the world
local distanceTraveled = 0 -- Total distance simulated/traveled
local nextPipeDist = 0     -- Distance threshold to spawn the next pipe

-- Slingshot / Aiming Properties
-- Variables for the "pull-and-release" launch mechanic.
local aiming = {
    active = false,        -- Is the player currently dragging the mouse?
    startX = 0,            -- Mouse X position where drag started
    startY = 0,            -- Mouse Y position where drag started
    currentX = 0,          -- Current Mouse X position during drag
    currentY = 0,          -- Current Mouse Y position during drag
    powerMultiplier = 3.0, -- Multiplier to convert drag distance to velocity
    maxPull = 200          -- Maximum pixel distance for drag (clamps power)
}

-- Pipe Properties
-- Manages the obstacles (pipes) in the game.
local pipes = {}           -- Table containing all active pipe objects
local pipeWidth = 80       -- Width of a pipe in pixels
local pipeGap = 180        -- Vertical gap space between top and bottom pipes
local pipeDistInterval = 400 -- Horizontal distance in pixels between consecutive pipes

-- Background
-- Parallax scrolling effect variables.
local backgroundScroll = 0 -- Current scroll offset for the background pattern
-- backgroundSpeed is derived dynamically from worldSpeed in love.update

-- Score
-- Tracks player progress and persistence.
local score = 0                   -- Current game score
local timeLeft = 0                -- Time Attack: Remaining time
local timePerPipe = 1           -- Time bonus per pipe cleared
local pipesClearedInLaunch = 0    -- Combo counter: pipes cleared in a single launch
local highscore = 0               -- Highest score achieved
local highscoreFile = "highscore.txt" -- File path for persistence

-- Floating Text for Score Feedback
-- Stores temporary text objects for visual effects (e.g., "+1 Score").
local floatingTexts = {}

-- Audio
-- Table to store loaded sound sources.
local sounds = {}

-- Loads the highscore from the local file system.
-- If the file doesn't exist, defaults to 0.
function loadHighscore()
    local f = io.open(highscoreFile, "r")
    if f then
        local content = f:read("*all")
        highscore = tonumber(content) or 0
        f:close()
    end
end

-- Saves the current highscore to the local file system.
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

-- LÖVE Load Callback
-- Called once at the start of the game. Used for initialization.
function love.load()
    -- Load Bird Sprites into memory
    -- Assumes filenames are frame-1.png to frame-5.png in the correct directory
    for i = 1, 5 do
        bird.sprites[i] = love.graphics.newImage("Sprites/Bird/frame-" .. i .. ".png")
    end

    -- Load Audio Assets
    -- 'static' is for short sounds loaded fully into memory.
    -- 'stream' is for longer music files streamed from disk.
    sounds.jump = love.audio.newSource("Audio/sfx_movement_ladder1b.wav", "static")
    sounds.score = love.audio.newSource("Audio/sfx_sounds_powerup6.wav", "static")
    sounds.music = love.audio.newSource("Audio/BGMNew.wav", "stream")
    
    -- Configure and play background music
    sounds.music:setLooping(true)
    sounds.music:play()

    -- Initialize game state
    loadHighscore()
    resetGame()
    gameState = states.MENU -- Force menu on startup
end

-- Resets all game variables to their initial state for a new game session.
function resetGame()
    -- Reset Bird
    bird.x = 100
    bird.y = 300
    bird.vy = 0
    bird.currentFrame = 1
    bird.animTimer = 0
    bird.isAnimating = false
    bird.angle = 0
    bird.jumpCount = 0
    
    -- Reset Environment
    pipes = {}
    floatingTexts = {}
    score = 0
    pipesClearedInLaunch = 0
    timeLeft = 30 -- Time Attack: Start with 30 seconds
    gameState = states.START
    aiming.active = false
    
    -- Reset Physics/World
    worldSpeed = 0
    distanceTraveled = 0
    nextPipeDist = 400 -- Set distance for the first pipe
end

-- Creates a new pipe pair with a random vertical offset.
-- @param xPos: The X coordinate where the pipe should be spawned.
function spawnPipe(xPos)
    local minHeight = 100
    -- Calculate max height ensuring there is room for the gap and bottom pipe
    local maxHeight = love.graphics.getHeight() - pipeGap - minHeight
    local topHeight = math.random(minHeight, maxHeight)
    
    -- Insert new pipe object into the pipes table
    table.insert(pipes, {
        x = xPos,
        top = topHeight,
        scored = false -- Flag to ensure we only score this pipe once
    })
end

-- Handles game over logic, including state transition and highscore persistence.
function gameOver()
    gameState = states.GAMEOVER
    if score >= highscore then
        highscore = score
        saveHighscore()
    end
end

-- LÖVE Update Callback
-- Called every frame. Main game logic loop.
-- @param dt: Delta time (time in seconds since the last frame).
function love.update(dt)
    -- Input handling for aiming
    local isAiming = aiming.active
    
    -- Time Dilation Mechanic: 
    -- Slow down the game simulation significantly (0.1x) while the user is aiming
    -- to allow for precision adjustments. Normal speed (1.0x) otherwise.
    local timeScale = isAiming and 0.1 or 1.0
    local gameDt = dt * timeScale

    -- Update Background Parallax
    -- Scroll background based on worldSpeed with a factor (0.1) for depth effect.
    backgroundScroll = (backgroundScroll + worldSpeed * 0.1 * gameDt) % 80

    if gameState == states.MENU then
        menuTitleTimer = menuTitleTimer + dt
        -- Center button
        startButton.x = love.graphics.getWidth() / 2 - startButton.width / 2
        startButton.y = love.graphics.getHeight() / 2 + 50
    end

    -- Main Gameplay Loop
    if gameState == states.PLAYING then
        -- Update Time Attack Timer
        -- Decrease by real delta time (dt) to penalize excessive slow-motion aiming
        timeLeft = timeLeft - dt
        if timeLeft <= 0 then
            timeLeft = 0
            gameOver()
        end

        -- Update Floating Score Texts
        -- Iterate backwards to allow safe removal of items
        for i = #floatingTexts, 1, -1 do
            local ft = floatingTexts[i]
            ft.timer = ft.timer + gameDt
            if ft.timer > ft.duration then
                table.remove(floatingTexts, i)
            end
        end

        -- Update Bird Physics (Vertical)
        -- Apply gravity to vertical velocity
        bird.vy = bird.vy + bird.gravity * gameDt
        -- Update position based on velocity
        bird.y = bird.y + bird.vy * gameDt
        
        -- Update World Physics (Horizontal)
        -- Apply friction/drag to slow down the world movement over time
        local drag = 0.3 -- Friction coefficient
        worldSpeed = worldSpeed - (worldSpeed * drag * gameDt)
        
        -- Stop movement if it becomes negligible to prevent micro-sliding
        if math.abs(worldSpeed) < 1 then worldSpeed = 0 end

        -- Update Bird Rotation
        -- Tilt up when rising (jumping), tilt down when falling
        -- Clamped between -45 degrees (-pi/4) and 90 degrees (pi/2)
        bird.angle = math.min(math.pi / 2, math.max(-math.pi / 4, bird.vy * 0.002))

        -- Update Animation
        -- Animate if currently flapping (launching) OR if moving significantly fast
        if bird.isAnimating or math.abs(worldSpeed) > 50 or math.abs(bird.vy) > 10 then
            bird.animTimer = bird.animTimer + gameDt
            if bird.animTimer >= bird.animSpeed then
                bird.animTimer = 0
                bird.currentFrame = bird.currentFrame + 1
                -- Loop animation frames
                if bird.currentFrame > #bird.sprites then
                    bird.currentFrame = 1
                    bird.isAnimating = false -- Stop specific launch animation loop
                end
            end
        else
            bird.currentFrame = 1 -- Reset to idle frame when stationary
        end

        -- Boundary Collision Detection (Floor/Ceiling)
        -- Game over if the bird leaves the vertical screen bounds
        if bird.y - bird.radius < 0 or bird.y + bird.radius > love.graphics.getHeight() then
            gameOver()
        end

        -- Pipe Spawning Logic
        -- Accumulate distance traveled. Note: worldSpeed is pixels/sec.
        -- Only count positive forward movement.
        if worldSpeed > 0 then
            distanceTraveled = distanceTraveled + worldSpeed * gameDt
        end

        -- Check if enough distance has been covered to spawn a new pipe
        if distanceTraveled > nextPipeDist then
            spawnPipe(love.graphics.getWidth() + 50) -- Spawn just off-screen to the right
            nextPipeDist = nextPipeDist + pipeDistInterval
        end

        -- Pipes Update & Collision Loop
        for i = #pipes, 1, -1 do
            local p = pipes[i]
            
            -- Move pipe horizontally based on worldSpeed
            -- If worldSpeed is positive (bird moves right), pipes move left.
            p.x = p.x - worldSpeed * gameDt

            -- Collision Detection (AABB vs Circle approximation)
            -- First check if bird is within the horizontal range of the pipe
            if bird.x + bird.radius > p.x and bird.x - bird.radius < p.x + pipeWidth then
                -- Then check vertical collision (hitting the top or bottom pipe segments)
                if bird.y - bird.radius < p.top or bird.y + bird.radius > p.top + pipeGap then
                    gameOver()
                end
            end

            -- Scoring Logic
            -- Increment score when the bird successfully passes a pipe
            if not p.scored and p.x + pipeWidth < bird.x then
                pipesClearedInLaunch = pipesClearedInLaunch + 1
                -- Combo scoring: Points multiply based on pipes cleared in one launch
                local points = 1 * pipesClearedInLaunch
                
                score = score + points
                p.scored = true
                
                -- Time Attack Bonus
                local timeBonus = timePerPipe * pipesClearedInLaunch -- Bonus time scales with combo
                timeLeft = timeLeft + timeBonus
                
                -- Play score sound (interrupt previous if playing for rapid scoring)
                sounds.score:stop()
                sounds.score:play()
                
                -- Generate floating feedback text
                local text = "+" .. points .. " (+" .. timeBonus .. "s)"
                if pipesClearedInLaunch > 1 then
                    text = text .. " (x" .. pipesClearedInLaunch .. "!)"
                end
                
                table.insert(floatingTexts, {
                    x = bird.x,
                    y = bird.y - 30,
                    text = text,
                    timer = 0,
                    duration = 0.8
                })
                
                -- Update highscore immediately
                if score > highscore then
                    highscore = score
                end
            end

            -- Cleanup Logic
            -- Remove pipes that have moved completely off-screen to the left
            if p.x + pipeWidth < -100 then
                table.remove(pipes, i)
            end
        end
    end
end

-- LÖVE Mouse Pressed Callback
-- Handles initiating the drag/aiming action.
function love.mousepressed(x, y, button)
    if button == 1 then -- Left mouse button
        if gameState == states.MENU then
            -- Check collision with Start Button
            if x >= startButton.x and x <= startButton.x + startButton.width and
               y >= startButton.y and y <= startButton.y + startButton.height then
               gameState = states.START
            end
        elseif gameState == states.GAMEOVER then
            resetGame() -- Restart game on click if game over
        else
            -- Start aiming mechanics
            aiming.active = true
            aiming.startX = x
            aiming.startY = y
            aiming.currentX = x
            aiming.currentY = y
            
            -- Transition from Start screen to Playing state on first interaction
            if gameState == states.START then
                gameState = states.PLAYING
            end
        end
    end
end

-- LÖVE Mouse Moved Callback
-- Updates the current aiming coordinates.
function love.mousemoved(x, y)
    if aiming.active then
        aiming.currentX = x
        aiming.currentY = y
    end
end

-- LÖVE Mouse Released Callback
-- Handles the launch logic when the player lets go of the drag.
function love.mousereleased(x, y, button)
    if button == 1 and aiming.active then
        aiming.active = false
        
        -- Calculate vector (Start - End) for "Pull back" mechanic
        -- Dragging left -> launches right. Dragging down -> launches up.
        local dx = aiming.startX - x
        local dy = aiming.startY - y

        -- Clamp to forward direction only (can't launch backward)
        if dx < 0 then dx = 0 end
        
        -- Clamp the launch vector magnitude to maxPull
        local len = math.sqrt(dx*dx + dy*dy)
        if len > aiming.maxPull then
            local scale = aiming.maxPull / len
            dx = dx * scale
            dy = dy * scale
        end
        
        -- Apply Physics Impulse
        -- Vertical impulse applied directly to Bird Velocity (resetting current fall speed)
        bird.vy = dy * aiming.powerMultiplier
        
        -- Horizontal impulse is applied to World Speed (Additive)
        -- This makes the bird feel like it accelerates forward
        worldSpeed = worldSpeed + dx * aiming.powerMultiplier
        
        -- Reset Combo Counter for the new launch
        pipesClearedInLaunch = 0
        
        -- Play jump sound and trigger animation
        sounds.jump:stop()
        sounds.jump:play()
        bird.isAnimating = true
    end
end

-- LÖVE Key Pressed Callback
-- Handles global keyboard input.
function love.keypressed(key)
    if key == "escape" then
        love.event.quit() -- Exit game
    end
    -- Note: Spacebar jump removed to enforce slingshot mechanics
end

-- LÖVE Draw Callback
-- Renders the game state to the screen.
function love.draw()
    -- Draw Checkerboard Background
    -- Creates a scrolling infinite background effect
    local cellSize = 40
    for y = 0, love.graphics.getHeight(), cellSize do
        -- Draw extra columns to cover the scrolling offset
        for x = -cellSize * 2, love.graphics.getWidth() + cellSize, cellSize do
            if (math.floor(x / cellSize) + math.floor(y / cellSize)) % 2 == 0 then
                love.graphics.setColor(0.96, 0.96, 0.86)
            else
                love.graphics.setColor(0.93, 0.91, 0.82)
            end
            -- Offset x by backgroundScroll
            love.graphics.rectangle("fill", x - backgroundScroll, y, cellSize, cellSize)
        end
    end

    -- Draw Pipes
    for _, p in ipairs(pipes) do
        love.graphics.setColor(0.2, 0.8, 0.2) -- Green color
        -- Top pipe
        love.graphics.rectangle("fill", p.x, 0, pipeWidth, p.top)
        -- Bottom pipe
        love.graphics.rectangle("fill", p.x, p.top + pipeGap, pipeWidth, love.graphics.getHeight() - (p.top + pipeGap))
        
        -- Pipe outlines
        love.graphics.setColor(0, 0, 0)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", p.x, 0, pipeWidth, p.top)
        love.graphics.rectangle("line", p.x, p.top + pipeGap, pipeWidth, love.graphics.getHeight() - (p.top + pipeGap))
    end

    -- Draw Bird
    love.graphics.setColor(1, 1, 1) -- Reset color to white for sprite
    local sprite = bird.sprites[bird.currentFrame]
    -- Calculate scale to match the logical radius
    local bScaleX = (bird.radius * 2) / sprite:getWidth()
    local bScaleY = (bird.radius * 2) / sprite:getHeight()
    
    -- Draw sprite centered on bird.x, bird.y with rotation
    love.graphics.draw(sprite, bird.x, bird.y, bird.angle, bScaleX, bScaleY, sprite:getWidth()/2, sprite:getHeight()/2)

    -- Draw Slingshot Visualization (if aiming)
    if aiming.active then
        -- Calculate clamped vector (duplicated logic from mousereleased for visual accuracy)
        local dx = aiming.startX - aiming.currentX
        local dy = aiming.startY - aiming.currentY

        -- Clamp to forward direction only
        if dx < 0 then dx = 0 end

        local len = math.sqrt(dx*dx + dy*dy)
        if len > aiming.maxPull then
            local scale = aiming.maxPull / len
            dx = dx * scale
            dy = dy * scale
        end
        
        -- Draw the "String" (Visual feedback for pull direction)
        love.graphics.setColor(0, 0, 0, 0.3)
        love.graphics.setLineWidth(2)
        love.graphics.line(bird.x, bird.y, bird.x - dx, bird.y - dy)
        love.graphics.circle("fill", bird.x - dx, bird.y - dy, 5)

        -- Trajectory Prediction Path
        love.graphics.setColor(1, 0, 0, 0.6) -- Semi-transparent red
        
        -- Simulation variables for trajectory prediction
        local simX = bird.x
        local simY = bird.y
        local simVy = dy * aiming.powerMultiplier 
        local simWorldSpeed = worldSpeed + (dx * aiming.powerMultiplier)
        
        local simDt = 1/60 -- Fixed timestep for stable prediction
        local drag = 0.3   -- Must match physics constant
        local gravity = bird.gravity
        
        -- Simulate physics steps into the future
        for i = 1, 90 do -- Simulate ~1.5 seconds (90 frames at 60fps)
            -- Update Physics (Euler integration)
            simVy = simVy + gravity * simDt
            simY = simY + simVy * simDt
            
            simWorldSpeed = simWorldSpeed - (simWorldSpeed * drag * simDt)
            if math.abs(simWorldSpeed) < 1 then simWorldSpeed = 0 end
            
            -- Move X relative to the world speed
            simX = simX + simWorldSpeed * simDt
            
            -- Draw point every 3rd frame for dotted line effect
            if i % 3 == 0 then
                love.graphics.circle("fill", simX, simY, 3)
            end
            
            -- Stop drawing if prediction goes off-screen
            if simY > love.graphics.getHeight() or simY < 0 or simX > love.graphics.getWidth() then
                break
            end
        end
    end

    -- Draw Floating Score Texts
    for _, ft in ipairs(floatingTexts) do
        local progress = ft.timer / ft.duration
        -- Pop-in and fade-out effect
        local scale = math.sin(progress * math.pi) * 2
        local alpha = 1 - progress
        
        -- Draw Drop Shadow
        love.graphics.setColor(0, 0, 0, alpha)
        love.graphics.print(ft.text, ft.x + 2, ft.y + 2, 0, scale, scale, 10, 10)
        -- Draw Text
        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.print(ft.text, ft.x, ft.y, 0, scale, scale, 10, 10)
    end

    -- Draw User Interface (UI)
    love.graphics.setColor(0, 0, 0)
    if gameState == states.MENU then
        -- Draw Waving Title
        local title = "Angry Flappy Bird"
        local font = love.graphics.newFont(40)
        love.graphics.setFont(font)
        love.graphics.setColor(0.4, 0.7, 1) -- Light Blue
        
        local titleW = font:getWidth(title)
        local startX = love.graphics.getWidth() / 2 - titleW / 2
        local startY = love.graphics.getHeight() / 2 - 100
        
        -- Draw each character with a sine wave offset
        for i = 1, #title do
            local char = string.sub(title, i, i)
            local offset = math.sin(menuTitleTimer * 5 + i * 0.5) * 10
            love.graphics.print(char, startX + font:getWidth(string.sub(title, 1, i-1)), startY + offset)
        end
        
        -- Draw Start Button
        love.graphics.setColor(1, 1, 1) -- White background
        love.graphics.rectangle("fill", startButton.x, startButton.y, startButton.width, startButton.height, 10, 10)
        love.graphics.setColor(0, 0, 0) -- Black outline
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", startButton.x, startButton.y, startButton.width, startButton.height, 10, 10)
        
        -- Button Text
        local btnFont = love.graphics.newFont(24)
        love.graphics.setFont(btnFont)
        local textW = btnFont:getWidth(startButton.text)
        local textH = btnFont:getHeight()
        love.graphics.print(startButton.text, startButton.x + startButton.width/2 - textW/2, startButton.y + startButton.height/2 - textH/2)
        
    elseif gameState == states.START then
        love.graphics.printf("Click and Drag to Launch!\nHighscore: " .. highscore, 0, love.graphics.getHeight()/2 - 20, love.graphics.getWidth(), "center")
    elseif gameState == states.GAMEOVER then
        love.graphics.printf("GAME OVER\nScore: " .. score .. "\nHighscore: " .. highscore .. "\nClick to Restart", 0, love.graphics.getHeight()/2 - 40, love.graphics.getWidth(), "center")
    else
        -- HUD during gameplay
        love.graphics.setFont(love.graphics.newFont(24))
        love.graphics.print("Score: " .. score, 20, 20)
        love.graphics.print("Best: " .. highscore, 20, 50)
        
        -- Draw Timer
        if timeLeft < 5 then love.graphics.setColor(1, 0, 0) end -- Warning color
        love.graphics.print("Time: " .. string.format("%.1f", timeLeft), 20, 80)
        love.graphics.setColor(1, 1, 1)
    end
end
