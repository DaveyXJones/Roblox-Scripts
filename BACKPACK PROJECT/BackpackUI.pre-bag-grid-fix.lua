--==================================================
-- BackpackUI
-- ModuleScript inside PlayerController > Modules
--
-- Stage 4 rewrite: attachment system UI added.
--
-- Equipment panel layout:
--   WEAPONS     primary, secondary, melee, grenade
--   PROTECTION  helmet, carrier
--   CLOTHING    chest, legs, feet
--   POUCHES     pouch_1 ... pouch_N  (dynamic)
--
-- NEW: Attachment interaction flow:
--   1. Select a scope/grip/suppressor in inventory
--      ? ATTACH button appears in detail panel
--      ? compatible weapon slots glow orange
--      ? tap a weapon slot to fit the attachment
--   2. Tap an equipped weapon (no inv selection)
--      ? detail panel shows fitted attachments
--      ? DETACH buttons return attachments to inventory
--   3. Weapon slots show small coloured dots indicating
--      which attachment slots are filled.
--==================================================

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UIS          = game:GetService("UserInputService")
local GuiService   = game:GetService("GuiService")

local BackpackUI = {}

local player    = Players.LocalPlayer
local Inventory = nil
local Equipment = nil
local Attachment = nil
local HUD       = nil

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RE_DropItem = ReplicatedStorage:WaitForChild("LootRemotes"):WaitForChild("DropItem", 10)

-- Platform detection (evaluated at call-time)
local function isMobile()
	return UIS.TouchEnabled and not UIS.KeyboardEnabled
end
local function isPC()
	return UIS.MouseEnabled and UIS.KeyboardEnabled
end
local function isController()
	return UIS.GamepadEnabled and not UIS.MouseEnabled
end

-- ============================================================
-- SOUNDS
-- ============================================================
local SOUND_OPEN    = "rbxassetid://3479742892"
local SOUND_CLOSE   = "rbxassetid://9121004292"
local SOUND_EQUIP   = "rbxassetid://96436142441881"
local SOUND_UNEQUIP = "rbxassetid://96436142441881"
local SOUND_ATTACH  = ""
local SOUND_DETACH  = ""

local function playSound(id)
	if id == "" or id == nil then return end
	local s = Instance.new("Sound")
	s.SoundId            = id
	s.Volume             = 0.6
	s.RollOffMaxDistance = 0
	s.Parent             = workspace
	s:Play()
	game:GetService("Debris"):AddItem(s, 4)
end

-- ============================================================
-- PALETTE
-- ============================================================
local C = {
	BG_MAIN      = Color3.fromRGB(14,  17,  20),
	BG_PANEL     = Color3.fromRGB(22,  27,  32),
	BG_SLOT      = Color3.fromRGB(30,  36,  44),
	BG_SLOT_LT   = Color3.fromRGB(38,  46,  56),
	BG_SEL       = Color3.fromRGB(48,  58,  70),
	BORDER       = Color3.fromRGB(52,  64,  76),
	BORDER_LT    = Color3.fromRGB(70,  84,  100),
	TEXT_HEAD    = Color3.fromRGB(215, 225, 235),
	TEXT_BODY    = Color3.fromRGB(155, 168, 180),
	TEXT_DIM     = Color3.fromRGB(90,  102, 114),
	ACCENT       = Color3.fromRGB(72,  152, 210),
	HOTKEY       = Color3.fromRGB(195, 175, 95),
	EQUIP_BG     = Color3.fromRGB(22,  28,  36),
	EQUIP_BD     = Color3.fromRGB(60,  76,  92),
	MOVE_PEND    = Color3.fromRGB(210, 140, 40),
	EQUIP_READY  = Color3.fromRGB(60,  180, 90),
	EQUIP_FULL   = Color3.fromRGB(72,  152, 210),
	-- Group accent colours
	COL_WEAPON   = Color3.fromRGB(200, 80,  80),
	COL_PROTECT  = Color3.fromRGB(80,  140, 200),
	COL_CLOTHING = Color3.fromRGB(80,  180, 120),
	COL_POUCH    = Color3.fromRGB(180, 140, 60),
	-- Attachment colours
	COL_ATTACH      = Color3.fromRGB(220, 160, 40),
	COL_ATTACH_READY = Color3.fromRGB(220, 160, 40),
	COL_SCOPE    = Color3.fromRGB(100, 180, 255),
	COL_SUPP     = Color3.fromRGB(180, 180, 180),
	COL_GRIP     = Color3.fromRGB(140, 200, 100),
}

-- ============================================================
-- WINDOW DIMENSIONS
-- ============================================================
local WIN_W    = 480
local WIN_H    = 720
local DETAIL_H = 120   -- taller to fit attachment info

local GRID_COLS = 5
local CELL_SIZE = 54
local CELL_PAD  = 5

-- Equipment slot cell dimensions
local EQ_W     = 80
local EQ_H     = 64
local EQ_PAD   = 6

-- ============================================================
-- SCREEN GUI
-- ============================================================
local screenGui = Instance.new("ScreenGui", player.PlayerGui)
screenGui.Name           = "BackpackUI"
screenGui.ResetOnSpawn   = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local overlay = Instance.new("Frame", screenGui)
overlay.Size                   = UDim2.new(1, 0, 1, 0)
overlay.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
overlay.BackgroundTransparency = 1
overlay.ZIndex                 = 10
overlay.Visible                = false

local window = Instance.new("Frame", screenGui)
window.Name                  = "Window"
window.Size                  = UDim2.new(0, WIN_W, 0, WIN_H)
window.AnchorPoint           = Vector2.new(0.5, 0.5)
window.Position              = UDim2.new(0.5, 0, 1.5, 0)
window.BackgroundColor3      = C.BG_MAIN
window.BorderSizePixel       = 0
window.ZIndex                = 11
window.Visible               = false
Instance.new("UICorner", window).CornerRadius = UDim.new(0, 12)
local winStroke = Instance.new("UIStroke", window)
winStroke.Color     = C.BORDER
winStroke.Thickness = 1.5

-- ============================================================
-- TITLE BAR
-- ============================================================
local titleBar = Instance.new("Frame", window)
titleBar.Size             = UDim2.new(1, 0, 0, 38)
titleBar.BackgroundColor3 = C.BG_PANEL
titleBar.BorderSizePixel  = 0
titleBar.ZIndex           = 12
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 12)
local tbCover = Instance.new("Frame", titleBar)
tbCover.Size             = UDim2.new(1, 0, 0.5, 0)
tbCover.Position         = UDim2.new(0, 0, 0.5, 0)
tbCover.BackgroundColor3 = C.BG_PANEL
tbCover.BorderSizePixel  = 0
tbCover.ZIndex           = 12

