Bullet = Class{}

local BULLET_SPEED = 400
local BULLET_KNOCKBACK = 200

function Bullet:init(player, map, index)
    self.player = player
    self.map = map
    self.index = index

    self.direction = player.direction
    self.scaleX = self.direction == 'right' and 1 or -1

    self.x = self.direction == 'right' and self.player.x + self.player.width + 5 or self.player.x - 4
    self.y = self.player.y + self.player.height / 2
    self.dx = self.direction == 'right' and BULLET_SPEED or -BULLET_SPEED

    self.offsetX = 8
    self.offsetY = 8

    self.lifetime = 2
    self.timer = 0

    self.texture = love.graphics.newImage('graphics/player/bullet.png')
end

function Bullet:applyKnockback(index)
    local enemy = self.map.enemies[index]
    enemy.dx = self.direction == 'right' and BULLET_KNOCKBACK or -BULLET_KNOCKBACK
end

function Bullet:updatePos()
    self.x = self.x - VIRTUAL_WIDTH
end

function Bullet:update(dt)
    self.x = self.x + self.dx * dt

    self.timer = self.timer + dt
    
    local tile = self.map:tileAt(self.x, self.y)
    if self.timer >= self.lifetime or tile.id ~= EMPTY then
        self.player:destroyBullet(self.index)
    end
end

function Bullet:render()
    love.graphics.draw(self.texture, math.floor(self.x), math.floor(self.y), 0, self.scaleX, 1, self.offsetX, self.offsetY)
end