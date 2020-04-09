local utf8 = require("utf8")

local function len_utf8(text)
    return utf8.len(text)
end

local function sub_utf8(text, from, to)
    assert(from)
    toByte = to and (utf8.offset(text, to + 1) - 1) or text:len()
    return text:sub(utf8.offset(text, from), toByte)
end

local TextLine = {
    name = "TextLine",
}
TextLine.__index = TextLine

setmetatable(TextLine, {__call = function(c, ...)
    local obj = setmetatable({}, TextLine)
    obj.class = TextLine
    if obj.initialize then
        obj.initialize(obj, ...)
    end
    return obj
end})

function TextLine:initialize(font, x, y, w, h, text)
    self.textObject = love.graphics.newText(font)
    self.scroll = 0
    self.cursor = {0, 0}
    self.x, self.y = x, y
    self.width, self.height = w, h
    self:setText(text or "") -- updates cursor too
    self.showCursor = false -- alternates over time
end

function TextLine:setPosition(x, y)
    self.x, self.y = x, y
end

function TextLine:setArea(x, y, w, h)
    self.x, self.y = x, y
    self.width, self.height = w, h
    self:setCursor()
end

function TextLine:getArea()
    return self.x, self.y, self.width, self.height
end

function TextLine:setFont(font)
    self.textObject:setFont(font)
    self:setCursor()
end

function TextLine:setText(text, selectAll)
    self.text = text
    self.textObject:set(text)

    local len = len_utf8(text)
    if selectAll then
        self:setCursor(0, len)
    else
        self:setCursor(len, len)
    end
end

function TextLine:getText(from, to)
    if from then
        return sub_utf8(self.text, from, to)
    else
        return self.text
    end
end

-- self.cursor describes the selected text, with self.cursor[1] being the the visual, blinking cursor
-- if no text is selected both value are the same
-- each value represents the characters before the cursor
function TextLine:setCursor(a, b)
    if not a then
        a, b = unpack(self.cursor)
    else
        b = b or a
    end
    self.cursor = {
        math.min(len_utf8(self.text), math.max(0, a)),
        math.min(len_utf8(self.text), math.max(0, b)),
    }
    local font = self.textObject:getFont()
    self.cursorX = {
        font:getWidth(sub_utf8(self.text, 1, self.cursor[1])),
        font:getWidth(sub_utf8(self.text, 1, self.cursor[2])),
    }

    local cursorX = self.scroll + self.x + self.cursorX[1]
    local leftOverlap = self.x - cursorX
    if leftOverlap > 0 then
        self.scroll = self.scroll + leftOverlap
    end
    local rightOverlap = cursorX - (self.x + self.width)
    if rightOverlap > 0 then
        self.scroll = self.scroll - rightOverlap
    end
end

function TextLine:getSelection()
    local f, t = self.cursor[1], self.cursor[2]
    if f > t then f, t = t, f end
    return f, t
end

function TextLine:getSelectedText()
    local f, t = self:getSelection()
    return self:getText(f + 1, t)
end

function TextLine:paste(text)
    local selStart, selEnd = self:getSelection()
    self:setText(self:getText(1, selStart) .. text .. self:getText(selEnd + 1))
    self:setCursor(selStart + len_utf8(text))
end

function TextLine:skipWord(backwards)
    local len = len_utf8(self.text)
    if len == 0 then return end

    local function isalphanum(c)
        -- TODO: Make this match more than only the ASCII-alphanums
        -- utf-8/ascii: digits, capital alphas, lower alphas
        return (c >= 48 and c <= 57) or (c >= 65 and c <= 90) or (c >= 97 and c < 122)
    end

    -- if you go backwards, the character left of the cursor (pos n) is character n
    -- if you go forwards, the character right of the cursor (pos n) is character n + 1
    local charOffset = backwards and 0 or 1
    local function cursorAlphaNum()
        local charPos = self.cursor[1] + charOffset
        if charPos > utf8.len(self.text) then return false end
        return isalphanum(utf8.codepoint(self.text, utf8.offset(self.text, charPos)))
    end

    local start = cursorAlphaNum()
    if backwards then
        while self.cursor[1] > 0 do
            if cursorAlphaNum() ~= start then break end
            self.cursor[1] = self.cursor[1] - 1
        end
    else
        while self.cursor[1] < len do
            if cursorAlphaNum() ~= start then break end
            self.cursor[1] = self.cursor[1] + 1
        end
    end

    self:setCursor()
end

function TextLine:update(dt)
    local lastShowCursor = self.showCursor
    self.showCursor = math.cos(love.timer.getTime() * 2.0 * math.pi) > 0
    return lastShowCursor ~= self.showCursor
