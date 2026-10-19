--==================================================
-- WeaponConfig
-- ModuleScript ? ReplicatedStorage
--
-- Single source of truth for every weapon's visual
-- and CFrame configuration.
--
-- Both GunHolder (server, world model) and
-- ViewmodelModule (client, first-person) read from
-- here by assetName.
--
-- To add a new gun:
--   1. Add its model to ReplicatedStorage/GunAssets/
--   2. Add an entry below with its assetName matching
--      the model name exactly.
--   3. That's it. ItemRegistry has the gameplay stats,
--      this file only holds visual / CFrame data.
--
-- FIELDS:
--   assetName    : string   must match GunAssets model name exactly
--   scale        : number   uniform scale applied after cloning
--   hipCF        : CFrame   viewmodel position at hip (first-person)
--   adsCF        : CFrame   viewmodel position when ADS (first-person)
--   axisFix      : CFrame   rotation correction for the viewmodel weld
--   handC0       : CFrame   weld offset from RightHand ? gun primary (3rd person)
--   partOffsets  : table?   optional per-part Vector3 offsets
--
-- NOTE: Gameplay stats (damage, fire rate, spread, recoil,
-- pellet count, sounds, etc.) are all in ItemRegistry.lua.
-- WeaponConfig is purely visual.
--==================================================

local WeaponConfig = {}

