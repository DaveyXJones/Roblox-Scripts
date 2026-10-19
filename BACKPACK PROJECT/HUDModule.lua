--==================================================
-- HUDModule  (Tactical / Survival restyle)
--==================================================
local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService   = game:GetService("RunService")

local HUDModule = {}

local player    = Players.LocalPlayer
local screenGui = Instance.new("ScreenGui", player.PlayerGui)
screenGui.Name         = "WeaponHUD"
screenGui.ResetOnSpawn = false

-- ============================================================
-- TACTICAL COLOR PALETTE
-- ============================================================
local COL = {
	-- Bar backgrounds
	BAR_BG        = Color3.fromRGB(18, 20, 22),
	BAR_STROKE    = Color3.fromRGB(40, 44, 48),

	-- Health: desaturated military green ? amber ? dark red
	HP_HIGH       = Color3.fromRGB(58, 142, 65),
	HP_MID        = Color3.fromRGB(168, 132, 40),
	HP_LOW        = Color3.fromRGB(160, 42, 38),

	-- Armor: steel blue ? dull gold ? burnt orange
	ARM_HIGH      = Color3.fromRGB(60, 105, 155),
	ARM_MID       = Color3.fromRGB(140, 125, 50),
	ARM_LOW       = Color3.fromRGB(165, 65, 40),

	-- Hunger: muted tan/brown ? dark orange ? dark red
	FOOD_HIGH     = Color3.fromRGB(148, 118, 62),
	FOOD_MID      = Color3.fromRGB(165, 82, 32),
	FOOD_LOW      = Color3.fromRGB(150, 40, 35),

	-- Thirst: slate blue ? dull teal ? dark red
	WATER_HIGH    = Color3.fromRGB(48, 100, 138),
	WATER_MID     = Color3.fromRGB(58, 120, 95),
	WATER_LOW     = Color3.fromRGB(150, 40, 35),

	-- Stamina: warm grey ? fades out
	STAM_FILL     = Color3.fromRGB(170, 160, 140),
	STAM_BG       = Color3.fromRGB(18, 20, 22),

	-- Panel & text
	PANEL_BG      = Color3.fromRGB(10, 12, 16),
	PANEL_STROKE  = Color3.fromRGB(42, 48, 55),
	TEXT_PRIMARY   = Color3.fromRGB(195, 200, 205),
	TEXT_DIM       = Color3.fromRGB(100, 108, 115),
	TEXT_ICON      = Color3.fromRGB(120, 128, 135),
	TEXT_AMMO_EMPTY = Color3.fromRGB(180, 60, 55),

	-- Notification / action text
	NOTIF_TEXT     = Color3.fromRGB(195, 185, 160),   -- warm off-white
	NOTIF_RELOAD   = Color3.fromRGB(170, 155, 120),   -- muted khaki
	NOTIF_EMPTY    = Color3.fromRGB(180, 70, 55),     -- dark red

	-- Fire mode colors
	FM_SEMI       = Color3.fromRGB(80, 155, 80),
	FM_AUTO       = Color3.fromRGB(185, 155, 55),
	FM_BURST      = Color3.fromRGB(185, 105, 45),

	-- Hotbar
	HB_BG_SLOT    = Color3.fromRGB(18, 22, 26),
	HB_BG_FULL    = Color3.fromRGB(30, 36, 42),
	HB_BORDER     = Color3.fromRGB(42, 50, 58),
	HB_SELECTED   = Color3.fromRGB(65, 130, 175),
	HB_HOTKEY     = Color3.fromRGB(155, 142, 90),
	HB_TEXT       = Color3.fromRGB(185, 190, 195),
	HB_QTY        = Color3.fromRGB(120, 128, 135),
}

-- ============================================================
-- HELPER: create a slim stat bar
-- ============================================================
local BAR_W  = 180
local BAR_H  = 8     -- slim tactical bars (was 14)
local BAR_X  = 20
local BAR_CORNER = UDim.new(0, 3)

