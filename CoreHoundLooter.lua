local ADDON_NAME, ADDON_TABLE = ...

-- Configurable variables
CHL_LOOT_MESSAGES_ENABLED = true	-- Controls addon messages
CHL_MASTERLOOTER_WISPER_ENABLE = true -- Controls if master looter will wisper the looter
CHL_GROUP_CHAT_LOOTER_ANNOUNCMENT = false	-- Controls if master looter will announce the name of the looter in chat

-- Helper variables
CHL_SKINNING_TARGETS = { "Core Hound", "Ancient Core Hound" }
CHL_PLAYERS_WITH_ADDON = {}
CHL_PLAYERS_WITHOUT_ADDON = {}
CHL_MOOBLOOTLIST = {}

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

function chlSplitString(inputstr, sep)
    if sep == nil then
        sep = "%s"
    end

    local t = {}

    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
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
        CHL_ShowPlayersWithAddon()
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

        if CHL_MOOBLOOTLIST[text] ~= nil then
            CHL_MOOBLOOTLIST[text] = CHL_MOOBLOOTLIST[text] + 1
        else
            CHL_MOOBLOOTLIST[text] = 1

            chlCallback(1, function()
                local tableSplitResult = chlSplitString(text, ':')
                local moobName = tableSplitResult[1]
                local _, playerIsMasterLooter = GetLootMethod();

                if CHL_MOOBLOOTLIST[text] == 1 then
					-- Check if it is a skinning target
                    if isContainedIn(CHL_SKINNING_TARGETS, moobName) then
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
                    end
                end
            end)
        end
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
		-- Returns the loot method
        local lootMethod, _, _ = GetLootMethod()

	
        if lootMethod == "master" then
            local time, eventName, _, _, _, _, _, destGuid, destName = CombatLogGetCurrentEventInfo()
            local creatureDied = string.sub(destGuid, 1, 8) == "Creature"

            if eventName == "UNIT_DIED" and creatureDied then

                chlCallback(1, function()
                    local hasLoot, _ = CanLootUnit(destGuid)
    
                    if hasLoot then
                        C_ChatInfo.SendAddonMessage("CHL", destName .. ":" .. destGuid, chl_groupType())
                    end
                end)
            end
        end
		
	-- On player login event register prefix
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

function CHL_ShowPlayersWithAddon()
	-- Sending DISCOVER message in addon chat
    C_ChatInfo.SendAddonMessage("CHL", "DISCOVER", chl_groupType())

    chlCallback(1, function()
		-- Print out players with addon
        print("The following players have C|cffff0000ore|rH|cffff0000ound|rL|cffff0000ooter|r installed and enabled:")
        table.foreach(CHL_PLAYERS_WITH_ADDON, print)
        
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
		print("The following players |cffff0000don't|r have C|cffff0000ore|rH|cffff0000ound|rL|cffff0000ooter|r installed:")
		table.foreach(CHL_PLAYERS_WITHOUT_ADDON, print)
		
		-- Clean variables
		CHL_PLAYERS_WITH_ADDON = {}
		CHL_PLAYERS_WITHOUT_ADDON = {}
		
    end)
end