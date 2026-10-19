--==================================================
-- InventoryModule
-- ModuleScript inside PlayerController > Modules
--
-- Data layer for the backpack. We keep the legacy
-- slot-index API for hotbar / save compatibility,
-- but each item now also owns a footprint inside a
-- grid so the UI can behave like a DayZ-style bag.
--==================================================

local InventoryModule = {}

local SurvivalRef = nil
function InventoryModule.SetSurvival(s) SurvivalRef = s end

-- ============================================================
-- CONFIG
-- ============================================================
local SLOT_COUNT   = 30
local HOTBAR_SIZE  = 6
local GRID_WIDTH   = 12
local GRID_HEIGHT  = 10

InventoryModule.TYPE = {
	AMMO       = "Ammo",
	HEAL       = "Heal",
	ARMOR      = "Armor",
	THROWABLE  = "Throwable",
	ATTACHMENT = "Attachment",
	MISC       = "Misc",
}

local DEFAULT_FOOTPRINTS = {
	primary    = { w = 4, h = 2 },
	secondary  = { w = 2, h = 2 },
	melee      = { w = 1, h = 3 },
	grenade    = { w = 1, h = 1 },
	helmet     = { w = 2, h = 2 },
	head       = { w = 2, h = 2 },
	carrier    = { w = 3, h = 3 },
	vest       = { w = 3, h = 3 },
	chest      = { w = 3, h = 3 },
	torso      = { w = 3, h = 3 },
	legs       = { w = 2, h = 3 },
	pants      = { w = 2, h = 3 },
	feet       = { w = 2, h = 2 },
	boots      = { w = 2, h = 2 },
	gloves     = { w = 2, h = 1 },
	eyes       = { w = 2, h = 1 },
	face       = { w = 2, h = 2 },
	scope      = { w = 1, h = 1 },
	suppressor = { w = 1, h = 2 },
	grip       = { w = 1, h = 1 },
	Ammo       = { w = 1, h = 1 },
	Heal       = { w = 1, h = 1 },
	Consumable = { w = 1, h = 1 },
	Misc       = { w = 1, h = 1 },
	["Bandage"]          = { w = 1, h = 1 },
	["Painkillers"]      = { w = 1, h = 1 },
	["Med Kit"]          = { w = 2, h = 2 },
	["Water Bottle"]     = { w = 1, h = 2 },
	["Canteen"]          = { w = 1, h = 2 },
	["Ration Pack"]      = { w = 2, h = 1 },
	["Energy Bar"]       = { w = 1, h = 1 },
	["Protein Bar"]      = { w = 1, h = 1 },
	["Canned Beans"]     = { w = 1, h = 2 },
	["Iron Sights"]      = { w = 1, h = 1 },
	["Red Dot Sight"]    = { w = 1, h = 1 },
	["ACOG"]             = { w = 2, h = 1 },
	["Sniper Scope"]     = { w = 2, h = 2 },
	["9mm Suppressor"]   = { w = 1, h = 2 },
	["5.56 Suppressor"]  = { w = 1, h = 2 },
	["7.62 Suppressor"]  = { w = 1, h = 2 },
	["Vertical Grip"]    = { w = 1, h = 1 },
	["Angled Grip"]      = { w = 1, h = 1 },
	["9mm Rounds"]       = { w = 1, h = 1 },
	["5.56 Rounds"]      = { w = 1, h = 1 },
	["7.62 Rounds"]      = { w = 1, h = 1 },
	[".50 AE Rounds"]    = { w = 1, h = 1 },
}

-- ============================================================
-- STATE
-- ============================================================
local slots = {}
local layouts = {}

for i = 1, SLOT_COUNT do
	slots[i] = nil
	layouts[i] = nil
end

-- ============================================================
-- CALLBACKS
-- ============================================================
local slotChangedListeners = {}
local layoutChangedListeners = {}
local onFull = nil

function InventoryModule.OnSlotChanged(fn)
	table.insert(slotChangedListeners, fn)
end

function InventoryModule.OnLayoutChanged(fn)
	table.insert(layoutChangedListeners, fn)
end

function InventoryModule.OnFull(fn)
	onFull = fn
end

local function shallowCopy(tbl)
	if type(tbl) ~= "table" then return tbl end
	local copy = {}
	for k, v in pairs(tbl) do
		copy[k] = v
	end
	return copy
end

local function deepCopy(tbl)
	if type(tbl) ~= "table" then return tbl end
	local copy = {}
	for k, v in pairs(tbl) do
		copy[k] = type(v) == "table" and deepCopy(v) or v
	end
	return copy
end

