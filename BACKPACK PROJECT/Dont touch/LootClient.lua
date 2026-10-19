--==================================================
-- LootClient
-- LocalScript ? StarterPlayerScripts
--
-- Receives pickup results from LootServer (world spawns)
-- and DeathLootServer (death bags) and routes items
-- into the player's InventoryModule.
--
-- PICKUP POLICY: all items go straight to inventory.
-- The player equips manually via the BackpackUI.
--==================================================

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService      = game:GetService("SoundService")
local Debris            = game:GetService("Debris")

local player  = Players.LocalPlayer

local PlayerScripts    = player:WaitForChild("PlayerScripts")
local PlayerController = PlayerScripts:WaitForChild("PlayerController")
local Modules          = PlayerController:WaitForChild("Modules")

local Inventory = require(Modules:WaitForChild("InventoryModule"))
local HUD       = require(Modules:WaitForChild("HUDModule"))

-- Wait for remotes folder (created by LootServer)
local remotes         = ReplicatedStorage:WaitForChild("LootRemotes")
local RE_PickupResult = remotes:WaitForChild("PickupResult")
local RE_PickupAck    = remotes:WaitForChild("PickupAck")
local RE_LootSpawned  = remotes:WaitForChild("LootSpawned")
local RE_LootRemoved  = remotes:WaitForChild("LootRemoved")
local RE_LootFeedback = remotes:WaitForChild("LootFeedback")

local function playLocalLootSound(soundId, volume)
	if type(soundId) ~= "string" or soundId == "" or soundId == "rbxassetid://0" then
		return
	end

	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = tonumber(volume) or 0.8
	sound.RollOffMaxDistance = 30
	sound.Parent = SoundService
	sound:Play()
	Debris:AddItem(sound, 4)
end

-- ============================================================
-- PICKUP RESULT
-- Fired by LootServer (world spawns) and DeathLootServer
-- (death bag looting). Signature: (success, spawnId, items)
--
-- items is a list of:
--   { name, type, quantity, maxStack, iconId, data }
-- ============================================================
RE_PickupResult.OnClientEvent:Connect(function(success, spawnId, items)
	if not success then
		HUD.ShowNotif("Already looted!", 1.2)
		return
	end

	if not items or #items == 0 then
		HUD.ShowNotif("Empty...", 1.2)
		RE_PickupAck:FireServer(spawnId, 0)
		return
	end

	local addedCount = 0
	local skipped    = 0
	local firstName  = ""

	for _, item in ipairs(items) do
		local slotIndex = Inventory.AddItem(item)

		if slotIndex then
			addedCount = addedCount + 1
			if addedCount == 1 then
				firstName = item.name
			end
			if Inventory.IsHotbarSlot(slotIndex) then
				HUD.HotbarRefreshSlot(slotIndex, Inventory.GetSlot(slotIndex))
			end
		else
			skipped = skipped + 1
			HUD.ShowNotif("Inventory full!", 1.5)
			break
		end
	end

	-- Acknowledge to server: how many items were actually accepted
	RE_PickupAck:FireServer(spawnId, addedCount)

	-- Feedback notification
	if addedCount == 1 then
		HUD.ShowNotif("+ " .. firstName, 1.2)
	elseif addedCount > 1 then
		HUD.ShowNotif("+ " .. addedCount .. " items", 1.4)
	end

	if skipped > 0 then
		print("[LootClient] " .. skipped .. " item(s) skipped — inventory full.")
	end
end)

-- ============================================================
-- WORLD LOOT SPAWNED / REMOVED
-- Reserved for minimap markers, world labels, etc.
-- ============================================================
RE_LootSpawned.OnClientEvent:Connect(function(spawnId, pos, spawnType)
	-- Future: add minimap dot or floating label
end)

RE_LootRemoved.OnClientEvent:Connect(function(spawnId)
	-- Future: remove minimap dot
end)

RE_LootFeedback.OnClientEvent:Connect(function(kind, payload)
	payload = type(payload) == "table" and payload or {}
	playLocalLootSound(payload.soundId, payload.soundVolume)

	if kind == "container_opened" then
		HUD.ShowNotif(string.upper(payload.text or ("Searched " .. tostring(payload.label or "container"))), 1.2)
	elseif kind == "container_empty" then
		HUD.ShowNotif(string.upper(payload.text or "Nothing useful."), 1.2)
	elseif kind == "item_picked" and payload.itemName and payload.showText ~= false then
		HUD.ShowNotif("+ " .. tostring(payload.itemName), 1.0)
	end
end)

print("[LootClient] Ready.")
