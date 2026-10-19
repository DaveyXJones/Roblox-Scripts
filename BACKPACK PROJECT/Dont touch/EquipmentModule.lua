--==================================================
-- EquipmentModule
-- ModuleScript inside PlayerController > Modules
--
-- Owns all worn / equipped item slots. The new UI
-- uses modern clothing slot names, but we keep legacy
-- aliases so existing items and systems still work.
--==================================================

local EquipmentModule = {}

local SLOT_ALIASES = {
	helmet  = "head",
	carrier = "vest",
	chest   = "torso",
	legs    = "pants",
	feet    = "boots",
}

local LEGACY_NAMES = {
	head  = "helmet",
	vest  = "carrier",
	torso = "chest",
	pants = "legs",
	boots = "feet",
}

local function normalizeSlotName(slotName)
	return SLOT_ALIASES[slotName] or slotName
end

local function getLegacyName(slotName)
	return LEGACY_NAMES[slotName]
end

EquipmentModule.SLOTS = {
	"primary",
	"secondary",
	"melee",
	"grenade",
	"utility",
	"hands",
	"head",
	"eyes",
	"face",
	"torso",
	"vest",
	"gloves",
	"pants",
	"boots",
}

EquipmentModule.SLOT_META = {
	primary   = { label = "PRIMARY", hint = "Main weapon" },
	secondary = { label = "SECONDARY", hint = "Sidearm" },
	melee     = { label = "MELEE", hint = "Melee weapon" },
	grenade   = { label = "GRENADE", hint = "Throwable holster" },
	utility   = { label = "UTILITY", hint = "Quick-use carry slot" },
	hands     = { label = "HANDS", hint = "Item in hands" },
	head      = { label = "HEAD", hint = "Helmet / headwear" },
	eyes      = { label = "EYES", hint = "Eyewear" },
	face      = { label = "FACE", hint = "Mask / face cover" },
	torso     = { label = "TORSO", hint = "Shirt / jacket" },
	vest      = { label = "VEST", hint = "Plate carrier / chest rig" },
	gloves    = { label = "GLOVES", hint = "Handwear" },
	pants     = { label = "PANTS", hint = "Lower clothing" },
	boots     = { label = "BOOTS", hint = "Footwear" },
}

EquipmentModule.SLOT_ACCEPTS = {
	primary   = { primary = true },
	secondary = { secondary = true },
	melee     = { melee = true },
	grenade   = { grenade = true },
	utility   = { Heal = true, Consumable = true, Misc = true },
	hands     = { any = true },
	head      = { head = true, helmet = true },
	eyes      = { eyes = true, eyewear = true },
	face      = { face = true, mask = true },
	torso     = { torso = true, chest = true },
	vest      = { vest = true, carrier = true },
	gloves    = { gloves = true },
	pants     = { pants = true, legs = true },
	boots     = { boots = true, feet = true },
}

local equipped = {}
for _, slot in ipairs(EquipmentModule.SLOTS) do
	equipped[slot] = nil
end

local pouchSlots = {}
local pouchCount = 0

local slotChangedListeners = {}

function EquipmentModule.OnSlotChanged(fn)
	table.insert(slotChangedListeners, fn)
end

local function fireChanged(slotName)
	local normalized = normalizeSlotName(slotName)
	local item = equipped[normalized] or pouchSlots[normalized]

	for _, fn in ipairs(slotChangedListeners) do
		fn(normalized, item)
	end

	local legacy = getLegacyName(normalized)
	if legacy then
		for _, fn in ipairs(slotChangedListeners) do
			fn(legacy, item)
		end
	end
end

local function getVestItem()
	return equipped["vest"]
end

local function rebuildPouches()
	for i = 1, pouchCount do
		local key = "pouch_" .. i
		pouchSlots[key] = nil
		fireChanged(key)
	end

	local vest = getVestItem()
	local newCount = 0
	if vest and vest.data and vest.data.pouchSlots then
		newCount = vest.data.pouchSlots
	end

	pouchCount = newCount
	for i = 1, pouchCount do
		pouchSlots["pouch_" .. i] = nil
	end

	fireChanged("vest")
end

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

function EquipmentModule.GetValidSlot(item)
	if not item then return nil end

	local forced = item.data and item.data.slot
	if forced then
		local normalized = normalizeSlotName(forced)
		if EquipmentModule.SLOT_ACCEPTS[normalized] then
			return normalized
		end
	end

	local fallbackHands = nil
	for _, slotName in ipairs(EquipmentModule.SLOTS) do
		local accepts = EquipmentModule.SLOT_ACCEPTS[slotName]
		if accepts.any then
			fallbackHands = slotName
		elseif accepts[item.type] then
			return slotName
		end
	end

	return fallbackHands