local titleLabel = Instance.new("TextLabel", titleBar)
titleLabel.Size                   = UDim2.new(1, -16, 1, 0)
titleLabel.Position               = UDim2.new(0, 14, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.TextColor3             = C.TEXT_HEAD
titleLabel.Font                   = Enum.Font.GothamBold
titleLabel.TextSize               = 14
titleLabel.TextXAlignment         = Enum.TextXAlignment.Left
titleLabel.Text                   = "BACKPACK"
titleLabel.ZIndex                 = 13

local closeHint = Instance.new("TextLabel", titleBar)
closeHint.Size                   = UDim2.new(0, 130, 1, 0)
closeHint.Position               = UDim2.new(1, -138, 0, 0)
closeHint.BackgroundTransparency = 1
closeHint.TextColor3             = C.TEXT_DIM
closeHint.Font                   = Enum.Font.Gotham
closeHint.TextSize               = 10
closeHint.TextXAlignment         = Enum.TextXAlignment.Right
closeHint.Text                   = "TAB / ESC to close"
closeHint.ZIndex                 = 13

-- ============================================================
-- SECTION DIVIDER HELPER
-- ============================================================
local function sectionDivider(parent, yPos, labelText, accentColor)
	local line = Instance.new("Frame", parent)
	line.Size             = UDim2.new(1, -24, 0, 1)
	line.Position         = UDim2.new(0, 12, 0, yPos)
	line.BackgroundColor3 = accentColor or C.BORDER
	line.BorderSizePixel  = 0
	line.ZIndex           = 12

	local lbl = Instance.new("TextLabel", parent)
	lbl.Size                   = UDim2.new(1, -24, 0, 18)
	lbl.Position               = UDim2.new(0, 14, 0, yPos + 4)
	lbl.BackgroundTransparency = 1
	lbl.TextColor3             = accentColor or C.TEXT_DIM
	lbl.Font                   = Enum.Font.GothamBold
	lbl.TextSize               = 9
	lbl.TextXAlignment         = Enum.TextXAlignment.Left
	lbl.Text                   = labelText
	lbl.ZIndex                 = 12

	return yPos + 24
end

-- ============================================================
-- SCROLLING CONTAINER
-- ============================================================
local scrollFrame = Instance.new("ScrollingFrame", window)
scrollFrame.Name                = "ScrollContent"
scrollFrame.Size                = UDim2.new(1, 0, 1, -38)
scrollFrame.Position            = UDim2.new(0, 0, 0, 38)
scrollFrame.BackgroundTransparency = 1
scrollFrame.BorderSizePixel     = 0
scrollFrame.ScrollBarThickness  = 4
scrollFrame.ScrollBarImageColor3 = C.BORDER_LT
scrollFrame.CanvasSize          = UDim2.new(0, 0, 0, 0)
scrollFrame.ZIndex              = 11

-- ============================================================
-- EQUIPMENT SLOT BUILDER
-- Now also builds attachment indicator dots for weapon slots.
-- ============================================================
local equipSlotFrames  = {}
local clearSelection

local ATTACH_DOT_COLORS = {
	scope      = C.COL_SCOPE,
	suppressor = C.COL_SUPP,
	grip       = C.COL_GRIP,
}

local function buildEquipSlot(parent, slotName, xPos, yPos, w, h, accentCol)
	local meta = (Equipment and Equipment.SLOT_META and Equipment.SLOT_META[slotName])
		or { label = slotName:upper(), hint = "" }

	local frame = Instance.new("Frame", parent)
	frame.Name             = "Equip_" .. slotName
	frame.Size             = UDim2.new(0, w, 0, h)
	frame.Position         = UDim2.new(0, xPos, 0, yPos)
	frame.BackgroundColor3 = C.EQUIP_BG
	frame.BorderSizePixel  = 0
	frame.ZIndex           = 12
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 7)
	local stroke = Instance.new("UIStroke", frame)
	stroke.Color     = C.EQUIP_BD
	stroke.Thickness = 1.5

	-- Item icon (hidden until equipped)
	local itemIcon = Instance.new("ImageLabel", frame)
	itemIcon.Name                   = "ItemIcon"
	itemIcon.Size                   = UDim2.new(1, -16, 1, -22)
	itemIcon.Position               = UDim2.new(0, 8, 0, 4)
	itemIcon.BackgroundTransparency = 1
	itemIcon.Image                  = ""
	itemIcon.ScaleType              = Enum.ScaleType.Fit
	itemIcon.ZIndex                 = 14
	itemIcon.Visible                = false

	-- Slot type label (top)
	local typeLabel = Instance.new("TextLabel", frame)
	typeLabel.Size                   = UDim2.new(1, -4, 0, 11)
	typeLabel.Position               = UDim2.new(0, 2, 0, 2)
	typeLabel.BackgroundTransparency = 1
	typeLabel.TextColor3             = accentCol or C.TEXT_DIM
	typeLabel.Font                   = Enum.Font.GothamBold
	typeLabel.TextSize               = 7
	typeLabel.TextXAlignment         = Enum.TextXAlignment.Center
	typeLabel.Text                   = meta.label
	typeLabel.ZIndex                 = 13

	-- Item name label (bottom)
	local nameLabel = Instance.new("TextLabel", frame)
	nameLabel.Name                   = "EquipName_" .. slotName
	nameLabel.Size                   = UDim2.new(1, -4, 0, 11)
	nameLabel.Position               = UDim2.new(0, 2, 1, -13)
	nameLabel.BackgroundTransparency = 1
	nameLabel.TextColor3             = C.TEXT_BODY
	nameLabel.Font                   = Enum.Font.Gotham
	nameLabel.TextSize               = 7
	nameLabel.TextXAlignment         = Enum.TextXAlignment.Center
	nameLabel.TextTruncate           = Enum.TextTruncate.AtEnd
	nameLabel.Text                   = ""
	nameLabel.ZIndex                 = 13

	-- Attachment indicator dots (weapon slots only)
	-- Three small dots at bottom-right: scope, suppressor, grip
	local attachDots = {}
	local isWeaponSlot = (slotName == "primary" or slotName == "secondary")
	if isWeaponSlot then
		local dotTypes = { "scope", "suppressor", "grip" }
		for di, dtype in ipairs(dotTypes) do
			local dot = Instance.new("Frame", frame)
			dot.Name             = "AttachDot_" .. dtype
			dot.Size             = UDim2.new(0, 6, 0, 6)
			dot.Position         = UDim2.new(1, -8 - (di - 1) * 9, 0, 3)
			dot.BackgroundColor3 = ATTACH_DOT_COLORS[dtype]
			dot.BackgroundTransparency = 0.7  -- dim when empty
			dot.BorderSizePixel  = 0
			dot.ZIndex           = 15
			dot.Visible          = true
			Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
			attachDots[dtype] = dot
		end
	end

	-- Invisible click button
	local btn = Instance.new("TextButton", frame)
	btn.Size                   = UDim2.new(1, 0, 1, 0)
	btn.BackgroundTransparency = 1
	btn.Text                   = ""
	btn.ZIndex                 = 16
	btn.Selectable             = true

	equipSlotFrames[slotName] = {
		frame      = frame,
		itemIcon   = itemIcon,
		stroke     = stroke,
		nameLabel  = nameLabel,
		btn        = btn,
		accentCol  = accentCol or C.EQUIP_BD,
		attachDots = attachDots,
	}

	return equipSlotFrames[slotName]