local function cloneItem(item)
	if not item then return nil end
	local copy = {
		id       = item.id,
		name     = item.name,
		type     = item.type,
		quantity = item.quantity,
		maxStack = item.maxStack,
		rarity   = item.rarity,
		iconId   = item.iconId or "",
		data     = deepCopy(item.data or {}),
	}
	if item.gridX then copy.gridX = item.gridX end
	if item.gridY then copy.gridY = item.gridY end
	if item.gridW then copy.gridW = item.gridW end
	if item.gridH then copy.gridH = item.gridH end
	return copy
end

local function cloneLayout(layout)
	return layout and shallowCopy(layout) or nil
end

local function fireSlotChanged(index)
	for _, fn in ipairs(slotChangedListeners) do
		fn(index, slots[index])
	end
end

local function syncItemLayoutFields(index)
	local item = slots[index]
	local layout = layouts[index]
	if not item then return end

	if layout then
		item.gridX = layout.x
		item.gridY = layout.y
		item.gridW = layout.w
		item.gridH = layout.h
	else
		item.gridX = nil
		item.gridY = nil
		item.gridW = nil
		item.gridH = nil
	end
end

local function fireLayoutChanged(index)
	syncItemLayoutFields(index)
	for _, fn in ipairs(layoutChangedListeners) do
		fn(index, cloneLayout(layouts[index]), slots[index])
	end
end

local function getItemFootprint(item)
	if not item then
		return 1, 1
	end

	if item.gridW and item.gridH then
		return math.max(1, item.gridW), math.max(1, item.gridH)
	end

	local gridSize = item.data and item.data.gridSize
	if type(gridSize) == "table" then
		local w = math.max(1, tonumber(gridSize.w or gridSize[1]) or 1)
		local h = math.max(1, tonumber(gridSize.h or gridSize[2]) or 1)
		return w, h
	end

	local fp = DEFAULT_FOOTPRINTS[item.type] or DEFAULT_FOOTPRINTS[item.name] or DEFAULT_FOOTPRINTS.Misc
	return fp.w, fp.h
end

local function makeLayout(x, y, item)
	local w, h = getItemFootprint(item)
	return {
		x = x,
		y = y,
		w = w,
		h = h,
	}
end

local function getOccupantsInRect(x, y, w, h, ignoreIndex)
	local found = {}
	for index, layout in pairs(layouts) do
		if layout and index ~= ignoreIndex then
			local overlap = not (
				x + w - 1 < layout.x
					or x > layout.x + layout.w - 1
					or y + h - 1 < layout.y
					or y > layout.y + layout.h - 1
			)
			if overlap then
				found[index] = true
			end
		end
	end
	return found
end

local function countKeys(dict)
	local count = 0
	for _ in pairs(dict) do
		count = count + 1
	end
	return count
end

local function firstKey(dict)
	for k in pairs(dict) do
		return k
	end
	return nil
end

local function isWithinGrid(x, y, w, h)
	return x >= 1
		and y >= 1
		and x + w - 1 <= GRID_WIDTH
		and y + h - 1 <= GRID_HEIGHT
end

local function canStackInto(target, incoming)
	if not target or not incoming then return false end
	if (target.maxStack or 1) <= 1 then return false end
	return target.name == incoming.name
end

local function mergeIntoSlot(index, incoming)
	local target = slots[index]
	if not canStackInto(target, incoming) then
		return 0
	end

	local free = math.max(0, (target.maxStack or 1) - (target.quantity or 0))
	if free <= 0 then
		return 0
	end

	local moved = math.min(free, incoming.quantity or 1)
	target.quantity = (target.quantity or 0) + moved
	fireSlotChanged(index)
	return moved
end

local function findFirstEmptySlot()
	for i = 1, SLOT_COUNT do
		if slots[i] == nil then
			return i
		end
	end
	return nil
end

local function findOpenSpotForItem(item, ignoreIndex)
	local w, h = getItemFootprint(item)
	for y = 1, GRID_HEIGHT - h + 1 do
		for x = 1, GRID_WIDTH - w + 1 do
			if countKeys(getOccupantsInRect(x, y, w, h, ignoreIndex)) == 0 then
				return x, y
			end
		end
	end
	return nil, nil
end

local function clearSlotInternal(index)
	slots[index] = nil
	layouts[index] = nil
	fireSlotChanged(index)
	fireLayoutChanged(index)
end

local function storeItem(index, item, x, y)
	slots[index] = cloneItem(item)
	layouts[index] = makeLayout(x, y, slots[index])
	fireSlotChanged(index)
	fireLayoutChanged(index)
end

-- ============================================================
-- PUBLIC GETTERS
-- ============================================================
function InventoryModule.GetSlot(index)
	return slots[index]
end

