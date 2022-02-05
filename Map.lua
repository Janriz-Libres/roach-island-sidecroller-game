Map = Class{}

require 'Animation'
require 'actors.Player'
require 'actors.Roach'

-- Tiles
TOP = 2
TOP_LEFT = 1
TOP_RIGHT = 3
LEFT = 11
RIGHT = 13
BOT_LEFT = 15
BOT_RIGHT = 14
DIRT = 12
EMPTY = 24

GRAVITY = 20

-- Map scroll speed
local INIT_SCROLL_SPEED = 20
local MAX_SCROLL_SPEED = 48

function Map:init()
    self.worldX = 0
    self.scrollSpeed = INIT_SCROLL_SPEED

    self.tileWidth = 8
    self.tileHeight = 8
    self.mapWidth = 40 * 2
    self.mapHeight = 23

    self.spriteSheet = love.graphics.newImage('graphics/terrain.png')
    self.sprites = generateQuads(self.spriteSheet, 8, 8)

    self.enemies = {}
    self.tilemap = {}

    -- ProcGen settings
    self.groundLevel = 20
    self.landWidth = 4
    self.peak = 20
    self.lastPeak = 20
    self.gapCount = 0

    player = nil

    self:generateTiles(1)
end

-- Generate map through procedural generation
function Map:generateTiles(start)
    -- First fill the map with empty tiles
    for y = 1, self.mapHeight do
        for x = start, self.mapWidth do
            self:setTile(x, y, EMPTY)
        end
    end

    -- Define possible land widths
    local widths = {4, 8, 12, 16, 20}

    local x = start
    while x <= self.mapWidth do
        -- 50% chance to generate land and 100% chance if a gap was created in last loop
        if math.random(2) == 1 or self.gapCount == 1 then
            -- Randomize land width and peak
            self.peak = math.random(self.groundLevel, self.groundLevel - 8)
            self.landWidth = math.min(self.mapWidth - x + 1, widths[math.random(5)])

            for xAxis = x, x + self.landWidth - 1 do
                self:setTile(xAxis, self.peak, TOP)

                for y = self.peak + 1, self.mapHeight do
                    self:setTile(xAxis, y, DIRT)
                end
            end

            -- Execute code if current peak is higher than last peak
            if self.peak < self.lastPeak and x > 1 then
                self:setTile(x, self.peak, TOP_LEFT)

                for y = self.peak + 1, self.lastPeak - 1 do
                    self:setTile(x, y, LEFT)
                end

                self:setTile(x, self.lastPeak, BOT_LEFT)
            -- Else execute following code if current peak is lower then last peak
            elseif self.peak > self.lastPeak and x > 1 then
                self:setTile(x - 1, self.lastPeak, TOP_RIGHT)

                for y = self.lastPeak + 1, self.peak - 1 do
                    self:setTile(x - 1, y, RIGHT)
                end

                self:setTile(x - 1, self.peak, BOT_RIGHT)
            end

            -- Keep track of last peak
            self.lastPeak = self.peak
            -- Reset gap count to 0
            self.gapCount = 0
        else
            -- Gaps are only 4 tiles wide
            self.landWidth = 4

            -- if no consecutive gaps then generate following tiles to last chunk of land
            if self.gapCount == 0 and x > 1 then
                self:setTile(x - 1, self.lastPeak, TOP_RIGHT)

                for y = self.lastPeak + 1, self.mapHeight do
                    self:setTile(x - 1, y, RIGHT)
                end
            end

            self.lastPeak = self.mapHeight + 1
            -- Keep track of gap count
            self.gapCount = self.gapCount + 1
        end

        -- Increment x
        x = x + self.landWidth
    end
end

-- Generate enemies
function Map:generateEnemies(start)
    for x = start, self.mapWidth, 2 do
        for y = self.groundLevel - 8, self.groundLevel do
            local tile = self:getTile(x, y)
            if self:isFloor(tile) and math.random(2) == 1 then
                self.enemies[#self.enemies + 1] = Roach(x, y, self, #self.enemies + 1)
            end
        end
    end
end

function Map:changeSpeed(bgMaxSpeed)
    scrollSpeed = math.min(bgMaxSpeed, scrollSpeed + 3)
    self.scrollSpeed = math.min(MAX_SCROLL_SPEED, self.scrollSpeed + 4)
end

-- Destroy the corresponding enemy by its index; called by the Roach class
function Map:destroyRoach(index)
    self.enemies[index] = nil
end

function Map:startGame(bgInitSpeed)
    self.enemies = {}
    self:generateEnemies(math.floor(self.worldX / self.tileWidth) + self.mapWidth / 4 + 13)

    player = Player(self)
    score = 0
    scoreRef = 0
    scrollSpeed = bgInitSpeed
    self.scrollSpeed = INIT_SCROLL_SPEED

    menuMusic:stop()
    bgMusic:play()
end

-- Get tile based from pixel position
function Map:tileAt(x, y)
    return {
        x = math.floor(x / self.tileWidth) + 1,
        y = math.floor(y / self.tileHeight) + 1,
        id = self:getTile(math.floor(x / self.tileWidth) + 1, math.floor(y / self.tileHeight) + 1)
    }
end

-- Get tile based from grid-based position
function Map:getTile(x, y)
    return self.tilemap[(y - 1) * self.mapWidth + x]
end

-- Set tile according to its position
function Map:setTile(x, y, id)
    self.tilemap[(y - 1) * self.mapWidth + x] = id
end

function Map:isFloor(tile)
    local floorTiles = {
        TOP_LEFT, TOP_RIGHT, TOP
    }

    for i, v in ipairs(floorTiles) do
        if tile == v then
            return true
        end
    end

    return false
end

function Map:collides(tile)
    local collidables = {
        TOP, TOP_LEFT, TOP_RIGHT, LEFT, RIGHT, DIRT
    }

    for i, v in ipairs(collidables) do
        if tile == v then
            return true
        end
    end

    return false
end

function Map:update(dt)
    self.worldX = self.worldX + self.scrollSpeed * dt

    if self.worldX >= VIRTUAL_WIDTH then
        -- Swap tiles from right side to left side of the tilemap
        for y = 1, self.mapHeight do
            for x = 1, self.mapWidth / 2 do
                local tile = self:getTile(self.mapWidth / 2 + x, y)
                self:setTile(x, y, tile)
            end
        end

        self:generateTiles(self.mapWidth / 2 + 1)

        if gameState ~= 'menu' then
            player:updatePos()

            -- Update enemies' positions
            for i, enemy in pairs(self.enemies) do
                enemy:updatePos()
            end

            self:generateEnemies(self.mapWidth / 2 + 1)
        end

        self.worldX = 0
    end

    if gameState ~= 'menu' then
        for i, enemy in pairs(self.enemies) do
            enemy:update(dt)
        end
    end

    if gameState == 'play' then
        player:update(dt)
    end
end

function Map:render()
    love.graphics.push()

    love.graphics.translate(math.floor(-self.worldX), 0)

    -- Draw tilemap
    for y = 1, self.mapHeight do
        for x = 1, self.mapWidth do
            local tile = self.sprites[self:getTile(x, y)]
            love.graphics.draw(self.spriteSheet, tile, (x - 1) * self.tileWidth, (y - 1) * self.tileHeight)
        end
    end

    if gameState ~= 'menu' then
        -- Draw enemies
        for i, enemy in pairs(self.enemies) do
            enemy:render()
        end
    end

    if gameState == 'play' then
        -- Draw player
        player:render()
    end

    love.graphics.pop()
end