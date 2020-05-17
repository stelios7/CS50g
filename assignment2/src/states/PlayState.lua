--[[
    GD50
    Breakout Remake

    -- PlayState Class --

    Author: Colton Ogden
    cogden@cs50.harvard.edu

    Represents the state of the game in which we are actively playing;
    player should control the paddle, with the ball actively bouncing between
    the bricks, walls, and the paddle. If the ball goes below the paddle, then
    the player should lose one point of health and be taken either to the Game
    Over screen if at 0 health or the Serve screen otherwise.
]]

PlayState = Class{__includes = BaseState}
local startingTime = love.timer.getTime()
--[[
    We initialize what's in our PlayState via a state table that we pass between
    states as we go from playing to serving.
]]
function PlayState:enter(params)
    self.paddle = params.paddle
    self.bricks = params.bricks
    self.health = params.health
    self.score = params.score
    self.highScores = params.highScores
    self.ball = params.ball
    self.balltable = {self.ball}
    self.level = params.level

    self.canBreakSpecial = false
    self.specialLevel = false
    for k, brick in pairs(self.bricks) do
        if brick.isSpecial then
            self.specialLevel = true
            break
        end
    end
    
    --*timer implementation for the powerups
    self.poweruptimer = love.timer.getTime() - startingTime -- = 0

    -- self.recoverPoints = 5000

    -- give ball random starting velocity
    self.ball.dx = math.random(-200, 200)
    self.ball.dy = math.random(-50, -60)
end

function PlayState:update(dt)
    if self.poweruptimer > 2.1 then
        --* Spawn a PowerUp
        self.poweruptimer = 0
        newPowerup = Powerup()
        --* Spawn Chance for special Powerup 
        if self.specialLevel and math.random() > 0.7 then
            newPowerup.skin = 10
            newPowerup.hasKeyPower = true
        else
            newPowerup.skin = math.random(9)
        end
        newPowerup.x = math.random(VIRTUAL_WIDTH / 5 , VIRTUAL_WIDTH * 4 / 5)
        newPowerup.y = 0
        newPowerup.dy = 100
    end
    self.poweruptimer = self.poweruptimer + dt

    if self.paused then
        if love.keyboard.wasPressed('space') then
            self.paused = false
            gSounds['pause']:play()
        else
            return
        end
    elseif love.keyboard.wasPressed('space') then
        self.paused = true
        gSounds['pause']:play()
        return
    end

    if love.keyboard.isDown('p') then
        SpawnNewBall(self.paddle, self.balltable)
    end

    -- update positions based on velocity
    self.paddle:update(dt)
    
    if newPowerup ~= nil then

        newPowerup:update(dt)
        
        if newPowerup:collides(self.paddle) then
            if newPowerup.hasKeyPower then
                self.canBreakSpecial = true
                gSounds['keypowerup']:play()
            else
                --* Obtain the powerup if collided
                
                SpawnNewBall(self.paddle, self.balltable)
                SpawnNewBall(self.paddle, self.balltable)
                
                gSounds['powerup']:play()
            end
            newPowerup.isActive = false
        end
    end


    for k, ball in pairs(self.balltable) do

        --*self.ball:update(dt)
        ball:update(dt)

        --*if self.ball:collides(self.paddle) then
        if ball:collides(self.paddle) then
            -- raise ball above paddle in case it goes below it, then reverse dy
            ball.y = self.paddle.y - 8
            ball.dy = -ball.dy

            --
            -- tweak angle of bounce based on where it hits the paddle
            --

            -- if we hit the paddle on its left side while moving left...
            if ball.x < self.paddle.x + (self.paddle.width / 2) and self.paddle.dx < 0 then
                ball.dx = -50 + -(8 * (self.paddle.x + self.paddle.width / 2 - ball.x))
            
            -- else if we hit the paddle on its right side while moving right...
            elseif ball.x > self.paddle.x + (self.paddle.width / 2) and self.paddle.dx > 0 then
                ball.dx = 50 + (8 * math.abs(self.paddle.x + self.paddle.width / 2 - ball.x))
            end

            gSounds['paddle-hit']:play()
        end
        
    
    -- detect collision across all bricks with the ball
        for k, brick in pairs(self.bricks) do
            -- only check collision if we're in play
            if brick.inPlay and ball:collides(brick) then

                if not brick.isSpecial then
                    -- add to score
                    local points = (brick.tier * 200 + brick.color * 25)
                    self.score = self.score + points

                    if self.score % 5000 < points  then
                        self.paddle.size = self.paddle.size < 4 and self.paddle.size + 1 or 4
                        self.paddle.width = self.paddle.size * 32
                    end
                    
                    if self.score % 10000 < points then
                        self.health = self.health < 3 and self.health + 1 or 3
                    end
                    
                    -- trigger the brick's hit function, which removes it from play
                    brick:hit()
                else
                    gSounds['specialchest']:stop()
                    gSounds['specialchest']:play()
                    if self.canBreakSpecial then
                        brick:hitSpecial()
                    end
                end
                -- if we have enough points, recover a point of health

                -- go to our victory screen if there are no more bricks left
                if self:checkVictory() then
                    gSounds['victory']:play()

                    gStateMachine:change('victory', {
                        level = self.level,
                        paddle = self.paddle,
                        health = self.health,
                        score = self.score,
                        highScores = self.highScores,
                        ball = self.ball,
                        recoverPoints = self.recoverPoints
                    })
                end

                --
                -- collision code for bricks
                --
                -- we check to see if the opposite side of our velocity is outside of the brick;
                -- if it is, we trigger a collision on that side. else we're within the X + width of
                -- the brick and should check to see if the top or bottom edge is outside of the brick,
                -- colliding on the top or bottom accordingly 
                --

                -- left edge; only check if we're moving right, and offset the check by a couple of pixels
                -- so that flush corner hits register as Y flips, not X flips
                if ball.x + 2 < brick.x and ball.dx > 0 then
                    
                    -- flip x velocity and reset position outside of brick
                    ball.dx = -ball.dx
                    ball.x = brick.x - 8
                
                -- right edge; only check if we're moving left, , and offset the check by a couple of pixels
                -- so that flush corner hits register as Y flips, not X flips
                elseif ball.x + 6 > brick.x + brick.width and ball.dx < 0 then
                    
                    -- flip x velocity and reset position outside of brick
                    ball.dx = -ball.dx
                    ball.x = brick.x + 32
                
                -- top edge if no X collisions, always check
                elseif ball.y < brick.y then
                    
                    -- flip y velocity and reset position outside of brick
                    ball.dy = -ball.dy
                    ball.y = brick.y - 8
                
                -- bottom edge if no X collisions or top collision, last possibility
                else
                    
                    -- flip y velocity and reset position outside of brick
                    ball.dy = -ball.dy
                    ball.y = brick.y + 16
                end

                -- slightly scale the y velocity to speed up the game, capping at +- 150
                if math.abs(ball.dy) < 150 then
                    ball.dy = ball.dy * 1.02
                end

                -- only allow colliding with one brick, for corners
                break
            end

        end
    
    -- if ball goes below bounds, revert to serve state and decrease health
        if ball.y >= VIRTUAL_HEIGHT then
            ball.isActive = false
            
            --*Check if the ball that went off-screen was the last one and ONLY then perform actions
            if PlayState:WasLastBall(self.balltable) then
                self.health = self.health - 1
                self.paddle.size = self.paddle.size > 1 and self.paddle.size - 1 or 1
                self.paddle.width = self.paddle.size * 32
                gSounds['hurt']:play()

                if self.health == 0 then
                    gStateMachine:change('game-over', {
                        score = self.score,
                        highScores = self.highScores
                    })
                else
                    gStateMachine:change('serve', {
                        paddle = self.paddle,
                        bricks = self.bricks,
                        health = self.health,
                        score = self.score,
                        highScores = self.highScores,
                        level = self.level,
                        recoverPoints = self.recoverPoints
                    })
                end
            end
        end
    end
    -- for rendering particle systems
    for k, brick in pairs(self.bricks) do
        brick:update(dt)
    end

    if love.keyboard.wasPressed('escape') then
        love.event.quit()
    end
