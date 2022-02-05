--[[
    "Roach Island"
    
    Author: Janriz Libres
    
    Sprite Credits:
    - Sprite Pack 4 by GrafXkid https://grafxkid.itch.io/sprite-pack-4
    - Kinda Cute Forest by Trixie https://trixelized.itch.io/kinda-cute-forest
    - Heart Pixel Art by HeartBeast https://github.com/uheartbeast/youtube-tutorials/tree/master/Action%20RPG/UI

    Sound Credits:
    - Yummie https://freesound.org/people/yummie/sounds/410574/
    - deleted_user_877451 https://freesound.org/people/deleted_user_877451/sounds/76376/
    - vikuserro https://freesound.org/people/vikuserro/sounds/265549/
    - Additional sound effects created on SFXR http://drpetter.se/project_sfxr.html

    Instructions: Annihilate as many roaches as possible.

    This game was created in 2020 as the final project for CS50: Introduction to Computer Science
]]

-- Import libraries
Class = require 'lib.class'
push = require 'lib.push'

-- Import dependencies
require 'Util'
require 'Map'

-- Set physical window size
WINDOW_WIDTH = 1280
WINDOW_HEIGHT = 600

-- Set 'actual' raster size
VIRTUAL_WIDTH = 320
VIRTUAL_HEIGHT = 180

-- Background scroll speed
local INIT_SCROLL_SPEED = 15
local MAX_SCROLL_SPEED = 36

function love.load()
    -- Generate random seed
    math.randomseed(os.time())

    -- Prevents blurring of graphics
    love.graphics.setDefaultFilter('nearest', 'nearest')

    -- Initialize fonts to be used
    bigFont = love.graphics.newFont('font.ttf', 24)
    medFont = love.graphics.newFont('font.ttf', 16)
    smallFont = love.graphics.newFont('font.ttf', 8)

    -- Initialize audio resources
    menuMusic = love.audio.newSource('music/menu.mp3', 'stream')
    bgMusic = love.audio.newSource('music/bgmusic.mp3', 'static')
    jump = love.audio.newSource('music/jump.wav', 'static')
    shoot = love.audio.newSource('music/shoot.wav', 'static')
    hurt = love.audio.newSource('music/hurt.wav', 'static')
    hit = love.audio.newSource('music/hit.wav', 'static')
    gameOverSound = love.audio.newSource('music/gameover.wav', 'static')

    -- Configure audio
    menuMusic:setLooping(true)
    bgMusic:setLooping(true)
    bgMusic:setVolume(0.7)
    jump:setVolume(0.8)
    shoot:setVolume(0.4)

    menuMusic:play()

    -- Import graphics
    background = love.graphics.newImage('graphics/background.png')
    background:setWrap('repeat')
    bgQuad = love.graphics.newQuad(0, 0, background:getWidth() * 2, background:getHeight(), background:getDimensions())

    sx = VIRTUAL_WIDTH / background:getWidth()
    sy = VIRTUAL_HEIGHT / background:getHeight()
    bgX = 0


    heartEmpty = love.graphics.newImage('graphics/heartEmpty.png')
    heartEmpty:setWrap('repeat')
    heartQuadsEmpty = love.graphics.newQuad(0, 0, heartEmpty:getWidth() * 3, heartEmpty:getHeight(), heartEmpty:getDimensions())

    heartFull = love.graphics.newImage('graphics/heartFull.png')
    heartFull:setWrap('repeat')
    heartQuadsFull = {
        love.graphics.newQuad(0, 0, heartFull:getWidth(), heartFull:getHeight(), heartFull:getDimensions()),
        love.graphics.newQuad(0, 0, heartFull:getWidth() * 2, heartFull:getHeight(), heartFull:getDimensions()),
        love.graphics.newQuad(0, 0, heartFull:getWidth() * 3, heartFull:getHeight(), heartFull:getDimensions())
    }

    scrollSpeed = INIT_SCROLL_SPEED
    scoreRef = 0

    gameState = 'menu'
    score = 0
    highscore = love.filesystem.getInfo('savedata.txt') and love.filesystem.read('savedata.txt') or 0

    menuScreens = {
        ['mainMenu'] = function()
            love.graphics.setFont(bigFont)
            love.graphics.printf('ROACH ISLAND', 0, VIRTUAL_HEIGHT / 2 - 20, VIRTUAL_WIDTH, 'center')

            love.graphics.setFont(smallFont)
            love.graphics.printf('Press ENTER to play', 0, VIRTUAL_HEIGHT / 2 + 10, VIRTUAL_WIDTH, 'center')
            love.graphics.printf('Press SPACE to see instructions', 0, VIRTUAL_HEIGHT / 2 + 20, VIRTUAL_WIDTH, 'center')
            
            love.graphics.printf('ESC to exit', 0, VIRTUAL_HEIGHT - 20, VIRTUAL_WIDTH, 'center')
        end,
        ['instructions'] = function()
            love.graphics.printf('_______________________________', 0, VIRTUAL_HEIGHT / 2 - 30, VIRTUAL_WIDTH, 'center')
            
            love.graphics.printf('A & D to move', 0, VIRTUAL_HEIGHT / 2 - 15, VIRTUAL_WIDTH, 'center')
            love.graphics.printf('W to jump', 0, VIRTUAL_HEIGHT / 2 - 5, VIRTUAL_WIDTH, 'center')
            love.graphics.printf('J to shoot', 0, VIRTUAL_HEIGHT / 2 + 5, VIRTUAL_WIDTH, 'center')
            love.graphics.printf('Space to change direction', 0, VIRTUAL_HEIGHT / 2 + 15, VIRTUAL_WIDTH, 'center')

            love.graphics.printf('_______________________________', 0, VIRTUAL_HEIGHT / 2 + 30, VIRTUAL_WIDTH, 'center')

            love.graphics.setFont(smallFont)
            love.graphics.printf('Press SPACE to go back', 0, VIRTUAL_HEIGHT / 2 + 60, VIRTUAL_WIDTH, 'center')
        end
    }

    menuState = 'mainMenu'

    -- Declare map object
    map = Map()

    love.window.setTitle('Roach Island')

    push:setupScreen(VIRTUAL_WIDTH, VIRTUAL_HEIGHT, WINDOW_WIDTH, WINDOW_HEIGHT, {
        fullscreen = false,
        resizable = true,
        vsync = 1
    })

    love.keyboard.keysPressed = {}
