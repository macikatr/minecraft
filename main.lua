
local VERSION = 1.21
local debug = false
local crafting_enabled = true -- toggle for auto crafting of requests
local ign = "Macika"
local Logo = require "artLogo"
local artLogo = Logo.artLogo

local config = require "config"
local resetDefault = config.resetDefault
local drawLoadingBar = config.drawLoadingBar
local monitorShowDashboard = config.monitorShowDashboard
local monitorPrintText = config.monitorPrintText
local rainbowColors = config.rainbowColors

local helpers = require "helpers"
local getPeripheral = helpers.getPeripheral
local logToFile = helpers.logToFile
local writeToLogFile = helpers.writeToLogFile
local removeNameSpace = helpers.removeNamespace
local getStorageBridge = helpers.getStorageBridge
local autodetectStorage = helpers.autodetectStorage
local checkMonitorSize = helpers.checkMonitorSize
local safeCall = helpers.safeCall

local crafting = require "crafting"
local colonyCategorizeRequests = crafting.colonyCategorizeRequests
local storageSystemHandleRequests = crafting.storageSystemHandleRequests


-- Initialize Rednet
rednet.open("top")


----------------------------------------------------------------------------
--* CHECK REQUIREMENTS
----------------------------------------------------------------------------
local monitors = { peripheral.find("monitor") }
mon1 = monitors[1]
mon2 = monitors[2]
mon1.clear()
mon2.clear()
local colony
local bridge
local storage
local cb = getPeripheral("chat_box")
local speaker = getPeripheral("speaker")
local relay = getPeripheral("redstone_relay")


function checkColonyIntegrator()
    colony = getPeripheral("colonyIntegrator") or getPeripheral("colony_integrator")
    if colony then return true else return false end
end

function checkBridge()
    bridge = getStorageBridge()
    if bridge then return true else return false end
end

function checkStorage()
    storage = autodetectStorage()

    if storage then return true else return false end
end


local missing_setup = true
local needTermDrawRequirements_executed = false


----------------------------------------------------------------------------
--* TERMINAL OUTPUT
----------------------------------------------------------------------------
local termWidth, termHeight = term.getSize()


function termDisplayArt(asciiArt)
    term.clear()

    local x, y = 6, 2

    for line in asciiArt:gmatch("[^\n]+") do
        term.setCursorPos(x, y)
        term.write(line)
        y = y + 1
    end
end


-- Function to simulate the loading process
function termLoadingAnimation()
    resetDefault(term)

    local width, height = term.getSize()

    local barWidth = math.floor(width * 0.8)
    local barX = math.floor((width - barWidth) / 2 + 1)
    local barHeight = math.floor(height * 0.9)

    term.setTextColor(colors.orange)
    term.setCursorPos(1, 1)

    termDisplayArt(artLogo)


    local barSpeed = 25
    for i = 0, barSpeed do
        local progress = i / barSpeed
        drawLoadingBar(term, barX, barHeight, barWidth, progress, colors.gray, colors.orange)
        sleep(0.1)
    end

    resetDefault(term)
end