end

function SpawnNewBall(paddle, balltable)
    local newBall = Ball()
        newBall.skin = math.random(7)
        newBall.x = paddle.x + (paddle.width / 2) - 4
        newBall.y = paddle.y - 8
        newBall.dx = math.random(-200, 200)
        newBall.dy = math.random(-80, -100)
    table.insert( balltable,newBall )
end

--[[ The WasLastBall() function takes in a table of BALL items
    and iterates through them. If there are any balls active the function 
    returns false, else if no balls are active this means that there are
    no other balls left in game
    ]]
function PlayState:WasLastBall(ballsTable)
    for k, ball in pairs(ballsTable) do
        if ball.isActive == true then
            return false
        end
    end
    return true
end

function PlayState:render()
    -- render bricks
    for k, brick in pairs(self.bricks) do
        brick:render()
    end

    -- render all particle systems
    for k, brick in pairs(self.bricks) do
        brick:renderParticles()
    end

    self.paddle:render()
    --*self.ball:render()
    for k, ball in pairs(self.balltable) do
        ball:render()
    end

    if newPowerup ~= nil then
        newPowerup:render() 
    end

    renderScore(self.score)
    renderHealth(self.health)

    -- pause text, if paused
    if self.paused then
        love.graphics.setFont(gFonts['large'])
        love.graphics.printf("PAUSED", 0, VIRTUAL_HEIGHT / 2 - 16, VIRTUAL_WIDTH, 'center')
    end

    --* Draw active time on screen
    love.graphics.setFont(gFonts['small'])
    love.graphics.printf(tostring(math.floor(self.poweruptimer)), 0, 50, 50, 'center')
end

function PlayState:checkVictory()
    for k, brick in pairs(self.bricks) do
        if brick.inPlay then
            return false
        end 
    end

    return true
end