end

function love.resize(w, h)
    push:resize(w, h)
end

-- Called everytime a key was pressed
function love.keypressed(key)
    if key == 'escape' and gameState ~= 'play' then
        love.filesystem.write('savedata.txt', highscore)
        love.event.quit()
    elseif key == 'escape' and gameState == 'play' then
        bgMusic:stop()
        menuMusic:play()
        gameState = 'menu'
    end

    if key == 'return' and gameState ~= 'play' and menuState == 'mainMenu' then
        gameState = 'play'
        map:startGame(INIT_SCROLL_SPEED)
    end

    if key == 'space' and gameState == 'menu' then
        menuState = menuState == 'instructions' and 'mainMenu' or 'instructions'
    elseif key == 'space' and gameState == 'gameOver' then
        menuMusic:play()
        gameState = 'menu'
    end

    love.keyboard.keysPressed[key] = true
end

function love.keyboard.wasPressed(key)
    return love.keyboard.keysPressed[key]
end

function love.update(dt)
    bgX = bgX + scrollSpeed * dt

    -- For infinite scrolling effect
    if bgX >= VIRTUAL_WIDTH then
        bgX = 0
    end

    if scoreRef >= 20 then
        scoreRef = scoreRef - 20
        map:changeSpeed(MAX_SCROLL_SPEED)
    end

    map:update(dt)

    love.keyboard.keysPressed = {}
end

-- Main function for drawing graphics on LÖVE2D
function love.draw()
    push:apply('start')

    love.graphics.push()

    -- Draw background
    love.graphics.translate(math.floor(-bgX), 0)
    love.graphics.draw(background, bgQuad, 0, 0, 0, sx, sy)

    love.graphics.pop()

    map:render()

    if gameState == 'menu' then
        menuScreens[menuState]()
    elseif gameState == 'play' then
        love.graphics.setFont(bigFont)
        love.graphics.printf(tostring(score), 0, 5, VIRTUAL_WIDTH, 'center')
        
        love.graphics.draw(heartEmpty, heartQuadsEmpty, 5, 5)
        love.graphics.draw(heartFull, heartQuadsFull[player.life], 5, 5)
    elseif gameState == 'gameOver' then
        love.graphics.setFont(bigFont)
        love.graphics.printf('GAME OVER', 0, VIRTUAL_HEIGHT / 2 - 10, VIRTUAL_WIDTH, 'center')

        love.graphics.setFont(smallFont)
        love.graphics.printf('Press ENTER to play again', 0, VIRTUAL_HEIGHT / 2 + 20, VIRTUAL_WIDTH, 'center')
        love.graphics.printf('Press SPACE to go back to main menu', 0, VIRTUAL_HEIGHT / 2 + 30, VIRTUAL_WIDTH, 'center')
        love.graphics.printf('Highscore: ' .. tostring(highscore), 0, VIRTUAL_HEIGHT / 2 + 55, VIRTUAL_WIDTH, 'center')
    end

    push:apply('end')
end