end

-- ============================================================
-- BUILD EQUIPMENT PANEL
-- ============================================================
local INNER_PAD  = 12
local ROW_H      = EQ_H + EQ_PAD + 24 + 8

local curY = 8

-- WEAPONS row
curY = sectionDivider(scrollFrame, curY, "WEAPONS", C.COL_WEAPON)
local weaponRowY = curY
local weaponSlots = { "primary", "secondary", "melee", "grenade" }
local weaponW     = { primary = 110, secondary = 80, melee = 80, grenade = 80 }

local wx = INNER_PAD
for _, sName in ipairs(weaponSlots) do
	local w = weaponW[sName] or EQ_W
	buildEquipSlot(scrollFrame, sName, wx, weaponRowY, w, EQ_H, C.COL_WEAPON)
	wx = wx + w + EQ_PAD
end
curY = weaponRowY + EQ_H + 16

-- PROTECTION row
curY = sectionDivider(scrollFrame, curY, "PROTECTION", C.COL_PROTECT)
local protectRowY  = curY
local protectSlots = { "helmet", "carrier" }
local protectW     = { helmet = 80, carrier = 140 }

local px2 = INNER_PAD
for _, sName in ipairs(protectSlots) do
	local w = protectW[sName] or EQ_W
	buildEquipSlot(scrollFrame, sName, px2, protectRowY, w, EQ_H, C.COL_PROTECT)
	px2 = px2 + w + EQ_PAD
end
curY = protectRowY + EQ_H + 16

-- CLOTHING row
curY = sectionDivider(scrollFrame, curY, "CLOTHING", C.COL_CLOTHING)
local clothRowY  = curY
local clothSlots = { "chest", "legs", "feet" }

local cx2 = INNER_PAD
for _, sName in ipairs(clothSlots) do
	buildEquipSlot(scrollFrame, sName, cx2, clothRowY, EQ_W, EQ_H, C.COL_CLOTHING)
	cx2 = cx2 + EQ_W + EQ_PAD
end
curY = clothRowY + EQ_H + 16

-- POUCHES section
local pouchHeaderY = curY
curY = sectionDivider(scrollFrame, curY, "CARRIER POUCHES", C.COL_POUCH)
local pouchRowY    = curY
local pouchRowFrames = {}

local function rebuildPouchUI()
	for _, sf in ipairs(pouchRowFrames) do
		if sf.frame then sf.frame:Destroy() end
	end
	pouchRowFrames = {}

	local count = Equipment and Equipment.GetPouchCount() or 0
	local pouchKeys = Equipment and Equipment.GetPouchSlots() or {}

	local px3 = INNER_PAD
	for i, slotName in ipairs(pouchKeys) do
		local sf = buildEquipSlot(scrollFrame, slotName, px3, pouchRowY, EQ_W, EQ_H, C.COL_POUCH)
		table.insert(pouchRowFrames, sf)

		local name = slotName
		sf.btn.MouseButton1Click:Connect(function()
			handleEquipSlotClick(name)
		end)

		px3 = px3 + EQ_W + EQ_PAD
	end

	local pouchBottom = count > 0 and (pouchRowY + EQ_H + 16) or pouchRowY
	return pouchBottom
end

local pouchBottom = rebuildPouchUI()
curY = pouchBottom

-- INVENTORY GRID
curY = sectionDivider(scrollFrame, curY, "INVENTORY  (30 SLOTS)", C.BORDER)
local gridStartY  = curY
local gridTotalW  = GRID_COLS * CELL_SIZE + (GRID_COLS - 1) * CELL_PAD
local gridStartX  = math.floor((WIN_W - gridTotalW) / 2)

-- ============================================================
-- DETAIL PANEL  (expanded for attachment support)
-- ============================================================
local detailPanel = Instance.new("Frame", window)
detailPanel.Name             = "DetailPanel"
detailPanel.Size             = UDim2.new(1, -24, 0, DETAIL_H)
detailPanel.Position         = UDim2.new(0, 12, 1, 4)
detailPanel.BackgroundColor3 = C.BG_PANEL
detailPanel.BorderSizePixel  = 0
detailPanel.ZIndex           = 15
Instance.new("UICorner", detailPanel).CornerRadius = UDim.new(0, 8)
local dpStroke = Instance.new("UIStroke", detailPanel)
dpStroke.Color     = C.BORDER
dpStroke.Thickness = 1.2

local dpName = Instance.new("TextLabel", detailPanel)
dpName.Size                   = UDim2.new(1, -12, 0, 18)
dpName.Position               = UDim2.new(0, 8, 0, 6)
dpName.BackgroundTransparency = 1
dpName.TextColor3             = C.TEXT_HEAD
dpName.Font                   = Enum.Font.GothamBold
dpName.TextSize               = 13
dpName.TextXAlignment         = Enum.TextXAlignment.Left
dpName.Text                   = ""
dpName.ZIndex                 = 16

local dpSub = Instance.new("TextLabel", detailPanel)
dpSub.Size                   = UDim2.new(1, -12, 0, 13)
dpSub.Position               = UDim2.new(0, 8, 0, 26)
dpSub.BackgroundTransparency = 1
dpSub.TextColor3             = C.TEXT_DIM
dpSub.Font                   = Enum.Font.Gotham
dpSub.TextSize               = 10
dpSub.TextXAlignment         = Enum.TextXAlignment.Left
dpSub.Text                   = ""
dpSub.ZIndex                 = 16

local dpHint = Instance.new("TextLabel", detailPanel)
dpHint.Size                   = UDim2.new(1, 0, 0, 30)
dpHint.Position               = UDim2.new(0, 0, 0, 6)
dpHint.BackgroundTransparency = 1
dpHint.TextColor3             = C.TEXT_DIM
dpHint.Font                   = Enum.Font.Gotham
dpHint.TextSize               = 10
dpHint.TextXAlignment         = Enum.TextXAlignment.Center
dpHint.Text                   = "Select a slot"
dpHint.ZIndex                 = 16

-- Action buttons row (bottom of detail panel)
local function makeActionButton(label, xOffset, color)
	local btn = Instance.new("TextButton", detailPanel)
	btn.Size                   = UDim2.new(0, 72, 0, 28)
	btn.Position               = UDim2.new(0, xOffset, 1, -36)
	btn.BackgroundColor3       = color
	btn.BorderSizePixel        = 0
	btn.TextColor3             = Color3.fromRGB(255, 255, 255)
	btn.Font                   = Enum.Font.GothamBold
	btn.TextSize               = 11
	btn.Text                   = label
	btn.ZIndex                 = 16
	btn.Visible                = false
	btn.Selectable             = true
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)
	return btn
end

