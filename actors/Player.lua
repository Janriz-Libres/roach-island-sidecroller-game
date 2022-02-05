Player = Class{}

-- Import bullet class
require 'actors.Bullet'

-- Player settings
local PLAYER_SPEED = 100
local JUMP_VELOCITY = 400
local FIRE_INTERVAL = 0.3
local RECOVERY_RATE = 10

local HURT_DURATION = 0.5
local TIMEOUT_DUR = 1

function Player:init(map)
    self.map = map
    self.life = 3

    self.width = 16
    self.height = 16

    self.x = 0
    self.y = 0
    self.dx = 0
    self.dy = 0

    self:setPos()

    -- Offset for scaling purposes
    self.offsetX = 16
    self.offsetY = 24

    -- Import graphics
    self.idleSheet = love.graphics.newImage('graphics/player/mike_idle.png')
    self.walkSheet = love.graphics.newImage('graphics/player/mike_walk.png')
    self.aerialSheet = love.graphics.newImage('graphics/player/mike_aerial.png')
    self.hurtSprite = love.graphics.newImage('graphics/player/mike_hurt.png')

    self.idleFrames = generateQuads(self.idleSheet, 32, 32)
    self.walkFrames = generateQuads(self.walkSheet, 32, 32)
    self.aerialFrames = generateQuads(self.aerialSheet, 32, 32)
    self.hurtFrame = generateQuads(self.hurtSprite, 32, 32)

    self.bullets = {}
    self.bulletTimer = 1

    self.hurtTimer = 0
    self.timeoutTimer = 0

    self.state = 'idle'
    self.direction = 'right'
    self.recovery = 0

    -- Define animations
    self.animations = {
        ['idle'] = Animation {
            texture = self.idleSheet,
            frames = self.idleFrames,
            interval = 0.6
        },
        ['walk'] = Animation {
            texture = self.walkSheet,
            frames = self.walkFrames,
            interval = 0.15
        },
        ['aerial'] = Animation {
            texture = self.aerialSheet,
            frames = self.aerialFrames,
            interval = 0.25
        },
        ['hurt'] = Animation {
            texture = self.hurtSprite,
            frames = self.hurtFrame
        }
    }

    self.anim = self.animations[self.state]

    -- Define behaviors according to state
    self.behaviors = {
        ['idle'] = function()
            if love.keyboard.isDown('a') or love.keyboard.isDown('d') then
                self:changeState('walk')
            elseif love.keyboard.isDown('w') then
                self.dy = -JUMP_VELOCITY
                jump:play()
                self:changeState('aerial')
            elseif love.keyboard.wasPressed('space') then
                self.direction = self.direction == 'left' and 'right' or 'left'
            end
        end,
        ['walk'] = function()
            if love.keyboard.isDown('a') then
                self.dx = -PLAYER_SPEED
            elseif love.keyboard.isDown('d') then
                self.dx = PLAYER_SPEED
            else
                self.dx = 0
                self:changeState('idle')
            end

            if love.keyboard.isDown('w') then
                self.dy = -JUMP_VELOCITY
                jump:play()
                self:changeState('aerial')
            elseif love.keyboard.wasPressed('space') then
                self.direction = self.direction == 'left' and 'right' or 'left'
            end

            local tileLeft = self.map:tileAt(self.x, self.y + self.height)
            local tileRight = self.map:tileAt(self.x + self.width - 1, self.y + self.height)

            if not self.map:collides(tileLeft.id) and not self.map:collides(tileRight.id) then
                self:changeState('aerial')
            end

            self:checkLeftCollision()
            self:checkRightCollision()
        end,
        ['aerial'] = function()
            if love.keyboard.isDown('a') then
                self.dx = -PLAYER_SPEED
            elseif love.keyboard.isDown('d') then
                self.dx = PLAYER_SPEED
            else
                self.dx = 0
            end

            if love.keyboard.wasPressed('space') then
                self.direction = self.direction == 'left' and 'right' or 'left'
            end

            self.dy = self.dy + GRAVITY

            local tileLeft = self.map:tileAt(self.x, self.y + self.height)
            local tileRight = self.map:tileAt(self.x + self.width - 1, self.y + self.height)

            if self.map:collides(tileLeft.id) or self.map:collides(tileRight.id) then
                self.dx = 0
                self.dy = 0
                
                self.y = (tileLeft.y - 1) * self.map.tileHeight - self.height
                self:changeState('idle')
            end

            self:checkLeftCollision()
            self:checkRightCollision()
        end,
        ['hurt'] = function(dt)
            self.dx = self.dx + self.recovery

            if self.recovery < 0 and self.dx <= 0 then
                self.dx = 0
            elseif self.recovery > 0 and self.dx >= 0 then
                self.dx = 0
            end

            self.hurtTimer = self.hurtTimer + dt

            if self.hurtTimer >= HURT_DURATION then
                self:changeState('aerial')
            end

            local tileLeft = self.map:tileAt(self.x, self.y + self.height)
            local tileRight = self.map:tileAt(self.x + self.width - 1, self.y + self.height)

            if not self.map:collides(tileLeft.id) and not self.map:collides(tileRight.id) then
                self.dy = self.dy + GRAVITY
            elseif self.map:collides(tileLeft.id) or self.map:collides(tileRight.id) then
                self.dy = 0
                self.y = (tileLeft.y - 1) * self.map.tileHeight - self.height
            end

            self:checkLeftCollision()
            self:checkRightCollision()
        end
    }
