--==================================================
-- EquipmentModule
-- ModuleScript inside PlayerController > Modules
--
-- Manages all equipment slots:
--
--   WEAPONS       primary, secondary, melee, grenade
--   PROTECTION    helmet, carrier
--   CLOTHING      chest, legs, feet
--   CARRIER POUCHES  pouch_1 … pouch_N
--     (pouch count is dynamic – determined by
--      which carrier is equipped)
--
-- BackpackUI reads SLOTS and SLOT_META to build
-- the UI panels. Pouch slots are listed separately
-- via GetPouchSlots() so the UI can build them
-- dynamically based on the equipped carrier.
--
-- ARMOR DURABILITY:
--   Helmet and carrier items track durability.
--   When equipped, durability starts at maxDurability
--   (which equals armorRating from ItemRegistry).
--   Server degrades durability on hits and notifies
--   client via ArmorDurability remote.
--==================================================

local EquipmentModule = {}

-- ============================================================
-- SLOT DEFINITIONS
-- ============================================================

-- Fixed slots – always present regardless of gear
EquipmentModule.SLOTS = {
	"primary",
	"secondary",
	"melee",
	"grenade",
	"helmet",
	"carrier",
	"chest",
	"legs",
	"feet",
}

EquipmentModule.SLOT_META = {
	primary   = { label = "PRIMARY",   hint = "Main weapon"        },
	secondary = { label = "SECONDARY", hint = "Sidearm"            },
	melee     = { label = "MELEE",     hint = "Melee weapon"       },
	grenade   = { label = "GRENADE",   hint = "Throwable"          },
	helmet    = { label = "HELMET",    hint = "Head protection"     },
	carrier   = { label = "CARRIER",   hint = "Plate carrier / rig" },
	chest     = { label = "CHEST",     hint = "Upper clothing"     },
	legs      = { label = "LEGS",      hint = "Lower clothing"     },
	feet      = { label = "FEET",      hint = "Footwear"           },
}

-- Which item.type values each fixed slot accepts.
-- item.data.slot can also override this (used by gear/clothing).
EquipmentModule.SLOT_ACCEPTS = {
	primary   = { primary   = true },
	secondary = { secondary = true },
	melee     = { melee     = true },
	grenade   = { grenade   = true },
	helmet    = { helmet    = true },
	carrier   = { carrier   = true },
	chest     = { chest     = true },
	legs      = { legs      = true },
	feet      = { feet      = true },
}

-- ============================================================
-- STATE
-- ============================================================

-- Fixed equipment slots
local equipped = {}
for _, slot in ipairs(EquipmentModule.SLOTS) do
	equipped[slot] = nil
end

-- Dynamic carrier pouch slots – rebuilt when carrier changes
-- keyed "pouch_1", "pouch_2" etc.
local pouchSlots  = {}
local pouchCount  = 0

-- ============================================================
-- CALLBACKS
-- ============================================================
local slotChangedListeners = {}

function EquipmentModule.OnSlotChanged(fn)
	table.insert(slotChangedListeners, fn)
end

local function fireChanged(slotName)
	for _, fn in ipairs(slotChangedListeners) do
		fn(slotName, equipped[slotName] or pouchSlots[slotName])
	end
end

-- ============================================================
-- POUCH MANAGEMENT
-- Called internally whenever the carrier slot changes.
-- Builds or tears down pouch_N slots based on the carrier's
-- pouchSlots data value.
-- ============================================================
local function rebuildPouches()
	-- Fire changed for all old pouch slots so UI clears them
	for i = 1, pouchCount do
		local key = "pouch_" .. i
		pouchSlots[key] = nil
		fireChanged(key)
	end

	local carrier = equipped["carrier"]
	local newCount = 0
	if carrier and carrier.data and carrier.data.pouchSlots then
		newCount = carrier.data.pouchSlots
	end

	pouchCount = newCount
	for i = 1, pouchCount do
		local key = "pouch_" .. i
		pouchSlots[key] = nil   -- empty to start
	end

	-- Notify UI that pouch layout changed
	fireChanged("carrier")  -- carrier listener can refresh pouch panel
end

-- ============================================================
-- POUCH PUBLIC API
-- ============================================================

-- Returns a list of active pouch slot keys e.g. {"pouch_1","pouch_2"}
function EquipmentModule.GetPouchSlots()
	local keys = {}
	for i = 1, pouchCount do
		table.insert(keys, "pouch_" .. i)
	end
	return keys
end

function EquipmentModule.GetPouchCount()
	return pouchCount
