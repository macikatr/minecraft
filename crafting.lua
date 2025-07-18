local helpers = require "helpers"
local logToFile = helpers.logToFile
local removeNamespace = helpers.removeNamespace

----------------------------------------------------------------------------
--* REQUEST HANDLING
----------------------------------------------------------------------------
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

function colonyCategorizeRequests(colony)
    local equipment_list = {}
    local builder_list = {}
    local domum_list = {}
    local others_list = {}

    if not colony then
        logToFile("Colony Integrator not available for categorizing requests.", "WARN_", true)
        return equipment_list, builder_list, domum_list, others_list
    end
 
    local success, requests = safeCall(colony.getRequests)
    if not success or not requests or #requests == 0 then
        logToFile("Failed to get colony requests or no requests found.", "INFO_")
        return equipment_list, builder_list, domum_list, others_list
    end

    for _, req in ipairs(requests) do

        if not req.items or not req.items[1] then
            logToFile("Skipping request due to missing item data: " .. tableToString(req), "DEBUG")
            goto continue_categorize_loop
        end


        local name_from_req = req.name or "Unknown"
        local target = req.target or ""
        local desc = req.desc or ""
        local count = req.count
        local item_displayName = trimLeadingWhitespace(req.items[1].displayName or name_from_req)
        local item_name_raw = req.items[1].name or ""
        local itemIsEquipment = isEquipment(desc)

        local nbtToStore = req.items[1].nbt
        local fingerprintToStore = req.items[1].fingerprint
        local formattedName = name_from_req 
        local isDomumOrnamentumItem = string.find(item_name_raw, "domum_ornamentum:", 1, true) == 1

        local itemEntry = {
            name = formattedName, 
            target = target, 
            count = count, 
            item_displayName = item_displayName,
            item_name_raw = item_name_raw, 
            item_name = item_name_raw,     
            desc = desc, 
            provided = 0, 
            isCraftable = false,
            equipment = itemIsEquipment, 
            displayColor = colors.white, 
            level = "Any Level", 
            nbtData = nbtToStore,
            fingerprint = fingerprintToStore
        }

        

        -- Equipment Categorization
        if itemIsEquipment then
            local levelTable = {
                ["and with maximal level: Leather"] = "Leather",
                ["and with maximal level: Stone"] = "Stone",
                ["and with maximal level: Chain"] = "Chain",
                ["and with maximal level: Gold"] = "Gold",
                ["and with maximal level: Iron"] = "Iron",
                ["and with maximal level: Diamond"] = "Diamond",

                ["with maximal level: Wood or Gold"] = "Wood or Gold"
            }

            local level = "Any Level"

            for pattern, mappedLevel in pairs(levelTable) do
                if string.find(desc, pattern) then
                    level = mappedLevel
                    break
                end
            end

            local new_name = level .. " " .. name

            table.insert(equipment_list, {
                name = new_name,
                target = target,
                count = count,
                item_displayName = item_displayName,
                item_name = item_name,
                desc = desc,
                provided = 0,
                isCraftable = false,
                equipment = itemIsEquipment,
                displayColor = colors.white,
                level = level
            })

            -- Builder Categorization
        elseif string.find(target, "Builder") then
            table.insert(builder_list, {
                name = name,
                target = target,
                count = count,
                item_displayName = item_displayName,
                item_name = item_name,
                desc = desc,
                provided = 0,
                isCraftable = false,
                equipment = itemIsEquipment,
                displayColor = colors.white,
                level = ""
            })

            -- Non-Builder Categorization
        else
            table.insert(others_list, {
                name = name,
                target = target,
                count = count,
                item_displayName = item_displayName,
                item_name = item_name,
                desc = desc,
                provided = 0,
                isCraftable = false,
                equipment = itemIsEquipment,
                displayColor = colors.white,
                level = ""
            })
        
        end
        ::continue_categorize_loop::
    end

    return equipment_list, builder_list, others_list
end