local function makeStatBar(parent, yOffset, fillColor, iconText, iconColor)
	local bar = Instance.new("Frame", parent)
	bar.Size              = UDim2.new(0, BAR_W, 0, BAR_H)
	bar.Position          = UDim2.new(0, BAR_X, 1, yOffset)
	bar.BackgroundColor3  = COL.BAR_BG
	bar.BackgroundTransparency = 0.25
	bar.BorderSizePixel   = 0
	Instance.new("UICorner", bar).CornerRadius = BAR_CORNER

	local stroke = Instance.new("UIStroke", bar)
	stroke.Color        = COL.BAR_STROKE
	stroke.Thickness    = 1
	stroke.Transparency = 0.5

	local fill = Instance.new("Frame", bar)
	fill.Name                  = "Fill"
	fill.Size                  = UDim2.new(1, 0, 1, 0)
	fill.BackgroundColor3      = fillColor
	fill.BackgroundTransparency = 0.1
	fill.BorderSizePixel       = 0
	Instance.new("UICorner", fill).CornerRadius = BAR_CORNER

	-- Icon label (left side, outside the bar)
	local icon = Instance.new("TextLabel", bar)
	icon.Name                  = "Icon"
	icon.Size                  = UDim2.new(0, 12, 0, 12)
	icon.Position              = UDim2.new(0, -15, 0.5, -6)
	icon.BackgroundTransparency = 1
	icon.TextColor3            = iconColor or COL.TEXT_ICON
	icon.Font                  = Enum.Font.GothamBold
	icon.TextSize              = 9
	icon.Text                  = iconText or ""

	-- Value label (overlaid, right-aligned inside bar)
	local label = Instance.new("TextLabel", bar)
	label.Name                  = "Label"
	label.Size                  = UDim2.new(1, -4, 1, 0)
	label.Position              = UDim2.new(0, 2, 0, 0)
	label.BackgroundTransparency = 1
	label.TextColor3            = COL.TEXT_PRIMARY
	label.Font                  = Enum.Font.GothamBold
	label.TextSize              = 7
	label.TextXAlignment        = Enum.TextXAlignment.Right
	label.TextYAlignment        = Enum.TextYAlignment.Center
	label.Text                  = ""

	return bar, fill, label
end

-- ============================================================
-- HELPER: old makeLabel (kept for compatibility)
-- ============================================================
local function makeLabel(size, pos, bgColor, textColor, text, bgTrans)
	local l = Instance.new("TextLabel", screenGui)
	l.Size                  = size
	l.Position              = pos
	l.BackgroundTransparency = bgTrans or 0.5
	l.BackgroundColor3      = bgColor or Color3.fromRGB(0,0,0)
	l.TextColor3            = textColor
	l.TextScaled            = true
	l.Font                  = Enum.Font.GothamBold
	l.Text                  = text or ""
	Instance.new("UICorner", l).CornerRadius = UDim.new(0, 8)
	return l
end

-- ============================================================
-- WEAPON PANEL  (bottom-right)
-- ============================================================
local PANEL_W = 190
local PANEL_H = 58
local PANEL_X = -PANEL_W - 14
local PANEL_Y = -PANEL_H - 14

local weaponPanel = Instance.new("Frame", screenGui)
weaponPanel.Name                  = "WeaponPanel"
weaponPanel.Size                  = UDim2.new(0, PANEL_W, 0, PANEL_H)
weaponPanel.AnchorPoint           = Vector2.new(1, 1)
weaponPanel.Position              = UDim2.new(1, -14, 1, -14)
weaponPanel.BackgroundColor3      = COL.PANEL_BG
weaponPanel.BackgroundTransparency = 0.35
weaponPanel.BorderSizePixel       = 0
Instance.new("UICorner", weaponPanel).CornerRadius = UDim.new(0, 8)
local wpStroke = Instance.new("UIStroke", weaponPanel)
wpStroke.Color     = COL.PANEL_STROKE
wpStroke.Thickness = 1.2