end

-- ============================================================
-- TYPE VALIDATION
-- ============================================================

function EquipmentModule.GetValidSlot(item)
	if not item then return nil end

	-- Hard override from item.data.slot
	local forced = item.data and item.data.slot
	if forced and EquipmentModule.SLOT_ACCEPTS[forced] then
		return forced
	end

	-- Match by item.type
	for _, slotName in ipairs(EquipmentModule.SLOTS) do
		local accepts = EquipmentModule.SLOT_ACCEPTS[slotName]
		if accepts and accepts[item.type] then
			return slotName
		end
	end

	return nil
end

function EquipmentModule.CanEquipInto(slotName, item)
	if not item then return false end

	-- Pouch slots accept anything (small items, grenades, consumables)
	if slotName:sub(1, 6) == "pouch_" then
		local idx = tonumber(slotName:sub(7))
		return idx and idx >= 1 and idx <= pouchCount
	end

	local accepts = EquipmentModule.SLOT_ACCEPTS[slotName]
	if not accepts then return false end

	-- Honour data.slot override
	if item.data and item.data.slot then
		return item.data.slot == slotName
	end

	return accepts[item.type] == true
end

-- ============================================================
-- PUBLIC API – GET
-- ============================================================

function EquipmentModule.GetSlot(slotName)
	if slotName:sub(1, 6) == "pouch_" then
		return pouchSlots[slotName]
	end
	return equipped[slotName]
end

function EquipmentModule.IsSlotEmpty(slotName)
	return EquipmentModule.GetSlot(slotName) == nil
end

-- ============================================================
-- PUBLIC API – EQUIP / UNEQUIP / SWAP
-- ============================================================

local function makeStoredItem(item)
	local stored = {
		id     = item.id     or "",
		name   = item.name,
		type   = item.type   or "",
		iconId = item.iconId or "",
		data   = item.data   or {},
	}

	-- Initialize durability for armor pieces (helmet/carrier)
	-- If the item already has durability (e.g. from save/load), keep it.
	-- Otherwise set to maxDurability (which equals armorRating).
	if stored.data.armorRating and stored.data.armorRating > 0 then
		if not stored.data.maxDurability then
			stored.data.maxDurability = stored.data.armorRating
		end
		if not stored.data.durability then
			stored.data.durability = stored.data.maxDurability
		end
	end

	return stored
end

function EquipmentModule.Equip(slotName, item)
	if EquipmentModule.GetSlot(slotName) ~= nil then
		return false   -- occupied; caller should Swap or Unequip first
	end
	if not EquipmentModule.CanEquipInto(slotName, item) then
		return false
	end

	local stored = makeStoredItem(item)

	if slotName:sub(1, 6) == "pouch_" then
		pouchSlots[slotName] = stored
	else
		equipped[slotName] = stored
		if slotName == "carrier" then rebuildPouches() end
	end

	fireChanged(slotName)
	return true
end

function EquipmentModule.Unequip(slotName)
	local item
	if slotName:sub(1, 6) == "pouch_" then
		item = pouchSlots[slotName]
		pouchSlots[slotName] = nil
	else
		item = equipped[slotName]
		equipped[slotName] = nil
		if slotName == "carrier" then rebuildPouches() end
	end
	if item then fireChanged(slotName) end
	return item
end

-- Swap: equip new item, return old one.  No type check – caller validates.
function EquipmentModule.Swap(slotName, item)
	local previous
	local stored = item and makeStoredItem(item) or nil

	if slotName:sub(1, 6) == "pouch_" then
		previous = pouchSlots[slotName]
		pouchSlots[slotName] = stored
	else
		previous = equipped[slotName]
		equipped[slotName] = stored
		if slotName == "carrier" then rebuildPouches() end
	end

	fireChanged(slotName)
	return previous
end

-- Force-set without type checks (used by save/load)
function EquipmentModule.ForceEquip(slotName, item)
	local stored = item and makeStoredItem(item) or nil

	if slotName:sub(1, 6) == "pouch_" then
		-- Ensure we have enough pouch slots; extend silently
		local idx = tonumber(slotName:sub(7))
		if idx and idx > pouchCount then pouchCount = idx end
		pouchSlots[slotName] = stored
	else
		equipped[slotName] = stored
		if slotName == "carrier" then rebuildPouches() end
	end

	fireChanged(slotName)
end

-- ============================================================
-- STAT HELPERS
-- Convenience functions other modules use frequently.
-- ============================================================

