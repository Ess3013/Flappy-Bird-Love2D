-- Game States
local states = { START = "start", PLAYING = "playing", GAMEOVER = "gameover" }
local gameState = states.START

-- Bird Properties
local bird = {
    x = 100, -- Adjusted for landscape
    y = 300,
    radius = 20, -- Slightly larger for better visibility
    velocity = 0,
    gravity = 1200, -- Reduced gravity for landscape feel
    jumpStrength = -400,
    sprites = {},
    currentFrame = 1,
    animTimer = 0,
    animSpeed = 0.05,
    isAnimating = false,
    angle = 0
}

-- Pipe Properties
local pipes = {}
local pipeWidth = 80 -- Wider pipes for landscape
local pipeGap = 180 -- Larger gap
local pipeSpeed = 250
local spawnTimer = 0
local spawnInterval = 1.8
local pipeImage

-- Score
local score = 0

function love.load()
    -- Load Bird Sprites
    for i = 1, 5 do
        bird.sprites[i] = love.graphics.newImage("Sprites/Bird/frame-" .. i .. ".png")
    end
    -- Load Pipe Sprite
    pipeImage = love.graphics.newImage("Sprites/pipe.png")
    resetGame()
end

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

function spawnPipe()
    local minHeight = 100
    local maxHeight = love.graphics.getHeight() - pipeGap - minHeight
    local topHeight = math.random(minHeight, maxHeight)
    
    table.insert(pipes, {
        x = love.graphics.getWidth(),
        top = topHeight,
        scored = false
    })
end

function love.update(dt)
    if gameState == states.PLAYING then
        -- Bird Physics
        bird.velocity = bird.velocity + bird.gravity * dt
        bird.y = bird.y + bird.velocity * dt

        -- Rotation logic
        bird.angle = math.min(math.pi / 2, math.max(-math.pi / 4, bird.velocity * 0.002))

        -- Animation Logic
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
            bird.currentFrame = 1
        end

        -- Collision
        if bird.y - bird.radius < 0 or bird.y + bird.radius > love.graphics.getHeight() then
            gameState = states.GAMEOVER
        end

        -- Spawning
        spawnTimer = spawnTimer + dt
        if spawnTimer > spawnInterval then
            spawnPipe()
            spawnTimer = 0
        end

        -- Pipes
        for i = #pipes, 1, -1 do
            local p = pipes[i]
            p.x = p.x - pipeSpeed * dt

            -- Collision Detection (AABB)
            if bird.x + bird.radius > p.x and bird.x - bird.radius < p.x + pipeWidth then
                if bird.y - bird.radius < p.top or bird.y + bird.radius > p.top + pipeGap then
                    gameState = states.GAMEOVER
                end
            end

            -- Scoring
            if not p.scored and p.x + pipeWidth < bird.x then
                score = score + 1
                p.scored = true
            end

            if p.x + pipeWidth < 0 then
                table.remove(pipes, i)
            end
        end
    end
end

function love.keypressed(key)
    if key == "space" then
        if gameState == states.START then
            gameState = states.PLAYING
            bird.isAnimating = true
        elseif gameState == states.PLAYING then
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
    love.graphics.clear(0.4, 0.6, 0.9)

    -- Draw Pipes with uniform scaling
    love.graphics.setColor(1, 1, 1)
    local scale = pipeWidth / pipeImage:getWidth()
    
    for _, p in ipairs(pipes) do
        -- Top Pipe: Draw it at p.top and flip it upwards. 
        -- We draw it "bottom-up" from the gap edge.
        love.graphics.draw(pipeImage, p.x, p.top, 0, scale, -scale, 0, 0)
        -- Since the sprite might not be long enough, we can draw another one above it if needed, 
        -- but with landscape and decent sprite length it usually works. 
        -- To be safe, we'd need a loop or a very long sprite.
        
        -- Bottom Pipe: Draw it at p.top + pipeGap
        love.graphics.draw(pipeImage, p.x, p.top + pipeGap, 0, scale, scale, 0, 0)
    end

    -- Draw Bird
    local sprite = bird.sprites[bird.currentFrame]
    local bScaleX = (bird.radius * 2) / sprite:getWidth()
    local bScaleY = (bird.radius * 2) / sprite:getHeight()
    love.graphics.draw(sprite, bird.x, bird.y, bird.angle, bScaleX, bScaleY, sprite:getWidth()/2, sprite:getHeight()/2)

    -- UI
    if gameState == states.START then
        love.graphics.printf("Press SPACE to Start", 0, love.graphics.getHeight()/2 - 10, love.graphics.getWidth(), "center")
    elseif gameState == states.GAMEOVER then
        love.graphics.printf("GAME OVER\nScore: " .. score .. "\nPress SPACE to Restart", 0, love.graphics.getHeight()/2 - 30, love.graphics.getWidth(), "center")
    else
        love.graphics.setFont(love.graphics.newFont(24))
        love.graphics.print("Score: " .. score, 20, 20)
    end
end
