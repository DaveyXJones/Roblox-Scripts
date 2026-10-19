--==================================================
-- LootSpawnData
-- ModuleScript ? ReplicatedStorage
--
-- All spawn point definitions in one place.
-- Add new points here without touching server logic.
--
-- SPAWN FIELDS:
--   id       : string   unique identifier (used for respawn tracking)
--   label    : string   human-readable name (for debugging)
--   pos      : Vector3  exact world position
--   type     : string   "ground" or "chest"
--   tier     : string   "civilian" / "mid" / "military"
--   context  : string   LootTableModule.CONTEXT value
--                       controls which items can roll here
--   containerStyle    : optional style id for chest spawns
--   containerLabel    : optional display name for searchable containers
--   searchDuration    : optional hold time when searching the container
--   containerAssetName: optional custom world model name from ReplicatedStorage
--   searchSoundId     : optional local search sound asset id
--==================================================

local LootSpawnData = {}

local T = {
	CIVILIAN = "civilian",
	MID      = "mid",
	MILITARY = "military",
}

local C = {
	FOOD        = "food",
	WATER       = "water",
	MEDICAL     = "medical",
	AMMO_PISTOL = "ammo_pistol",
	AMMO_AR     = "ammo_ar",
	AMMO_ANY    = "ammo_any",
	WEAPON      = "weapon",
	GEAR        = "gear",
	RANDOM      = "random",
}