-- Weapon icon
local weaponIcon = Instance.new("ImageLabel", weaponPanel)
weaponIcon.Name                   = "WeaponIcon"
weaponIcon.Size                   = UDim2.new(0, 36, 0, 36)
weaponIcon.Position               = UDim2.new(0, 6, 0, 6)
weaponIcon.BackgroundTransparency = 1
weaponIcon.Image                  = ""
weaponIcon.ScaleType              = Enum.ScaleType.Fit
weaponIcon.Visible                = false

-- Weapon name
local weaponLabel = Instance.new("TextLabel", weaponPanel)
weaponLabel.Name                   = "WeaponName"
weaponLabel.Size                   = UDim2.new(1, -52, 0, 20)
weaponLabel.Position               = UDim2.new(0, 6, 0, 4)
weaponLabel.BackgroundTransparency = 1
weaponLabel.TextColor3             = COL.TEXT_PRIMARY
weaponLabel.Font                   = Enum.Font.GothamBold
weaponLabel.TextSize               = 13
weaponLabel.TextXAlignment         = Enum.TextXAlignment.Left
weaponLabel.TextTruncate           = Enum.TextTruncate.AtEnd
weaponLabel.Text                   = ""

-- Fire mode badge
local fireModeLabel = Instance.new("TextLabel", weaponPanel)
fireModeLabel.Name                   = "FireMode"
fireModeLabel.Size                   = UDim2.new(0, 48, 0, 18)
fireModeLabel.Position               = UDim2.new(1, -52, 0, 4)
fireModeLabel.BackgroundTransparency = 1
fireModeLabel.TextColor3             = COL.FM_AUTO
fireModeLabel.Font                   = Enum.Font.GothamBold
fireModeLabel.TextSize               = 11
fireModeLabel.TextXAlignment         = Enum.TextXAlignment.Right
fireModeLabel.Text                   = ""

-- Ammo count
local ammoLabel = Instance.new("TextLabel", weaponPanel)
ammoLabel.Name                   = "AmmoCount"
ammoLabel.Size                   = UDim2.new(1, -10, 0, 24)
ammoLabel.Position               = UDim2.new(0, 6, 1, -28)
ammoLabel.BackgroundTransparency = 1
ammoLabel.TextColor3             = COL.TEXT_PRIMARY
ammoLabel.Font                   = Enum.Font.GothamBold
ammoLabel.TextSize               = 18
ammoLabel.TextXAlignment         = Enum.TextXAlignment.Left
ammoLabel.Text                   = ""

-- Notification label (center screen: reload, empty, etc.)
local notifLabel    = Instance.new("TextLabel", screenGui)
notifLabel.Size                  = UDim2.new(0, 240, 0, 16)
notifLabel.Position              = UDim2.new(0.5, -120, 0.55, 0)
notifLabel.BackgroundTransparency = 1
notifLabel.TextColor3            = COL.NOTIF_TEXT
notifLabel.Font                  = Enum.Font.GothamBold
notifLabel.TextSize              = 14
notifLabel.Text                  = ""
-- Drop shadow for readability
local notifShadow = Instance.new("TextLabel", screenGui)
notifShadow.Size                  = notifLabel.Size
notifShadow.Position              = notifLabel.Position + UDim2.new(0, 1, 0, 1)
notifShadow.BackgroundTransparency = 1
notifShadow.TextColor3            = Color3.fromRGB(0, 0, 0)
notifShadow.TextTransparency      = 0.5
notifShadow.Font                  = Enum.Font.GothamBold
notifShadow.TextSize              = 14
notifShadow.Text                  = ""
notifShadow.ZIndex                = notifLabel.ZIndex - 1

-- Crosshair
local crosshair = Instance.new("TextLabel", screenGui)
crosshair.Size                  = UDim2.new(0, 0, 0, 0)
crosshair.Position              = UDim2.new(0.5, -10, 0.5, -10)
crosshair.BackgroundTransparency = 1
crosshair.TextColor3            = Color3.fromRGB(220, 220, 220)
crosshair.Text                  = "+"
crosshair.TextScaled            = true
crosshair.Font                  = Enum.Font.GothamBold

