--[[
    ScoreState Class
    Author: Colton Ogden
    cogden@cs50.harvard.edu

    A simple state used to display the player's score before they
    transition back into the play state. Transitioned to from the
    PlayState when they collide with a Pipe.
]]

ScoreState = Class{__includes = BaseState}

-- Medal dimensios are 512x512 pixels
local bronzeMedal = love.graphics.newImage('medals/medalBronze.png')
local silverMedal = love.graphics.newImage('medals/medalSilver.png')
local goldMedal = love.graphics.newImage('medals/medalGold.png')

local scale_factor = 0.15 -- 0.1 too small
local MEDAL_WIDTH = silverMedal:getWidth() / 2 * scale_factor

--[[
    When we enter the score state, we expect to receive the score
    from the play state so we know what to render to the State.
]]
function ScoreState:enter(params)
    self.score = params.score
end

function ScoreState:update(dt)
    -- go back to play if enter is pressed
    if love.keyboard.wasPressed('enter') or love.keyboard.wasPressed('return') then
        gStateMachine:change('countdown')
    end
end

function ScoreState:render()
    -- simply render the score to the middle of the screen
    love.graphics.setFont(flappyFont)
    love.graphics.printf('Oof! You lost!', 0, 64, VIRTUAL_WIDTH, 'center')

    love.graphics.setFont(mediumFont)
    love.graphics.printf('Score: ' .. tostring(self.score), 0, 100, VIRTUAL_WIDTH, 'center')

    -- *IMPLEMENT AWARD SYSTEM HERE
    if (self.score < 5) then
        -- no awards for me
        AwardMedal('Better luck next time!')
    elseif(self.score < 10) then
        -- bronze medal
        AwardMedal('Nice, BRONZE MEDAL', bronzeMedal)
    elseif(self.score < 25) then
        -- silver medal
        AwardMedal('Awesome, SILVER MEDAL', silverMedal)
    else
        -- gold medal.
        AwardMedal('EXCELENT, GOLD MEDAL', goldMedal)
    end

    love.graphics.printf('Press Enter to Play Again!', 0, 160, VIRTUAL_WIDTH, 'center')
end

function AwardMedal(param, medal)
    love.graphics.printf(param, 0,130, VIRTUAL_WIDTH, 'center')
    if medal ~= nil then
        love.graphics.draw(medal, VIRTUAL_WIDTH / 2 - MEDAL_WIDTH, 180, 0, scale_factor, scale_factor)
    end
end