
-- If true, Advanced Computer will show all Log information. Default: false
local bShowInGameLog = false

local bDisableLog = false


-- Name of the log file e.g. "logFileName"_log.txt
local logFileName = "LC"


function logToFile(message, level, bPrint)
    if not bDisableLog then
        level = level or "INFO_"
        bPrint = bPrint or bShowInGameLog

        local logFolder = logFileName .. "_logs"
        local logFilePath = logFolder .. "/" .. logFileName .. "_log_latest.txt"


        if not fs.exists(logFolder) then
            local success, err = pcall(function() fs.makeDir(logFolder) end)
            if not success then
                print(string.format("Failed to create log folder: %s", err))
                return
            end
        end


        local success, err = pcall(function()
            local logFile = fs.open(logFilePath, "a")
            if logFile then
                -- Write the log entry with a timestamp and level
                logFile.writeLine(string.format("[%s] [%s] %s", os.date("%Y-%m-%d %H:%M:%S"), level, message))
                logFile.close()
            else
                error("Unable to open log file.")
            end
        end)


        if not success then
            print(string.format("Error writing to log file: %s", err))
            return
        end

        -- Optionally print the message to the console
        if bPrint then
            if level == "ERROR" or level == "FATAL" then
                print("")
            end

            print(string.format("%s", message))

            if level == "ERROR" or level == "FATAL" then
                print("")
            end
        end

        free = fs.getFreeSpace("/")

        logCounter = (logCounter or 0) + 1
        if logCounter >= 250 or free < 80000 then
            rotateLogs(logFolder, logFilePath)
            logCounter = 0
        end
    end
end

-- Rotates logs and limits the number of old logs stored
function rotateLogs(logFolder, logFilePath)
    local maxLogs = 2 -- Maximum number of log files to keep


    local timestamp = os.date("%Y-%m-%d_%H-%M-%S")
    local archivedLog = string.format("%s/log_%s.txt", logFolder, timestamp)


    local success, err = pcall(function()
        if fs.exists(logFilePath) then
            fs.move(logFilePath, archivedLog)
        end
    end)

    if not success then
        print(string.format("Failed to rotate log file: %s", err))
        return
    end


    local logs = fs.list(logFolder)
    table.sort(logs)

    local logCount = #logs
    while logCount > maxLogs do
        local oldestLog = logFolder .. "/" .. logs[1]
        local deleteSuccess, deleteErr = pcall(function() fs.delete(oldestLog) end)
        if not deleteSuccess then
            print(string.format("Failed to delete old log file: %s", deleteErr))
            break
        end
        table.remove(logs, 1)
        logCount = logCount - 1
    end
end

----------------------------------------------------------------------------
--* ERROR-HANDLING FUNCTION
----------------------------------------------------------------------------

function safeCall(func, ...)
    local success, result = pcall(func, ...)
    if not success then
        logToFile((result or "Unknown error"), "ERROR")
        return false
    end
    return true
end


----------------------------------------------------------------------------
--* DEBUG FUNCTIONS
----------------------------------------------------------------------------

function debugDiskSpace()
    local free = fs.getFreeSpace("/")
    print("Free disk space:", free, "bytes")

    for _, f in ipairs(fs.list("/")) do
        local path = "/" .. f
        if not fs.isDir(path) then
            print(path, fs.getSize(path))
        end
    end
end

function debugPrintTableToLog(t, logFile, indent)
    indent = indent or 0
    local prefix = string.rep("  ", indent)

    for key, value in pairs(t) do
        if type(value) == "table" then
            logFile:write(prefix .. tostring(key) .. ":\n")
            debugPrintTableToLog(value, logFile, indent + 1)
        else
            logFile:write(prefix .. tostring(key) .. ": " .. tostring(value) .. "\n")
        end
    end
end

function debugTableTest()
    local logFile = io.open("M_log.txt", "w")
    if not logFile then
        error("Could not open log file for writing")
    end


    local success, result = pcall(function()
        local requests = peripheral.find("colony_integrator").getRequests()
        debugPrintTableToLog(requests, logFile)
    end)

    if not success then
        logFile:write("Error: " .. tostring(result) .. "\n")
    end

    logFile:close()

    print(result or "Table logged successfully")
end


----------------------------------------------------------------------------
--* GENERIC HELPER FUNCTIONS
----------------------------------------------------------------------------

function trimLeadingWhitespace(str)
    return str:match("^%s*(.*)$")
end

function getLastWord(str)
    return string.match(str, "%S+$")