-- OTS dot reticle
local otsDot = Instance.new("Frame", screenGui)
otsDot.Name                    = "OTSDot"
otsDot.Size                    = UDim2.new(0, 8, 0, 8)
otsDot.AnchorPoint             = Vector2.new(0.5, 0.5)
otsDot.Position                = UDim2.new(0.5, 0, 0.5, 0)
otsDot.BackgroundColor3        = Color3.fromRGB(220, 220, 220)
otsDot.BackgroundTransparency  = 0.1
otsDot.BorderSizePixel         = 0
otsDot.Visible                 = false
otsDot.ZIndex                  = 20
Instance.new("UICorner", otsDot).CornerRadius = UDim.new(1, 0)
local dotStroke = Instance.new("UIStroke", otsDot)
dotStroke.Color     = Color3.fromRGB(0, 0, 0)
dotStroke.Thickness = 1.5
dotStroke.Transparency = 0.3

local notifGeneration = 0
local notifTimer      = 0

-- ============================================================
-- DAMAGE FLASH + LOW HEALTH VIGNETTE
-- ============================================================
local damageFlash = Instance.new("Frame", screenGui)
damageFlash.Name                   = "DamageFlash"
damageFlash.Size                   = UDim2.new(1, 0, 1, 0)
damageFlash.BackgroundTransparency = 1
damageFlash.BackgroundColor3       = Color3.fromRGB(160, 10, 0)
damageFlash.BorderSizePixel        = 0
damageFlash.ZIndex                 = 20

local flashGrad = Instance.new("UIGradient", damageFlash)
flashGrad.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0,   0.0),
	NumberSequenceKeypoint.new(0.4, 0.85),
	NumberSequenceKeypoint.new(0.5, 1.0),
	NumberSequenceKeypoint.new(0.6, 0.85),
	NumberSequenceKeypoint.new(1,   0.0),
})
flashGrad.Rotation = 0

local damageFlashV = Instance.new("Frame", screenGui)
damageFlashV.Name                   = "DamageFlashV"
damageFlashV.Size                   = UDim2.new(1, 0, 1, 0)
damageFlashV.BackgroundTransparency = 1
damageFlashV.BackgroundColor3       = Color3.fromRGB(160, 10, 0)
damageFlashV.BorderSizePixel        = 0
damageFlashV.ZIndex                 = 20
local flashGradV = Instance.new("UIGradient", damageFlashV)
flashGradV.Transparency = flashGrad.Transparency
flashGradV.Rotation     = 90

local lowHealthVig  = Instance.new("Frame", screenGui)
lowHealthVig.Name                   = "LowHealthVignette"
lowHealthVig.Size                   = UDim2.new(1, 0, 1, 0)
lowHealthVig.BackgroundTransparency = 1
lowHealthVig.BackgroundColor3       = Color3.fromRGB(140, 0, 0)
lowHealthVig.BorderSizePixel        = 0
lowHealthVig.ZIndex                 = 19
local lvGrad = Instance.new("UIGradient", lowHealthVig)
lvGrad.Transparency = flashGrad.Transparency
lvGrad.Rotation     = 0

local lowHealthVigV = Instance.new("Frame", screenGui)
lowHealthVigV.Name                   = "LowHealthVignetteV"
lowHealthVigV.Size                   = UDim2.new(1, 0, 1, 0)
lowHealthVigV.BackgroundTransparency = 1
lowHealthVigV.BackgroundColor3       = Color3.fromRGB(140, 0, 0)
lowHealthVigV.BorderSizePixel        = 0
lowHealthVigV.ZIndex                 = 19
local lvGradV = Instance.new("UIGradient", lowHealthVigV)
lvGradV.Transparency = flashGrad.Transparency
lvGradV.Rotation     = 90

local isCritical   = false
local pulseActive  = false

local FLASH_PEAK = 0.25
local FLASH_FADE = TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function triggerDamageFlash()
	TweenService:Create(damageFlash,  TweenInfo.new(0), { BackgroundTransparency = FLASH_PEAK }):Play()
	TweenService:Create(damageFlashV, TweenInfo.new(0), { BackgroundTransparency = FLASH_PEAK }):Play()
	TweenService:Create(damageFlash,  FLASH_FADE, { BackgroundTransparency = 1 }):Play()
	TweenService:Create(damageFlashV, FLASH_FADE, { BackgroundTransparency = 1 }):Play()
