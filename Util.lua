-- Function derived from Colton Ogden's Super Mario Bros. Demo; generates quads from a spritesheet given the width and height of the quad
function generateQuads(atlas, tileWidth, tileHeight)
    local sheetWidth = atlas:getWidth() / tileWidth
    local sheetHeight = atlas:getHeight() / tileHeight

    local quads = {}

    for y = 1, sheetHeight do
        for x = 1, sheetWidth do
            quads[(y - 1) * sheetWidth + x] = love.graphics.newQuad((x - 1) * tileWidth, (y - 1) * tileHeight, tileWidth, tileHeight, atlas:getDimensions())
        end
    end

    return quads
end