function termShowLog()
    term.setCursorPos(1, 1)
    term.clearLine()
    term.setCursorPos(1, 2)
    term.clearLine()
    term.setCursorPos(1, 3)
    term.clearLine()
    term.setCursorPos(1, 4)
    term.clearLine()

    local text_Divider = "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    term.setCursorPos(math.floor((termWidth - #text_Divider) / 2) + 1, 4)
    term.write(text_Divider)

    local text_Requirements = "\187 Lost City Logs \171   v" .. VERSION
    term.setCursorPos(math.floor((termWidth - #text_Requirements) / 2) + 1, 2)
    textutils.slowWrite(text_Requirements, 16)
end


----------------------------------------------------------------------------
--* MONITOR OUTPUT
----------------------------------------------------------------------------
local x, y = 1, 1
function monitorDisplayArt(asciiArt, monitor_)
    monitor_.clear()

    local x, y = 1, 2

    for line in asciiArt:gmatch("[^\n]+") do
        monitor_.setCursorPos(x, y)
        monitor_.write(line)
        y = y + 1
    end
end

function monitorLoadingAnimation(monitor_)
    resetDefault(monitor_)

    monitor_.setTextScale(1)

    local width, height = monitor_.getSize()

    local barWidth = math.floor(width * 0.9)
    local barX = math.floor((width - barWidth) / 2 + 1)
    local barHeight = 17

    monitor_.setTextColor(colors.orange)
    monitor_.setCursorPos(1, 1)

    monitorDisplayArt(artLogo, monitor_)

    local barSpeed = 30
    for i = 0, barSpeed do
        local progress = i / barSpeed
        drawLoadingBar(monitor_, barX, barHeight, barWidth, progress, colors.gray, colors.orange)
        sleep(0.1)
    end



    resetDefault(monitor_)

    monitor_.setTextScale(0.5)
end

----------------------------------------------------------------------------
--* MAIN LOGIC FUNCTIONS
----------------------------------------------------------------------------


function checkAllPeripheral()
    
    if not checkColonyIntegrator() or not colony.isInColony() then
        missing_setup = true
    end

    if not checkBridge() then
        missing_setup = true
    end

    if not checkStorage() then
        missing_setup = true
    end


    while missing_setup do
        termDrawCheckRequirements()
        sleep(1)
    end
end


----------------------------------------------------------------------------
--* SETUP GUIDANCE
----------------------------------------------------------------------------


function termDrawProgramReq_helper(y, isRequirementMet)
    if isRequirementMet then
        term.setTextColor(colors.green)
        term.setCursorPos(49, y)
        term.write("[O]")
    else
        term.setTextColor(colors.red)
        term.setCursorPos(49, y)
        term.write("[X]")
    end

    term.setTextColor(colors.white)
end

function termDrawProgramReq_Header()
    local text_Divider = "-------------------------------------------------------"
    term.setCursorPos(math.floor((termWidth - #text_Divider) / 2) + 1, 4)

    term.write(text_Divider)

    local text_Requirements = "\187 Program Requirements \171"
    term.setCursorPos(math.floor((termWidth - #text_Requirements) / 2) + 1, 2)

    textutils.slowWrite(text_Requirements, 16)
end

function termDrawCheckRequirements()
    if not needTermDrawRequirements_executed then
        term.clear()
    end

    local text_Monitor_1 = "\16 Monitor attached"
    term.setCursorPos(2, 6)
    term.write(text_Monitor_1)

    local text_Monitor_2 = "\16 Monitor size (min 4x4)"
    term.setCursorPos(2, 8)
    term.write(text_Monitor_2)

    local text_Colony_1 = "\16 Colony Integrator attached"
    term.setCursorPos(2, 10)
    term.write(text_Colony_1)

    local text_Colony_2 = "\16 Colony Integrator in a colony"
    term.setCursorPos(2, 12)
    term.write(text_Colony_2)

    local text_StorageBridge = "\16 ME or RS Bridge attached"
    term.setCursorPos(2, 14)
    term.write(text_StorageBridge)

    local text_Storage = "\16 Storage/Warehouse attached"
    term.setCursorPos(2, 16)
    term.write(text_Storage)




    if mon1 and mon2 then
        termDrawProgramReq_helper(6, true)

        if checkMonitorSize(mon1) and checkMonitorSize(mon2)  then
            termDrawProgramReq_helper(8, true)
        else
            termDrawProgramReq_helper(8, false)
        end
    else
        termDrawProgramReq_helper(6, false)
        termDrawProgramReq_helper(8, false)
    end


    if checkColonyIntegrator() then
        termDrawProgramReq_helper(10, true)

        if colony.isInColony() then
            termDrawProgramReq_helper(12, true)
        else
            termDrawProgramReq_helper(12, false)
        end
    else
        termDrawProgramReq_helper(10, false)
        termDrawProgramReq_helper(12, false)
    end


    if checkBridge() then
        termDrawProgramReq_helper(14, true)
    else
        termDrawProgramReq_helper(14, false)
    end


    if checkStorage() then
        termDrawProgramReq_helper(16, true)
    else
        termDrawProgramReq_helper(16, false)
    end

    if not needTermDrawRequirements_executed then
        termDrawProgramReq_Header()
        needTermDrawRequirements_executed = true
    end



    if checkColonyIntegrator() and checkBridge() and checkStorage() then
        if checkMonitorSize(mon1) and checkMonitorSize(mon2) and colony.isInColony() then
            termDrawProgramReq_helper(6, true)
            termDrawProgramReq_helper(8, true)
            termDrawProgramReq_helper(10, true)
            termDrawProgramReq_helper(12, true)
            termDrawProgramReq_helper(14, true)
            termDrawProgramReq_helper(16, true)

            missing_setup = false
            needTermDrawRequirements_executed = false


            local text_RequirementsFullfilled = "Requirements fullfilled"
            term.setCursorPos(math.floor((termWidth - #text_RequirementsFullfilled) / 2), 19)
            term.setTextColor(colors.green)
            sleep(0.5)
            textutils.slowWrite(text_RequirementsFullfilled, 16)
            textutils.slowWrite(" . . .", 5)
            sleep(1)


            -- Cleanup
            term.setTextColor(colors.white)
            term.clear()
            term.setCursorPos(1, 1)

            return true
        end
    end

    return true
end


----------------------------------------------------------------------------
--* OVERVIEW FUNCTIONS
----------------------------------------------------------------------------


function centerText(mon, text, line, txtback, txtcolor, pos)
    monX, monY = mon.getSize()
    mon.setBackgroundColor(txtback)
    mon.setTextColor(txtcolor)
    length = string.len(text)
    dif = math.floor(monX-length)
    x = math.floor(dif/2)
    
    if pos == "head" then
        mon.setCursorPos(x+1, line)
        mon.write(text)
    elseif pos == "left" then
        mon.setCursorPos(2, line)
        mon.write(text) 
    elseif pos == "right" then
        mon.setCursorPos(monX-length, line)
        mon.write(text)
    end
end
 
function prepareMonitor1() 
    mon1.clear()
    mon1.setTextScale(0.5)
    centerText(mon1, "Citizens", 1, colors.black, colors.white, "head")
end

local function convert(num)
    local newnumber = string.sub(tostring(num), 1,4)
	newnumber = tonumber(newnumber)
	return tostring(newnumber)
end

function printCitizens()
    local x, y = mon1.getSize()
    local citizens = colony.getCitizens()

    drawBox(mon1, 2, x - 1, 3, ( math.ceil(#citizens / 2)) + 13, "CITIZENS", colors.gray,
        colors.purple)

     --Citizens
    monitorPrintText(mon1, 5, "left", "Name:", colors.orange)
     for i = 1, #citizens do
        local person = citizens[i]
        local gender  = ""
        if person then
            if person.gender == nil then
            gender = "U"
        elseif person.gender == "male" then
            gender = "M"  
        else
            gender = "F"
        end
            monitorPrintText(mon1, i + 5, "left", (person.name .. " / " .. gender), rainbowColors[i] or colors.white)
        end
    end
    monitorPrintText(mon1, 5, "right", "-JOB-", colors.orange)
     for i = 1, #citizens do
        local person = citizens[i]
        local work = ""
        if person.work == nil then
            work = "Jobless"
        else
            work = removeNameSpace(person.work.job, "com.minecolonies.job.")
        end 
        
            monitorPrintText(mon1, i + 5, "right", work, rainbowColors[i] or colors.white)
        end
    monitorPrintText(mon1, 5, "center", "-HAPPINESS-", colors.orange)
     for i = 1, #citizens do
        local person = citizens[i]
        local happiness = convert(person.happiness)
         
        
            monitorPrintText(mon1, i + 5, "center", happiness, rainbowColors[i] or colors.white)
        end
    
    
end
 



function summary(mon)
    curx, cury = mon.getCursorPos()
    cury = cury +6
    mon.setTextScale(0.5)

    local text_Divider = "-------------------------------------------------------"
    mon1.setCursorPos(2, cury)

    mon1.write(text_Divider)

    local text_Requirements = "\187 Summary \171"
    mon1.setCursorPos(2, cury+2)
    mon1.setTextColor(colors.orange)

    mon1.write(text_Requirements)

    mon.setCursorPos(2, cury+4)
    mon.write("Building Sites: ".. colony.amountOfConstructionSites())
    mon.setCursorPos(2, cury+5)
    mon.write("Citizens: ".. colony.amountOfCitizens())
    mon.setCursorPos(2, cury+6)
    mon.write("Capacity: ".. colony.maxOfCitizens())
    mon.setCursorPos(2, cury+7)

        local underAttack = "No"
        if colony.isUnderAttack() then
            underAttack = "Yes"
            cb.sendToastToPlayer("Colony Is Under Attack!", "WARNING", ign, "&4&lSystem", "()", "&c&l")
            speaker.playSound("entity.creeper.primed")
            relay.setAnalogOutput("top", 15)
            sleep(0.5)
            relay.setAnalogOutput("top", 0)
        end
    mon.write("Is under attack? ".. underAttack)
    mon.setCursorPos(2, cury+8)
    mon.write("Overall happiness: ".. math.floor(colony.getHappiness()))
    mon.setCursorPos(2, cury+9)
    mon.write("Amount of graves: ".. colony.amountOfGraves())
       
end


----------------------------------------------------------------------------
--* STORAGE SYSTEM REQUEST AND SEND
----------------------------------------------------------------------------

-- Color code: red = not available
--          yellow = stuck
--            blue = crafting
--           green = fully exported



function requestAndFulfill()
    local equipment_list, builder_list, domum_list, others_list

    local requests = colony.getRequests()

            if requests and storage then
            equipment_list, builder_list, domum_list, others_list = colonyCategorizeRequests(colony, storage, requests)
            else
            logToFile("Failed to get colony requests or no requests found.", "INFO_")
          
        end
    
    --writeToLogFile("log1.txt", equipment_list, builder_list, domum_list, others_list)
    if crafting_enabled and bridge and storage then
        -- storageSystemHandleRequests(bridge, storage, equipment_list)

        storageSystemHandleRequests(bridge, storage, builder_list)

        -- storageSystemHandleRequests(bridge, storage, domum_list)

        -- storageSystemHandleRequests(bridge, storage, others_list)
    end

    return equipment_list, builder_list, domum_list, others_list

end





----------------------------------------------------------------------------
--* MAIN
----------------------------------------------------------------------------

function main()
    termLoadingAnimation()
    
    checkAllPeripheral()

    monitorLoadingAnimation(mon2)


    while true do
         
        checkAllPeripheral()
        
        -- debugTableTest()
        -- sleep(2)

        -- debugDiskSpace()


        termShowLog()

        term.setCursorPos(1, 5)

        --prepareMonitor1()

        printCitizens()
        
        summary(mon1)
        sleep(5)



        


        local equipment_list, builder_list, domum_list, others_list = requestAndFulfill()

        monitorShowDashboard(mon2, equipment_list, builder_list, domum_list, others_list)
    end
 
end

if not debug or colony.isInColony() then
main()
end