end

local PULSE_IN   = TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
local PULSE_OUT  = TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
local PULSE_PEAK = 0.3

local function startPulse()
	if pulseActive then return end
	pulseActive = true
	local function doPulse()
		if not isCritical then
			TweenService:Create(lowHealthVig,  PULSE_OUT, { BackgroundTransparency = 1 }):Play()
			TweenService:Create(lowHealthVigV, PULSE_OUT, { BackgroundTransparency = 1 }):Play()
			pulseActive = false
			return
		end
		local tIn = TweenService:Create(lowHealthVig,  PULSE_IN, { BackgroundTransparency = PULSE_PEAK })
		TweenService:Create(lowHealthVigV, PULSE_IN, { BackgroundTransparency = PULSE_PEAK }):Play()
		tIn:Play()
		tIn.Completed:Connect(function()
			if not isCritical then
				TweenService:Create(lowHealthVig,  PULSE_OUT, { BackgroundTransparency = 1 }):Play()
				TweenService:Create(lowHealthVigV, PULSE_OUT, { BackgroundTransparency = 1 }):Play()
				pulseActive = false
				return
			end
			local tOut = TweenService:Create(lowHealthVig,  PULSE_OUT, { BackgroundTransparency = 1 })
			TweenService:Create(lowHealthVigV, PULSE_OUT, { BackgroundTransparency = 1 }):Play()
			tOut:Play()
			tOut.Completed:Connect(doPulse)
		end)
	end
	doPulse()
end

function HUDModule.FlashDamage()   triggerDamageFlash() end
function HUDModule.SetCritical(active)
	isCritical = active
	if active then startPulse() end
end

-- ============================================================
-- HOTBAR
-- ============================================================
local SLOT_COUNT = 6
local SLOT_SIZE  = 54
local SLOT_PAD   = 6
local HOTBAR_W   = (SLOT_SIZE * SLOT_COUNT) + (SLOT_PAD * (SLOT_COUNT - 1))
local HOTBAR_H   = SLOT_SIZE

local hotbarFrame = Instance.new("Frame", screenGui)
hotbarFrame.Name             = "Hotbar"
hotbarFrame.Size             = UDim2.new(0, HOTBAR_W + 16, 0, HOTBAR_H + 16)
hotbarFrame.AnchorPoint      = Vector2.new(0.5, 1)
hotbarFrame.Position         = UDim2.new(0.5, 0, 1, -14)
hotbarFrame.BackgroundColor3 = COL.PANEL_BG
hotbarFrame.BackgroundTransparency = 0.3
hotbarFrame.BorderSizePixel  = 0
Instance.new("UICorner", hotbarFrame).CornerRadius = UDim.new(0, 10)
local hotbarStroke = Instance.new("UIStroke", hotbarFrame)
hotbarStroke.Color     = COL.HB_BORDER
hotbarStroke.Thickness = 1.2

local hotbarSlots = {}