end

-- function getLastWord(str)
--     local words = {}
--     for word in string.gmatch(str, "%S+") do
--         table.insert(words, word)
--     end
--     return words[#words] or "" 
-- end

function tableToString(tbl, indent)
    indent = indent or 0
    local toString = string.rep("  ", indent) .. "{\n"
    for key, value in pairs(tbl) do
        local formattedKey = type(key) == "string" and string.format("%q", key) or tostring(key)
        if type(value) == "table" then
            toString = toString ..
                string.rep("  ", indent + 1) ..
                "[" .. formattedKey .. "] = " .. tableToString(value, indent + 1) .. ",\n"
        else
            local formattedValue = type(value) == "string" and string.format("%q", value) or tostring(value)
            toString = toString ..
                string.rep("  ", indent + 1) .. "[" .. formattedKey .. "] = " .. formattedValue .. ",\n"
        end
    end
    return toString .. string.rep("  ", indent) .. "}"
end

function writeToLogFile(fileName, equipment_list, builder_list, domum_list, others_list)
    local success, file_or_err = pcall(io.open, fileName, "w")
    if not success then
        logToFile("Could not open file for writing: " .. fileName .. " Error: " .. tostring(file_or_err), "ERROR", true)
        return
    end
    local file = file_or_err
    if file then
    file:write("Equipment List:\n")
    file:write(tableToString(equipment_list) .. "\n\n")
    file:write("Standard Builder List:\n")
    file:write(tableToString(builder_list) .. "\n\n")
    file:write("Domum Builder List:\n")
    file:write(tableToString(domum_list) .. "\n\n")
    file:write("Others List:\n")
    file:write(tableToString(others_list) .. "\n\n")
    file:close()
    end
end

function getPeripheral(type)
    local peripheral = peripheral.find(type)
    if not peripheral then
        -- logToFile(type .. " peripheral not found.", "WARN_")
        return nil
    end

    -- logToFile(type .. " peripheral found.")

    return peripheral
end

function checkMonitorSize(monitor)
    monitor.setTextScale(0.5)
    local width, height = monitor.getSize()

    if width < 79 or height < 38 then
        logToFile("Use more Monitors! (min 4x3)", "WARN_")

        return false
    end

    return true
end

function getStorageBridge()
    local meBridge = getPeripheral("meBridge") or getPeripheral("me_bridge")
    local rsBridge = getPeripheral("rsBridge") or getPeripheral("rs_bridge")

    if meBridge then
        return meBridge
    elseif rsBridge then
        return rsBridge
    else
        logToFile("Neither ME Storage Bridge nor RS Storage Bridge found.", "WARN_")

        return nil
    end
end

function autodetectStorage()
    for _, side in pairs(peripheral.getNames()) do
        if peripheral.hasType(side, "inventory") then
            -- logToFile("Storage detected on " .. side)

            return side
        end
    end
    logToFile("No storage container detected!", "WARN_")

    return nil
end
--* to remove mod name minecraft:coal -> coal
function removeNamespace(itemName, pattern)
    if type(itemName) ~= "string" then return tostring(itemName) end
    local indexStart, IndexEnd = string.find(itemName, pattern)
    if IndexEnd then
        return string.sub(itemName, IndexEnd + 1)
    end
    return itemName
end

----------------------------------------------------------------------------
--* NBT TO SNBT STRING CONVERSION HELPER (SIMPLIFIED)
----------------------------------------------------------------------------
function convertNbtToSnbtString(nbtTable)
    if type(nbtTable) ~= "table" then
        logToFile("convertNbtToSnbtString: Input is not a table, returning nil. Type: " .. type(nbtTable), "WARN_")
        return nil
    end
    if next(nbtTable) == nil then
        logToFile("convertNbtToSnbtString: Input table is empty, returning empty SNBT string '{}'.", "DEBUG")
        return "{}"
    end

    local parts = {}
    for key, value in pairs(nbtTable) do
        local keyStr = tostring(key) 

        if type(value) == "string" then
            local escapedValue = string.gsub(value, "\\", "\\\\")
            escapedValue = string.gsub(escapedValue, "\"", "\\\"")
            table.insert(parts, string.format("%s:\"%s\"", keyStr, escapedValue))
        elseif type(value) == "number" then
            table.insert(parts, string.format("%s:%s", keyStr, tostring(value)))
        elseif type(value) == "boolean" then
            table.insert(parts, string.format("%s:%s", keyStr, tostring(value)))
        elseif keyStr == "textureData" and type(value) == "table" then
            local textureParts = {}
            for texKey, texValue in pairs(value) do
                if type(texValue) == "string" then
                    local escapedTexKey = string.gsub(tostring(texKey), "\\", "\\\\")
                    escapedTexKey = string.gsub(escapedTexKey, "\"", "\\\"")
                    local escapedTexValue = string.gsub(texValue, "\\", "\\\\")
                    escapedTexValue = string.gsub(escapedTexValue, "\"", "\\\"")
                    table.insert(textureParts, string.format("\"%s\":\"%s\"", escapedTexKey, escapedTexValue))
                else
                    logToFile("convertNbtToSnbtString: Non-string value found in textureData for key '" .. tostring(texKey) .. "'. Skipping.", "WARN_")
                end
            end
            table.insert(parts, string.format("%s:{%s}", keyStr, table.concat(textureParts, ",")))
        else
            logToFile(string.format("convertNbtToSnbtString: Unsupported type '%s' for key '%s' or unhandled complex table. Value: %s", type(value), keyStr, tableToString(value)), "WARN_")
        end
    end
    local snbtString = "{" .. table.concat(parts, ",") .. "}"
    logToFile("convertNbtToSnbtString: Converted NBT table to SNBT string: " .. snbtString, "TRACE")
    return snbtString
end

local function isEquipment(desc)
    if type(desc) ~= "string" then return false end
    local equipmentKeywords = { "Sword ", "Bow ", "Pickaxe ", "Axe ", "Shovel ", "Hoe ", "Shears ", "Helmet ",
        "Chestplate ", "Leggings ", "Boots ", "Shield" }

    for _, keyword in ipairs(equipmentKeywords) do
        if string.find(desc, keyword) then
            return true
        end
    end
    return false
end

function equipmentCraft(name, level, item_name)
    if (item_name == "minecraft:bow") then
        return item_name, true
    end

    if (level == "Iron" or level == "Iron and Diamond" or level == "Any Level") and (craftEquipmentOfLevel == "Iron" or craftEquipmentOfLevel == "Iron and Diamond") then
        if level == "Any Level" then
            level = "Iron"
        end

        item_name = string.lower("minecraft:" .. level .. "_" .. getLastWord(name))

        return item_name, true
    elseif (level == "Diamond" or level == "Iron and Diamond" or level == "Any Level") and craftEquipmentOfLevel == "Diamond" then
        if level == "Any Level" then
            level = "Diamond"
        end

        item_name = string.lower("minecraft:" .. level .. "_" .. getLastWord(name))
        return item_name, true
    end

    return item_name, false
end

function detectQuantityFieldOnce(bridge, itemName, nbtTable, fingerprint)
    local item_quantity_field = nil
    local spec
    if fingerprint then
        spec = {fingerprint = fingerprint}
    else
        spec = {name = itemName}
        if nbtTable then 
            local nbtString = convertNbtToSnbtString(nbtTable)
            if nbtString then spec.nbt = nbtString end
        end
    end
 
    local success, itemDataResult = safeCall(bridge.getItem, spec)
    if success and itemDataResult then
        if type(itemDataResult.amount) == "number" then item_quantity_field = "amount"; return "amount" end
        if type(itemDataResult.count) == "number" then item_quantity_field = "count"; return "count" end
        logToFile("Could not detect quantity field (amount/count) for " .. itemName .. ". Spec: " ..tableToString(spec), "WARN_")
    else
        logToFile("Failed to getItem for quantity field detection: " .. itemName .. ". Error: " ..tostring(itemDataResult) .. ". Spec: " .. tableToString(spec), "WARN_")
    end
    logToFile("Defaulting quantity field to 'amount' for " .. itemName, "DEBUG")
    item_quantity_field = "amount" 
    return item_quantity_field
end


return {    logToFile = logToFile, 
            writeToLogFile = writeToLogFile,
            tableToString = tableToString,
            getPeripheral = getPeripheral, 
            getStorageBridge = getStorageBridge, 
            autodetectStorage = autodetectStorage, 
            checkMonitorSize = checkMonitorSize,
            removeNamespace = removeNamespace,
            trimLeadingWhitespace = trimLeadingWhitespace,
            safeCall = safeCall,
            isEquipment = isEquipment,
            convertNbtToSnbtString = convertNbtToSnbtString,
            equipmentCraft = equipmentCraft,
            detectQuantityFieldOnce = detectQuantityFieldOnce,
            bShowInGameLog = bShowInGameLog
        }