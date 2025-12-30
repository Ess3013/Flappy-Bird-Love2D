-- Game States
local states = { START = "start", PLAYING = "playing", GAMEOVER = "gameover" }
local gameState = states.START

-- Bird Properties
local bird = {
    x = 50,
    y = 300,
    radius = 15,
    velocity = 0,
    gravity = 1500,
    jumpStrength = -400
}

-- Pipe Properties
local pipes = {}
local pipeWidth = 50
local pipeGap = 150
local pipeSpeed = 200
local spawnTimer = 0
local spawnInterval = 1.5

-- Score
local score = 0

function love.load()
    resetGame()
end

function resetGame()
    bird.y = 300
    bird.velocity = 0
    pipes = {}
    spawnTimer = 0
    score = 0
    gameState = states.START
end

function spawnPipe()
    local minHeight = 50
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

        -- Ground/Ceiling Collision
        if bird.y - bird.radius < 0 or bird.y + bird.radius > love.graphics.getHeight() then
            gameState = states.GAMEOVER
        end

        -- Pipe Spawning
        spawnTimer = spawnTimer + dt
        if spawnTimer > spawnInterval then
            spawnPipe()
            spawnTimer = 0
        end

        -- Pipe Movement and Collision
        for i = #pipes, 1, -1 do
            local p = pipes[i]
            p.x = p.x - pipeSpeed * dt

            -- Collision Detection (AABB-ish for circle vs rectangle)
            local birdRight = bird.x + bird.radius
            local birdLeft = bird.x - bird.radius
            local birdTop = bird.y - bird.radius
            local birdBottom = bird.y + bird.radius

            if birdRight > p.x and birdLeft < p.x + pipeWidth then
                if birdTop < p.top or birdBottom > p.top + pipeGap then
                    gameState = states.GAMEOVER
                end
            end

            -- Scoring
            if not p.scored and p.x + pipeWidth < bird.x then
                score = score + 1
                p.scored = true
            end

            -- Remove Off-screen Pipes
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
        elseif gameState == states.PLAYING then
            bird.velocity = bird.jumpStrength
        elseif gameState == states.GAMEOVER then
            resetGame()
        end
    end
end

function love.draw()
    -- Background
    love.graphics.clear(0.4, 0.6, 0.9)

    -- Draw Pipes
    love.graphics.setColor(0.2, 0.8, 0.2)
    for _, p in ipairs(pipes) do
        -- Top Pipe
        love.graphics.rectangle("fill", p.x, 0, pipeWidth, p.top)
        -- Bottom Pipe
        love.graphics.rectangle("fill", p.x, p.top + pipeGap, pipeWidth, love.graphics.getHeight() - (p.top + pipeGap))
    end

    -- Draw Bird
    love.graphics.setColor(1, 1, 0)
    love.graphics.circle("fill", bird.x, bird.y, bird.radius)

    -- UI
    love.graphics.setColor(1, 1, 1)
    if gameState == states.START then
        love.graphics.printf("Press SPACE to Start", 0, love.graphics.getHeight()/2 - 10, love.graphics.getWidth(), "center")
    elseif gameState == states.GAMEOVER then
        love.graphics.printf("GAME OVER", 0, love.graphics.getHeight()/2 - 20, love.graphics.getWidth(), "center")
        love.graphics.printf("Score: " .. score, 0, love.graphics.getHeight()/2, love.graphics.getWidth(), "center")
        love.graphics.printf("Press SPACE to Restart", 0, love.graphics.getHeight()/2 + 20, love.graphics.getWidth(), "center")
    else
        love.graphics.print("Score: " .. score, 10, 10)
    end
end