local btnUse    = makeActionButton("USE",    8,   Color3.fromRGB(50,  140, 80))
local btnEquip  = makeActionButton("EQUIP",  84,  Color3.fromRGB(40,  130, 170))
local btnAttach = makeActionButton("ATTACH", 84,  C.COL_ATTACH)  -- shares position with EQUIP (only one visible at a time)
local btnMove   = makeActionButton("MOVE",   160, Color3.fromRGB(60,  110, 180))
local btnDrop   = makeActionButton("DROP",   236, Color3.fromRGB(160, 50,  50))

-- ============================================================
-- ATTACHMENT SUB-PANEL
-- Shown inside the detail panel when an equipped weapon is
-- tapped (no inventory selection). Displays fitted attachments
-- with DETACH buttons.
-- ============================================================
local attachSubFrame = Instance.new("Frame", detailPanel)
attachSubFrame.Name              = "AttachSub"
attachSubFrame.Size              = UDim2.new(1, -16, 0, 32)
attachSubFrame.Position          = UDim2.new(0, 8, 0, 44)
attachSubFrame.BackgroundTransparency = 1
attachSubFrame.BorderSizePixel   = 0
attachSubFrame.ZIndex            = 16
attachSubFrame.Visible           = false

-- We build 3 detach slots: scope, suppressor, grip
local detachButtons = {}
local ATTACH_SLOT_W = 140
local ATTACH_SLOT_H = 28

local function buildDetachSlot(attachType, xPos, label, dotColor)
	local container = Instance.new("Frame", attachSubFrame)
	container.Size             = UDim2.new(0, ATTACH_SLOT_W, 0, ATTACH_SLOT_H)
	container.Position         = UDim2.new(0, xPos, 0, 0)
	container.BackgroundColor3 = C.BG_SLOT
	container.BorderSizePixel  = 0
	container.ZIndex           = 17
	Instance.new("UICorner", container).CornerRadius = UDim.new(0, 5)

	-- Colour dot
	local dot = Instance.new("Frame", container)
	dot.Size             = UDim2.new(0, 6, 0, 6)
	dot.Position         = UDim2.new(0, 4, 0.5, -3)
	dot.BackgroundColor3 = dotColor
	dot.BorderSizePixel  = 0
	dot.ZIndex           = 18
	Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

	-- Name label
	local nameL = Instance.new("TextLabel", container)
	nameL.Size                   = UDim2.new(1, -52, 1, 0)
	nameL.Position               = UDim2.new(0, 14, 0, 0)
	nameL.BackgroundTransparency = 1
	nameL.TextColor3             = C.TEXT_BODY
	nameL.Font                   = Enum.Font.Gotham
	nameL.TextSize               = 9
	nameL.TextXAlignment         = Enum.TextXAlignment.Left
	nameL.TextTruncate           = Enum.TextTruncate.AtEnd
	nameL.Text                   = label
	nameL.ZIndex                 = 18

	-- Detach button
	local detBtn = Instance.new("TextButton", container)
	detBtn.Size                   = UDim2.new(0, 36, 0, 20)
	detBtn.Position               = UDim2.new(1, -40, 0.5, -10)
	detBtn.BackgroundColor3       = Color3.fromRGB(140, 50, 50)
	detBtn.BorderSizePixel        = 0
	detBtn.TextColor3             = Color3.fromRGB(255, 255, 255)
	detBtn.Font                   = Enum.Font.GothamBold
	detBtn.TextSize               = 8
	detBtn.Text                   = "  X  "
	detBtn.ZIndex                 = 18
	detBtn.Selectable             = true
	Instance.new("UICorner", detBtn).CornerRadius = UDim.new(0, 4)

	detachButtons[attachType] = {
		container = container,
		nameLabel = nameL,
		detBtn    = detBtn,
	}

	return detachButtons[attachType]
end

buildDetachSlot("scope",      0,                   "No Scope",      C.COL_SCOPE)
buildDetachSlot("suppressor", ATTACH_SLOT_W + 4,   "No Suppressor", C.COL_SUPP)
buildDetachSlot("grip",       (ATTACH_SLOT_W + 4) * 2, "No Grip",  C.COL_GRIP)

local detailVisible = false
local detailOpen    = UDim2.new(0, 12, 1, -(DETAIL_H + 8))
local detailClosed  = UDim2.new(0, 12, 1, 4)
local detailTween   = TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

local function showDetailPanel(show)
	if show == detailVisible then return end
	detailVisible = show
	TweenService:Create(detailPanel, detailTween,
		{ Position = show and detailOpen or detailClosed }):Play()
end

-- ============================================================
-- ATTACHMENT TARGETING HIGHLIGHTS
-- When an attachment item is selected in inventory, glow
-- weapon slots that support that attachment type.
-- ============================================================
local attachTargetMode   = false
local attachTargetType   = nil   -- "scope", "suppressor", or "grip"
local selectedWeaponSlot = nil   -- for viewing weapon attachments

local function setAttachTargetHighlights(attachType)
	local weaponSlotNames = { "primary", "secondary" }
	for _, slotName in ipairs(weaponSlotNames) do
		local sf = equipSlotFrames[slotName]
		if not sf then continue end
		if attachType and Equipment then
			local weapon = Equipment.GetSlot(slotName)
			if weapon and Attachment and Attachment.CanAttach(weapon, { data = { attachType = attachType } }) then
				sf.stroke.Color     = C.COL_ATTACH_READY
				sf.stroke.Thickness = 2.5
			else
				local occupied = not Equipment.IsSlotEmpty(slotName)
				sf.stroke.Color     = occupied and C.ACCENT or sf.accentCol
				sf.stroke.Thickness = 1.5
			end
		else
			local occupied = Equipment and not Equipment.IsSlotEmpty(slotName)
			sf.stroke.Color     = occupied and C.ACCENT or sf.accentCol
			sf.stroke.Thickness = 1.5
		end
	end
end

-- ============================================================
-- EQUIP-TARGETING HIGHLIGHT (existing system for gear/weapons)
-- ============================================================
local equipTargetMode = false

local ALL_FIXED_SLOTS = {
	"primary","secondary","melee","grenade",
	"helmet","carrier","chest","legs","feet"
}

local function setEquipTargetHighlights(item)
	for _, slotName in ipairs(ALL_FIXED_SLOTS) do
		local sf = equipSlotFrames[slotName]
		if not sf then continue end
		if item and Equipment and Equipment.CanEquipInto(slotName, item) then
			local occupied = not Equipment.IsSlotEmpty(slotName)
			sf.stroke.Color     = occupied and C.EQUIP_FULL or C.EQUIP_READY
			sf.stroke.Thickness = 2.5
		else
			local occupied = Equipment and not Equipment.IsSlotEmpty(slotName)
			sf.stroke.Color     = occupied and C.ACCENT or sf.accentCol
			sf.stroke.Thickness = 1.5
		end
	end
	if Equipment then
		for _, slotName in ipairs(Equipment.GetPouchSlots()) do
			local sf = equipSlotFrames[slotName]
			if not sf then continue end
			if item and Equipment.CanEquipInto(slotName, item) then
				local occupied = not Equipment.IsSlotEmpty(slotName)
				sf.stroke.Color     = occupied and C.EQUIP_FULL or C.EQUIP_READY
				sf.stroke.Thickness = 2.5
			else
				local occupied = not Equipment.IsSlotEmpty(slotName)
				sf.stroke.Color     = occupied and C.ACCENT or sf.accentCol
				sf.stroke.Thickness = 1.5
			end
		end
	end