for i = 1, SLOT_COUNT do
	local hotkey = i + 2
	local xPos   = 8 + (i - 1) * (SLOT_SIZE + SLOT_PAD)

	local slot = Instance.new("Frame", hotbarFrame)
	slot.Name             = "HotbarSlot" .. i
	slot.Size             = UDim2.new(0, SLOT_SIZE, 0, SLOT_SIZE)
	slot.Position         = UDim2.new(0, xPos, 0, 8)
	slot.BackgroundColor3 = COL.HB_BG_SLOT
	slot.BorderSizePixel  = 0
	Instance.new("UICorner", slot).CornerRadius = UDim.new(0, 6)
	local ss = Instance.new("UIStroke", slot)
	ss.Color     = COL.HB_BORDER
	ss.Thickness = 1.2

	local hk = Instance.new("TextLabel", slot)
	hk.Name                  = "Hotkey"
	hk.Size                  = UDim2.new(0, 14, 0, 14)
	hk.Position              = UDim2.new(0, 3, 0, 3)
	hk.BackgroundTransparency = 1
	hk.TextColor3            = COL.HB_HOTKEY
	hk.Font                  = Enum.Font.GothamBold
	hk.TextScaled            = true
	hk.Text                  = tostring(hotkey)

	local icon = Instance.new("ImageLabel", slot)
	icon.Name                  = "Icon"
	icon.Size                  = UDim2.new(0, 28, 0, 28)
	icon.Position              = UDim2.new(0.5, -14, 0, 8)
	icon.BackgroundTransparency = 1
	icon.Image                 = ""
	icon.ScaleType             = Enum.ScaleType.Fit

	local nameL = Instance.new("TextLabel", slot)
	nameL.Name                  = "ItemName"
	nameL.Size                  = UDim2.new(1, -4, 0, 12)
	nameL.Position              = UDim2.new(0, 2, 1, -24)
	nameL.BackgroundTransparency = 1
	nameL.TextColor3            = COL.HB_TEXT
	nameL.Font                  = Enum.Font.GothamBold
	nameL.TextSize              = 8
	nameL.TextXAlignment        = Enum.TextXAlignment.Center
	nameL.TextTruncate          = Enum.TextTruncate.AtEnd
	nameL.Text                  = ""

	local qty = Instance.new("TextLabel", slot)
	qty.Name                  = "Qty"
	qty.Size                  = UDim2.new(1, -4, 0, 11)
	qty.Position              = UDim2.new(0, 2, 1, -12)
	qty.BackgroundTransparency = 1
	qty.TextColor3            = COL.HB_QTY
	qty.Font                  = Enum.Font.Gotham
	qty.TextSize              = 8
	qty.TextXAlignment        = Enum.TextXAlignment.Center
	qty.Text                  = ""

	hotbarSlots[i] = slot
end

-- ============================================================
-- HOTBAR PUBLIC API
-- ============================================================
function HUDModule.HotbarRefreshSlot(index, item)
	local slot = hotbarSlots[index]
	if not slot then return end
	local icon   = slot:FindFirstChild("Icon")
	local nameL  = slot:FindFirstChild("ItemName")
	local qty    = slot:FindFirstChild("Qty")
	local stroke = slot:FindFirstChildOfClass("UIStroke")
	if item then
		slot.BackgroundColor3 = COL.HB_BG_FULL
		if icon   then icon.Image   = item.iconId or ""              end
		if nameL  then nameL.Text   = item.name                      end
		if qty    then qty.Text     = "x" .. tostring(item.quantity) end
		if stroke then stroke.Color = COL.HB_BORDER                  end
	else
		slot.BackgroundColor3 = COL.HB_BG_SLOT
		if icon   then icon.Image   = "" end
		if nameL  then nameL.Text   = "" end
		if qty    then qty.Text     = "" end
		if stroke then stroke.Color = COL.HB_BORDER end
	end
end

function HUDModule.HotbarSetActive(index)
	for i, slot in ipairs(hotbarSlots) do
		local stroke = slot:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color     = (i == index) and COL.HB_SELECTED or COL.HB_BORDER
			stroke.Thickness = (i == index) and 2 or 1.2
		end
	end
end

function HUDModule.HotbarClearActive()
	for _, slot in ipairs(hotbarSlots) do
		local stroke = slot:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color     = COL.HB_BORDER
			stroke.Thickness = 1.2
		end
	end
end

-- ============================================================
-- EXISTING WEAPON/AMMO API
-- ============================================================
function HUDModule.UpdateWeapon(weapon)
	local name   = type(weapon) == "string" and weapon or weapon.name
	local iconId = type(weapon) == "table"  and weapon.iconId or ""

	if iconId and iconId ~= "" then
		weaponIcon.Image   = iconId
		weaponIcon.Visible = true
		weaponLabel.Position = UDim2.new(0, 48, 0, 4)
		weaponLabel.Size     = UDim2.new(1, -100, 0, 20)
	else
		weaponIcon.Visible   = false
		weaponLabel.Position = UDim2.new(0, 6, 0, 4)
		weaponLabel.Size     = UDim2.new(1, -58, 0, 20)
	end

	weaponLabel.Text = name:upper()
