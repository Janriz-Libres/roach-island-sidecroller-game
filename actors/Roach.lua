Roach = Class{}

-- Roach/enemy settings
local SPEED = 25
local ENEMY_KNOCKBACK = 200
local RECOVERY_RATE = 10

function Roach:init(x, y, map, index)
    self.life = 3

    self.map = map
    self.index = index

    self.width = 16
    self.height = 16

    -- Initial position of enemy
    self.x = (x - 1) * self.map.tileWidth
    self.y = (y - 1) * self.map.tileHeight - self.height
    self.dx = 0
    self.dy = 0

    self.offsetX = 16
    self.offsetY = 24

    self.idleSheet = love.graphics.newImage('graphics/roach/roach_idle.png')
    self.runSheet = love.graphics.newImage('graphics/roach/roach_run.png')
    self.hurtSprite = love.graphics.newImage('graphics/roach/roach_hurt.png')

    self.idleFrames = generateQuads(self.idleSheet, 32, 32)
    self.runFrames = generateQuads(self.runSheet, 32, 32)
    self.hurtFrame = generateQuads(self.hurtSprite, 32, 32)

    self.stateInterval = math.random(2, 5)
    self.stateTimer = 0

    self.state = 'idle'
    self.direction = 'left'
    self.recovery = 0

    self.animations = {
        ['idle'] = Animation {
            texture = self.idleSheet,
            frames = self.idleFrames,
            interval = 0.6
        },
        ['run'] = Animation {
            texture = self.runSheet,
            frames = self.runFrames,
            interval = 0.15
        },
        ['hurt'] = Animation {
            texture = self.hurtSprite,
            frames = self.hurtFrame
        }
    }

    self.anim = self.animations[self.state]

    self.behaviors = {
        ['idle'] = function(dt)
            self.dx = 0

            self.stateTimer = self.stateTimer + dt

            if self.stateTimer >= self.stateInterval then
                self:pickRandState()
            end

            self:checkFloorCollision()
        end,
        ['run'] = function(dt)
            self.stateTimer = self.stateTimer + dt

            if self.stateTimer >= self.stateInterval then
                self:pickRandState()
            end

            self:checkLeftCollision()
            self:checkRightCollision()
            self:checkFloorCollision()
        end,
        ['hurt'] = function(dt)
            self.dx = self.dx + self.recovery

            if self.recovery < 0 and self.dx <= 0 then
                self.dx = 0
            elseif self.recovery > 0 and self.dx >= 0 then
                self.dx = 0
            end

            self.stateTimer = self.stateTimer + dt

            if self.stateTimer >= self.stateInterval then
                self:pickRandState()
            end

            local tileLeft = self.map:tileAt(self.x, self.y + self.height)
            local tileRight = self.map:tileAt(self.x + self.width - 1, self.y + self.height)

            if not self.map:isFloor(tileLeft.id) and not self.map:isFloor(tileRight.id) then
                self.state = 'fall'
            end

            self:checkLeftCollision()
            self:checkRightCollision()
        end,
        ['fall'] = function()
            self.dy = self.dy + GRAVITY

            local tileLeft = self.map:tileAt(self.x, self.y + self.height)
            local tileRight = self.map:tileAt(self.x + self.width - 1, self.y + self.height)

            if self.map:isFloor(tileLeft.id) or self.map:isFloor(tileRight.id) then
                self.dx = 0
                self.dy = 0
                self.y = (tileLeft.y - 1) * self.map.tileHeight - self.height
                self:checkFloorCollision()
                self:pickRandState()
            end

            if self.y > VIRTUAL_HEIGHT then
                score = score + 1
                scoreRef = scoreRef + 1
                self.map:destroyRoach(self.index)
            end

            self:checkLeftCollision()
            self:checkRightCollision()
        end
    }

    self:pickRandState()
end