end

-- ============================================================
-- REFRESH ATTACHMENT DOTS on weapon slots
-- ============================================================
local function refreshAttachDots(slotName)
	local sf = equipSlotFrames[slotName]
	if not sf or not sf.attachDots then return end
	if not Equipment or not Attachment then return end

	local weapon = Equipment.GetSlot(slotName)
	for dtype, dot in pairs(sf.attachDots) do
		if weapon then
			local fitted = Attachment.GetAttachment(weapon, dtype)
			if fitted then
				dot.BackgroundTransparency = 0    -- bright = fitted
			elseif weapon.data and weapon.data.attachmentSlots and weapon.data.attachmentSlots[dtype] then
				dot.BackgroundTransparency = 0.7  -- dim = available but empty
			else
				dot.BackgroundTransparency = 1    -- hidden = not supported
			end
		else
			dot.BackgroundTransparency = 1  -- no weapon
		end
	end
end

-- ============================================================
-- SHOW WEAPON ATTACHMENTS in detail panel
-- Called when tapping an equipped weapon with no inv selection.
-- ============================================================
local function showWeaponAttachments(slotName)
	local weapon = Equipment and Equipment.GetSlot(slotName) or nil
	if not weapon then return end

	selectedWeaponSlot = slotName
	dpHint.Visible     = false
	dpName.Text        = weapon.name:upper() .. "  —  ATTACHMENTS"
	dpSub.Text         = "Tap  X  to detach"

	-- Hide normal action buttons
	btnUse.Visible    = false
	btnEquip.Visible  = false
	btnAttach.Visible = false
	btnMove.Visible   = false
	btnDrop.Visible   = false

	-- Show attachment sub-panel
	attachSubFrame.Visible = true

	-- Update each slot
	for _, dtype in ipairs({"scope", "suppressor", "grip"}) do
		local db = detachButtons[dtype]
		if not db then continue end
		local fitted = Attachment and Attachment.GetAttachment(weapon, dtype)
		local supported = weapon.data and weapon.data.attachmentSlots and weapon.data.attachmentSlots[dtype]

		if fitted then
			db.nameLabel.Text         = fitted.name
			db.nameLabel.TextColor3   = C.TEXT_HEAD
			db.detBtn.Visible         = true
			db.container.BackgroundColor3 = C.BG_SLOT_LT
		elseif supported then
			db.nameLabel.Text         = "Empty"
			db.nameLabel.TextColor3   = C.TEXT_DIM
			db.detBtn.Visible         = false
			db.container.BackgroundColor3 = C.BG_SLOT
		else
			db.nameLabel.Text         = "N/A"
			db.nameLabel.TextColor3   = C.TEXT_DIM
			db.detBtn.Visible         = false
			db.container.BackgroundColor3 = C.BG_SLOT
		end
	end

	showDetailPanel(true)
end

-- ============================================================
-- SELECTION + MOVE STATE
-- ============================================================
local lootSlotFrames   = {}
local selectedLootSlot = nil
local moveMode         = false

local function makeInventoryItem(item, itemTypeOverride)
	if not item then return nil end
	return {
		id       = item.id     or "",
		name     = item.name,
		type     = itemTypeOverride or item.type or "",
		quantity = 1,
		maxStack = 1,
		iconId   = item.iconId or "",
		data     = item.data   or {},
	}
end

local function refreshHotbarSlot(index)
	if HUD and index and Inventory and Inventory.IsHotbarSlot(index) then
		HUD.HotbarRefreshSlot(index, Inventory.GetSlot(index))
	end
end

local function isAttachmentItem(item)
	if not item or not item.data then return false end
	local aType = item.data.attachType
	return aType == "scope" or aType == "suppressor" or aType == "grip"
end

local function updateDetailContent(index)
	local item = Inventory and Inventory.GetSlot(index) or nil

	-- Always hide attachment sub-panel when showing inventory item
	attachSubFrame.Visible = false
	selectedWeaponSlot     = nil

	if item then
		dpHint.Visible  = false
		btnUse.Visible  = true
		btnMove.Visible = true
		btnDrop.Visible = true
		dpName.Text     = item.name:upper()
		dpSub.Text      = (item.type or "")
			.. "   x" .. tostring(item.quantity)
			.. (item.maxStack > 1 and ("  /  " .. item.maxStack) or "")

		-- Is this an attachment item?
		if isAttachmentItem(item) then
			btnEquip.Visible   = false
			btnAttach.Visible  = true
			attachTargetMode   = true
			attachTargetType   = item.data.attachType
			equipTargetMode    = false
			setEquipTargetHighlights(nil)
			setAttachTargetHighlights(attachTargetType)
			dpSub.Text = item.data.attachType:upper() .. "  —  tap a weapon slot to attach"
		elseif Equipment then
			local validSlot = Equipment.GetValidSlot(item)
			btnEquip.Visible  = validSlot ~= nil
			btnAttach.Visible = false
			equipTargetMode   = validSlot ~= nil
			attachTargetMode  = false
			attachTargetType  = nil
			setAttachTargetHighlights(nil)
			setEquipTargetHighlights(validSlot and item or nil)
		else
			btnEquip.Visible  = false
			btnAttach.Visible = false
			attachTargetMode  = false
			attachTargetType  = nil
		end
	else
		dpHint.Visible    = true
		btnUse.Visible    = false
		btnEquip.Visible  = false
		btnAttach.Visible = false
		btnMove.Visible   = false
		btnDrop.Visible   = false
		dpName.Text       = ""
		dpSub.Text        = ""
		equipTargetMode   = false
		attachTargetMode  = false
		attachTargetType  = nil
		setEquipTargetHighlights(nil)
		setAttachTargetHighlights(nil)
	end
end

clearSelection = function()
	if selectedLootSlot and lootSlotFrames[selectedLootSlot] then
		local prev = lootSlotFrames[selectedLootSlot]
		prev.frame.BackgroundColor3 = prev.hasItem and C.BG_SLOT_LT or C.BG_SLOT
		prev.stroke.Color           = C.BORDER
		prev.stroke.Thickness       = 1
	end
	selectedLootSlot   = nil
	selectedWeaponSlot = nil
	moveMode           = false
	equipTargetMode    = false
	attachTargetMode   = false
	attachTargetType   = nil
	dpName.Text        = ""
	dpSub.Text         = ""
	dpHint.Visible     = true
	btnUse.Visible     = false
	btnEquip.Visible   = false
	btnAttach.Visible  = false
	btnMove.Visible    = false
	btnMove.Text       = "MOVE"
	btnDrop.Visible    = false
	attachSubFrame.Visible = false
	setEquipTargetHighlights(nil)
	setAttachTargetHighlights(nil)
	showDetailPanel(false)
end