end

function HUDModule.UpdateAmmo(weaponName, current, max)
	if max == 0 then
		ammoLabel.Text    = ""
		ammoLabel.Visible = false
		return
	end
	ammoLabel.Visible    = true
	ammoLabel.Text       = current .. " / " .. max
	ammoLabel.TextColor3 = current == 0
		and COL.TEXT_AMMO_EMPTY
		or  COL.TEXT_PRIMARY
end

function HUDModule.UpdateFireMode(modes, index)
	if #modes <= 1 then
		fireModeLabel.Text = ""
		return
	end
	local mode = modes[index]
	fireModeLabel.Text = mode.name:upper()
	local colors = {
		Semi  = COL.FM_SEMI,
		Auto  = COL.FM_AUTO,
		Burst = COL.FM_BURST,
	}
	fireModeLabel.TextColor3 = colors[mode.name] or COL.TEXT_PRIMARY
end

-- ============================================================
-- STAT BARS  (bottom-left, stacking upward)
--
-- Layout (from bottom):
--   -18  = thirst
--   -30  = hunger
--   -42  = health
--   -54  = armor  (hidden when no armor)
--   -66  = stamina (hidden when full)
-- ============================================================

-- THIRST BAR
local thirstBar, thirstFill, thirstLabel = makeStatBar(screenGui, -18, COL.WATER_HIGH, "W", COL.WATER_HIGH)

function HUDModule.UpdateThirst(thirst, max)
	local pct = math.clamp(thirst / max, 0, 1)
	thirstFill.Size = UDim2.new(pct, 0, 1, 0)
	if pct > 0.5 then
		thirstFill.BackgroundColor3 = COL.WATER_HIGH
	elseif pct > 0.2 then
		thirstFill.BackgroundColor3 = COL.WATER_MID
	else
		thirstFill.BackgroundColor3 = COL.WATER_LOW
	end
end

-- HUNGER BAR
local hungerBar, hungerFill, hungerLabel = makeStatBar(screenGui, -30, COL.FOOD_HIGH, "F", COL.FOOD_HIGH)

function HUDModule.UpdateHunger(hunger, max)
	local pct = math.clamp(hunger / max, 0, 1)
	hungerFill.Size = UDim2.new(pct, 0, 1, 0)
	if pct > 0.5 then
		hungerFill.BackgroundColor3 = COL.FOOD_HIGH
	elseif pct > 0.2 then
		hungerFill.BackgroundColor3 = COL.FOOD_MID
	else
		hungerFill.BackgroundColor3 = COL.FOOD_LOW
	end
end

-- HEALTH BAR
local healthBar, healthFill, healthLabel = makeStatBar(screenGui, -42, COL.HP_HIGH, "+", COL.HP_HIGH)
local lastHealth = 100

function HUDModule.UpdateHealth(health, max)
	local pct = health / max
	if health < lastHealth then triggerDamageFlash() end
	lastHealth = health
	isCritical = pct <= 0.25
	if isCritical then startPulse() end
	healthFill.Size = UDim2.new(pct, 0, 1, 0)
	healthLabel.Text = tostring(math.floor(health))
	if pct > 0.5 then
		healthFill.BackgroundColor3 = COL.HP_HIGH
	elseif pct > 0.25 then
		healthFill.BackgroundColor3 = COL.HP_MID
	else
		healthFill.BackgroundColor3 = COL.HP_LOW
	end
end

-- ARMOR BAR (hidden until armor equipped)
local armorBar, armorFill, armorLabel = makeStatBar(screenGui, -54, COL.ARM_HIGH, "A", COL.ARM_HIGH)
armorBar.Visible = false

local ARMOR_MAX = 110