WeaponConfig.CONFIGS = {

	-- ============================================================
	-- P226  (Secondary / Pistol)
	-- ============================================================
	["P226"] = {
		assetName  = "P226",
		scale      = 0.10,
		hipCF      = CFrame.new(1.220, -1.180, -2.250)
			* CFrame.Angles(math.rad(-0.000), math.rad(30.000), math.rad(10.000)),
		
		adsCF      = CFrame.new(0.011, -0.735, -2.375),
		axisFix    = CFrame.Angles(math.rad(0), math.rad(-180), math.rad(0)),
		
		handC0     = CFrame.new(0, -0.2, -0.6)
			* CFrame.Angles(math.rad(-40), math.rad(180), math.rad(-29)),
	},

	-- ============================================================
	-- M4A1VM  (Primary / AR)
	-- ============================================================
	["M4A1VM"] = {
		assetName = "M4A1VM",
		scale     = 1.1,
		hipCF     = CFrame.new(0.380, -1.200, -0.980)
			* CFrame.Angles(math.rad(0.000), math.rad(60.000), math.rad(10.000)),
		
		adsCF     = CFrame.new(-0.009, -0.810, -0.420),
		axisFix   = CFrame.Angles(math.rad(0), math.rad(0), math.rad(0)),
		
		handC0    = CFrame.new(0, 0.1, -0.8)
			* CFrame.Angles(math.rad(0), math.rad(0), math.rad(-30)),
	},

	-- ============================================================
	-- AK74VM  (Primary / AK-74)
	-- ============================================================
	["AK74VM"] = {
		assetName = "AK74VM",
		scale     = 1.2,
		hipCF       = CFrame.new(0.300, -0.75, -0.860)
			* CFrame.Angles(math.rad(0.000), math.rad(65.000), math.rad(10.000)),
		
		adsCF       = CFrame.new(0.001, -0.435, -0.485),
		axisFix = CFrame.Angles(math.rad(0), math.rad(-90), math.rad(0)),
		
		handC0    = CFrame.new(0, 0.1, -0.65)
			* CFrame.Angles(math.rad(0), math.rad(-90), math.rad(40)),
	},

	-- ============================================================
	-- SCAR-HVM  (Primary / SCAR-H)
	-- ============================================================
	["SCAR-HVM"] = {
		assetName = "SCAR-HVM",
		scale     = 1.15,
		hipCF     = CFrame.new(0.300, -1.775, -1.950)
			* CFrame.Angles(math.rad(-0.000), math.rad(60.000), math.rad(10.000)),
		
		adsCF     = CFrame.new(-0.004, -1.110, -0.325),
		axisFix = CFrame.Angles(math.rad(0), math.rad(90), math.rad(0)),
		
		handC0    = CFrame.new(0, -0.05, -0.15)
			* CFrame.Angles(math.rad(0), math.rad(90), math.rad(-30)),
	},

	-- ============================================================
	-- MP5VM  (Primary / MP5)
	-- ============================================================
	["MP5VM"] = {
		assetName = "MP5VM",
		scale     = 1.2,
		hipCF     = CFrame.new(0.300, -0.990, -0.725)
			* CFrame.Angles(math.rad(-0.000), math.rad(60.000), math.rad(10.000)),
		
		adsCF     = CFrame.new(0.016, -0.770, -1.160),
		axisFix = CFrame.Angles(math.rad(0), math.rad(-90), math.rad(0)),
		
		handC0    = CFrame.new(0, 0.05, -0.5)
			* CFrame.Angles(math.rad(0), math.rad(-90), math.rad(30)),
	},

	-- ============================================================
	-- M870VM  (Primary / Shotgun)
	-- ============================================================
	["M870VM"] = {
		assetName = "M870VM",
		scale     = 1.2,
		hipCF     = CFrame.new(0.300, -0.635, -0.540)
			* CFrame.Angles(math.rad(-0.000), math.rad(60.000), math.rad(10.000)),
		
		adsCF     = CFrame.new(0.006, -0.395, -0.495),
		axisFix   = CFrame.Angles(0, math.rad(-180), 0),
		
		handC0    = CFrame.new(0, 0.1, -0.85)
			* CFrame.Angles(math.rad(0), math.rad(-180), math.rad(-30)),
	},

	-- ============================================================
	-- SVDVM  (Primary / SVD DMR)
	-- ============================================================
	["SVDVM"] = {
		assetName = "SVDVM",
		scale     = 1.1,
		hipCF     = CFrame.new(0.300, -0.800, -1.000)
			* CFrame.Angles(math.rad(0.000), math.rad(60.000), math.rad(10.000)),
		
		adsCF     = CFrame.new(0.001, -0.485, -0.190),
		axisFix   = CFrame.Angles(0, math.rad(-90), 0),
		
		handC0    = CFrame.new(0, 0.12, -0.9)
			* CFrame.Angles(math.rad(0), math.rad(-90), math.rad(-30)),
	},

	-- ============================================================
	-- DeagleVM  (Secondary / Desert Eagle)
	-- ============================================================
	["DeagleVM"] = {
		assetName = "DeagleVM",
		scale     = 1.2,
		hipCF     = CFrame.new(1.200, -1.300, -1.400)
			* CFrame.Angles(math.rad(-0.000), math.rad(40.000), math.rad(10.000)),
		
		adsCF     = CFrame.new(0.001, -0.665, -1.380),
		axisFix   = CFrame.Angles(0, math.rad(0), 0),
		
		handC0    = CFrame.new(0, -0.2, -0.2)
			* CFrame.Angles(math.rad(-40), math.rad(0), math.rad(-29)),
	},

	-- ============================================================
	-- CombatKnifeVM  (Melee)
	-- ============================================================
	["CombatKnifeVM"] = {
		assetName = "CombatKnifeVM",
		scale     = 3.25,
		hipCF     = CFrame.new(0.35,-0.25, -0.89),
		adsCF     = CFrame.new(0.35, -0.45, -4.50),
		axisFix = CFrame.Angles(math.rad(70), math.rad(185), math.rad(-80)),
		handC0    = CFrame.new(0, 0.29, -0.75)
			* CFrame.Angles(math.rad(35), math.rad(180), math.rad(-90)),
	},

	-- ============================================================
	-- FireAxeVM  (Melee)
	-- ============================================================
	["FireAxeVM"] = {
		assetName = "FireAxeVM",
		scale     = 1.2,
		hipCF     = CFrame.new(0.35,-0.45, -0.75),
		adsCF     = CFrame.new(0.35, -0.45, -4.50),
		axisFix = CFrame.Angles(math.rad(-45), math.rad(0), math.rad(0)),
		handC0    = CFrame.new(0, 0.24, -0.75)
			* CFrame.Angles(math.rad(-45), math.rad(0), math.rad(-0)),
	},

}

-- ============================================================
-- GET  (by assetName)
-- ============================================================
function WeaponConfig.Get(assetName)
	if not assetName then return nil end
	return WeaponConfig.CONFIGS[assetName]
end

print("[WeaponConfig] Loaded. Configs registered: " .. (function()
	local n = 0; for _ in pairs(WeaponConfig.CONFIGS) do n = n + 1 end; return n
end)())

return WeaponConfig