-- ============================================================
-- EQUIP SLOT CLICK HANDLER (reworked for attachments)
-- ============================================================
handleEquipSlotClick = function(slotName)
	if not Equipment or not Inventory then return end

	-- -- CASE 1: Attachment mode — fit attachment onto weapon --
	if attachTargetMode and selectedLootSlot and attachTargetType then
		local invItem = Inventory.GetSlot(selectedLootSlot)
		if not invItem then clearSelection(); return end

		local weapon = Equipment.GetSlot(slotName)
		if not weapon then return end

		if not Attachment then return end
		if not Attachment.CanAttach(weapon, invItem) then return end

		-- Detach existing attachment of same type if present
		local existing = Attachment.Detach(weapon, attachTargetType)

		-- Fit the new attachment
		local ok, reason = Attachment.Attach(weapon, invItem)
		if ok then
			Inventory.ClearSlot(selectedLootSlot)
			local returnedSlot = nil
			if existing then
				returnedSlot = Inventory.AddItem(
					makeInventoryItem(existing, existing.data and existing.data.attachType or "Misc"),
					selectedLootSlot
				)
			end
			refreshHotbarSlot(selectedLootSlot)
			if returnedSlot and returnedSlot ~= selectedLootSlot then
				refreshHotbarSlot(returnedSlot)
			end
			refreshAttachDots(slotName)
			playSound(SOUND_ATTACH)
		else
			if existing then
				Attachment.Attach(weapon, {
					id   = existing.id,
					name = existing.name,
					data = existing.data,
				})
			end
			if HUD then HUD.ShowNotif(reason or "Can't attach", 1.5) end
		end

		clearSelection()
		return
	end

	-- -- CASE 2: Inventory item selected — equip gear/weapon --
	if selectedLootSlot then
		local invItem = Inventory.GetSlot(selectedLootSlot)
		if not invItem then clearSelection(); return end

		if not Equipment.CanEquipInto(slotName, invItem) then return end

		Inventory.ClearSlot(selectedLootSlot)
		local displaced = Equipment.Swap(slotName, invItem)

		local returnedSlot = nil
		if displaced then
			returnedSlot = Inventory.AddItem(makeInventoryItem(displaced), selectedLootSlot)
		end

		refreshHotbarSlot(selectedLootSlot)
		if returnedSlot and returnedSlot ~= selectedLootSlot then
			refreshHotbarSlot(returnedSlot)
		end

		if slotName == "carrier" then
			pouchBottom = rebuildPouchUI()
			updateScrollCanvas()
		end

		playSound(SOUND_EQUIP)
		clearSelection()
		return
	end

	-- -- CASE 3: No selection — tap equipped weapon to see attachments --
	local isWeaponSlot = (slotName == "primary" or slotName == "secondary")
	if isWeaponSlot and Equipment.GetSlot(slotName) then
		showWeaponAttachments(slotName)
		return
	end

	-- -- CASE 4: No selection — unequip to inventory --
	local equipped = Equipment.GetSlot(slotName)
	if not equipped then return end

	local returnedSlot = Inventory.AddItem({
		id       = equipped.id     or "",
		name     = equipped.name,
		type     = equipped.type   or "",
		quantity = 1,
		maxStack = 1,
		iconId   = equipped.iconId or "",
		data     = equipped.data   or {},
	})

	if returnedSlot then
		Equipment.Unequip(slotName)
		if HUD and Inventory.IsHotbarSlot(returnedSlot) then
			HUD.HotbarRefreshSlot(returnedSlot, Inventory.GetSlot(returnedSlot))
		end
		if slotName == "carrier" then
			pouchBottom = rebuildPouchUI()
			updateScrollCanvas()
		end
		playSound(SOUND_UNEQUIP)
	else
		if HUD then HUD.ShowNotif("Inventory full!", 1.5) end
	end
end

-- ============================================================
-- REFRESH HELPERS
-- ============================================================
local refreshEquipSlot

local function refreshLootSlot(index, item)
	local s = lootSlotFrames[index]
	if not s then return end
	s.hasItem = item ~= nil

	if item then
		s.icon.Image  = item.iconId or ""
		s.nameL.Text  = item.name
		s.qty.Text    = "x" .. tostring(item.quantity)
		if selectedLootSlot ~= index then
			s.frame.BackgroundColor3 = C.BG_SLOT_LT
			s.stroke.Color           = C.BORDER
			s.stroke.Thickness       = 1
		end
	else
		s.icon.Image  = ""
		s.nameL.Text  = ""
		s.qty.Text    = ""
		if selectedLootSlot ~= index then
			s.frame.BackgroundColor3 = C.BG_SLOT
			s.stroke.Color           = C.BORDER
			s.stroke.Thickness       = 1
		end
	end

	if selectedLootSlot == index then
		updateDetailContent(index)
	end
end

refreshEquipSlot = function(slotName, item)
	local s = equipSlotFrames[slotName]
	if not s then return end
	if item then
		s.itemIcon.Image   = item.iconId or ""
		s.itemIcon.Visible = true
		s.nameLabel.Text   = item.name
		s.stroke.Color     = C.ACCENT
		s.stroke.Thickness = 1.5
	else
		s.itemIcon.Visible = false
		s.nameLabel.Text   = ""
		s.stroke.Color     = s.accentCol or C.EQUIP_BD
		s.stroke.Thickness = 1.5
	end
	-- Refresh attachment dots
	refreshAttachDots(slotName)
	-- If this is the carrier slot, rebuild pouches
	if slotName == "carrier" then
		pouchBottom = rebuildPouchUI()
		updateScrollCanvas()
	end
end

-- ============================================================
-- SCROLL CANVAS SIZING
-- ============================================================
function updateScrollCanvas()
	local gridRows  = math.ceil(30 / GRID_COLS)
	local gridH     = gridRows * CELL_SIZE + (gridRows - 1) * CELL_PAD
	local totalH    = gridStartY + gridH + 24
	scrollFrame.CanvasSize = UDim2.new(0, 0, 0, totalH)
end

