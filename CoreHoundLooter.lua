local ADDON_NAME, ADDON_TABLE = ...

-- Configurable variables
CHL_LOOT_MESSAGES_ENABLED = true	-- Controls addon messages
CHL_MASTERLOOTER_WISPER_ENABLE = true -- Controls if master looter will wisper the looter
CHL_GROUP_CHAT_LOOTER_ANNOUNCMENT = false	-- Controls if master looter will announce the name of the looter in chat

-- Helper variables
CHL_PLAYERS_WITH_ADDON = {}
CHL_PLAYERS_WITHOUT_ADDON = {}

-- Fixed variables
SLASH_CHL1 = "/chl"
CHL_ADDON_PREFIX = "CHL"

-- FUNCTION SECTION

function isContainedIn(tab, val)
    for index, value in ipairs(tab) do
        if value == val then
            return true
        end
    end

    return false
end


function chlCallback(duration, callback)
    local newFrame = CreateFrame("Frame")
    newFrame:SetScript("OnUpdate", function (self, elapsed)
        duration = duration - elapsed
        if duration <= 0 then
            callback()
            newFrame:SetScript("OnUpdate", nil)
        end
    end)
end

function chlSplitString(inputstr, separator)
    local t = {}

    for str in string.gmatch(inputstr, "([^" .. separator .. "]+)") do
        table.insert(t, str)
    end

    return t
end

function chl_boolToString(bool)
    return bool and 'true' or 'false'
end

function chl_groupType()
    if IsInRaid() then
        return "RAID"
    else
        return "PARTY"
    end
end

-- END FUNCTION SECTION

function SlashCmdList.CHL(msg)
    if msg == "" or msg == "help" then
        CHL_PrintHelp()
    elseif msg == "pwa" then
        CHL_ShowPlayersWithoutAddon()
	elseif msg == "whispers enable" then
		CHL_MASTERLOOTER_WISPER_ENABLE = true
		print("Master looter will be whispering people to loot.")
	elseif msg == "whispers disable" then
		CHL_MASTERLOOTER_WISPER_ENABLE = false
		print("Master looter won't be whispering people to loot.")
    elseif msg == "loot show" then
        CHL_LOOT_MESSAGES_ENABLED = true
        print("CHL loot messages are <ENABLED>.")
    elseif msg == "loot hide" then
        CHL_LOOT_MESSAGES_ENABLED = false
        print("CHL loot messages are <DISABLED>.")
	elseif msg == "announcements enable" then
		CHL_GROUP_CHAT_LOOTER_ANNOUNCMENT = true
		print("Master looter will be announcing people who should loot")
	elseif msg == "announcements disable" then
		CHL_GROUP_CHAT_LOOTER_ANNOUNCMENT = false
		print("Master looter won't be announcing people who should loot")
	elseif msg == "status" then
		print("Addon shows messages when its your turn to loot: <" .. chl_boolToString(CHL_LOOT_MESSAGES_ENABLED) .. "> ")
		print("Master looter also whispers looter to loot: <" .. chl_boolToString(CHL_MASTERLOOTER_WISPER_ENABLE) .. "> ")
		print("Announcing the looter in group chat: <" .. chl_boolToString(CHL_GROUP_CHAT_LOOTER_ANNOUNCMENT) .. "> ")
    else
        print("Invalid command:" .. msg .. " not recognized.")
    end
end