-- Total armour rating from helmet + carrier combined
-- Only counts pieces that still have durability remaining
function EquipmentModule.GetTotalArmor()
	local total = 0
	local helmet  = equipped["helmet"]
	local carrier = equipped["carrier"]
	if helmet  and helmet.data  and helmet.data.armorRating then
		if (helmet.data.durability or 0) > 0 then
			total = total + helmet.data.armorRating
		end
	end
	if carrier and carrier.data and carrier.data.armorRating then
		if (carrier.data.durability or 0) > 0 then
			total = total + carrier.data.armorRating
		end
	end
	return total
end

-- Returns full armor data table for server sync
-- Includes rating, durability, and maxDurability per piece
function EquipmentModule.GetArmorData()
	local data = {}
	local helmet  = equipped["helmet"]
	local carrier = equipped["carrier"]

	if helmet and helmet.data and helmet.data.armorRating and helmet.data.armorRating > 0 then
		data.helmet = {
			rating        = helmet.data.armorRating,
			durability    = helmet.data.durability or helmet.data.armorRating,
			maxDurability = helmet.data.maxDurability or helmet.data.armorRating,
		}
	end

	if carrier and carrier.data and carrier.data.armorRating and carrier.data.armorRating > 0 then
		data.carrier = {
			rating        = carrier.data.armorRating,
			durability    = carrier.data.durability or carrier.data.armorRating,
			maxDurability = carrier.data.maxDurability or carrier.data.armorRating,
		}
	end

	return data
end

-- Returns total remaining durability as a percentage (0-1)
-- Used by HUD to display the armor bar
function EquipmentModule.GetArmorDurabilityPercent()
	local totalDur = 0
	local totalMax = 0
	local helmet  = equipped["helmet"]
	local carrier = equipped["carrier"]

	if helmet and helmet.data and (helmet.data.maxDurability or 0) > 0 then
		totalDur = totalDur + (helmet.data.durability or 0)
		totalMax = totalMax + helmet.data.maxDurability
	end
	if carrier and carrier.data and (carrier.data.maxDurability or 0) > 0 then
		totalDur = totalDur + (carrier.data.durability or 0)
		totalMax = totalMax + carrier.data.maxDurability
	end

	if totalMax <= 0 then return 0 end
	return totalDur / totalMax
end

-- Apply durability update from server (after taking damage)
function EquipmentModule.ApplyDurabilityUpdate(durabilityData)
	if not durabilityData then return end

	if durabilityData.helmet then
		local helmet = equipped["helmet"]
		if helmet and helmet.data then
			if durabilityData.helmet.destroyed then
				-- Armor piece is destroyed, unequip it
				equipped["helmet"] = nil
				fireChanged("helmet")
				print("[Equipment] Helmet destroyed!")
			else
				helmet.data.durability = durabilityData.helmet.durability
			end
		end
	end

	if durabilityData.carrier then
		local carrier = equipped["carrier"]
		if carrier and carrier.data then
			if durabilityData.carrier.destroyed then
				-- Armor piece is destroyed, unequip it and clear pouches
				equipped["carrier"] = nil
				rebuildPouches()
				print("[Equipment] Carrier destroyed!")
			else
				carrier.data.durability = durabilityData.carrier.durability
			end
		end
	end
end

-- Combined speed multiplier from clothing
function EquipmentModule.GetSpeedMultiplier()
	local multi = 1.0
	for _, slot in ipairs({ "chest", "legs", "feet" }) do
		local item = equipped[slot]
		if item and item.data and item.data.speedMulti then
			multi = multi * item.data.speedMulti
		end
	end
	return multi
end

-- Combined stealth bonus from clothing
function EquipmentModule.GetStealthBonus()
	local total = 0
	for _, slot in ipairs({ "helmet", "chest", "legs", "feet" }) do
		local item = equipped[slot]
		if item and item.data and item.data.stealthBonus then
			total = total + item.data.stealthBonus
		end
	end
	return total
end


-- ============================================================
-- INIT
-- ============================================================
function EquipmentModule.Init()
	for _, slot in ipairs(EquipmentModule.SLOTS) do
		equipped[slot] = nil
	end
	pouchSlots        = {}
	pouchCount        = 0
	slotChangedListeners = {}
	print("[Equipment] Initialized.")
end
-----DEV FUNCTION VIEWMODEL
function EquipmentModule.DevSetSlot(slotName, item)
	equipped[slotName] = item
	fireChanged(slotName)
	print("[Equipment] DEV: Set " .. slotName .. " = " .. (item and item.name or "nil"))
end
return EquipmentModule