function InventoryModule.GetAllSlots()
	local copy = {}
	for i = 1, SLOT_COUNT do
		copy[i] = cloneItem(slots[i])
	end
	return copy
end

function InventoryModule.GetSlotCount()
	return SLOT_COUNT
end

function InventoryModule.GetHotbarSize()
	return HOTBAR_SIZE
end

function InventoryModule.IsHotbarSlot(index)
	return index <= HOTBAR_SIZE
end

function InventoryModule.IsFull()
	return findFirstEmptySlot() == nil
end

function InventoryModule.IsEmpty()
	for i = 1, SLOT_COUNT do
		if slots[i] ~= nil then
			return false
		end
	end
	return true
end

function InventoryModule.GetGridSize()
	return GRID_WIDTH, GRID_HEIGHT
end

function InventoryModule.GetGridConfig()
	return {
		width = GRID_WIDTH,
		height = GRID_HEIGHT,
	}
end

function InventoryModule.GetItemLayout(index)
	return cloneLayout(layouts[index])
end

function InventoryModule.GetAllLayouts()
	local copy = {}
	for i = 1, SLOT_COUNT do
		copy[i] = cloneLayout(layouts[i])
	end
	return copy
end

function InventoryModule.GetItemFootprint(item)
	local w, h = getItemFootprint(item)
	return w, h
end

function InventoryModule.GetItemAtCell(x, y)
	for index, layout in pairs(layouts) do
		if layout then
			if x >= layout.x and x <= layout.x + layout.w - 1
				and y >= layout.y and y <= layout.y + layout.h - 1 then
				return index, slots[index]
			end
		end
	end
	return nil, nil
end

function InventoryModule.CanPlaceItemAt(item, x, y, ignoreIndex)
	local w, h = getItemFootprint(item)
	if not isWithinGrid(x, y, w, h) then
		return false, "Out of bounds"
	end

	local blockers = getOccupantsInRect(x, y, w, h, ignoreIndex)
	if countKeys(blockers) > 0 then
		return false, "Occupied", firstKey(blockers)
	end

	return true, nil, nil
end

function InventoryModule.FindOpenSpot(item, ignoreIndex)
	return findOpenSpotForItem(item, ignoreIndex)
end

function InventoryModule.SetSlot(index, item)
	if index < 1 or index > SLOT_COUNT then return end

	if not item then
		clearSlotInternal(index)
		return
	end

	local copy = cloneItem(item)
	local targetX = tonumber(copy.gridX)
	local targetY = tonumber(copy.gridY)
	local w, h = getItemFootprint(copy)
	copy.gridW = w
	copy.gridH = h

	if not targetX or not targetY or not isWithinGrid(targetX, targetY, w, h) then
		targetX, targetY = findOpenSpotForItem(copy, index)
	end

	if not targetX or not targetY then
		warn("[Inventory] No free grid space for slot " .. tostring(index) .. " (" .. tostring(copy.name) .. ")")
		clearSlotInternal(index)
		return
	end

	if countKeys(getOccupantsInRect(targetX, targetY, w, h, index)) > 0 then
		local openX, openY = findOpenSpotForItem(copy, index)
		targetX, targetY = openX, openY
	end

	if not targetX or not targetY then
		warn("[Inventory] Grid placement collision for slot " .. tostring(index))
		clearSlotInternal(index)
		return
	end

	slots[index] = copy
	layouts[index] = { x = targetX, y = targetY, w = w, h = h }
	fireSlotChanged(index)
	fireLayoutChanged(index)
end

function InventoryModule.SlotToHotkey(index)
	return index + 2
end

function InventoryModule.HotkeyToSlot(key)
	local index = key - 2
	if index >= 1 and index <= HOTBAR_SIZE then
		return index
	end
	return nil
end

-- ============================================================
-- ADD ITEM
-- ============================================================
function InventoryModule.AddItem(item)
	item = cloneItem(item)
	if not item then return nil end

	if (item.maxStack or 1) > 1 then
		for i = 1, SLOT_COUNT do
			local moved = mergeIntoSlot(i, item)
			if moved > 0 then
				item.quantity = (item.quantity or 0) - moved
				if item.quantity <= 0 then
					return i
				end
			end
		end
	end

	local slotIndex = findFirstEmptySlot()
	if not slotIndex then
		return nil
	end

	local x, y = findOpenSpotForItem(item)
	if not x or not y then
		return nil
	end

	storeItem(slotIndex, item, x, y)

	if InventoryModule.IsFull() and onFull then
		onFull()
	end

	return slotIndex
end