-- ============================================================
-- SPAWN POINTS
-- ============================================================
LootSpawnData.SPAWNS = {

	-- --------------------------------------------------------
	-- HILLTOP CACHE
	-- --------------------------------------------------------
	{
		id      = "hilltop_cache_01",
		label   = "Hilltop Cache",
		pos     = Vector3.new(780.341, 119.107, -1650.963),
		type    = "ground",
		tier    = T.CIVILIAN,
		context = C.FOOD,
	},

	-- --------------------------------------------------------
	-- MILITARY OUTPOST / SHIPPING FACTORY
	-- --------------------------------------------------------
	{
		id      = "mil_tent_front_01",
		label   = "In Front of Military Tent",
		pos     = Vector3.new(1423.958, 19.567, -1584.515),
		type    = "ground",
		tier    = T.MILITARY,
		context = C.AMMO_PISTOL,
	},
	{
		id      = "mil_tent_inside_01",
		label   = "Inside Military Tent",
		pos     = Vector3.new(1385.858, 19.433, -1537.515),
		type    = "chest",
		tier    = T.MILITARY,
		context = C.AMMO_AR,
		containerStyle = "ammo_crate",
		containerLabel = "Ammo Crate",
		searchDuration = 1.55,
	},
	{
		id      = "mil_ammo_random_01",
		label   = "Military - Random Ammo",
		pos     = Vector3.new(1450.073, 19.299, -1431.138),
		type    = "ground",
		tier    = T.MILITARY,
		context = C.AMMO_ANY,
	},
	{
		id      = "shipping_bandage_01",
		label   = "Shipping - Bandage",
		pos     = Vector3.new(1535.492, 19.339, -1414.916),
		type    = "ground",
		tier    = T.MID,
		context = C.MEDICAL,
	},
	{
		id      = "broken_truck_food_01",
		label   = "Next to Broken Down Truck",
		pos     = Vector3.new(1578.27, 19.299, -1532.994),
		type    = "ground",
		tier    = T.MID,
		context = C.FOOD,
	},
	{
		id      = "guardshack_room1_01",
		label   = "Inside GuardShack - Room 1",
		pos     = Vector3.new(1541.604, 23.005, -1608.254),
		type    = "chest",
		tier    = T.MILITARY,
		context = C.AMMO_ANY,
		containerStyle = "ammo_crate",
		containerLabel = "Guard Shack Ammo Crate",
		searchDuration = 1.55,
	},
	{
		id      = "guardshack_room2_01",
		label   = "GuardShack - Next Room",
		pos     = Vector3.new(1519.467, 23.005, -1605.656),
		type    = "chest",
		tier    = T.MILITARY,
		context = C.FOOD,
		containerStyle = "supply_crate",
		containerLabel = "Guard Shack Supply Crate",
		searchDuration = 1.45,
	},
	{
		id      = "pavilion_water_01",
		label   = "Under Pavilion - Water Bottle",
		pos     = Vector3.new(1701.569, 19.49, -1652.631),
		type    = "ground",
		tier    = T.MID,
		context = C.WATER,
	},
	{
		id      = "warehouse_wing1_01",
		label   = "Shipping Warehouse - Wing 1",
		pos     = Vector3.new(1559.239, 38.71, -1801.936),
		type    = "chest",
		tier    = T.MID,
		context = C.RANDOM,
		containerStyle = "box_pile",
		containerLabel = "Warehouse Boxes",
		searchDuration = 1.4,
	},
	{
		id      = "warehouse_wing2_01",
		label   = "Shipping Warehouse - Wing 2",
		pos     = Vector3.new(1556.448, 38.737, -1915.333),
		type    = "chest",
		tier    = T.MID,
		context = C.RANDOM,
		containerStyle = "box_pile",
		containerLabel = "Warehouse Boxes",
		searchDuration = 1.4,
	},
	{
		id      = "pier_01",
		label   = "Pier - End 1",
		pos     = Vector3.new(1786.957, 19.485, -1875.508),
		type    = "ground",
		tier    = T.MID,
		context = C.RANDOM,
	},
	{
		id      = "pier_02",
		label   = "Pier - End 2",
		pos     = Vector3.new(1633.223, 19.485, -1999.167),
		type    = "ground",
		tier    = T.MID,
		context = C.RANDOM,
	},
	{
		id      = "pier_03",
		label   = "Next Pier",
		pos     = Vector3.new(1792.958, 19.485, -1999.495),
		type    = "ground",
		tier    = T.MID,
		context = C.RANDOM,
	},

	-- --------------------------------------------------------
	-- THE BRIDGE
	-- --------------------------------------------------------
	{
		id      = "bridge_bus_01",
		label   = "Bus on the Bridge",
		pos     = Vector3.new(868.349, 88.998, -1458.516),
		type    = "ground",
		tier    = T.CIVILIAN,
		context = C.FOOD,
	},
	{
		id      = "bridge_police_car_01",
		label   = "Next to Police Car",
		pos     = Vector3.new(875.35, 101.429, -1217.777),
		type    = "ground",
		tier    = T.CIVILIAN,
		context = C.AMMO_PISTOL,
	},
	{
		id      = "bridge_petro_truck_01",
		label   = "Behind Petroleum Truck",
		pos     = Vector3.new(908.171, 101.429, -1080.047),
		type    = "ground",
		tier    = T.CIVILIAN,
		context = C.FOOD,
	},
	{
		id      = "bridge_ambulance_01",
		label   = "Ambulance / Police Cars - Bandage",
		pos     = Vector3.new(910.171, 101.429, -923.935),
		type    = "ground",
		tier    = T.CIVILIAN,
		context = C.MEDICAL,
	},
	{
		id      = "bridge_ambulance_02",
		label   = "Ambulance Cluster - Random",
		pos     = Vector3.new(924.798, 101.429, -941.935),
		type    = "ground",
		tier    = T.CIVILIAN,
		context = C.RANDOM,
	},
	{
		id      = "bridge_semi_01",
		label   = "Abandoned Semi Truck",
		pos     = Vector3.new(920.171, 101.429, -809.935),
		type    = "ground",
		tier    = T.CIVILIAN,
		context = C.FOOD,
	},
	{
		id      = "bridge_humvee_01",
		label   = "Next to Humvee",
		pos     = Vector3.new(867.096, 101.429, -722.934),
		type    = "ground",
		tier    = T.MID,
		context = C.AMMO_AR,
	},
	{
		id      = "bridge_divider_townside_01",
		label   = "Divider Bridge - Town Side",
		pos     = Vector3.new(893.4, 75.372, -347.997),
		type    = "ground",
		tier    = T.CIVILIAN,
		context = C.RANDOM,
	},

	-- --------------------------------------------------------
	-- CITY CENTER
	-- --------------------------------------------------------
	{
		id      = "city_store_chest_01",
		label   = "Store - Center City",
		pos     = Vector3.new(1176.529, 48.237, -275.17),
		type    = "chest",
		tier    = T.MID,
		context = C.RANDOM,
		containerStyle = "supply_crate",
		containerLabel = "Store Backroom Crate",
		searchDuration = 1.45,
	},
	{
		id      = "city_warthog_chest_01",
		label   = "Warthog Military - Center City",
		pos     = Vector3.new(1101.208, 46.625, 53.078),
		type    = "chest",
		tier    = T.MILITARY,
		context = C.AMMO_ANY,
		containerStyle = "weapon_case",
		containerLabel = "Warthog Weapons Case",
		searchDuration = 1.9,
	},
	{
		id      = "city_coffee_01",
		label   = "Coffee Shop - City",
		pos     = Vector3.new(1049.292, 48.144, 289.832),
		type    = "ground",
		tier    = T.CIVILIAN,
		context = C.FOOD,
	},
	{
		id      = "city_coffee_02",
		label   = "Coffee Shop 2 - City",
		pos     = Vector3.new(1014.583, 48.346, 312.04),
		type    = "ground",
		tier    = T.CIVILIAN,
		context = C.FOOD,
	},
	{
		id      = "city_taxi_dealership_01",
		label   = "Taxi by Dealership",
		pos     = Vector3.new(1600.858, 19.222, -334.297),
		type    = "ground",
		tier    = T.CIVILIAN,
		context = C.RANDOM,
	},
	{
		id      = "city_restaurant_01",
		label   = "Restaurant in Town",
		pos     = Vector3.new(1297.024, 48.277, 150.474),
		type    = "ground",
		tier    = T.CIVILIAN,
		context = C.FOOD,
	},
	{
		id      = "city_restaurant_02",
		label   = "Restaurant 2",
		pos     = Vector3.new(1265.951, 53.706, 140.998),
		type    = "ground",
		tier    = T.CIVILIAN,
		context = C.FOOD,
	},
	{
		id      = "city_restaurant_entrance_01",
		label   = "Restaurant Entrance",
		pos     = Vector3.new(1294.234, 51.3, 98.459),
		type    = "ground",
		tier    = T.CIVILIAN,
		context = C.RANDOM,
	},
	{
		id      = "city_office_downtown_01",
		label   = "Office Downtown",
		pos     = Vector3.new(513.205, 75.459, 102.068),
		type    = "chest",
		tier    = T.MID,
		context = C.RANDOM,
		containerStyle = "box_pile",
		containerLabel = "Office Storage Boxes",
		searchDuration = 1.35,
	},

	-- --------------------------------------------------------
	-- TOWNSIDE
	-- --------------------------------------------------------
	{
		id      = "town_bench_01",
		label   = "Bench in Townside",
		pos     = Vector3.new(784.15, 50.371, 418.419),
		type    = "ground",
		tier    = T.CIVILIAN,
		context = C.RANDOM,
	},
	{
		id      = "town_gas_station_01",
		label   = "Gas Station",
		pos     = Vector3.new(821.354, 19.262, 628.107),
		type    = "chest",
		tier    = T.MID,
		context = C.RANDOM,
		containerStyle = "supply_crate",
		containerLabel = "Gas Station Supply Crate",
		searchDuration = 1.45,
	},
	{
		id      = "town_diner_01",
		label   = "Diner in Town",
		pos     = Vector3.new(364.114, 22.85, 62.139),
		type    = "ground",
		tier    = T.CIVILIAN,
		context = C.FOOD,
	},
	{
		id      = "town_bar_01",
		label   = "Bar in Town",
		pos     = Vector3.new(661.366, 75.412, -285.693),
		type    = "ground",
		tier    = T.CIVILIAN,
		context = C.RANDOM,
	},
	{
		id      = "town_bar_pool_01",
		label   = "Bar - Pool Table",
		pos     = Vector3.new(691.534, 78.636, -227.607),
		type    = "chest",
		tier    = T.MID,
		context = C.RANDOM,
		containerStyle = "duffel_bag",
		containerLabel = "Stashed Gym Bag",
		searchDuration = 1.3,
	},
	{
		id      = "town_bar_upstairs_01",
		label   = "Bar - Table Upstairs",
		pos     = Vector3.new(680.391, 99.712, -307.303),
		type    = "ground",
		tier    = T.CIVILIAN,
		context = C.RANDOM,
	},
	{
		id      = "town_bar_upstairs_02",
		label   = "Bar - Floor Upstairs",
		pos     = Vector3.new(706.863, 95.293, -323.898),
		type    = "ground",
		tier    = T.CIVILIAN,
		context = C.AMMO_PISTOL,
	},
	{
		id      = "town_pickup_truck_01",
		label   = "Random Pickup Truck",
		pos     = Vector3.new(454.399, 43.442, -438.403),
		type    = "ground",
		tier    = T.CIVILIAN,
		context = C.RANDOM,
	},

	-- --------------------------------------------------------
	-- TOWN HALL
	-- --------------------------------------------------------
	{
		id      = "townhall_chest_01",
		label   = "Town Hall",
		pos     = Vector3.new(82.45, 20.605, -181.598),
		type    = "chest",
		tier    = T.MID,
		context = C.RANDOM,
		containerStyle = "box_pile",
		containerLabel = "Town Hall Records Boxes",
		searchDuration = 1.35,
	},
	{
		id      = "townhall_front_01",
		label   = "Town Hall Front",
		pos     = Vector3.new(17.168, 20.605, -268.977),
		type    = "ground",
		tier    = T.CIVILIAN,
		context = C.RANDOM,
	},
	{
		id      = "townhall_barricade_01",
		label   = "Town Hall Barricade 1",
		pos     = Vector3.new(143.557, 22.837, -308.959),
		type    = "ground",
		tier    = T.MID,
		context = C.AMMO_PISTOL,
	},
	{
		id      = "townhall_barricade_02",
		label   = "Town Hall Barricade 2",
		pos     = Vector3.new(138.529, 22.79, -272.029),
		type    = "ground",
		tier    = T.MID,
		context = C.AMMO_PISTOL,
	},
	{
		id      = "townhall_barricade_03",
		label   = "Town Hall Barricade 3",
		pos     = Vector3.new(136.696, 22.837, -334.112),
		type    = "ground",
		tier    = T.MID,
		context = C.AMMO_ANY,
	},
	{
		id      = "townhall_pickup_truck_01",
		label   = "Back of Pickup Truck",
		pos     = Vector3.new(153.7, 23.207, -542.184),
		type    = "ground",
		tier    = T.CIVILIAN,
		context = C.RANDOM,
	},

	-- --------------------------------------------------------
	-- FIRE DEPARTMENT
	-- --------------------------------------------------------
	{
		id      = "fire_dept_01",
		label   = "Fire Department",
		pos     = Vector3.new(2.978, 19.47, -559.5),
		type    = "ground",
		tier    = T.MID,
		context = C.MEDICAL,
	},
	{
		id      = "fire_dept_02",
		label   = "Firehouse 2",
		pos     = Vector3.new(31.758, 19.47, -626.3),
		type    = "ground",
		tier    = T.MID,
		context = C.MEDICAL,
	},

	-- --------------------------------------------------------
	-- MILITARY ROADBLOCK
	-- --------------------------------------------------------
	{
		id      = "mil_roadblock_chest_01",
		label   = "Military Roadblock - Chest",
		pos     = Vector3.new(1538.536, 19.222, -513.84),
		type    = "chest",
		tier    = T.MILITARY,
		context = C.AMMO_AR,
		containerStyle = "ammo_crate",
		containerLabel = "Roadblock Ammo Crate",
		searchDuration = 1.55,
	},
	{
		id      = "mil_roadblock_truck_01",
		label   = "Military Roadblock - Covered Truck",
		pos     = Vector3.new(1537.431, 19.222, -541.814),
		type    = "ground",
		tier    = T.MILITARY,
		context = C.AMMO_ANY,
	},
	{
		id      = "mil_roadblock_tank_01",
		label   = "Tank Behind Roadblock",
		pos     = Vector3.new(1677.302, 19.222, -632.417),
		type    = "ground",
		tier    = T.MILITARY,
		context = C.AMMO_AR,
	},

	-- --------------------------------------------------------
	-- HOSPITAL
	-- --------------------------------------------------------
	{
		id      = "hospital_ground_01",
		label   = "Hospital",
		pos     = Vector3.new(1449.164, 21.022, 933.764),
		type    = "ground",
		tier    = T.MID,
		context = C.MEDICAL,
	},
	{
		id      = "hospital_table_01",
		label   = "Table in Hospital",
		pos     = Vector3.new(1519.824, 23.841, 989.424),
		type    = "ground",
		tier    = T.MID,
		context = C.MEDICAL,
	},
	{
		id      = "hospital_chest_01",
		label   = "Hospital Chest",
		pos     = Vector3.new(1454.202, 21.022, 1014.179),
		type    = "chest",
		tier    = T.MID,
		context = C.MEDICAL,
		containerStyle = "medical_crate",
		containerLabel = "Hospital Medical Crate",
		searchDuration = 1.75,
	},
	{
		id      = "hospital_ambulance_01",
		label   = "Ambulance at Side of Hospital",
		pos     = Vector3.new(1266.624, 19.397, 1118.274),
		type    = "ground",
		tier    = T.MID,
		context = C.MEDICAL,
	},

	-- --------------------------------------------------------
	-- LIBRARY
	-- --------------------------------------------------------
	{
		id      = "library_chest_01",
		label   = "Library in Town - Chest",
		pos     = Vector3.new(853.688, 19.974, 997.622),
		type    = "chest",
		tier    = T.CIVILIAN,
		context = C.RANDOM,
		containerStyle = "box_pile",
		containerLabel = "Library Storage Boxes",
		searchDuration = 1.35,
	},
	{
		id      = "library_front_01",
		label   = "Front of Library",
		pos     = Vector3.new(841.578, 19.974, 987.996),
		type    = "ground",
		tier    = T.CIVILIAN,
		context = C.RANDOM,
	},

	-- --------------------------------------------------------
	-- SCHOOL
	-- --------------------------------------------------------
	{
		id      = "school_level2_01",
		label   = "School - Level 2",
		pos     = Vector3.new(757.037, 46.122, 983.71),
		type    = "ground",
		tier    = T.CIVILIAN,
		context = C.RANDOM,
	},
	{
		id      = "school_level2_room_01",
		label   = "School - Level 2 Room",
		pos     = Vector3.new(833.394, 46.122, 996.559),
		type    = "ground",
		tier    = T.CIVILIAN,
		context = C.RANDOM,
	},
	{
		id      = "school_nurses_01",
		label   = "School - Nurses Office",
		pos     = Vector3.new(705.078, 48.163, 915.42),
		type    = "ground",
		tier    = T.CIVILIAN,
		context = C.MEDICAL,
	},
	{
		id      = "school_nurses_desk_01",
		label   = "School - Nurses Office Desk",
		pos     = Vector3.new(716.724, 48.8, 906.851),
		type    = "ground",
		tier    = T.CIVILIAN,
		context = C.MEDICAL,
	},
	{
		id      = "school_computer_lab_01",
		label   = "School - Computer Lab",
		pos     = Vector3.new(757.25, 46.122, 824.786),
		type    = "chest",
		tier    = T.CIVILIAN,
		context = C.RANDOM,
		containerStyle = "box_pile",
		containerLabel = "Computer Lab Storage Boxes",
		searchDuration = 1.35,
	},
	{
		id      = "school_cafeteria_01",
		label   = "School - Cafeteria",
		pos     = Vector3.new(801.85, 22.525, 906.837),
		type    = "ground",
		tier    = T.CIVILIAN,
		context = C.FOOD,
	},
	{
		id      = "school_cafeteria_02",
		label   = "School - Cafeteria 2",
		pos     = Vector3.new(809.353, 19.974, 934.888),
		type    = "ground",
		tier    = T.CIVILIAN,
		context = C.FOOD,
	},
	{
		id      = "school_hallway_01",
		label   = "School - Hallway",
		pos     = Vector3.new(746.049, 19.974, 927.039),
		type    = "ground",
		tier    = T.CIVILIAN,
		context = C.RANDOM,
	},
	{
		id      = "school_classroom_01",
		label   = "School - Classroom",
		pos     = Vector3.new(700.913, 19.974, 923.825),
		type    = "ground",
		tier    = T.CIVILIAN,
		context = C.RANDOM,
	},

	-- --------------------------------------------------------
	-- BRIDGE UNDERPASS / STRANDED VEHICLES
	-- --------------------------------------------------------
	{
		id      = "truck_under_bridge_01",
		label   = "Truck Under Bridge",
		pos     = Vector3.new(710.636, 19.299, -1373.761),
		type    = "ground",
		tier    = T.CIVILIAN,
		context = C.RANDOM,
	},
	{
		id      = "semi_stallout_01",
		label   = "Semi Truck Stall Out",
		pos     = Vector3.new(783.687, 61.597, -1561.775),
		type    = "ground",
		tier    = T.CIVILIAN,
		context = C.RANDOM,
	},

	-- --------------------------------------------------------
	-- FARM / OUTSKIRTS
	-- --------------------------------------------------------
	{
		id      = "farm_outhouse_01",
		label   = "Outhouse",
		pos     = Vector3.new(468.354, 19.267, -1965.609),
		type    = "ground",
		tier    = T.CIVILIAN,
		context = C.RANDOM,
	},
	{
		id      = "farm_01",
		label   = "Farm",
		pos     = Vector3.new(444.21, 19.267, -1836.631),
		type    = "ground",
		tier    = T.CIVILIAN,
		context = C.FOOD,
	},

	-- --------------------------------------------------------
	-- PRISON
	-- --------------------------------------------------------
	{
		id      = "prison_radiotower_01",
		label   = "Prison - Radio Tower",
		pos     = Vector3.new(-323.367, 19.656, 405.934),
		type    = "ground",
		tier    = T.MID,
		context = C.RANDOM,
	},
	{
		id      = "prison_barracks_chest_01",
		label   = "Prison - Military Barracks Chest",
		pos     = Vector3.new(-307.835, 19.81, 452.836),
		type    = "chest",
		tier    = T.MILITARY,
		context = C.AMMO_AR,
		containerStyle = "ammo_crate",
		containerLabel = "Barracks Ammo Crate",
		searchDuration = 1.55,
	},
	{
		id      = "prison_barracks_01",
		label   = "Prison - Military Barracks",
		pos     = Vector3.new(-391.52, 19.799, 417.717),
		type    = "ground",
		tier    = T.MILITARY,
		context = C.AMMO_ANY,
	},
	{
		id      = "prison_barracks_02",
		label   = "Prison - Military Barracks 2",
		pos     = Vector3.new(-394.828, 19.799, 436.823),
		type    = "ground",
		tier    = T.MILITARY,
		context = C.GEAR,
	},
	{
		id      = "prison_office_01",
		label   = "Prison - Office",
		pos     = Vector3.new(-447.987, 20.162, 387.124),
		type    = "ground",
		tier    = T.MID,
		context = C.RANDOM,
	},
	{
		id      = "prison_office_02",
		label   = "Prison - Office Upper",
		pos     = Vector3.new(-346.638, 25.599, 811.289),
		type    = "ground",
		tier    = T.MID,
		context = C.RANDOM,
	},
	{
		id      = "prison_foodcourt_01",
		label   = "Prison - Food Court",
		pos     = Vector3.new(-531.971, 21.499, 655.096),
		type    = "ground",
		tier    = T.CIVILIAN,
		context = C.FOOD,
	},
	{
		id      = "prison_foodcourt_02",
		label   = "Prison - Food Court 2",
		pos     = Vector3.new(-549.318, 21.499, 677.345),
		type    = "ground",
		tier    = T.CIVILIAN,
		context = C.FOOD,
	},
	{
		id      = "prison_holding_cell_01",
		label   = "Prison - Holding Cell",
		pos     = Vector3.new(-632.068, 18.799, 671.903),
		type    = "chest",
		tier    = T.MID,
		context = C.RANDOM,
		containerStyle = "duffel_bag",
		containerLabel = "Prisoner Stash Bag",
		searchDuration = 1.3,
	},
	{
		id      = "prison_level2_01",
		label   = "Prison - Level 2",
		pos     = Vector3.new(-545.937, 36.099, 683.996),
		type    = "ground",
		tier    = T.MID,
		context = C.RANDOM,
	},
	{
		id      = "prison_topfloor_01",
		label   = "Prison - Top Floor",
		pos     = Vector3.new(-514.048, 49.099, 684.86),
		type    = "chest",
		tier    = T.MILITARY,
		context = C.AMMO_AR,
		containerStyle = "ammo_crate",
		containerLabel = "Top Floor Ammo Crate",
		searchDuration = 1.55,
	},
	{
		id      = "prison_topfloor_02",
		label   = "Prison - Top Floor Opposite Wing",
		pos     = Vector3.new(-531.719, 48.999, 649.902),
		type    = "chest",
		tier    = T.MILITARY,
		context = C.WEAPON,
		containerStyle = "weapon_case",
		containerLabel = "Prison Weapons Case",
		searchDuration = 1.95,
	},
	{
		id      = "prison_ambulance_01",
		label   = "Prison - Back of Ambulance",
		pos     = Vector3.new(-464.095, 21.727, 539.189),
		type    = "ground",
		tier    = T.MID,
		context = C.MEDICAL,
	},
	{
		id      = "prison_mil_truck_01",
		label   = "Prison - Next to Covered Military Truck",
		pos     = Vector3.new(-401.58, 18.71, 562.817),
		type    = "chest",
		tier    = T.MILITARY,
		context = C.AMMO_ANY,
		containerStyle = "ammo_crate",
		containerLabel = "Truck Ammo Crate",
		searchDuration = 1.55,
	},
	{
		id      = "prison_swat_01",
		label   = "Prison Entrance - Swat Trucks",
		pos     = Vector3.new(-327.453, 18.71, 523.24),
		type    = "ground",
		tier    = T.MID,
		context = C.AMMO_PISTOL,
	},
	{
		id      = "prison_police_car_01",
		label   = "Prison Entrance - Police Car",
		pos     = Vector3.new(-259.004, 18.71, 530.193),
		type    = "ground",
		tier    = T.MID,
		context = C.AMMO_PISTOL,
	},

	-- --------------------------------------------------------
	-- FACTORY
	-- --------------------------------------------------------
	{
		id      = "factory_chest_01",
		label   = "Factory - Chest",
		pos     = Vector3.new(18.757, 19.403, -2447.068),
		type    = "chest",
		tier    = T.MID,
		context = C.RANDOM,
		containerStyle = "box_pile",
		containerLabel = "Factory Boxes",
		searchDuration = 1.4,
	},
	{
		id      = "factory_ground_01",
		label   = "Factory - Floor 1",
		pos     = Vector3.new(-48.782, 19.403, -2535.369),
		type    = "ground",
		tier    = T.MID,
		context = C.RANDOM,
	},
	{
		id      = "factory_ground_02",
		label   = "Factory - Floor 2",
		pos     = Vector3.new(-74.498, 19.403, -2492.231),
		type    = "ground",
		tier    = T.MID,
		context = C.AMMO_ANY,
	},
	{
		id      = "factory_ground_03",
		label   = "Factory - Floor 3",
		pos     = Vector3.new(18.68, 19.403, -2526.583),
		type    = "ground",
		tier    = T.MID,
		context = C.RANDOM,
	},
	{
		id      = "factory_chest_02",
		label   = "Factory - Chest 2",
		pos     = Vector3.new(1.876, 19.403, -2565.448),
		type    = "chest",
		tier    = T.MID,
		context = C.AMMO_ANY,
		containerStyle = "ammo_crate",
		containerLabel = "Factory Ammo Crate",
		searchDuration = 1.55,
	},
	{
		id      = "factory_outside_01",
		label   = "Factory Outside",
		pos     = Vector3.new(280.793, 19.351, -2349.523),
		type    = "ground",
		tier    = T.CIVILIAN,
		context = C.RANDOM,
	},
	{
		id      = "factory_outside_02",
		label   = "Factory Outside 2",
		pos     = Vector3.new(200.664, 19.351, -2409.25),
		type    = "ground",
		tier    = T.CIVILIAN,
		context = C.RANDOM,
	},
	{
		id      = "factory_outback_chest_01",
		label   = "Factory Outback - Chest",
		pos     = Vector3.new(161.757, 19.351, -2692.739),
		type    = "chest",
		tier    = T.MID,
		context = C.AMMO_AR,
		containerStyle = "ammo_crate",
		containerLabel = "Outback Ammo Crate",
		searchDuration = 1.55,
	},
	{
		id      = "factory_storage_chest_01",
		label   = "Factory - Storage Chest",
		pos     = Vector3.new(-79.194, 19.551, -2179.594),
		type    = "chest",
		tier    = T.MID,
		context = C.GEAR,
		containerStyle = "duffel_bag",
		containerLabel = "Factory Gear Bag",
		searchDuration = 1.3,
	},
	{
		id      = "factory_shipping_container_01",
		label   = "Factory - Shipping Container",
		pos     = Vector3.new(-105.176, 19.351, -2434.517),
		type    = "ground",
		tier    = T.MID,
		context = C.RANDOM,
	},
}

-- ============================================================
-- HELPER: get spawn by id
-- ============================================================
function LootSpawnData.GetById(id)
	for _, spawn in ipairs(LootSpawnData.SPAWNS) do
		if spawn.id == id then return spawn end
	end
	return nil
end

return LootSpawnData
