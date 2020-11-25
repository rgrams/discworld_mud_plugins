
local quowMapsByID = {
	--    { filename, display name, gridX, gridY, ~centerX, ~centerY, region }
	[1] = { "am.png", "Ankh-Morpork", 14, 14, 718, 802, "AM" },
	[2] = { "am_assassins.png", "AM Assassins", 28, 28, 457, 61, "AM" },
	[3] = { "am_buildings.png", "AM Buildings", 25, 25, 208, 76, "AM" },
	[4] = { "am_cruets.png", "AM Cruets", 24, 24, 300, 69, "AM" },
	[5] = { "am_docks.png", "AM Docks", 14, 14, 174, 216, "AM" },
	[6] = { "am_guilds.png", "AM Guilds", 28, 28, 487, 245, "AM" },
	[7] = { "am_isle_gods.png", "AM Isle of Gods", 24, 24, 342, 587, "AM" },
	[8] = { "am_shades.png", "Shades Maze", 80, 80, 46, 179, "AM" },
	[9] = { "am_smallgods.png", "Temple of Small Gods", 24, 24, 221, 224, "AM" },
	[10] = { "am_temples.png", "AM Temples", 24, 24, 575, 419, "AM" },
	[11] = { "am_thieves.png", "AM Thieves", 28, 28, 431, 300, "AM" },
	[12] = { "am_uu.png", "Unseen University", 28, 28, 166, 393, "AM" },
	[13] = { "am_warriors.png", "AM Warriors", 32, 25, 135, 104, "AM" },
	[14] = { "am_watch_house.png", "Pseudopolis Watch House", 24, 24, 88, 104, "AM" },
	[15] = { "magpyr.png", "Magpyr's Castle", 20, 20, 141, 440, "Magpyr" },
	[16] = { "bois.png", "Bois", 14, 14, 239, 169, "Bois" },
	[17] = { "bp.png", "Bes Pelargic", 14, 14, 1070, 748, "BP" },
	[18] = { "bp_buildings.png", "BP Buildings", 24, 24, 428, 177, "BP" },
	[19] = { "bp_estates.png", "BP Estates", 14, 14, 540, 506, "BP" },
	[20] = { "bp_wizards.png", "BP Wizards", 20, 20, 101, 517, "BP" },
	[21] = { "brown_islands.png", "Brown Islands", 28, 28, 105, 101, "Brown" },
	[22] = { "deaths_domain.png", "Death's Domain", 28, 28, 98, 86, "Death" },
	[23] = { "djb.png", "Djelibeybi", 14, 14, 438, 369, "DJB" },
	[24] = { "djb_wizards.png", "IIL - DJB Wizards", 28, 28, 210, 210, "DJB" },
	[25] = { "ephebe.png", "Ephebe", 14, 14, 407, 349, "Ephebe" },
	[26] = { "ephebe_under.png", "Ephebe Underdocks", 14, 14, 247, 285, "Ephebe" },
	[27] = { "genua.png", "Genua", 14, 14, 470, 242, "Genua" },
	[28] = { "genua_sewers.png", "Genua Sewers", 21, 21, 405, 312, "Genua" },
	[29] = { "grflx.png", "GRFLX Caves", 20, 20, 303, 222, "GRFLX" },
	[30] = { "hashishim_caves.png", "Hashishim Caves", 28, 28, 258, 132, "Klatch" },
	[31] = { "klatch.png", "Klatch Region", 14, 14, 724, 515, "Klatch" },
	[32] = { "lancre_castle.png", "Lancre Region", 14, 14, 285, 33, "Ramtops" },
	[33] = { "mano_rossa.png", "Mano Rossa", 28, 28, 298, 202, "Genua" },
	[34] = { "monks_cool.png", "Monks of Cool", 14, 14, 113, 170, "Ramtops" },
	[35] = { "netherworld.png", "Netherworld", 14, 14, 42, 75, "Nether" },
	[37] = { "pumpkin_town.png", "Pumpkin Town", 48, 48, 375, 194, "Pumpkin" },
	[38] = { "ramtops.png", "Ramtops Regions", 14, 14, 827, 223, "Ramtops" },
	[39] = { "sl.png", "Sto-Lat", 14, 14, 367, 222, "Sto-Lat" },
	[40] = { "sl_aoa.png", "Academy of Artificers", 25, 25, 47, 87, "Sto-Lat" },
	[41] = { "sl_cabbages.png", "Cabbage Warehouse", 28, 28, 60, 92, "Sto-Lat" },
	[42] = { "sl_library.png", "AoA Library", 57, 57, 220, 411, "Sto-Lat" },
	[43] = { "sl_sewers.png", "Sto-Lat Sewers", 14, 14, 162, 204, "Sto-Lat" },
	[44] = { "sprite_caves.png", "Sprite Caves", 14, 14, 113, 182, "Sprites" },
	[45] = { "sto_plains.png", "Sto Plains Region", 14, 14, 752, 390, "Sto-Plains" },
	[46] = { "uberwald.png", "Uberwald Region", 14, 14, 673, 643, "Uber" },
	[47] = { "uu_library_full.png", "UU Library", 30, 30, 165, 4810, "UU" },
	[48] = { "farmsteads.png", "Klatchian Farmsteads", 28, 28, 445, 171, "Klatch" },
	[49] = { "ctf_arena.png", "CTF Arena", 48, 48, 307, 283, "CTF" },
	[50] = { "pk_arena.png", "PK Arena", 30, 30, 155, 331, "PK" },
	[51] = { "am_postoffice.png", "AM Post Office", 28, 28, 156, 69, "AM" },
	[52] = { "bp_ninjas.png", "Ninja Guild", 28, 28, 109, 56, "BP" },
	[53] = { "tshop.png", "The Travelling Shop", 28, 28, 355, 315, "T-Shop" },
	[54] = { "slippery_hollow.png", "Slippery Hollow", 14, 14, 215, 123, "S-Hollow" },
	[55] = { "creel_guild.png", "House of Magic - Creel", 28, 28, 38, 86, "Ramtops" },
	[56] = { "quow_specials.png", "Special Areas", 28, 28, 288, 28, "Misc" },
	[57] = { "skund_wolftrails.png", "Skund Wolf Trail", 12, 12, 41, 587, "Skund" },
	[58] = { "medina.png", "Medina", 38, 38, 131, 126, "BP" },
	[59] = { "copperhead.png", "Copperhead", 12, 12, 55, 47, "Copper" },
	[60] = { "ephebe_citadel.png", "The Citadel", 11, 11, 37, 74, "Ephebe" },
	[61] = { "am_fools.png", "AM Fools' Guild", 28, 28, 13, 65, "AM" },
	[62] = { "thursday.png", "Thursday's Island", 28, 28, 112, 65, "Thursday" },
	[63] = { "unsinkable.png", "SS Unsinkable", 28, 28, 143, 124, "Unsinkable" },
	[99] = { "discwhole.png", "Whole Disc", 1, 1, 1175, 3726, "Terrains" },
}

return quowMapsByID