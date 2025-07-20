local helpers = require "helpers"
local logToFile = helpers.logToFile
local removeNamespace = helpers.removeNamespace
local safeCall = helpers.safeCall
local isEquipment = helpers.isEquipment
local bShowInGameLog = helpers.bShowInGameLog
local tableToString = helpers.tableToString
local equipmentCraft = helpers.equipmentCraft
local detectQuantityFieldOnce = helpers.detectQuantityFieldOnce
local convertNbtToSnbtString = helpers.convertNbtToSnbtString
local trimLeadingWhitespace = helpers.trimLeadingWhitespace



----------------------------------------------------------------------------
--* REQUEST HANDLING
----------------------------------------------------------------------------


function colonyCategorizeRequests(colony, storage, requests)
    local equipment_list = {}
    local builder_list = {}
    local domum_list = {}
    local others_list = {}

    if not colony then
        logToFile("Colony Integrator not available for categorizing requests.", "WARN_", true)
        return equipment_list, builder_list, domum_list, others_list  
    end
   
    for _, req in ipairs(requests) do

        if not req.items or not req.items[1] then
            logToFile("Skipping request due to missing item data: " .. tableToString(req), "DEBUG")
            goto continue_categorize_loop
        end


        local requestId = req.id  --> Unique ID XXXX-XXX..
        local name_from_req = req.name or "Unknown" --> Chestplate, 1 Oak Door, 16 Mutton Dinner
        local target = req.target or "" --> Builder's Hut, Restaurant, Knight Calum...
        local desc = req.desc or "" --> and with maximal level:.. or nil
        local count = req.count --> requested amount from that item
        local item_displayName = trimLeadingWhitespace(req.items[1].displayName or name_from_req) --> [Oak Door] [Paper]
        local item_name_raw = req.items[1].name or "" --> minecraft:oak_door
        local itemIsEquipment = isEquipment(desc) --> boolean
        local nbtToStore = req.items[1].nbt --> so far nil..
        local fingerprintToStore = req.items[1].fingerprint --> -3452345235432
        local formattedName = name_from_req --> Chestplate, 1 Oak Door, 16 Mutton Dinner
        local isDomumOrnamentumItem = string.find(item_name_raw, "domum_ornamentum:", 1, true) == 1 --> boolean
        local isProvided = false
        local providedAmount = 0
        for slot, exportedItem in pairs(storage.list()) do
            if exportedItem.name == item_name_raw then
                isProvided = true
                providedAmount = exportedItem.count
                
            end
        end
        
        local itemEntry = {
            id = requestId,
            name = formattedName, 
            target = target, 
            count = count, 
            item_displayName = item_displayName,
            item_name_raw = item_name_raw, 
            item_name = item_name_raw,     
            desc = desc, 
            provided = providedAmount, 
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
                local blockType = removeNamespace(item_name_raw, ":")
                local textureData = nbtToStore["textureData"]
                local textureDataSize = 0
                if type(textureData) == "table" then
                    for _ in pairs(textureData) do textureDataSize = textureDataSize + 1 end
                end
                if textureDataSize == 1 and nbtToStore and nbtToStore.type then
                    local singleMaterial = "UnknownMaterial"
                    if type(textureData) == "table" then 
                        for _, mat_val in pairs(textureData) do 
                            singleMaterial = removeNamespace(tostring(mat_val), ":");
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
                        if matKeys[1] then table.insert(materialsExtracted, removeNamespace(tostring(textureData[matKeys[1]])), ":") end
                        if matKeys[2] then table.insert(materialsExtracted, removeNamespace(tostring(textureData[matKeys[2]])), ":") end
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

----------------------------------------------------------------------------
--* STORAGE SYSTEM REQUEST AND SEND
----------------------------------------------------------------------------

local b_craftEquipment = true
local qtyField = nil

function storageSystemHandleRequests(bridge, storage, request_list)
     
   for _, item in ipairs(request_list) do
        local itemToRequest = item.item_name_raw 
        local nbtTableForRequest = item.nbtData   
        local fingerprintForRequest = item.fingerprint 
        local canCraftThisItemBasedOnRules = true 
        local isDomumItem = string.find(item.item_name_raw, "domum_ornamentum:", 1, true) == 1
        
        local useOriginalNbtAndFingerprint = fingerprintForRequest ~= nil
        local isProvided = false
        for slot, exportedItem in pairs(storage.list()) do
            if exportedItem.name == itemToRequest then
                isProvided = true
                
            end
        end
        if isDomumItem then
            logToFile("Processing Domum Request: " .. item.item_displayName, "DEBUG", bShowInGameLog)
            logToFile("  Original Raw ID: " .. item.item_name_raw, "DEBUG", bShowInGameLog)
        end
 
        if item.equipment and b_craftEquipment then 
            local potentialTargetItem, tierCraftableByRules
            potentialTargetItem, tierCraftableByRules = equipmentCraft(item.name, item.level, item.item_name_raw)

            if tierCraftableByRules then
                if potentialTargetItem ~= item.item_name_raw then
                    logToFile("  EquipmentCraft: Mapped '"..item.item_name_raw.."' to TARGET '" .. potentialTargetItem .. "'. Will use this for AE2.", "INFO_")
                    itemToRequest = potentialTargetItem
                    useOriginalNbtAndFingerprint = false 
                    nbtTableForRequest = nil          
                    fingerprintForRequest = nil       
                else
                    logToFile("  EquipmentCraft: Target '" .. itemToRequest .. "' is same as original. Tier rules allow. Using original NBT/FP if present.", "INFO_")
                end
                canCraftThisItemBasedOnRules = true
            else
                logToFile("  EquipmentCraft: Rules prevent crafting for: " .. item.name .. " (Level: " .. item.level .. ", Original ID: " .. item.item_name_raw .. ")", "INFO_")
                canCraftThisItemBasedOnRules = false
                useOriginalNbtAndFingerprint = false 
            end
        elseif item.equipment and not b_craftEquipment then
            canCraftThisItemBasedOnRules = false 
            logToFile("  Master equipment crafting switch b_craftEquipment is OFF. Cannot craft: ".. item.item_displayName, "INFO_")
            useOriginalNbtAndFingerprint = false 
        end
        
        local qtyField = detectQuantityFieldOnce(bridge, itemToRequest, (useOriginalNbtAndFingerprint and nbtTableForRequest) or nil, (useOriginalNbtAndFingerprint and fingerprintForRequest) or nil)
        
        if isDomumItem then logToFile("  Using Qty Field: " .. qtyField .. " for item: " .. itemToRequest, "DEBUG", bShowInGameLog) end
        
        local itemData, itemStoredSystem, itemIsCraftableSystemAE
        local getItemSpec = { name = itemToRequest } 

        if useOriginalNbtAndFingerprint and fingerprintForRequest then 
            getItemSpec.fingerprint = fingerprintForRequest
            if isDomumItem or item.equipment then logToFile("  Calling bridge.getItem with fingerprint spec: " .. tableToString(getItemSpec), "DEBUG", bShowInGameLog) end
        else
            if not useOriginalNbtAndFingerprint and nbtTableForRequest then
                 local nbtString = convertNbtToSnbtString(nbtTableForRequest)
                 if nbtString then getItemSpec.nbt = nbtString end
            elseif useOriginalNbtAndFingerprint and nbtTableForRequest and not fingerprintForRequest then
                 local nbtString = convertNbtToSnbtString(nbtTableForRequest)
                 if nbtString then getItemSpec.nbt = nbtString end
            end
            if isDomumItem or item.equipment then logToFile("  Calling bridge.getItem for '"..itemToRequest.."' with name/NBT string spec: " .. tableToString(getItemSpec), "DEBUG", bShowInGameLog) end
        end
        
        
        -- local successGetItem, resultGetItem = safeCall(bridge.getItem, getItemSpec)
        local successGetItem, resultGetItem = pcall(function()
                return bridge.getItem(getItemSpec)
            end)
        
        if successGetItem and resultGetItem then
            itemData = resultGetItem
            itemStoredSystem = itemData[qtyField] or 0
            itemIsCraftableSystemAE = itemData.isCraftable 
            if isDomumItem or item.equipment then logToFile("  bridge.getItem result for '"..itemToRequest.."' - Stored: " .. itemStoredSystem .. ", AE Craftable: " .. tostring(itemIsCraftableSystemAE), "DEBUG", bShowInGameLog) end
        else
            logToFile(item.item_displayName .. " (target ID: "..itemToRequest..", FP: "..tostring(fingerprintForRequest)..") not in system or error. getItemSpec: " .. tableToString(getItemSpec) .. " Err: " .. tostring(resultGetItem), "WARN_", true)
            item.displayColor = colors.red
            goto continue_request_loop 
        end
        
        item.isCraftable = itemIsCraftableSystemAE 
 
        if itemStoredSystem > 0 and not isProvided then
            local countToExport = item.count - item.provided
            -- item.provided = countToExport
            if countToExport > 0 then
                local exportSpec = { name = itemToRequest, count = countToExport }

                if useOriginalNbtAndFingerprint and fingerprintForRequest then
                    exportSpec.fingerprint = fingerprintForRequest
                    if isDomumItem or item.equipment then logToFile("  Calling bridge.exportItemToPeripheral with fingerprint spec: " .. tableToString(exportSpec), "DEBUG", bShowInGameLog) end
                else
                    if not useOriginalNbtAndFingerprint and nbtTableForRequest then 
                         local nbtString = convertNbtToSnbtString(nbtTableForRequest)
                         if nbtString then exportSpec.nbt = nbtString end
                    elseif useOriginalNbtAndFingerprint and nbtTableForRequest and not fingerprintForRequest then
                         local nbtString = convertNbtToSnbtString(nbtTableForRequest)
                         if nbtString then exportSpec.nbt = nbtString end
                    end
                    if isDomumItem or item.equipment then logToFile("  Calling bridge.exportItemToPeripheral for '"..itemToRequest.."' with name/NBT string spec: " .. tableToString(exportSpec), "DEBUG", bShowInGameLog) end
                end
                
                -- local successExport, exportedResult = safeCall(bridge.exportItemToPeripheral, exportSpec, storage)
                local successExport, exportedResult = pcall(function()
                    return bridge.exportItem(exportSpec, "left")
                    -- return bridge.exportItemToPeripheral(exportSpec, storage)
                end)
                if successExport and exportedResult then
                    local exportedAmountValue = 0
                    if type(exportedResult) == "number" then
                        exportedAmountValue = exportedResult
                    elseif type(exportedResult) == "table" and exportedResult[qtyField] then
                        exportedAmountValue = exportedResult[qtyField]
                    elseif type(exportedResult) == "table" and exportedResult["count"] then 
                        exportedAmountValue = exportedResult["count"]
                    elseif type(exportedResult) == "table" and exportedResult["amount"] then 
                        exportedAmountValue = exportedResult["amount"]
                    else
                        logToFile("Unexpected result type/structure from exportItemToPeripheral for " .. item.item_displayName .. " ("..itemToRequest.."): " .. type(exportedResult) .. " Value: " .. tableToString(exportedResult or {}), "WARN_", bShowInGameLog)
                    end
                    ---------
                    item.provided = item.provided + (tonumber(exportedAmountValue) or 0)
                    ---------
                    if isDomumItem or item.equipment then logToFile("  Exported: " .. exportedAmountValue .. " of "..itemToRequest..", New Provided: " .. item.provided, "DEBUG", bShowInGameLog) end
                else
                    logToFile("Failed to export " .. item.item_displayName .. " (as "..itemToRequest.."). exportSpec: " .. tableToString(exportSpec) .. " Err: " .. tostring(exportedResult), "WARN_", true)
                end
            end
        end
 
        if item.provided >= item.count then
            item.displayColor = colors.green
        else 
            local currentItemInSystem = itemStoredSystem
            if item.provided > 0 and item.provided < item.count then 
                local recheckSpec = { name = itemToRequest }
                if useOriginalNbtAndFingerprint and fingerprintForRequest then 
                    recheckSpec.fingerprint = fingerprintForRequest
                elseif useOriginalNbtAndFingerprint and nbtTableForRequest and not fingerprintForRequest then 
                    local nbtString = convertNbtToSnbtString(nbtTableForRequest)
                    if nbtString then recheckSpec.nbt = nbtString end
                end
                -- local successRecheck, recheckResultData = safeCall(bridge.getItem, recheckSpec)
                local successRecheck, recheckResultData = pcall(function()
                    return bridge.getItem(recheckSpec)
                end)
                if successRecheck and recheckResultData then
                    currentItemInSystem = recheckResultData[qtyField] or 0
                end
            end
 
            if item.provided < item.count and currentItemInSystem == 0 and not item.isCraftable then 
                 item.displayColor = colors.red 
            else 
                 item.displayColor = colors.yellow 
            end
        end
        
        if item.provided < item.count and item.isCraftable and canCraftThisItemBasedOnRules then
            local nbtStringToCraft = nil
            if itemToRequest == item.item_name_raw and nbtTableForRequest then
                 nbtStringToCraft = convertNbtToSnbtString(nbtTableForRequest)
            elseif isDomumItem and nbtTableForRequest then 
                 nbtStringToCraft = convertNbtToSnbtString(nbtTableForRequest)
            end

            local isItemCraftingSpec = { name = itemToRequest }
            if nbtStringToCraft then isItemCraftingSpec.nbt = nbtStringToCraft end

            if isDomumItem or item.equipment or nbtStringToCraft then logToFile("  Calling bridge.isItemCrafting for '"..itemToRequest.."' with spec: " .. tableToString(isItemCraftingSpec), "DEBUG", bShowInGameLog) end
            -- local successCraftingCheck, isCurrentlyCrafting = safeCall(bridge.isItemCrafting, isItemCraftingSpec)
            local successCraftingCheck, isCurrentlyCrafting = pcall(function()
                return bridge.isItemCrafting(isItemCraftingSpec)
            end)
 
            if successCraftingCheck and isCurrentlyCrafting then
                item.displayColor = colors.blue 
                if isDomumItem or item.equipment or nbtStringToCraft then logToFile("  Item '"..itemToRequest.."' is already crafting.", "DEBUG", bShowInGameLog) end
            else 
                local craftSpec = { name = itemToRequest, count = item.count - item.provided }
                if nbtStringToCraft then craftSpec.nbt = nbtStringToCraft end

                if isDomumItem or item.equipment or nbtStringToCraft then logToFile("  Calling bridge.craftItem for '"..itemToRequest.."' with spec: " .. tableToString(craftSpec), "DEBUG", bShowInGameLog) end
                local successCraft, craftInitiateResult = safeCall(bridge.craftItem, craftSpec)
                local successCraft, craftInitiateResult = pcall(function()
                    return bridge.craftItem(craftSpec)
                end)


                if successCraft and craftInitiateResult then 
                    item.displayColor = colors.blue 
                    logToFile("Crafting initiated for: " .. item.item_displayName .. " (as " .. itemToRequest .. ")", "INFO_", bShowInGameLog)
                else
                    logToFile("Crafting request failed for " .. item.item_displayName .. " (as " .. itemToRequest .. "). craftSpec: " .. tableToString(craftSpec) .. " Err: " ..tostring(craftInitiateResult), "WARN_", true)
                    if item.provided == 0 then item.displayColor = colors.red else item.displayColor = colors.yellow end
                end
            end
        elseif item.provided < item.count and not item.isCraftable then 
             item.displayColor = colors.red 
             if item.equipment then logToFile("  Cannot craft "..item.item_displayName.." (target ID: "..itemToRequest.."): AE system reports not craftable.", "INFO_", bShowInGameLog) end
        elseif item.provided < item.count and item.isCraftable and not canCraftThisItemBasedOnRules then 
             if item.equipment then logToFile("  Skipping crafting for equipment (script rules prevent crafting this tier): " .. item.item_displayName .. " (requested as " .. item.level .. ", evaluated to not craft " .. itemToRequest .. ")", "INFO_", bShowInGameLog) end
             if item.provided == 0 then item.displayColor = colors.yellow else item.displayColor = colors.yellow end
        end
        ::continue_request_loop::
    end
   
end

return {
        colonyCategorizeRequests = colonyCategorizeRequests,
        storageSystemHandleRequests = storageSystemHandleRequests
            
    }