function HUDModule.UpdateArmor(armorRating, durabilityPercent)
	if armorRating <= 0 then
		armorBar.Visible = false
		return
	end
	armorBar.Visible = true

	local pct
	if durabilityPercent and durabilityPercent > 0 then
		pct = math.clamp(durabilityPercent, 0, 1)
	else
		pct = math.clamp(armorRating / ARMOR_MAX, 0, 1)
	end

	armorFill.Size = UDim2.new(pct, 0, 1, 0)
	armorLabel.Text = tostring(math.floor(armorRating))

	if pct > 0.5 then
		armorFill.BackgroundColor3 = COL.ARM_HIGH
	elseif pct > 0.25 then
		armorFill.BackgroundColor3 = COL.ARM_MID
	else
		armorFill.BackgroundColor3 = COL.ARM_LOW
	end
end

-- STAMINA BAR (only visible while draining/recovering)
local staminaBar, staminaFill, staminaLabel = makeStatBar(screenGui, -66, COL.STAM_FILL, "S", COL.STAM_FILL)
staminaBar.Visible = false
local staminaVisible    = false
local staminaFadeTimer  = 0
local STAM_FADE_DELAY   = 1.5    -- seconds after full before fading out
local STAM_FADE_TIME    = 0.4

function HUDModule.UpdateStamina(stamina, max)
	local pct = math.clamp(stamina / max, 0, 1)
	staminaFill.Size = UDim2.new(pct, 0, 1, 0)

	if pct < 1.0 then
		-- Stamina is draining or recovering: show bar
		if not staminaVisible then
			staminaVisible = true
			staminaBar.Visible = true
			TweenService:Create(staminaBar, TweenInfo.new(0.2), {
				BackgroundTransparency = 0.25
			}):Play()
			TweenService:Create(staminaFill, TweenInfo.new(0.2), {
				BackgroundTransparency = 0.1
			}):Play()
		end
		staminaFadeTimer = 0
	else
		-- Stamina is full: start countdown to hide
		if staminaVisible then
			staminaFadeTimer = staminaFadeTimer + (1/60) -- approximate dt
			if staminaFadeTimer >= STAM_FADE_DELAY then
				staminaVisible = false
				TweenService:Create(staminaBar, TweenInfo.new(STAM_FADE_TIME), {
					BackgroundTransparency = 1
				}):Play()
				TweenService:Create(staminaFill, TweenInfo.new(STAM_FADE_TIME), {
					BackgroundTransparency = 1
				}):Play()
				task.delay(STAM_FADE_TIME, function()
					if not staminaVisible then
						staminaBar.Visible = false
					end
				end)
			end
		end
	end
end

-- ============================================================
-- NOTIFICATION / ACTION TEXT
-- ============================================================
function HUDModule.ShowNotif(text, duration)
	notifLabel.Text = text
	notifShadow.Text = text
	notifLabel.TextColor3 = COL.NOTIF_TEXT
	notifTimer = duration or 1.2
	notifGeneration = notifGeneration + 1
	local gen = notifGeneration
	task.delay(duration or 1.2, function()
		if notifGeneration == gen then
			if notifLabel.Text ~= "RELOADING..." and notifLabel.Text ~= "EMPTY -- press R" then
				notifLabel.Text = ""
				notifShadow.Text = ""
				notifTimer = 0
			end
		end
	end)
end

function HUDModule.SetReloading(active)
	notifLabel.Text = active and "RELOADING..." or ""
	notifShadow.Text = notifLabel.Text
	notifLabel.TextColor3 = COL.NOTIF_RELOAD
end

function HUDModule.SetEmpty()
	notifLabel.Text = "EMPTY -- press R"
	notifShadow.Text = notifLabel.Text
	notifLabel.TextColor3 = COL.NOTIF_EMPTY
end

function HUDModule.SetCrosshair(visible)
	crosshair.Visible = visible
end

function HUDModule.ShowOTSDot(visible)
	otsDot.Visible    = visible
	if visible then
		crosshair.Visible = false
	end
end

function HUDModule.Tick(dt)
	if notifTimer > 0 then
		notifTimer = notifTimer - dt
		if notifTimer <= 0 then
			notifTimer = 0
			if notifLabel.Text ~= "RELOADING..." and notifLabel.Text ~= "EMPTY -- press R" then
				notifLabel.Text = ""
				notifShadow.Text = ""
			end
		end
	end
end

return HUDModule