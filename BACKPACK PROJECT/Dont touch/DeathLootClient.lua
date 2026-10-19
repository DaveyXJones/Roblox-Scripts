--==================================================
-- DeathLootClient
-- LocalScript ? StarterPlayerScripts
--
-- Handles the client side of the death-loot system:
--
--   1. When the server calls RF_RequestDropData, this
--      script gathers everything from InventoryModule
--      and EquipmentModule and returns it to the server.
--
--   2. Listens for RE_BagSpawned / RE_BagRemoved to
--      keep a local map of active bags (reserved for
--      minimap markers or future UI hooks).
--
-- NOTE: Actual pickup result (items flowing into the
-- looting player's inventory) is handled by the
-- existing LootClient via the PickupResult remote —
-- no duplication needed here.
--
-- PLACEMENT: StarterPlayerScripts
--==================================================

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

-- -- Resolve module path --------------------------------------
-- PlayerController lives in PlayerScripts at runtime.
local PlayerScripts    = player:WaitForChild("PlayerScripts")
local PlayerController = PlayerScripts:WaitForChild("PlayerController")
local Modules          = PlayerController:WaitForChild("Modules")

local Inventory  = require(Modules:WaitForChild("InventoryModule"))
local Equipment  = require(Modules:WaitForChild("EquipmentModule"))

-- -- Remotes --------------------------------------------------
local remotes = ReplicatedStorage:WaitForChild("LootRemotes")

local RF_RequestDropData = remotes:WaitForChild("RequestDropData")
local RE_BagSpawned      = remotes:WaitForChild("BagSpawned")
local RE_BagRemoved      = remotes:WaitForChild("BagRemoved")

-- ============================================================
-- LOCAL BAG REGISTRY  (for future minimap / UI use)
-- ============================================================
local activeBags = {}  -- [bagId] = Vector3 position

RE_BagSpawned.OnClientEvent:Connect(function(bagId, position)
	activeBags[bagId] = position
	-- Future hook: add minimap marker here
end)

RE_BagRemoved.OnClientEvent:Connect(function(bagId)
	activeBags[bagId] = nil
	-- Future hook: remove minimap marker here
end)

-- ============================================================
-- BUILD DROP LIST
-- Called by the server right after the player dies.
-- Returns a flat list of item tables: one entry per slot
-- (inventory slots + all equipment slots).
-- The client owns both data layers so this is authoritative.
-- ============================================================
local function buildDropList()
	local items = {}

	-- -- Inventory slots --------------------------------------
	local allSlots = Inventory.GetAllSlots()
	for _, slot in ipairs(allSlots) do
		if slot then
			table.insert(items, {
				name     = slot.name,
				type     = slot.type     or "Misc",
				quantity = slot.quantity or 1,
				maxStack = slot.maxStack or 1,
				iconId   = slot.iconId   or "",
				data     = slot.data     or {},
			})
		end
	end

	-- -- Equipment slots (fixed + pouches) -------------------
	local fixedSlots = Equipment.SLOTS  -- {"primary","secondary","melee",...}
	for _, slotName in ipairs(fixedSlots) do
		local item = Equipment.GetSlot(slotName)
		if item then
			table.insert(items, {
				name     = item.name,
				type     = item.type     or "Misc",
				quantity = 1,
				maxStack = 1,
				iconId   = item.iconId   or "",
				data     = item.data     or {},
			})
		end
	end

	-- Pouch slots (dynamic count based on equipped carrier)
	local pouchKeys = Equipment.GetPouchSlots()
	for _, pouchKey in ipairs(pouchKeys) do
		local item = Equipment.GetSlot(pouchKey)
		if item then
			table.insert(items, {
				name     = item.name,
				type     = item.type     or "Misc",
				quantity = 1,
				maxStack = 1,
				iconId   = item.iconId   or "",
				data     = item.data     or {},
			})
		end
	end

	return items
end

-- ============================================================
-- CLEAR LOCAL STATE ON DEATH
-- After handing off the drop data, wipe the client's own
-- inventory and equipment so the respawned character starts
-- fresh. The server already has the item list at this point.
-- ============================================================
local function clearOnDeath()
	Inventory.ClearAll()

	-- Unequip fixed slots
	for _, slotName in ipairs(Equipment.SLOTS) do
		if not Equipment.IsSlotEmpty(slotName) then
			Equipment.Unequip(slotName)
		end
	end

	-- Unequip pouches
	for _, pouchKey in ipairs(Equipment.GetPouchSlots()) do
		if not Equipment.IsSlotEmpty(pouchKey) then
			Equipment.Unequip(pouchKey)
		end
	end
end

-- ============================================================
-- RF_RequestDropData HANDLER
-- Server invokes this; we return the drop list.
-- ============================================================
RF_RequestDropData.OnClientInvoke = function()
	local dropList = buildDropList()
	clearOnDeath()
	return dropList
end

print("[DeathLootClient] Ready.")