end

function EquipmentModule.CanEquipInto(slotName, item)
	if not item then return false end

	slotName = normalizeSlotName(slotName)
	if slotName:sub(1, 6) == "pouch_" then
		local idx = tonumber(slotName:sub(7))
		return idx and idx >= 1 and idx <= pouchCount
	end

	local accepts = EquipmentModule.SLOT_ACCEPTS[slotName]
	if not accepts then return false end

	local forced = item.data and item.data.slot
	if forced then
		return normalizeSlotName(forced) == slotName
	end

	if accepts.any then
		return true
	end

	return accepts[item.type] == true
end

function EquipmentModule.GetSlot(slotName)
	slotName = normalizeSlotName(slotName)
	if slotName:sub(1, 6) == "pouch_" then
		return pouchSlots[slotName]
	end
	return equipped[slotName]
end

function EquipmentModule.IsSlotEmpty(slotName)
	return EquipmentModule.GetSlot(slotName) == nil
end

function EquipmentModule.IsArmorSlot(slotName)
	slotName = normalizeSlotName(slotName)
	return slotName == "head" or slotName == "vest"
end

local function deepCopy(tbl)
	if type(tbl) ~= "table" then return tbl end
	local copy = {}
	for k, v in pairs(tbl) do
		copy[k] = type(v) == "table" and deepCopy(v) or v
	end
	return copy
end

local function makeStoredItem(item)
	local stored = {
		id     = item.id or "",
		name   = item.name,
		type   = item.type or "",
		quantity = item.quantity or 1,
		maxStack = item.maxStack or 1,
		iconId = item.iconId or "",
		data   = deepCopy(item.data or {}),
	}

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
	slotName = normalizeSlotName(slotName)
	if EquipmentModule.GetSlot(slotName) ~= nil then
		return false
	end
	if not EquipmentModule.CanEquipInto(slotName, item) then
		return false
	end

	local stored = makeStoredItem(item)

	if slotName:sub(1, 6) == "pouch_" then
		pouchSlots[slotName] = stored
	else
		equipped[slotName] = stored
		if slotName == "vest" then
			rebuildPouches()
		end
	end

	fireChanged(slotName)
	return true
end

function EquipmentModule.Unequip(slotName)
	slotName = normalizeSlotName(slotName)

	local item
	if slotName:sub(1, 6) == "pouch_" then
		item = pouchSlots[slotName]
		pouchSlots[slotName] = nil
	else
		item = equipped[slotName]
		equipped[slotName] = nil
		if slotName == "vest" then
			rebuildPouches()
		end
	end

	if item then
		fireChanged(slotName)
	end

	return item
end

function EquipmentModule.Swap(slotName, item)
	slotName = normalizeSlotName(slotName)
	local stored = item and makeStoredItem(item) or nil
	local previous

	if slotName:sub(1, 6) == "pouch_" then
		previous = pouchSlots[slotName]
		pouchSlots[slotName] = stored
	else
		previous = equipped[slotName]
		equipped[slotName] = stored
		if slotName == "vest" then
			rebuildPouches()
		end
	end

	fireChanged(slotName)
	return previous
end

function EquipmentModule.MoveSlot(sourceSlot, targetSlot)
	sourceSlot = normalizeSlotName(sourceSlot)
	targetSlot = normalizeSlotName(targetSlot)
	if sourceSlot == targetSlot then
		return true
	end

	local sourceItem = EquipmentModule.GetSlot(sourceSlot)
	if not sourceItem then
		return false
	end
	if not EquipmentModule.CanEquipInto(targetSlot, sourceItem) then
		return false
	end

	local targetItem = EquipmentModule.GetSlot(targetSlot)
	if targetItem and not EquipmentModule.CanEquipInto(sourceSlot, targetItem) then
		return false
	end

	local movedSource = EquipmentModule.Unequip(sourceSlot)
	if not movedSource then
		return false
	end

	local movedTarget = nil
	if targetItem then
		movedTarget = EquipmentModule.Unequip(targetSlot)
	end

	if not EquipmentModule.Equip(targetSlot, movedSource) then
		if movedTarget then
			EquipmentModule.Equip(targetSlot, movedTarget)
		end
		EquipmentModule.Equip(sourceSlot, movedSource)
		return false
	end

	if movedTarget and not EquipmentModule.Equip(sourceSlot, movedTarget) then
		local rollback = EquipmentModule.Unequip(targetSlot)
		if rollback then
			EquipmentModule.Equip(sourceSlot, rollback)
		end
		EquipmentModule.Equip(targetSlot, movedTarget)
		return false
	end

	return true