end

function Player:setPos()
    local edge = math.floor(self.map.worldX / self.map.tileWidth)

    for x = edge + 20, edge + 5, -1 do
        for y = 1, self.map.mapHeight do
            local tile = self.map:getTile(x, y)
            -- Place player if tile is not empty
            if self.map:isFloor(tile) then
                self.x = (x - 1) * self.map.tileWidth - self.width / 2
                self.y = (y - 1) * self.map.tileHeight - self.height

                return
            end
        end
    end
end

function Player:updatePos()
    self.x = self.x - VIRTUAL_WIDTH

    for i, bullet in pairs(self.bullets) do
        bullet:updatePos()
    end
end

function Player:isHurt(enemy, knockback)
    if self.timeoutTimer >= TIMEOUT_DUR then
        self.dx = enemy.x > self.x and -knockback or knockback
        self.recovery = self.dx < 0 and RECOVERY_RATE or -RECOVERY_RATE
        self.hurtTimer = 0
        self.timeoutTimer = 0
        self.life = self.life - 1

        if self.life <= 0 then
            self:gameOver()
        end

        hurt:play()
        self:changeState('hurt')
    end
end

-- Check for collisions on the left
function Player:checkLeftCollision()
    if self.dx < 0 then
        local tileTop = self.map:tileAt(self.x - 1, self.y)
        local tileBot = self.map:tileAt(self.x - 1, self.y + self.height - 1)

        if tileTop.id ~= EMPTY or tileBot.id ~= EMPTY then
            self.dx = 0
            self.x = tileTop.x * self.map.tileWidth
        end
    end
end

-- Check for collisions on the right
function Player:checkRightCollision()
    if self.dx > 0 then
        local tileTop = self.map:tileAt(self.x + self.width, self.y)
        local tileBot = self.map:tileAt(self.x + self.width, self.y + self.height - 1)

        if tileTop.id ~= EMPTY or tileBot.id ~= EMPTY then
            self.dx = 0
            self.x = (tileTop.x - 1) * self.map.tileWidth - self.width
        end
    end
end

-- Change state function
function Player:changeState(state)
    self.anim:restart()
    self.state = state
    self.anim = self.animations[state]
end

-- Destroy bullet if hit a wall or enemy
function Player:destroyBullet(index)
    self.bullets[index] = nil
end

function Player:gameOver()
    gameState = 'gameOver'
    highscore = math.max(score, highscore)

    bgMusic:stop()
    gameOverSound:play()
end

function Player:bounce()
    self.dy = -JUMP_VELOCITY
    hit:play()
    self:changeState('aerial')
end

function Player:update(dt)
    self.behaviors[self.state](dt)
    self.anim:update(dt)

    -- Player movement
    self.x = self.x + self.dx * dt
    self.y = self.y + self.dy * dt

    -- Clamp player's maximum x position
    self.x = math.min(self.x, self.map.worldX + VIRTUAL_WIDTH - self.width)

    -- When player goes out of screen or falls then declare game over
    if self.x + self.width + 10 < self.map.worldX or self.y - self.height > VIRTUAL_HEIGHT then
        self:gameOver()
    end

    self.bulletTimer = self.bulletTimer + dt
    self.timeoutTimer = self.timeoutTimer + dt

    -- Shoot bullets
    if love.keyboard.isDown('j') and self.bulletTimer >= FIRE_INTERVAL then
        self.bullets[#self.bullets + 1] = Bullet(self, self.map, #self.bullets + 1)
        self.bulletTimer = 0
        shoot:play()
    end

    -- Update bullet objects
    for i, bullet in pairs(self.bullets) do
        bullet:update(dt)
    end
end

function Player:render()
    -- Where the player is facing; depends on the declared direction
    local scaleX = self.direction == 'left' and -1 or 1

    -- Renders the player to the screen 
    love.graphics.draw(self.anim:getTexture(), self.anim:getCurrentFrame(), math.floor(self.x) + 8, math.floor(self.y) + 8, 0, scaleX, 1, self.offsetX, self.offsetY)

    -- Render bullets to the screen
    for i, bullet in pairs(self.bullets) do
        bullet:render()
    end
end