function InventoryModule.AddItemAt(item, x, y)
	item = cloneItem(item)
	if not item then return nil, "No item" end

	local blockerIndex = InventoryModule.GetItemAtCell(x, y)
	if blockerIndex then
		local moved = mergeIntoSlot(blockerIndex, item)
		if moved > 0 and moved >= (item.quantity or 1) then
			return blockerIndex
		end
		return nil, "Target occupied"
	end

	local ok, reason = InventoryModule.CanPlaceItemAt(item, x, y)
	if not ok then
		return nil, reason
	end

	local slotIndex = findFirstEmptySlot()
	if not slotIndex then
		return nil, "Inventory full"
	end

	storeItem(slotIndex, item, x, y)

	if InventoryModule.IsFull() and onFull then
		onFull()
	end

	return slotIndex
end

-- ============================================================
-- REMOVE / CLEAR
-- ============================================================
function InventoryModule.RemoveQuantity(index, amount)
	if not slots[index] then return end
	slots[index].quantity = slots[index].quantity - (amount or 1)
	if slots[index].quantity <= 0 then
		clearSlotInternal(index)
		return
	end
	fireSlotChanged(index)
end

function InventoryModule.ClearSlot(index)
	if not slots[index] then return end
	clearSlotInternal(index)
end

function InventoryModule.ClearAll()
	for i = 1, SLOT_COUNT do
		if slots[i] or layouts[i] then
			slots[i] = nil
			layouts[i] = nil
			fireSlotChanged(i)
			fireLayoutChanged(i)
		end
	end
end

-- ============================================================
-- USE ITEM
-- ============================================================
function InventoryModule.UseItem(index)
	local item = slots[index]
	if not item then return end

	local consumed = true

	if SurvivalRef and item.data then
		local d = item.data
		if d.hungerRestore then
			consumed = SurvivalRef.Eat(item)
		elseif d.waterRestore then
			consumed = SurvivalRef.Drink(item)
		elseif d.healAmount then
			consumed = SurvivalRef.UseBandage(item)
		end
	end

	if consumed ~= false then
		InventoryModule.RemoveQuantity(index, 1)
	end
end

-- ============================================================
-- GRID MOVEMENT
-- ============================================================
function InventoryModule.MoveItemToGrid(index, x, y)
	local item = slots[index]
	local layout = layouts[index]
	if not item or not layout then
		return false, "No item"
	end

	local w, h = getItemFootprint(item)
	if not isWithinGrid(x, y, w, h) then
		return false, "Out of bounds"
	end

	local blockers = getOccupantsInRect(x, y, w, h, index)
	local blockerCount = countKeys(blockers)
	if blockerCount == 0 then
		layouts[index] = { x = x, y = y, w = w, h = h }
		fireLayoutChanged(index)
		return true
	end

	if blockerCount == 1 then
		local blockerIndex = firstKey(blockers)
		local other = slots[blockerIndex]
		local oldLayout = cloneLayout(layout)
		local newOtherLayout = layouts[blockerIndex]

		if canStackInto(other, item) then
			local moved = mergeIntoSlot(blockerIndex, item)
			if moved >= (item.quantity or 1) then
				clearSlotInternal(index)
				return true
			end
			return false, "Stack is full"
		end

		if oldLayout and newOtherLayout then
			local otherFits = InventoryModule.CanPlaceItemAt(other, oldLayout.x, oldLayout.y, blockerIndex)
			if otherFits then
				layouts[index] = { x = x, y = y, w = w, h = h }
				layouts[blockerIndex] = {
					x = oldLayout.x,
					y = oldLayout.y,
					w = newOtherLayout.w,
					h = newOtherLayout.h,
				}
				fireLayoutChanged(index)
				fireLayoutChanged(blockerIndex)
				return true
			end
		end
	end

	return false, "Occupied"
end

-- ============================================================
-- SWAP LEGACY SLOT ORDER
-- ============================================================
function InventoryModule.SwapSlots(a, b)
	if a == b then return end

	local slotTmp = slots[a]
	slots[a] = slots[b]
	slots[b] = slotTmp

	local layoutTmp = layouts[a]
	layouts[a] = layouts[b]
	layouts[b] = layoutTmp

	fireSlotChanged(a)
	fireSlotChanged(b)
	fireLayoutChanged(a)
	fireLayoutChanged(b)
end

-- ============================================================
-- INIT
-- ============================================================
function InventoryModule.Init()
	for i = 1, SLOT_COUNT do
		slots[i] = nil
		layouts[i] = nil
	end
	print("[Inventory] Initialized. Slots: " .. SLOT_COUNT .. " (hotbar: " .. HOTBAR_SIZE .. "), grid: " .. GRID_WIDTH .. "x" .. GRID_HEIGHT)
end

return InventoryModule
