--==================================================
-- ItemRegistry
-- ModuleScript inside PlayerController > Modules
--
-- Single source of truth for every item definition
-- in the game. The LootSystem, inventory, and
-- equipment modules all read from here.
--
-- To add a new item: add an entry to the
-- appropriate section below. That's it.
--
-- REWORKED: Weapon stats now include realistic
-- magazine capacities, per-weapon spread, recoil,
-- headshot multipliers, effective range, damage
-- falloff, pellet count (shotgun), and per-weapon
-- sound asset IDs.
--
-- NEW data fields for weapons:
--   hipSpread       : number  (pixel spread from centre at hip)
--   adsSpread       : number  (pixel spread from centre when ADS)
--   recoilKick      : number  (viewmodel kick intensity, 0-1 scale)
--   headshotMulti   : number  (damage multiplier on head hit)
--   effectiveRange  : number  (studs — full damage up to this range)
--   maxRange        : number  (studs — zero damage beyond this)
--   pelletCount     : number  (1 for rifles/pistols, 8+ for shotguns)
--   pelletSpread    : number  (cone angle in degrees for pellets)
--   muzzleVelocity  : number  (informational / future bullet drop)
--   shootSound      : string  (rbxassetid:// for fire sound)
--   reloadOutSound  : string  (rbxassetid:// for mag-out sound)
--   reloadInSound   : string  (rbxassetid:// for mag-in sound)
--   shootVolume     : number  (volume for fire sound, 0-1)
--==================================================

local ItemRegistry = {}

-- ============================================================
-- RARITY
-- ============================================================
ItemRegistry.RARITY = {
	COMMON    = "Common",
	UNCOMMON  = "Uncommon",
	RARE      = "Rare",
	EPIC      = "Epic",
	LEGENDARY = "Legendary",
}

local R = ItemRegistry.RARITY  -- shorthand below

-- ============================================================
-- ITEM TYPE TAGS
-- These match EquipmentModule.SLOT_ACCEPTS and
-- InventoryModule.TYPE values.
-- ============================================================
ItemRegistry.TYPE = {
	-- Weapons
	PRIMARY    = "primary",
	SECONDARY  = "secondary",
	MELEE      = "melee",
	GRENADE    = "grenade",
	-- Gear
	HELMET     = "helmet",
	CARRIER    = "carrier",
	CHEST      = "chest",
	LEGS       = "legs",
	FEET       = "feet",
	-- Consumables
	HEAL       = "Heal",
	AMMO       = "Ammo",
	CONSUMABLE = "Consumable",
	-- Attachments
	SCOPE      = "scope",
	SUPPRESSOR = "suppressor",
	GRIP       = "grip",
	-- Misc
	MISC       = "Misc",
}

local T = ItemRegistry.TYPE  -- shorthand below

-- ============================================================
-- HELPER
-- Builds a complete item table with sensible defaults.
-- Callers only need to supply what differs from defaults.
-- ============================================================
local function item(def)
	return {
		id          = def.id,
		name        = def.name,
		type        = def.type,
		description = def.description or "",
		rarity      = def.rarity      or R.COMMON,
		iconId      = def.iconId      or "",
		quantity    = def.quantity    or 1,
		maxStack    = def.maxStack    or 1,
		data        = def.data        or {},
	}
end

-- ============================================================
-- ----------------------------------------------------------
--  WEAPONS — PRIMARY
-- ----------------------------------------------------------
-- Realistic stats per weapon class:
--
--  ASSAULT RIFLES  (M4A1, SCAR-H, AK-74)
--    ~20-30 dmg, 30-rnd mag, fast fire rate, medium spread
--
--  SMG  (MP5)
--    ~18 dmg, 30-rnd mag, fastest fire rate, wider hip spread
--    but tighter ADS, short effective range
--
--  SHOTGUN  (M870)
--    ~14 dmg PER PELLET × 8 pellets, 6-rnd tube, pump action,
--    very short effective range, wide pellet cone
--
--  DMR  (SVD)
--    ~55 dmg, 10-rnd mag, slow semi-auto, tightest spread,
--    long effective range, high headshot multi
-- ============================================================
ItemRegistry.WEAPONS_PRIMARY = {

	item { id = "m4a1",   name = "M4A1",
		type = T.PRIMARY, rarity = R.UNCOMMON,
		description = "Versatile 5.56 assault rifle. Reliable at most ranges.",
		data = {
			weaponSlot      = "primary",
			damage          = 24,
			fireRate        = 0.085,        -- ~700 RPM
			reloadTime      = 2.4,
			maxAmmo         = 30,
			ammoType        = "5.56 Rounds",
			fireModes       = { "Semi", "Auto", "Burst" },
			defaultMode     = 2,

			-- NEW: per-weapon ballistics
			hipSpread       = 7,
			adsSpread       = 1.5,
			recoilKick      = 0.35,
			headshotMulti   = 2.0,
			effectiveRange  = 150,
			maxRange        = 300,
			pelletCount     = 1,
			pelletSpread    = 0,
			muzzleVelocity  = 940,

			-- NEW: per-weapon sounds  (replace "" with real rbxassetid when you have audio)
			shootSound      = "",    -- M4 fire sound
			reloadOutSound  = "",    -- mag-out sound
			reloadInSound   = "",    -- mag-in / bolt release
			shootVolume     = 0.85,

			attachmentSlots = { scope = true, suppressor = true, grip = true },
			attachments     = {},
			assetName       = "M4A1VM",
		},
	},

	item { id = "scar-h",   name = "SCAR-H",
		type = T.PRIMARY, rarity = R.UNCOMMON,
		description = "Heavy battle rifle. Harder-hitting 7.62 with more recoil.",
		data = {
			weaponSlot      = "primary",
			damage          = 32,
			fireRate        = 0.10,         -- ~600 RPM
			reloadTime      = 2.7,
			maxAmmo         = 20,           -- SCAR-H uses 20-rnd mags
			ammoType        = "7.62 Rounds",
			fireModes       = { "Semi", "Auto" },
			defaultMode     = 2,

			hipSpread       = 8,
			adsSpread       = 1.8,
			recoilKick      = 0.52,
			headshotMulti   = 2.0,
			effectiveRange  = 170,
			maxRange        = 350,
			pelletCount     = 1,
			pelletSpread    = 0,
			muzzleVelocity  = 850,

			shootSound      = "",
			reloadOutSound  = "",
			reloadInSound   = "",
			shootVolume     = 0.90,

			attachmentSlots = { scope = true, suppressor = true, grip = true },
			attachments     = {},
			assetName       = "SCAR-HVM",
		},
	},

	item { id = "ak74",   name = "AK-74",
		type = T.PRIMARY, rarity = R.UNCOMMON,
		description = "Rugged 5.45 rifle. Hard-hitting with pronounced recoil.",
		data = {
			weaponSlot      = "primary",
			damage          = 28,
			fireRate        = 0.10,         -- ~600 RPM
			reloadTime      = 2.8,
			maxAmmo         = 30,
			ammoType        = "7.62 Rounds",
			fireModes       = { "Semi", "Auto" },
			defaultMode     = 2,

			hipSpread       = 9,
			adsSpread       = 2.0,
			recoilKick      = 0.48,
			headshotMulti   = 2.0,
			effectiveRange  = 140,
			maxRange        = 280,
			pelletCount     = 1,
			pelletSpread    = 0,
			muzzleVelocity  = 880,

			shootSound      = "",
			reloadOutSound  = "",
			reloadInSound   = "",
			shootVolume     = 0.90,

			attachmentSlots = { scope = true, suppressor = true, grip = true },
			attachments     = {},
			assetName       = "AK74VM",
		},
	},

	item { id = "mp5",    name = "MP5",
		type = T.PRIMARY, rarity = R.COMMON,
		description = "Compact 9mm SMG. Fast rate of fire, controllable recoil.",
		data = {
			weaponSlot      = "primary",
			damage          = 18,
			fireRate        = 0.067,        -- ~900 RPM
			reloadTime      = 2.0,
			maxAmmo         = 30,
			ammoType        = "9mm Rounds",
			fireModes       = { "Semi", "Auto" },
			defaultMode     = 2,

			hipSpread       = 6,            -- SMGs are decent from hip
			adsSpread       = 2.2,
			recoilKick      = 0.22,         -- very controllable
			headshotMulti   = 1.8,
			effectiveRange  = 60,           -- short effective range
			maxRange        = 120,
			pelletCount     = 1,
			pelletSpread    = 0,
			muzzleVelocity  = 400,

			shootSound      = "",
			reloadOutSound  = "",
			reloadInSound   = "",
			shootVolume     = 0.75,

			attachmentSlots = { scope = true, suppressor = true, grip = true },
			attachments     = {},
			assetName       = "MP5VM",
		},
	},

	item { id = "m870",   name = "M870",
		type = T.PRIMARY, rarity = R.COMMON,
		description = "12-gauge pump shotgun. Devastating spread at close range.",
		data = {
			weaponSlot      = "primary",
			damage          = 14,           -- PER PELLET (14 × 8 = 112 max point blank)
			fireRate        = 0.85,         -- pump action cycle time
			reloadTime      = 3.8,          -- loading shells one by one feel
			maxAmmo         = 6,            -- 5+1 tube magazine
			ammoType        = "12G Shells",
			fireModes       = { "Pump" },
			defaultMode     = 1,

			hipSpread       = 4,            -- shotgun base spread is small; pellets do the fanning
			adsSpread       = 2,
			recoilKick      = 0.70,         -- big pump kick
			headshotMulti   = 1.5,          -- less headshot bonus (buckshot spread)
			effectiveRange  = 25,           -- 12G is brutal up close, useless far
			maxRange        = 55,
			pelletCount     = 8,            -- 8 pellets per shell
			pelletSpread    = 5.5,          -- degrees — wide cone
			muzzleVelocity  = 380,

			shootSound      = "",
			reloadOutSound  = "",
			reloadInSound   = "",
			shootVolume     = 1.0,          -- shotguns are LOUD

			attachmentSlots = { scope = false, suppressor = false, grip = true },
			attachments     = {},
			assetName       = "M870VM",
		},
	},

	item { id = "svd",    name = "SVD",
		type = T.PRIMARY, rarity = R.RARE,
		description = "7.62 designated marksman rifle. Surgical at long range.",
		data = {
			weaponSlot      = "primary",
			damage          = 55,
			fireRate        = 0.38,         -- semi-auto DMR, deliberate shots
			reloadTime      = 3.0,
			maxAmmo         = 10,
			ammoType        = "7.62 Rounds",
			fireModes       = { "Semi" },
			defaultMode     = 1,

			hipSpread       = 14,           -- terrible from hip — it's a DMR
			adsSpread       = 0.8,          -- tightest ADS of any weapon
			recoilKick      = 0.60,         -- sharp single kick
			headshotMulti   = 2.5,          -- rewarded for precision
			effectiveRange  = 250,          -- long range king
			maxRange        = 500,
			pelletCount     = 1,
			pelletSpread    = 0,
			muzzleVelocity  = 830,

			shootSound      = "",
			reloadOutSound  = "",
			reloadInSound   = "",
			shootVolume     = 0.95,

			attachmentSlots = { scope = true, suppressor = true, grip = false },
			attachments     = {},
			assetName       = "SVDVM",
		},
	},
}

-- ============================================================
-- WEAPONS — SECONDARY
-- ============================================================
ItemRegistry.WEAPONS_SECONDARY = {

	item { id = "p226",   name = "P226",
		type = T.SECONDARY, rarity = R.COMMON,
		description = "Reliable 9mm sidearm. Quick draw, fast reload.",
		data = {
			weaponSlot      = "secondary",
			damage          = 26,
			fireRate        = 0.18,         -- semi-auto, decent click speed
			reloadTime      = 1.6,
			maxAmmo         = 15,
			ammoType        = "9mm Rounds",
			fireModes       = { "Semi" },
			defaultMode     = 1,

			hipSpread       = 5,
			adsSpread       = 1.8,
			recoilKick      = 0.20,         -- light pistol kick
			headshotMulti   = 2.0,
			effectiveRange  = 50,
			maxRange        = 100,
			pelletCount     = 1,
			pelletSpread    = 0,
			muzzleVelocity  = 375,

			shootSound      = "",
			reloadOutSound  = "",
			reloadInSound   = "",
			shootVolume     = 0.70,

			attachmentSlots = { scope = false, suppressor = true, grip = false },
			attachments     = {},
			assetName       = "P226",
		},
	},

	item { id = "deagle", name = "Desert Eagle",
		type = T.SECONDARY, rarity = R.RARE,
		description = "Hand cannon. .50 AE hits like a truck, kicks like one too.",
		data = {
			weaponSlot      = "secondary",
			damage          = 52,
			fireRate        = 0.32,         -- slow for a pistol
			reloadTime      = 2.1,
			maxAmmo         = 7,
			ammoType        = ".50 AE Rounds",
			fireModes       = { "Semi" },
			defaultMode     = 1,

			hipSpread       = 10,           -- big bore = big hip sway
			adsSpread       = 2.5,
			recoilKick      = 0.65,         -- massive kick
			headshotMulti   = 2.2,
			effectiveRange  = 70,
			maxRange        = 140,
			pelletCount     = 1,
			pelletSpread    = 0,
			muzzleVelocity  = 470,

			shootSound      = "",
			reloadOutSound  = "",
			reloadInSound   = "",
			shootVolume     = 1.0,          -- LOUD

			attachmentSlots = { scope = false, suppressor = false, grip = false },
			attachments     = {},
			assetName       = "DeagleVM",
		},
	},
}

-- ============================================================
-- WEAPONS — MELEE
-- ============================================================
-- data fields:
--   damage      : number
--   range       : number  (studs)
--   swingRate   : number  (seconds between swings)
--   canBlock    : bool
-- ============================================================
ItemRegistry.WEAPONS_MELEE = {

	item { id = "combat_knife", name = "Combat Knife",
		type = T.MELEE, rarity = R.COMMON,
		description = "Standard issue. Fast and quiet.",
		data = {
			damage    = 40,
			range     = 6,
			swingRate = 0.45,
			canBlock  = false,
			assetName = "CombatKnifeVM",
		},
	},

	item { id = "machete",      name = "Machete",
		type = T.MELEE, rarity = R.UNCOMMON,
		description = "Heavy blade. Slower but deals more damage.",
		data = {
			damage    = 65,
			range     = 6.5,
			swingRate = 0.80,
			canBlock  = false,
			assetName = "MacheteVM",
		},
	},

	item { id = "baseball_bat", name = "Baseball Bat",
		type = T.MELEE, rarity = R.COMMON,
		description = "Blunt and brutal. Can stagger enemies.",
		data = {
			damage    = 45,
			range     = 7.5,
			swingRate = 0.70,
			canBlock  = true,
			assetName = "BatVM",
		},
	},

	item { id = "fire_axe",     name = "Fire Axe",
		type = T.MELEE, rarity = R.UNCOMMON,
		description = "Slow, devastating. Also chops doors.",
		data = {
			damage    = 85,
			range     = 8.0,
			swingRate = 1.0,
			canBlock  = false,
			assetName = "FireAxeVM",
			anim1     = "rbxassetid://97813475569431",
			anim2     = "rbxassetid://97813475569431",
		},
	},
}

-- ============================================================
-- WEAPONS — GRENADES
-- ============================================================
ItemRegistry.WEAPONS_GRENADES = {

	item { id = "frag_grenade",  name = "Frag Grenade",
		type = T.GRENADE, rarity = R.UNCOMMON, maxStack = 3,
		description = "Cook it. Throw it. Run.",
		data = {
			fuseTime    = 4,
			blastRadius = 12,
			damage      = 100,
			grenadeType = "frag",
			assetName   = "FragGrenade",
		},
	},

	item { id = "smoke_grenade", name = "Smoke Grenade",
		type = T.GRENADE, rarity = R.COMMON, maxStack = 3,
		description = "Thick white smoke. Provides cover.",
		data = {
			fuseTime    = 1,
			blastRadius = 0,
			damage      = 0,
			grenadeType = "smoke",
			assetName   = "SmokeGrenade",
		},
	},

	item { id = "flashbang",     name = "Flashbang",
		type = T.GRENADE, rarity = R.UNCOMMON, maxStack = 3,
		description = "Blinds and deafens. Works on you too.",
		data = {
			fuseTime    = 2,
			blastRadius = 10,
			damage      = 0,
			grenadeType = "flashbang",
			assetName   = "Flashbang",
		},
	},

	item { id = "molotov",       name = "Molotov Cocktail",
		type = T.GRENADE, rarity = R.UNCOMMON, maxStack = 2,
		description = "Burns the area on impact. Denies space.",
		data = {
			fuseTime    = 0,
			blastRadius = 8,
			damage      = 15,
			grenadeType = "molotov",
			assetName   = "Molotov",
		},
	},
}

-- ============================================================
-- ATTACHMENTS
-- ============================================================
ItemRegistry.ATTACHMENTS = {

	-- Scopes
	item { id = "iron_sights",  name = "Iron Sights",
		type = T.SCOPE, rarity = R.COMMON,
		description = "Default sights. No magnification.",
		data = {
			attachType  = "scope",
			zoomFOV     = 45,
			aimSpread   = 1.0,
			reticleId   = "",
			reticleSize = 1,
		},
	},

	item { id = "red_dot",      name = "Red Dot Sight",
		type = T.SCOPE, rarity = R.COMMON,
		description = "Fast target acquisition. No magnification.",
		data = {
			attachType  = "scope",
			zoomFOV     = 42,
			aimSpread   = 0.9,
			reticleId   = "",
			reticleSize = 1,
		},
	},

	item { id = "acog",         name = "ACOG",
		type = T.SCOPE, rarity = R.UNCOMMON,
		description = "4x magnification. Good for mid-long range.",
		data = {
			attachType  = "scope",
			zoomFOV     = 25,
			aimSpread   = 0.75,
			reticleId   = "",
			reticleSize = 1,
		},
	},

	item { id = "sniper_scope", name = "Sniper Scope",
		type = T.SCOPE, rarity = R.RARE,
		description = "8x magnification. For long range engagements.",
		data = {
			attachType  = "scope",
			zoomFOV     = 15,
			aimSpread   = 0.6,
			reticleId   = "",
			reticleSize = 1.2,
		},
	},

	-- Suppressors
	item { id = "suppressor_9mm",  name = "9mm Suppressor",
		type = T.SUPPRESSOR, rarity = R.UNCOMMON,
		description = "Reduces muzzle report. Slight velocity loss.",
		data = {
			attachType    = "suppressor",
			damageMulti   = 0.92,
			suppressedSnd = "",
		},
	},

	item { id = "suppressor_556",  name = "5.56 Suppressor",
		type = T.SUPPRESSOR, rarity = R.UNCOMMON,
		description = "NATO suppressor. Keeps you off the radar.",
		data = {
			attachType    = "suppressor",
			damageMulti   = 0.90,
			suppressedSnd = "",
		},
	},

	item { id = "suppressor_762",  name = "7.62 Suppressor",
		type = T.SUPPRESSOR, rarity = R.RARE,
		description = "Heavy calibre suppressor. Still hits hard.",
		data = {
			attachType    = "suppressor",
			damageMulti   = 0.88,
			suppressedSnd = "",
		},
	},

	-- Grips
	item { id = "vertical_grip",   name = "Vertical Grip",
		type = T.GRIP, rarity = R.COMMON,
		description = "Reduces muzzle climb. Steadier on full auto.",
		data = {
			attachType  = "grip",
			recoilMulti = 0.75,
			aimSpread   = 0.9,
		},
	},

	item { id = "angled_grip",     name = "Angled Grip",
		type = T.GRIP, rarity = R.UNCOMMON,
		description = "Faster ADS. Slight recoil reduction.",
		data = {
			attachType  = "grip",
			recoilMulti = 0.85,
			aimSpread   = 0.85,
		},
	},
}

-- ============================================================
-- GEAR — HELMETS
-- ============================================================
ItemRegistry.GEAR_HELMETS = {

	item { id = "baseball_cap",   name = "Baseball Cap",
		type = T.HELMET, rarity = R.COMMON,
		description = "No protection. Keeps the sun out.",
		data = { armorRating = 0,  slot = "helmet", clothingId = "" },
	},

	item { id = "helmet_lvl1",    name = "Helmet (Level 1)",
		type = T.HELMET, rarity = R.COMMON,
		description = "Basic ballistic helmet. Some protection.",
		data = { armorRating = 15, slot = "helmet", clothingId = "" },
	},

	item { id = "helmet_lvl2",    name = "Helmet (Level 2)",
		type = T.HELMET, rarity = R.UNCOMMON,
		description = "Military helmet with visor.",
		data = { armorRating = 30, slot = "helmet", clothingId = "" },
	},

	item { id = "helmet_lvl3",    name = "Helmet (Level 3)",
		type = T.HELMET, rarity = R.RARE,
		description = "Full coverage. Rated for rifle rounds.",
		data = { armorRating = 50, slot = "helmet", clothingId = "" },
	},
}

-- ============================================================
-- GEAR — PLATE CARRIERS
-- ============================================================
ItemRegistry.GEAR_CARRIERS = {

	item { id = "chest_rig",      name = "Chest Rig",
		type = T.CARRIER, rarity = R.COMMON,
		description = "Light rig. Adds 2 pouch slots. No hard plates.",
		data = { armorRating = 0,  slot = "carrier", pouchSlots = 2, clothingId = "" },
	},

	item { id = "carrier_lvl1",   name = "Plate Carrier (Level 1)",
		type = T.CARRIER, rarity = R.COMMON,
		description = "Soft armour insert. Adds 3 pouch slots.",
		data = { armorRating = 20, slot = "carrier", pouchSlots = 3, clothingId = "" },
	},

	item { id = "carrier_lvl2",   name = "Plate Carrier (Level 2)",
		type = T.CARRIER, rarity = R.UNCOMMON,
		description = "Ceramic plates. Adds 4 pouch slots.",
		data = { armorRating = 40, slot = "carrier", pouchSlots = 4, clothingId = "" },
	},

	item { id = "carrier_lvl3",   name = "Plate Carrier (Level 3)",
		type = T.CARRIER, rarity = R.RARE,
		description = "Steel plates. Maximum protection, adds 5 pouch slots.",
		data = { armorRating = 60, slot = "carrier", pouchSlots = 5, clothingId = "" },
	},
}

-- ============================================================
-- GEAR — CLOTHING (chest, legs, feet)
-- ============================================================
ItemRegistry.GEAR_CLOTHING = {

	-- Chest
	item { id = "tshirt",         name = "T-Shirt",
		type = T.CHEST, rarity = R.COMMON,
		description = "Civilian clothing.",
		data = { slot = "chest", speedMulti = 1.0, stealthBonus = 0, clothingId = "" },
	},

	item { id = "military_jacket", name = "Military Jacket",
		type = T.CHEST, rarity = R.UNCOMMON,
		description = "Light camo. Small stealth bonus.",
		data = { slot = "chest", speedMulti = 1.0, stealthBonus = 5, clothingId = "" },
	},

	item { id = "ghillie_top",    name = "Ghillie Top",
		type = T.CHEST, rarity = R.RARE,
		description = "Heavy but near invisible in vegetation.",
		data = { slot = "chest", speedMulti = 0.92, stealthBonus = 25, clothingId = "" },
	},

	-- Legs
	item { id = "jeans",          name = "Jeans",
		type = T.LEGS, rarity = R.COMMON,
		description = "Civilian pants.",
		data = { slot = "legs", speedMulti = 1.0, stealthBonus = 0, clothingId = "" },
	},

	item { id = "military_pants", name = "Military Pants",
		type = T.LEGS, rarity = R.UNCOMMON,
		description = "Durable and practical.",
		data = { slot = "legs", speedMulti = 1.0, stealthBonus = 3, clothingId = "" },
	},

	item { id = "ghillie_legs",   name = "Ghillie Legs",
		type = T.LEGS, rarity = R.RARE,
		description = "Lower half to match ghillie top.",
		data = { slot = "legs", speedMulti = 0.92, stealthBonus = 25, clothingId = "" },
	},

	-- Feet
	item { id = "sneakers",       name = "Sneakers",
		type = T.FEET, rarity = R.COMMON,
		description = "Quiet soles. Slight stealth benefit.",
		data = { slot = "feet", speedMulti = 1.0, stealthBonus = 5, clothingId = "" },
	},

	item { id = "boots",          name = "Combat Boots",
		type = T.FEET, rarity = R.COMMON,
		description = "Durable. No stealth bonus.",
		data = { slot = "feet", speedMulti = 0.97, stealthBonus = 0, clothingId = "" },
	},

	item { id = "tactical_boots", name = "Tactical Boots",
		type = T.FEET, rarity = R.UNCOMMON,
		description = "Balances speed and protection.",
		data = { slot = "feet", speedMulti = 1.0, stealthBonus = 2, clothingId = "" },
	},
}

-- ============================================================
-- CONSUMABLES
-- ============================================================
ItemRegistry.CONSUMABLES = {

	item { id = "bandage",     name = "Bandage",
		type = T.HEAL, rarity = R.COMMON, maxStack = 5,
		description = "Stops bleeding. Restores a small amount of health.",
		data = { healAmount = 20 },
	},

	item { id = "medkit",      name = "Med Kit",
		type = T.HEAL, rarity = R.UNCOMMON,
		description = "Full field medical kit. Restores significant health.",
		data = { healAmount = 75 },
	},

	item { id = "painkillers", name = "Painkillers",
		type = T.HEAL, rarity = R.COMMON, maxStack = 3,
		description = "Dull the pain. Gradual health recovery.",
		data = { healAmount = 35 },
	},

	item { id = "water_bottle", name = "Water Bottle",
		type = T.CONSUMABLE, rarity = R.COMMON, maxStack = 3,
		description = "Restores thirst.",
		data = { waterRestore = 40 },
	},

	item { id = "canteen",     name = "Canteen",
		type = T.CONSUMABLE, rarity = R.COMMON,
		description = "Larger water supply. Restores more thirst.",
		data = { waterRestore = 80 },
	},

	item { id = "ration",      name = "Ration Pack",
		type = T.CONSUMABLE, rarity = R.COMMON, maxStack = 3,
		description = "Military ration. Restores hunger.",
		data = { hungerRestore = 50 },
	},
}

-- ============================================================
-- AMMO
-- ============================================================
ItemRegistry.AMMO = {
	item { id = "ammo_9mm",   name = "9mm Rounds",
		type = T.AMMO, rarity = R.COMMON, maxStack = 60,
		description = "9mm pistol and SMG ammunition." },

	item { id = "ammo_556",   name = "5.56 Rounds",
		type = T.AMMO, rarity = R.COMMON, maxStack = 60,
		description = "NATO 5.56 rifle ammunition." },

	item { id = "ammo_762",   name = "7.62 Rounds",
		type = T.AMMO, rarity = R.COMMON, maxStack = 60,
		description = "7.62 rifle and DMR ammunition." },

	item { id = "ammo_50ae",  name = ".50 AE Rounds",
		type = T.AMMO, rarity = R.UNCOMMON, maxStack = 35,
		description = "Heavy pistol rounds for the Desert Eagle." },

	item { id = "ammo_12g",   name = "12G Shells",
		type = T.AMMO, rarity = R.COMMON, maxStack = 30,
		description = "12 gauge shotgun shells." },
}

-- ============================================================
-- LOOKUP BY ID
-- ============================================================
local _byId = {}

local function register(list)
	for _, entry in ipairs(list) do
		if entry.id then
			_byId[entry.id] = entry
		end
	end
end

register(ItemRegistry.WEAPONS_PRIMARY)
register(ItemRegistry.WEAPONS_SECONDARY)
register(ItemRegistry.WEAPONS_MELEE)
register(ItemRegistry.WEAPONS_GRENADES)
register(ItemRegistry.ATTACHMENTS)
register(ItemRegistry.GEAR_HELMETS)
register(ItemRegistry.GEAR_CARRIERS)
register(ItemRegistry.GEAR_CLOTHING)
register(ItemRegistry.CONSUMABLES)
register(ItemRegistry.AMMO)

function ItemRegistry.Get(id)
	local src = _byId[id]
	if not src then return nil end
	local copy = {}
	for k, v in pairs(src) do
		copy[k] = v
	end
	copy.data = {}
	for k, v in pairs(src.data) do
		copy.data[k] = v
	end
	if copy.data.attachments then
		copy.data.attachments = {}
	end
	return copy
end

function ItemRegistry.GetBySlot(slot)
	local results = {}
	for _, entry in pairs(_byId) do
		if entry.data and entry.data.slot == slot then
			table.insert(results, ItemRegistry.Get(entry.id))
		end
	end
	return results
end

print("[ItemRegistry] Loaded. Items registered: " .. (function()
	local n = 0; for _ in pairs(_byId) do n = n + 1 end; return n
end)())

return ItemRegistry