-- ============================================================
-- BUILD LOOT SLOTS
-- ============================================================
for i = 1, 30 do
	local col = (i - 1) % GRID_COLS
	local row = math.floor((i - 1) / GRID_COLS)
	local px  = gridStartX + col * (CELL_SIZE + CELL_PAD)
	local py  = gridStartY + row * (CELL_SIZE + CELL_PAD)

	local frame = Instance.new("Frame", scrollFrame)
	frame.Name             = "Slot" .. i
	frame.Size             = UDim2.new(0, CELL_SIZE, 0, CELL_SIZE)
	frame.Position         = UDim2.new(0, px, 0, py)
	frame.BackgroundColor3 = C.BG_SLOT
	frame.BorderSizePixel  = 0
	frame.ZIndex           = 12
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 5)
	local stroke = Instance.new("UIStroke", frame)
	stroke.Color     = C.BORDER
	stroke.Thickness = 1

	local idxL = Instance.new("TextLabel", frame)
	idxL.Size                   = UDim2.new(0, 14, 0, 11)
	idxL.Position               = UDim2.new(0, 2, 0, 2)
	idxL.BackgroundTransparency = 1
	idxL.TextColor3             = C.TEXT_DIM
	idxL.Font                   = Enum.Font.Gotham
	idxL.TextSize               = 7
	idxL.Text                   = tostring(i)
	idxL.ZIndex                 = 13

	if i <= 6 and not isMobile() then
		local hk = Instance.new("TextLabel", frame)
		hk.Size                   = UDim2.new(0, 14, 0, 11)
		hk.Position               = UDim2.new(1, -16, 0, 2)
		hk.BackgroundTransparency = 1
		hk.TextColor3             = C.HOTKEY
		hk.Font                   = Enum.Font.GothamBold
		hk.TextSize               = 7
		hk.Text                   = tostring(i + 2)
		hk.ZIndex                 = 13
	end

	local icon = Instance.new("ImageLabel", frame)
	icon.Name                   = "Icon"
	icon.Size                   = UDim2.new(0, 28, 0, 28)
	icon.Position               = UDim2.new(0.5, -14, 0, 6)
	icon.BackgroundTransparency = 1
	icon.Image                  = ""
	icon.ScaleType              = Enum.ScaleType.Fit
	icon.ZIndex                 = 13

	local nameL = Instance.new("TextLabel", frame)
	nameL.Name                  = "ItemName"
	nameL.Size                  = UDim2.new(1, -4, 0, 10)
	nameL.Position              = UDim2.new(0, 2, 1, -19)
	nameL.BackgroundTransparency = 1
	nameL.TextColor3            = C.TEXT_BODY
	nameL.Font                  = Enum.Font.GothamBold
	nameL.TextSize              = 7
	nameL.TextXAlignment        = Enum.TextXAlignment.Center
	nameL.TextTruncate          = Enum.TextTruncate.AtEnd
	nameL.Text                  = ""
	nameL.ZIndex                = 13

	local qty = Instance.new("TextLabel", frame)
	qty.Name                  = "Qty"
	qty.Size                  = UDim2.new(1, -4, 0, 9)
	qty.Position              = UDim2.new(0, 2, 1, -9)
	qty.BackgroundTransparency = 1
	qty.TextColor3            = C.TEXT_DIM
	qty.Font                  = Enum.Font.Gotham
	qty.TextSize              = 7
	qty.TextXAlignment        = Enum.TextXAlignment.Center
	qty.Text                  = ""
	qty.ZIndex                = 13

	local btn = Instance.new("TextButton", frame)
	btn.Size                   = UDim2.new(1, 0, 1, 0)
	btn.BackgroundTransparency = 1
	btn.Text                   = ""
	btn.ZIndex                 = 14
	btn.Selectable             = true

	local function selectLootSlot(index)
		if moveMode and selectedLootSlot then
			if index ~= selectedLootSlot then
				Inventory.SwapSlots(selectedLootSlot, index)
				if HUD then
					if Inventory.IsHotbarSlot(selectedLootSlot) then
						HUD.HotbarRefreshSlot(selectedLootSlot, Inventory.GetSlot(selectedLootSlot))
					end
					if Inventory.IsHotbarSlot(index) then
						HUD.HotbarRefreshSlot(index, Inventory.GetSlot(index))
					end
				end
			end
			clearSelection()
			return
		end

		if selectedLootSlot == index then
			clearSelection()
			return
		end

		if selectedLootSlot and lootSlotFrames[selectedLootSlot] then
			local prev = lootSlotFrames[selectedLootSlot]
			prev.frame.BackgroundColor3 = prev.hasItem and C.BG_SLOT_LT or C.BG_SLOT
			prev.stroke.Color           = C.BORDER
			prev.stroke.Thickness       = 1
		end

		selectedLootSlot = index
		if lootSlotFrames[index] then
			lootSlotFrames[index].frame.BackgroundColor3 = C.BG_SEL
			lootSlotFrames[index].stroke.Color           = C.ACCENT
			lootSlotFrames[index].stroke.Thickness       = 2
		end

		updateDetailContent(index)
		showDetailPanel(true)
	end

	btn.MouseButton1Click:Connect(function()
		selectLootSlot(i)
	end)

	lootSlotFrames[i] = {
		frame   = frame,
		stroke  = stroke,
		icon    = icon,
		nameL   = nameL,
		qty     = qty,
		btn     = btn,
		hasItem = false,
	}
end

-- Set canvas size
updateScrollCanvas()

-- ============================================================
-- WIRE UP FIXED EQUIPMENT SLOT BUTTONS
-- ============================================================
local allFixedSlots = {
	"primary","secondary","melee","grenade",
	"helmet","carrier","chest","legs","feet"
}
for _, slotName in ipairs(allFixedSlots) do
	local sf = equipSlotFrames[slotName]
	if sf and sf.btn then
		local name = slotName
		sf.btn.MouseButton1Click:Connect(function()
			handleEquipSlotClick(name)
		end)
	end
end

-- ============================================================
-- BUTTON ACTIONS
-- ============================================================
btnUse.MouseButton1Click:Connect(function()
	if not selectedLootSlot then return end
	if not (Inventory and Inventory.GetSlot(selectedLootSlot)) then return end
	Inventory.UseItem(selectedLootSlot)
	if not Inventory.GetSlot(selectedLootSlot) then
		clearSelection()
	else
		updateDetailContent(selectedLootSlot)
	end
end)

btnEquip.MouseButton1Click:Connect(function()
	if not selectedLootSlot then return end
	if not (Inventory and Equipment) then return end
	local item = Inventory.GetSlot(selectedLootSlot)
	if not item then return end
	local targetSlot = Equipment.GetValidSlot(item)
	if not targetSlot then return end
	handleEquipSlotClick(targetSlot)
end)

btnAttach.MouseButton1Click:Connect(function()
	-- ATTACH button: if only one compatible weapon, attach directly.
	-- If both primary and secondary could take it, let the player tap.
	if not selectedLootSlot then return end
	if not (Inventory and Equipment and Attachment) then return end
	local item = Inventory.GetSlot(selectedLootSlot)
	if not item or not isAttachmentItem(item) then return end

	local compatibleSlots = {}
	for _, slotName in ipairs({"primary", "secondary"}) do
		local weapon = Equipment.GetSlot(slotName)
		if weapon and Attachment.CanAttach(weapon, item) then
			table.insert(compatibleSlots, slotName)
		end
	end

	if #compatibleSlots == 1 then
		-- Only one option — attach directly
		handleEquipSlotClick(compatibleSlots[1])
	elseif #compatibleSlots == 0 then
		if HUD then HUD.ShowNotif("No compatible weapon equipped", 1.5) end
	else
		-- Multiple options — prompt to tap
		dpSub.Text = "Tap a highlighted weapon slot..."
	end
end)

