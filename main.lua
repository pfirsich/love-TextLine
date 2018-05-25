local TextLine = require("textline")

function love.load()
    local font = love.graphics.newFont(20)
    textLine = TextLine(font, 20, 20, 300, 30)
    textLine._focused = true
    love.keyboard.setKeyRepeat(true)
end

function love.draw()
    love.graphics.setColor({1.0, 1.0, 1.0})
    love.graphics.rectangle("line", textLine.x - 5, textLine.y - 5,
        textLine.width + 10, textLine.height + 10)
    textLine:draw({0.5, 0.5, 0.5}, textLine._focused)
end

function love.keypressed(...)
    if textLine._focused then
        textLine:keyPressed(...)
    end
end

function love.textinput(...)
    if textLine._focused then
        textLine:textInput(...)
    end
end

function love.mousepressed(x, y, button)
    textLine._focused = textLine:inArea(x, y, 5)
    if textLine._focused and button == 1 then
        textLine:mousePressed(x, y)
    end
end

function love.mousemoved(x, y, dx, dy)
    if textLine._focused then
        textLine:mouseMoved(x, y)
    end
end

function love.mousereleased(x, y, button)
    if textLine._focused and button == 1 then
        textLine:mouseReleased(x, y)
    end
end
