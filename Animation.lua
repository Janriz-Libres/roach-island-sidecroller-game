-- Class derived from Colton Odgen's Super Mario Bros. Demo; creates functionality for animations
Animation = Class{}

function Animation:init(params)
    self.texture = params.texture
    self.frames = params.frames
    self.interval = params.interval or 0.5

    self.timer = 0
    self.currentFrame = 1
end

-- Restart frames and timer whenever there are state changes
function Animation:restart()
    self.timer = 0
    self.currentFrame = 1
end

-- Returns the texture for object to render
function Animation:getTexture()
    return self.texture
end

-- Get current frame
function Animation:getCurrentFrame()
    return self.frames[self.currentFrame]
end

function Animation:update(dt)
    if #self.frames ~= 1 then
        self.timer = self.timer + dt

        while self.timer >= self.interval do
            self.timer = self.timer - self.interval

            self.currentFrame = (self.currentFrame + 1) % (#self.frames + 1)

            if self.currentFrame == 0 then self.currentFrame = 1 end
        end
    end
end