function CHL_OnEvent(self, event, ...)
	
    if event == "CHAT_MSG_ADDON" then
        local prefix, text, channel, sender, target = ...

		-- Check if prefix is targeting this addon
        if prefix ~= "CHL" then return end
		
		-- If discovery of players with addon has been triggered react to it
        if text == "DISCOVER" then
			-- Sending acknowledge
            C_ChatInfo.SendAddonMessage("CHL", "ACKNOWLEDGE", "WHISPER", sender)
            return
        end
		
		-- Adds persons with addon to the "CHL_PLAYERS_WITH_ADDON" list
        if text == "ACKNOWLEDGE" then
            if not isContainedIn(CHL_PLAYERS_WITH_ADDON, sender) then
                table.insert(CHL_PLAYERS_WITH_ADDON , sender)
            end
        
            return
        end

        -- Loot event is happening
		chlCallback(1, function()
			local moobName = text
			local _, playerIsMasterLooter = GetLootMethod();
				
			-- If it is a skinning target print it out to party or raid channel
			if CHL_LOOT_MESSAGES_ENABLED == true then
				print("|c00FFAA00" .. sender .. " can loot the " .. moobName .."|r")
			end
								
			if playerIsMasterLooter == 0 then
				if CHL_MASTERLOOTER_WISPER_ENABLE == true then 
					SendChatMessage("Please loot the " .. moobName, "WHISPER", nil, sender)
				end
				-- Master looter announces whos turn it is to loot
				if CHL_GROUP_CHAT_LOOTER_ANNOUNCMENT == true then
					SendChatMessage(sender .. "'s turn to loot the " .. moobName, chl_groupType())
				end
			end

		end)
		
	-- Triggers on (unfiltered) combat log event 
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
		-- Returns the loot method
        local lootMethod, _, _ = GetLootMethod()

		-- Only work in 'master loot' mode protection
        if lootMethod == "master" then
            local timestamp, eventName, hideCaster, sourceGuid , sourceName, sourceFlags, sourceRaidFlags, destGuid, destName = CombatLogGetCurrentEventInfo()
            --destGuid format =  [Unit type]-0-[server ID]-[instance ID]-[zone UID]-[ID]-[spawn UID]
			local guidSplitResult = chlSplitString(destGuid, '-')
			local unitType = guidSplitResult[1] == "Creature"
			local zoneUID = guidSplitResult[5]  == "12230"  --[[ MoltenCore ZoneID is 12230 ]]
			-- local zoneUID = guidSplitResult[5]  == "411"  --[[ Durotar ZoneID is 411 ]] -- This is used for testing the addon on Elder Mottled Boar/Bloodtalon Scythemaw in Durotar
			local creatureID = guidSplitResult[6]
			-- local spawnID = guidSplitResult[7]
						
			-- Check if creature died and if it died in the right zone ID
            if eventName == "UNIT_DIED" and unitType and zoneUID then
                chlCallback(1, function()
                    local hasLoot, _ = CanLootUnit(destGuid)
    
					-- Check if creature can be looted
                    if hasLoot then
						-- Check if creature matched GUID
						if creatureID == "11673" --[[ Ancient Core Hound ]] or creatureID == "11671" --[[ Core Hound ]] then 
						-- if creatureID == "3100" --[[ Elder Mottled Boar ]] or creatureID == "3123" --[[ Bloodtalon Scythemaw ]] then -- This is used for testing the addon on Elder Mottled Boar/Bloodtalon Scythemaw in Durotar
							C_ChatInfo.SendAddonMessage("CHL", destName , chl_groupType())
						end
                    end
                end)
            end
        end
		
	-- Triggers on player login event register prefix
    elseif event == "PLAYER_LOGIN" then
        C_ChatInfo.RegisterAddonMessagePrefix("CHL")
    end
end

function CHL_PrintHelp()
	print("The following commands are available for C|cffff0000ore|rH|cffff0000ound|rL|cffff0000ooter|r")
	print("/chl -- Shows help")
	print("/chl pwa -- Shows people with addon enabled in your group")
	print("/chl loot show/hide -- Shows/hides loot messages to you (default - show)")
	print("/chl whispers enable/disable -- Enables/disables whispering people [affects only master looter] (default - enable)")
	print("/chl status -- Prints out current settings")
	print("/chl announcements enable/disable -- Announces looter in group chat [affects only master looter] (default - disable)")
end

function CHL_ShowPlayersWithoutAddon()
	
	-- Sending DISCOVER message in addon chat
    C_ChatInfo.SendAddonMessage("CHL", "DISCOVER", chl_groupType())
	
	-- Using delay so that we can register all the responses 
    chlCallback(1, function()      
		if not IsInRaid() then return end
		
		-- Get names of all players in group
		for i = 1, GetNumGroupMembers() do
			local name = GetRaidRosterInfo(i)
			local fullName = name .. '-' .. GetRealmName()
			
			-- Check if player has addon, if not add him to CHL_PLAYERS_WITHOUT_ADDON
			if not isContainedIn(CHL_PLAYERS_WITH_ADDON, fullName ) then
                table.insert(CHL_PLAYERS_WITHOUT_ADDON, fullName )
            end
		end
		
		-- Print out players without addon
		if not CHL_PLAYERS_WITHOUT_ADDON == nil then
			print("The following players |cffff0000don't|r have C|cffff0000ore|rH|cffff0000ound|rL|cffff0000ooter|r installed:")
			table.foreach(CHL_PLAYERS_WITHOUT_ADDON, print)
		else
			print("Everyone in group has C|cffff0000ore|rH|cffff0000ound|rL|cffff0000ooter|r installed!")
		end 
		
		-- Clean variables
		CHL_PLAYERS_WITH_ADDON = {}
		CHL_PLAYERS_WITHOUT_ADDON = {}
		
    end)
end