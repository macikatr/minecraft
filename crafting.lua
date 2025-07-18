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

        if string.find(target, "Builder", 1, true) then
            if isDomumOrnamentumItem then
                local blockType = removeNamespace(item_name_raw)
                local textureData = nbtToStore["textureData"]
                local textureDataSize = 0
                if type(textureData) == "table" then
                    for _ in pairs(textureData) do textureDataSize = textureDataSize + 1 end
                end
                if textureDataSize == 1 and nbtToStore and nbtToStore.type then
                    local singleMaterial = "UnknownMaterial"
                    if type(textureData) == "table" then 
                        for _, mat_val in pairs(textureData) do 
                            singleMaterial = removeNamespace(tostring(mat_val));
                            break
                         end
                    local style = tostring(nbtToStore.type):gsub("_", " ") :gsub("^%l", string.upper):gsub("%s%l", function(c) return string.upper(c) end)
                    itemEntry.name = string.format("%s (%s, %s)", item_displayName, style, singleMaterial)
                end
                elseif textureDataSize == 2 and nbtToStore then
                    local materialsExtracted = {}
                    if type(textureData) == "table" then
                        local matKeys = {}
                        for matkey in pairs(textureData) do table.insert(matKeys, matkey) end
                        if matKeys[1] then table.insert(materialsExtracted, removeNamespace(tostring(textureData[matKeys[1]]))) end
                        if matKeys[2] then table.insert(materialsExtracted, removeNamespace(tostring(textureData[matKeys[2]]))) end
                    end
                    if #materialsExtracted == 2 then
                        itemEntry.name = string.format("%s (%s, %s, %s)", item_displayName, blockType, materialsExtracted[1], materialsExtracted[2] )
                    else
                        itemEntry.name = string.format("%s (%s, MaterialsErr)", item_displayName, blockType)
                        logToFile("Domum 2-mat block " .. item_displayName .. " issue extracting 2 materials.", "WARN_")
                    end
                else
                    itemEntry.name = string.format("%s (%s, NBT_Err)", item_displayName, blockType) 
                    logToFile("Unhandled Domum block: " .. item_displayName .. " textureDataSize: " .. textureDataSize .. " NBT: " .. tableToString(nbtToStore or {}), "WARN_")

                end  
                table.insert(domum_list, itemEntry)
            else
                itemEntry.name = name_from_req 
                table.insert(builder_list, itemEntry)
            end
         
        elseif itemIsEquipment then
            local levelTable = {
                ["and with maximal level: Leather"] = "Leather",
                ["and with maximal level: Stone"] = "Stone",
                ["and with maximal level: Chain"] = "Chain",
                ["and with maximal level: Gold"] = "Gold",
                ["and with maximal level: Iron"] = "Iron",
                ["and with maximal level: Diamond"] = "Diamond",

                ["with maximal level: Wood or Gold"] = "Wood or Gold"
            }

            local extractedLevel = "Any Level"

            for pattern, mappedLevel in pairs(levelTable) do
                if string.find(desc, pattern) then
                    extractedLevel = mappedLevel
                    break
                end
            end

            if extractedLevel == "Any Level" then 
                if string.find(desc, "Diamond") then extractedLevel = "Diamond"
                elseif string.find(desc, "Iron") then extractedLevel = "Iron"
                elseif string.find(desc, "Chain") then extractedLevel = "Chain"
                elseif string.find(desc, "Stone") then extractedLevel = "Stone" 
                elseif string.find(desc, "Gold") then extractedLevel = "Gold"
                elseif string.find(desc, "Leather") then extractedLevel = "Leather"
                elseif string.find(desc, "Wood") then extractedLevel = "Wood"
                end
            end

            itemEntry.level = extractedLevel 
            itemEntry.name = extractedLevel .. " " .. name_from_req

            table.insert(equipment_list, itemEntry)

            else
            itemEntry.name = name_from_req 
            table.insert(others_list, itemEntry)
        end

        ::continue_categorize_loop::
    end

    return equipment_list, builder_list, domum_list, others_list
end