btnMove.MouseButton1Click:Connect(function()
	if not selectedLootSlot then return end
	if moveMode then
		moveMode = false
		if lootSlotFrames[selectedLootSlot] then
			lootSlotFrames[selectedLootSlot].stroke.Color = C.ACCENT
		end
		btnMove.Text = "MOVE"
		updateDetailContent(selectedLootSlot)
	else
		if not (Inventory and Inventory.GetSlot(selectedLootSlot)) then return end
		moveMode = true
		if lootSlotFrames[selectedLootSlot] then
			lootSlotFrames[selectedLootSlot].stroke.Color = C.MOVE_PEND
		end
		btnMove.Text = "CANCEL"
		dpSub.Text   = "Click destination slot..."
	end
end)

btnDrop.MouseButton1Click:Connect(function()
	if not selectedLootSlot then return end

	local item = Inventory.GetSlot(selectedLootSlot)
	if not item then return end

	-- Build item data to send to server
	local dropData = {
		name     = item.name,
		type     = item.type     or "Misc",
		quantity = item.quantity  or 1,
		maxStack = item.maxStack  or 1,
		iconId   = item.iconId    or "",
		data     = item.data      or {},
	}

	-- Remove from inventory
	Inventory.ClearSlot(selectedLootSlot)

	-- Update hotbar if needed
	if HUD and Inventory.IsHotbarSlot(selectedLootSlot) then
		HUD.HotbarRefreshSlot(selectedLootSlot, nil)
	end

	-- Tell server to spawn the item in the world
	if RE_DropItem then
		RE_DropItem:FireServer(dropData)
	end

	clearSelection()
	playSound(SOUND_CLOSE)
end)

-- ============================================================
-- DETACH BUTTON WIRING
-- Each detach button removes the attachment from the weapon
-- and returns it to inventory.
-- ============================================================
for _, dtype in ipairs({"scope", "suppressor", "grip"}) do
	local db = detachButtons[dtype]
	if db and db.detBtn then
		local attachType = dtype
		db.detBtn.MouseButton1Click:Connect(function()
			if not selectedWeaponSlot then return end
			if not (Equipment and Attachment and Inventory) then return end

			local weapon = Equipment.GetSlot(selectedWeaponSlot)
			if not weapon then return end

			local removed = Attachment.Detach(weapon, attachType)
			if not removed then return end

			local returnedSlot = Inventory.AddItem({
				id       = removed.id   or "",
				name     = removed.name,
				type     = removed.data and removed.data.attachType or "Misc",
				quantity = 1,
				maxStack = 1,
				iconId   = "",
				data     = removed.data or {},
			})

			if returnedSlot then
				refreshAttachDots(selectedWeaponSlot)
				playSound(SOUND_DETACH)
				-- Refresh the attachment sub-panel
				showWeaponAttachments(selectedWeaponSlot)
				if HUD and Inventory.IsHotbarSlot(returnedSlot) then
					HUD.HotbarRefreshSlot(returnedSlot, Inventory.GetSlot(returnedSlot))
				end
			else
				-- Re-attach if inventory is full
				Attachment.Attach(weapon, { id = removed.id, name = removed.name, data = removed.data })
				if HUD then HUD.ShowNotif("Inventory full!", 1.5) end
			end
		end)
	end
end

-- ============================================================
-- OPEN / CLOSE
-- ============================================================
local isOpen    = false
local tweenInfo = TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local OPEN_POS  = UDim2.new(0.5, 0, 0.5, 0)
local CLOSE_POS = UDim2.new(0.5, 0, 1.5, 0)

local function open()
	isOpen          = true
	overlay.Visible = true
	window.Visible  = true

	TweenService:Create(overlay, TweenInfo.new(0.2), { BackgroundTransparency = 0.6 }):Play()
	TweenService:Create(window,  tweenInfo,           { Position = OPEN_POS }):Play()

	-- Refresh inventory grid
	if Inventory then
		for i = 1, Inventory.GetSlotCount() do
			refreshLootSlot(i, Inventory.GetSlot(i))
		end
	end

	-- Refresh all equipment slots
	if Equipment then
		for _, name in ipairs(allFixedSlots) do
			refreshEquipSlot(name, Equipment.GetSlot(name))
		end
		for _, name in ipairs(Equipment.GetPouchSlots()) do
			refreshEquipSlot(name, Equipment.GetSlot(name))
		end
	end

	if isPC() then
		local Camera = require(script.Parent:WaitForChild("CameraModule"))
		Camera.SetUIOverride(true)
	elseif isController() then
		GuiService.AutoSelectGuiEnabled = true
		local firstSlot = lootSlotFrames[1]
		if firstSlot and firstSlot.btn then
			GuiService.SelectedObject = firstSlot.btn
		end
	end
	playSound(SOUND_OPEN)
end

local function close()
	isOpen = false
	clearSelection()
	TweenService:Create(overlay, TweenInfo.new(0.2), { BackgroundTransparency = 1 }):Play()
	local t = TweenService:Create(window, tweenInfo, { Position = CLOSE_POS })
	t:Play()
	t.Completed:Connect(function()
		if not isOpen then
			overlay.Visible = false
			window.Visible  = false
		end
	end)
	if isPC() then
		local Camera = require(script.Parent:WaitForChild("CameraModule"))
		Camera.SetUIOverride(false)
	elseif isController() then
		GuiService.AutoSelectGuiEnabled = false
		GuiService.SelectedObject = nil
	end
	playSound(SOUND_CLOSE)
end

-- ============================================================
-- PUBLIC API
-- ============================================================
function BackpackUI.IsOpen() return isOpen end

function BackpackUI.Toggle()
	if isOpen then close() else open() end
end

function BackpackUI.RefreshLootSlot(index)
	if Inventory then refreshLootSlot(index, Inventory.GetSlot(index)) end
end

function BackpackUI.RefreshEquipSlot(slotName)
	if Equipment then refreshEquipSlot(slotName, Equipment.GetSlot(slotName)) end
end

-- ============================================================
-- INIT
-- ============================================================
function BackpackUI.Init(inventoryModule, equipmentModule)
	Inventory = inventoryModule
	Equipment = equipmentModule

	HUD = require(script.Parent:WaitForChild("HUDModule"))

	-- Load AttachmentModule
	local ok, result = pcall(function()
		return require(script.Parent:WaitForChild("AttachmentModule"))
	end)
	if ok then
		Attachment = result
		print("[BackpackUI] AttachmentModule loaded.")
	else
		warn("[BackpackUI] Could not load AttachmentModule: " .. tostring(result))
	end

	inventoryModule.OnSlotChanged(function(index, item)
		refreshLootSlot(index, item)
	end)

	if equipmentModule then
		equipmentModule.OnSlotChanged(function(slotName, item)
			refreshEquipSlot(slotName, item)
		end)
	end

	UIS.InputBegan:Connect(function(input, gpe)
		if gpe then return end
		if input.KeyCode == Enum.KeyCode.Tab then
			if isOpen then close() else open() end
		end
		if input.KeyCode == Enum.KeyCode.Escape and isOpen then
			close()
		end
	end)

	print("[BackpackUI] Initialized (with attachment support).")
end

return BackpackUI
