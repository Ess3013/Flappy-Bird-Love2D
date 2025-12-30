-- Game States
local states = { START = "start", PLAYING = "playing", GAMEOVER = "gameover" }
local gameState = states.START

-- Bird Properties
local bird = {
    x = 100,
    y = 300,
    radius = 20,
    velocity = 0,
    gravity = 1200,
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
local pipeWidth = 80
local pipeGap = 180
local pipeSpeed = 250
local spawnTimer = 0
local spawnInterval = 1.8

-- Score
local score = 0
local highscore = 0
local highscoreFile = "highscore.txt"

function loadHighscore()
    if love.filesystem.getInfo(highscoreFile) then
        local content = love.filesystem.read(highscoreFile)
        highscore = tonumber(content) or 0
    end
end

function saveHighscore()
    love.filesystem.write(highscoreFile, tostring(highscore))
end

function love.load()
    -- Load Bird Sprites
    for i = 1, 5 do
        bird.sprites[i] = love.graphics.newImage("Sprites/Bird/frame-" .. i .. ".png")
    end
    loadHighscore()
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

function gameOver()
    gameState = states.GAMEOVER
    if score > highscore then
        highscore = score
        saveHighscore()
    end
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

        -- Collision (Floor/Ceiling)
        if bird.y - bird.radius < 0 or bird.y + bird.radius > love.graphics.getHeight() then
            gameOver()
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
                    gameOver()
                end
            end

            -- Scoring
            if not p.scored and p.x + pipeWidth < bird.x then
                score = score + 1
                p.scored = true
                -- Optional: update highscore live if exceeded
                if score > highscore then
                    highscore = score
                end
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

    -- UI
    love.graphics.setColor(0, 0, 0)
    if gameState == states.START then
        love.graphics.printf("Press SPACE to Start\nHighscore: " .. highscore, 0, love.graphics.getHeight()/2 - 20, love.graphics.getWidth(), "center")
    elseif gameState == states.GAMEOVER then
        love.graphics.printf("GAME OVER\nScore: " .. score .. "\nHighscore: " .. highscore .. "\nPress SPACE to Restart", 0, love.graphics.getHeight()/2 - 40, love.graphics.getWidth(), "center")
    else
        love.graphics.setFont(love.graphics.newFont(24))
        love.graphics.print("Score: " .. score, 20, 20)
        love.graphics.print("Best: " .. highscore, 20, 50)
    end
end
