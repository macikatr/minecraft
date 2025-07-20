----------------------------------------------------------------------------
--* MONITOR OR TERMINAL OUTPUT
----------------------------------------------------------------------------

function resetDefault(screen)
    screen.setTextColor(colors.white)
    screen.setBackgroundColor(colors.black)
    screen.setCursorPos(1, 1)
    screen.clear()
end

function drawLoadingBar(screen, x, y, width, progress, bgColor, barColor)
    screen.setBackgroundColor(bgColor or colors.gray)
    screen.setTextColor(colors.white)
    screen.setCursorPos(x, y)

    -- Draw the empty bar
    screen.write(string.rep(" ", width))

    -- Draw the filled part
    local filledWidth = math.floor(progress * width)
    screen.setCursorPos(x, y)
    screen.setBackgroundColor(barColor or colors.green)
    screen.write(string.rep(" ", filledWidth))
end

local function ensure_width(line, width)
    width = width or term.getSize()

    line = line:sub(1, width)
    if #line < width then
        line = line .. (" "):rep(width - #line)
    end

    return line
end

function monitorPrintText(monitor, y, pos, text, ...)
    local w, h = monitor.getSize()
    local fg = monitor.getTextColor()
    local bg = monitor.getBackgroundColor()

    local x = 1
    if pos == "left" then
        x = 4
        text = ensure_width(text, math.floor(w / 2) - 2)
    elseif pos == "center" then
        x = math.floor((w - #text) / 2)
    elseif pos == "right" then
        x = w - #text - 2
    elseif pos == "middle" then
        x = math.floor((w - #text) / 2)
        y = math.floor(h / 2) - 2
    end

    if select("#", ...) > 0 then
        monitor.setTextColor(select(1, ...))
    end
    if select("#", ...) > 1 then
        monitor.setBackgroundColor(select(2, ...))
    end

    monitor.setCursorPos(x, y)
    monitor.write(text)
    monitor.setTextColor(fg)
    monitor.setBackgroundColor(bg)
end

function drawBox(monitor, xMin, xMax, yMin, yMax, title, bcolor, tcolor)
    monitor.setBackgroundColor(bcolor)
    for xPos = xMin, xMax, 1 do
        monitor.setCursorPos(xPos, yMin)
        monitor.write(" ")
    end
    for yPos = yMin, yMax, 1 do
        monitor.setCursorPos(xMin, yPos)
        monitor.write(" ")
        monitor.setCursorPos(xMax, yPos)
        monitor.write(" ")
    end
    for xPos = xMin, xMax, 1 do
        monitor.setCursorPos(xPos, yMax)
        monitor.write(" ")
    end
    monitor.setCursorPos(xMin + 2, yMin)
    monitor.setBackgroundColor(colors.black)
    monitor.setTextColor(tcolor)
    monitor.write(" ")
    monitor.write(title)
    monitor.write(" ")
    monitor.setTextColor(colors.white)
end


function monitorDashboardRequests(monitor, equipment_list, builder_list, domum_list, others_list)
    local x, y = monitor.getSize()

    local equipment_count = equipment_list == nil and 0 or #equipment_list
    local builder_count = builder_list == nil and 0 or #builder_list
    local domum_count = domum_list == nil and 0 or #domum_list
    local others_count = others_list == nil and 0 or #others_list



    drawBox(monitor, 2, x - 1, 3, (equipment_count + domum_count + math.ceil(builder_count / 2) + others_count) + 13, "REQUESTS", colors.gray,
        colors.purple)


    --Builder
    monitorPrintText(monitor, 5, "center", "Builder", colors.orange)
    local half = math.ceil(builder_count / 2)

    for i = 1, half do
        local item = builder_list[i]
        if item then
            monitorPrintText(monitor, i + 5, "left", (item.provided .. "/" .. item.name), item.displayColor)
        end
    end

    for i = half + 1, builder_count do
        local item = builder_list[i]
        if item then
            monitorPrintText(monitor, i - half + 5, "right", (item.provided .. "/" .. item.name),
                item.displayColor)
        end
    end
    --Domum
    monitorPrintText(monitor, math.ceil(builder_count / 2) + 7, "center", "Domum", colors.orange)
    local half = math.ceil(builder_count / 2)

    for i = 1, half do
        local item = domum_list[i]
        if item then
            monitorPrintText(monitor, i + 5, "left", (item.provided .. "/" .. item.name), item.displayColor)
        end
    end

    for i = half + 1, builder_count do
        local item = builder_list[i]
        if item then
            monitorPrintText(monitor, i - half + 5, "right", (item.provided .. "/" .. item.name),
                item.displayColor)
        end
    end


    --Equipment
    monitorPrintText(monitor,domum_count + math.ceil(builder_count / 2) + 9, "center", "Equipment", colors.orange)
    if equipment_list then
        for i, item in pairs(equipment_list) do
        monitorPrintText(monitor, domum_count + math.ceil(builder_count / 2) + i + 9, "left", item.name, item.displayColor)
        monitorPrintText(monitor, domum_count + math.ceil(builder_count / 2) + i + 9, "right", item.target, colors.lightGray)
        end
    end


    --Others
    monitorPrintText(monitor, domum_count + equipment_count + math.ceil(builder_count / 2) + 11, "center", "Other", colors.orange)
    for i, item in pairs(others_list) do
        monitorPrintText(monitor, i + domum_count + equipment_count + math.ceil(builder_count / 2) + 11, "left",
            (item.provided .. "/" .. item.name),
            item.displayColor)
        monitorPrintText(monitor, i + domum_count + equipment_count + math.ceil(builder_count / 2) + 11, "right", item.target, colors.lightGray)
    end
end


----------------------------------------------------------------------------
-- MONITOR DASHBOARD NAME
----------------------------------------------------------------------------

-- 1st line on dashboard with color changing depending on the refreshInterval
-- Reset through a rainbow

local dashboardName = "MineColonies DASHBOARD"
-- Displays Ticker in the first row right-side. Default: 15
local refreshInterval = 15

local rainbowColors = {
    colors.red, colors.orange, colors.yellow,
    colors.green, colors.cyan, colors.blue,
    colors.purple, colors.magenta, colors.pink,
    colors.lightBlue, colors.red, colors.orange, colors.yellow,
    colors.green, colors.cyan, colors.blue,
    colors.purple, colors.magenta, colors.pink,
    colors.lightBlue,

}


function monitorDisplayDashboardName(monitor, y, text, colorsTable)
    local w, h = monitor.getSize()
    local x = math.floor((w - #text) / 2) + 1

    for i = 1, #text do
        local char = text:sub(i, i)
        local color = colorsTable[i]
        monitor.setTextColor(color)
        monitor.setCursorPos(x + i - 1, y)
        monitor.write(char)
        sleep(0.01)
    end
end

function dashboardGenerateTransitionColors(progress, length)
    local colorsTable = {}
    local threshold = math.floor((progress) * length)

    for i = 1, length do
        if i <= threshold then
            table.insert(colorsTable, colors.orange)
        else
            table.insert(colorsTable, colors.white)
        end
    end

    return colorsTable
end

function dashboardGenerateRainbowColors(baseColors, length)
    local result = {}
    local totalColors = #baseColors

    for i = 1, length do
        result[i] = baseColors[((i - 1) % totalColors) + 1]
    end

    return result
end

function monitorDashboardName(monitor)
    local startTime = os.clock()
    local y = 1

    while true do
        local elapsedTime = os.clock() - startTime
        local progress = math.min(elapsedTime / (refreshInterval - 1), 1)

        if elapsedTime >= refreshInterval then
            sleep(0.5)

            local rainbowColorsTable = dashboardGenerateRainbowColors(rainbowColors, #dashboardName)

            monitorDisplayDashboardName(monitor, y, dashboardName, rainbowColorsTable)
            sleep(0.1)
        else
            local colorsTable = dashboardGenerateTransitionColors(progress, #dashboardName)

            monitorDisplayDashboardName(monitor, y, dashboardName, colorsTable)
            sleep(0.1)
        end


        if elapsedTime >= refreshInterval then
            break
        end
    end
end

--TODO
function monitorShowDashboard(monitor, equipment_list, builder_list, domum_list, others_list)
    monitor.clear()

    monitorDashboardRequests(monitor, equipment_list, builder_list, domum_list, others_list)

    --   monitorDashboardResearch()

    --   monitorDashboardStats()

    monitorDashboardName(monitor)
end


return { resetDefault = resetDefault, 
        drawLoadingBar = drawLoadingBar, 
        monitorPrintText = monitorPrintText,   
        drawBox = drawBox, 
        monitorShowDashboard = monitorShowDashboard,
        rainbowColors = rainbowColors    
    }