end

function TextLine:draw(selectionColor, drawCursor)
    local lg = love.graphics
    local font = lg.getFont()
    local fontH = font:getHeight()

    local scissorBackup = {lg.getScissor()}
    lg.setScissor(self.x, self.y, self.width, self.height)

    local textH = self.textObject:getHeight()
    local textY = self.y + self.height/2 - textH/2
    local cursorX, cursor2X = self.x + self.cursorX[1], self.x + self.cursorX[2]
    local selStartX, selEndX = math.min(cursorX, cursor2X), math.max(cursorX, cursor2X)

    lg.push()
        lg.translate(self.scroll, 0)
        local col = {lg.getColor()}

        if drawCursor then
            lg.setColor(selectionColor)
            if selStartX > selEndX then selStartX, selEndX = selEndX, selStartX end
            lg.rectangle("fill", selStartX, textY, selEndX - selStartX, textH)
        end

        lg.setColor(col)
        lg.draw(self.textObject, self.x, textY)

        if drawCursor and self.showCursor then
            lg.line(cursorX, self.y, cursorX, self.y + self.height)
        end
    lg.pop()

    lg.setScissor(unpack(scissorBackup))
end

function TextLine:moveCursor(backwards, skipWord, resetSelection)
    if skipWord then
        self:skipWord(backwards)
    else
        local delta = backwards and -1 or 1
        self:setCursor(self.cursor[1] + delta, self.cursor[2])
    end
    if resetSelection then self:setCursor(self.cursor[1]) end
end

-- if you pass events to TextLine, it is assumed to be in focus.
-- focus is not handled by this class itself

-- returns true if the text was modified
function TextLine:keyPressed(key, scanCode, isRepeat)
    local ctrl = love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl")
    if love._os == "OS X" then
        ctrl = love.keyboard.isDown("lgui") or love.keyboard.isDown("rgui")
    end
    local shift = love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift")

    if key == "home" then
        self:setCursor(0, shift and self.cursor[2])
        if not shift then self:setCursor(self.cursor[1]) end
    end

    if key == "end" then
        self:setCursor(len_utf8(self.text), shift and self.cursor[2])
        if not shift then self:setCursor(self.cursor[1]) end
    end

    if key == "left" then
        if self.cursor[1] == self.cursor[2] or shift then
            self:moveCursor(true, ctrl, not shift)
        else
            local selStart, selEnd = self:getSelection()
            self:setCursor(selStart)
        end
    end

    if key == "right" then
        if self.cursor[1] == self.cursor[2] or shift then
            self:moveCursor(false, ctrl, not shift)
        else
            local selStart, selEnd = self:getSelection()
            self:setCursor(selEnd)
        end
    end

    if key == "a" and ctrl then
        self:setCursor(len_utf8(self.text), 0)
    end

    -- clipboard
    if ctrl and (key == "c" or key == "x") then
        love.system.setClipboardText(self:getSelectedText())
    end

    if ctrl and key == "v" then
        self:paste(love.system.getClipboardText())
        return true
    end

    if ctrl and key == "x" then
        self:paste("")
        return true
    end

    -- deletion
    if key == "backspace" then
        if self.cursor[1] == self.cursor[2] then
            self:moveCursor(true, ctrl, false)
        end
        self:paste("")
        return true
    end

    if key == "delete" then
        if self.cursor[1] == self.cursor[2] then
            self:moveCursor(false, ctrl, false)
        end
        self:paste("")
        return true
    end
end

function TextLine:pickCursor(x)
    local font = self.textObject:getFont()
    local offX = self.x + self.scroll
    for i = 1, len_utf8(self.text) do
        if x < offX + font:getWidth(self:getText(1, i)) then
            return i - 1
        end
    end
    return len_utf8(self.text)
end

function TextLine:inArea(x, y, margin)
    margin = margin or 0
    return x > self.x - margin and
           x < self.x + self.width + margin and
           y > self.y - margin and
           y < self.y + self.height + margin
end

-- only handle left mouse button
function TextLine:mousePressed(x, y)
    self.mouseDown = true
    self:setCursor(self:pickCursor(x))
end

function TextLine:mouseMoved(x, y)
    if self.mouseDown then
        self:setCursor(self:pickCursor(x), self.cursor[2])
    end
end

function TextLine:mouseReleased(x, y)
    self.mouseDown = false
end

function TextLine:textInput(text)
    self:paste(text)
    self:setCursor(self.cursor[1])
end

return TextLine
