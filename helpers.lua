
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

function writeToLogFile(fileName, equipment_list, builder_list, others_list)
    local file = io.open(fileName, "w") -- Open file in write mode

    if not file then
        error("Could not open file for writing: " .. fileName)
    end

    -- Write the contents of each list
    file:write("Equipment List:\n")
    file:write(tableToString(equipment_list) .. "\n\n")

    file:write("Builder List:\n")
    file:write(tableToString(builder_list) .. "\n\n")

    file:write("Others List:\n")
    file:write(tableToString(others_list) .. "\n\n")

    file:close() -- Close the file
end

local function ensure_width(line, width)
    width = width or term.getSize()

    line = line:sub(1, width)
    if #line < width then
        line = line .. (" "):rep(width - #line)
    end

    return line
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

function removeNamespace(itemName)
    if type(itemName) ~= "string" then return tostring(itemName) end
    local colonIndex = string.find(itemName, ":")
    if colonIndex then
        return string.sub(itemName, colonIndex + 1)
    end
    return itemName
end


return {    logToFile = logToFile, 
            getPeripheral = getPeripheral, 
            getStorageBridge = getStorageBridge, 
            autodetectStorage = autodetectStorage, 
            checkMonitorSize = checkMonitorSize,
            removeNamespace = removeNamespace
        }