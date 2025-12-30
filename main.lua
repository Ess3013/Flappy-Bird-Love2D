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
    -- Draw Checkerboard Background
    local cellSize = 40
    for y = 0, love.graphics.getHeight(), cellSize do
        for x = 0, love.graphics.getWidth(), cellSize do
            if (x / cellSize + y / cellSize) % 2 == 0 then
                love.graphics.setColor(0.96, 0.96, 0.86) -- Beige 1
            else
                love.graphics.setColor(0.93, 0.91, 0.82) -- Beige 2
            end
            love.graphics.rectangle("fill", x, y, cellSize, cellSize)
        end
    end

    -- Draw Pipes
    for _, p in ipairs(pipes) do
        love.graphics.setColor(0.2, 0.8, 0.2) -- Green
        -- Top Pipe
        love.graphics.rectangle("fill", p.x, 0, pipeWidth, p.top)
        -- Bottom Pipe
        love.graphics.rectangle("fill", p.x, p.top + pipeGap, pipeWidth, love.graphics.getHeight() - (p.top + pipeGap))
        
        -- Black Borders
        love.graphics.setColor(0, 0, 0)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", p.x, 0, pipeWidth, p.top)
        love.graphics.rectangle("line", p.x, p.top + pipeGap, pipeWidth, love.graphics.getHeight() - (p.top + pipeGap))
    end