end

function EquipmentModule.ForceEquip(slotName, item)
	slotName = normalizeSlotName(slotName)
	local stored = item and makeStoredItem(item) or nil

	if slotName:sub(1, 6) == "pouch_" then
		local idx = tonumber(slotName:sub(7))
		if idx and idx > pouchCount then
			pouchCount = idx
		end
		pouchSlots[slotName] = stored
	else
		equipped[slotName] = stored
		if slotName == "vest" then
			rebuildPouches()
		end
	end

	fireChanged(slotName)
end

function EquipmentModule.GetTotalArmor()
	local total = 0
	local head = equipped["head"]
	local vest = equipped["vest"]

	if head and head.data and head.data.armorRating and (head.data.durability or 0) > 0 then
		total = total + head.data.armorRating
	end

	if vest and vest.data and vest.data.armorRating and (vest.data.durability or 0) > 0 then
		total = total + vest.data.armorRating
	end

	return total
end

function EquipmentModule.GetArmorData()
	local data = {}
	local head = equipped["head"]
	local vest = equipped["vest"]

	if head and head.data and head.data.armorRating and head.data.armorRating > 0 then
		data.helmet = {
			rating        = head.data.armorRating,
			durability    = head.data.durability or head.data.armorRating,
			maxDurability = head.data.maxDurability or head.data.armorRating,
		}
	end

	if vest and vest.data and vest.data.armorRating and vest.data.armorRating > 0 then
		data.carrier = {
			rating        = vest.data.armorRating,
			durability    = vest.data.durability or vest.data.armorRating,
			maxDurability = vest.data.maxDurability or vest.data.armorRating,
		}
	end

	return data
end

function EquipmentModule.GetArmorDurabilityPercent()
	local totalDur = 0
	local totalMax = 0
	local head = equipped["head"]
	local vest = equipped["vest"]

	if head and head.data and (head.data.maxDurability or 0) > 0 then
		totalDur = totalDur + (head.data.durability or 0)
		totalMax = totalMax + head.data.maxDurability
	end

	if vest and vest.data and (vest.data.maxDurability or 0) > 0 then
		totalDur = totalDur + (vest.data.durability or 0)
		totalMax = totalMax + vest.data.maxDurability
	end

	if totalMax <= 0 then
		return 0
	end

	return totalDur / totalMax
end

function EquipmentModule.ApplyDurabilityUpdate(durabilityData)
	if not durabilityData then return end

	if durabilityData.helmet then
		local head = equipped["head"]
		if head and head.data then
			if durabilityData.helmet.destroyed then
				equipped["head"] = nil
				fireChanged("head")
				print("[Equipment] Helmet destroyed!")
			else
				head.data.durability = durabilityData.helmet.durability
			end
		end
	end

	if durabilityData.carrier then
		local vest = equipped["vest"]
		if vest and vest.data then
			if durabilityData.carrier.destroyed then
				equipped["vest"] = nil
				rebuildPouches()
				print("[Equipment] Carrier destroyed!")
			else
				vest.data.durability = durabilityData.carrier.durability
			end
		end
	end
end

function EquipmentModule.GetSpeedMultiplier()
	local multi = 1.0
	for _, slot in ipairs({ "torso", "pants", "boots" }) do
		local item = equipped[slot]
		if item and item.data and item.data.speedMulti then
			multi = multi * item.data.speedMulti
		end
	end
	return multi
end

function EquipmentModule.GetStealthBonus()
	local total = 0
	for _, slot in ipairs({ "head", "torso", "pants", "boots", "gloves" }) do
		local item = equipped[slot]
		if item and item.data and item.data.stealthBonus then
			total = total + item.data.stealthBonus
		end
	end
	return total
end

function EquipmentModule.Init()
	for _, slot in ipairs(EquipmentModule.SLOTS) do
		equipped[slot] = nil
	end
	pouchSlots = {}
	pouchCount = 0
	print("[Equipment] Initialized.")
end

function EquipmentModule.DevSetSlot(slotName, item)
	slotName = normalizeSlotName(slotName)
	equipped[slotName] = item
	fireChanged(slotName)
	print("[Equipment] DEV: Set " .. slotName .. " = " .. (item and item.name or "nil"))
end

return EquipmentModule