function Roach:pickRandState()
    self.state = math.random(2) == 1 and 'idle' or 'run'
    self.anim = self.animations[self.state]

    if self.state == 'run' then
        self.direction = math.random(2) == 1 and 'left' or 'right'
        self.dx = self.direction == 'left' and -SPEED or SPEED
    else
        self.dx = 0
    end

    self.stateTimer = 0
    self.stateInterval = math.random(2, 5)
end

function Roach:updatePos()
    self.x = self.x - VIRTUAL_WIDTH

    if self.x + self.width - 1 <= 0 then
        self.map:destroyRoach(self.index)
    end
end

function Roach:checkLeftCollision()
    if self.dx < 0 then
        local tileTop = self.map:tileAt(self.x - 1, self.y)
        local tileBot = self.map:tileAt(self.x - 1, self.y + self.height - 1)

        if self.map:collides(tileTop.id) or self.map:collides(tileBot.id) then
            self.dx = -self.dx
            self.direction = self.direction == 'left' and 'right' or 'left'
        end
    end
end

function Roach:checkRightCollision()
    if self.dx > 0 then
        local tileTop = self.map:tileAt(self.x + self.width, self.y)
        local tileBot = self.map:tileAt(self.x + self.width, self.y + self.height - 1)

        if self.map:collides(tileTop.id) or self.map:collides(tileBot.id) then
            self.dx = -self.dx
            self.direction = self.direction == 'left' and 'right' or 'left'
        end
    end
end

-- Check for collision with player
function Roach:collidesPlayer()
    if player.x > self.x + self.width - 1 or
        player.x + player.width - 1 < self.x then
        
        return false
    end

    if player.y > self.y + self.height - 1 or
        player.y + player.height - 1 < self.y then
            
        return false
    end

    return true
end

function Roach:checkFloorCollision()
    local tileLeft = self.map:tileAt(self.x, self.y + self.height)
    local tileRight = self.map:tileAt(self.x + self.width - 1, self.y + self.height)

    if not self.map:isFloor(tileLeft.id) then
        self.x = tileLeft.x * self.map.tileWidth
        self.dx = SPEED
        self.direction = 'right'
    elseif not self.map:isFloor(tileRight.id) then
        self.x = (tileRight.x - 1) * self.map.tileWidth - self.width
        self.dx = -SPEED
        self.direction = 'left'
    end
end

function Roach:collidesBullet(bullet)
    if bullet.x < self.x or bullet.x > self.x + self.width - 1 then
        return false
    end

    if bullet.y < self.y or bullet.y > self.y + self.height - 1 then
        return false
    end

    return true
end

function Roach:isHurt()
    self.anim:restart()
    self.state = 'hurt'
    self.anim = self.animations['hurt']

    self.stateTimer = 0
    self.stateInterval = 0.5

    self.life = self.life - 1
end

function Roach:checkLife()
    if self.life <= 0 then
        self.map:destroyRoach(self.index)
        score = score + 1
        scoreRef = scoreRef + 1
    end
end

function Roach:update(dt)
    self.behaviors[self.state](dt)
    self.anim:update(dt)

    self.x = self.x + self.dx * dt
    self.y = self.y + self.dy * dt

    -- Check for collision with player
    if self:collidesPlayer() then
        if self.y < player.y + player.height - 1 and self.y > player.y then
            player:bounce()
            self:isHurt()
            self:checkLife()
            self.dx = 0
        else
            player:isHurt(self, ENEMY_KNOCKBACK)
        end
    end

    -- Check for bullet collisions
    for i, bullet in pairs(player.bullets) do
        if self:collidesBullet(bullet) then
            self.recovery = bullet.direction == 'right' and -RECOVERY_RATE or RECOVERY_RATE

            self:isHurt()

            bullet:applyKnockback(self.index)
            player:destroyBullet(i)

            self:checkLife()
        end
    end
end

function Roach:render()
    local scaleX = self.direction == 'left' and -1 or 1

    love.graphics.draw(self.anim:getTexture(), self.anim:getCurrentFrame(), math.floor(self.x) + 8, math.floor(self.y) + 8, 0, scaleX, 1, self.offsetX, self.offsetY)
end