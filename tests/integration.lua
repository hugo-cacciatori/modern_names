package.path = "./?.lua;./?/init.lua;" .. package.path
love = love or require("tests.love_stub")
local Sdk = require("tests.modkit.sdk")
local GameVersion = require("src.core.GameVersion")
local Runtime = require("src.mods.Runtime")
local Logger = require("src.core.Logger")
if Logger.warn then Logger.warn = function() end end

local total = 0
local function check(value, message)
  total = total + 1
  assert(value, message)
end

-- ------------------------------------------------------------ 1. Pure Casing & Exceptions
local mainInit = assert(loadfile(MOD_PATH .. "/main.lua"))()
local dummyMod = { hooks = { wrap = function() end }, path = MOD_PATH }
-- the engine's mod:read: a file of the mod's own folder, nil when absent
function dummyMod:read(rel)
  local handle = io.open(MOD_PATH .. "/" .. rel, "rb")
  if not handle then return nil end
  local data = handle:read("*a")
  handle:close()
  return data
end
mainInit(dummyMod)
local format = dummyMod.exports.format

check(format("BULBASAUR") == "Bulbasaur", "casing: Bulbasaur")
check(format("CHARMANDER") == "Charmander", "casing: Charmander")
check(format("FARFETCH'D") == "Farfetch'd", "casing: Farfetch'd")
check(format("FARFETCH’D") == "Farfetch'd", "casing: Farfetch'd (curly)")
check(format("MR. MIME") == "Mr. Mime", "casing: Mr. Mime (space)")
check(format("MR.MIME") == "Mr. Mime", "casing: Mr. Mime (nospace)")
check(format("MR_MIME") == "Mr. Mime", "casing: Mr. Mime (underscore)")
check(format("MIME JR.") == "Mime Jr.", "casing: Mime Jr.")
check(format("MIME JR") == "Mime Jr.", "casing: Mime Jr. (noperiod)")
check(format("HO-OH") == "Ho-Oh", "casing: Ho-Oh")
check(format("HO_OH") == "Ho-Oh", "casing: Ho-Oh (underscore)")
check(format("PORYGON2") == "Porygon2", "casing: Porygon2")
check(format("PORYGON-Z") == "Porygon-Z", "casing: Porygon-Z")
check(format("NIDORAN♀") == "Nidoran♀", "casing: Nidoran♀")
check(format("NIDORAN♂") == "Nidoran♂", "casing: Nidoran♂")
check(format("NIDORAN F") == "Nidoran♀", "casing: Nidoran F")
check(format("NIDORAN M") == "Nidoran♂", "casing: Nidoran M")
check(format("TYPE: NULL") == "Type: Null", "casing: Type: Null")
check(format("??????????") == "??????????", "casing: ??????????")
check(format("?") == "?", "casing: ?")
check(format("BELLSPROUT") == "Bellsprout", "casing: Bellsprout")
check(format("VICTREEBEL") == "Victreebel", "casing: Victreebel")

-- ------------------------------------------------------------ 2. Profile Loading
local PROFILES = {
  { version = "firered", gen = 3 },
  { version = "leafgreen", gen = 3 },
  { version = "ruby", gen = 3 },
  { version = "sapphire", gen = 3 },
  { version = "emerald", gen = 3 },
  { version = "red", gen = 1 },
  { version = "blue", gen = 1 },
  { version = "yellow", gen = 1 },
  { version = "gold", gen = 2 },
  { version = "silver", gen = 2 },
  { version = "crystal", gen = 2 },
}

local function sampleData(gen)
  if gen == 3 then
    local d = Sdk.gen3Data()
    d.gen3Pokemon._names[25] = "PIKACHU"
    d.gen3Pokemon._names[83] = "FARFETCH'D"
    d.gen3Pokemon._names[122] = "MR. MIME"
    d.gen3Pokemon._names[233] = "PORYGON2"
    d.gen3Pokemon._names[250] = "HO-OH"
    return d
  end
  return {
    pokemon = {
      BULBASAUR = { name = "BULBASAUR", id = "BULBASAUR" },
      CHARMANDER = { name = "CHARMANDER", id = "CHARMANDER" },
      FARFETCHD = { name = "FARFETCH'D", id = "FARFETCHD" },
      MR_MIME = { name = "MR.MIME", id = "MR_MIME" },
      NIDORAN_F = { name = "NIDORAN♀", id = "NIDORAN_F" },
      NIDORAN_M = { name = "NIDORAN♂", id = "NIDORAN_M" },
      PORYGON2 = { name = "PORYGON2", id = "PORYGON2" },
      HO_OH = { name = "HO-OH", id = "HO_OH" },
      CYNDAQUIL = { name = "CYNDAQUIL", id = "CYNDAQUIL" },
      QUILAVA = { name = "QUILAVA", id = "QUILAVA" },
    }
  }
end

for _, p in ipairs(PROFILES) do
  GameVersion.set(p.version)
  Runtime.reset()
  local opts = { generation = p.gen, data = sampleData(p.gen) }
  if p.gen == 3 then
    local Pokemon3 = require("src.core.game3.pokemon")
    Pokemon3._names = opts.data.gen3Pokemon._names
    local RomText3 = require("src.core.game3.rom_text")
    local okEgg = pcall(RomText3.plain, "gText_EggNickname")
    if not okEgg then
      local origPlain = RomText3.plain
      RomText3.plain = function(id, ...)
        if id == "gText_EggNickname" then return "EGG" end
        return origPlain(id, ...)
      end
    end
  end
  local run = Sdk.loadMod(MOD_PATH, opts)
  check(#run.errors == 0, p.version .. ": load error: " .. table.concat(run.errors, "\n"))
  check(run.mod and run.mod.state == "loaded", p.version .. ": mod loaded")

  if p.gen == 3 then
    local Pokemon3 = require("src.core.game3.pokemon")
    -- Check species names in Pokemon._names
    check(Pokemon3._names[4] == "Charmander", p.version .. ": Charmander formatted")
    check(Pokemon3._names[16] == "Pidgey", p.version .. ": Pidgey formatted")
    check(Pokemon3._names[29] == "Nidoran♀", p.version .. ": Nidoran♀ formatted")
    check(Pokemon3._names[83] == "Farfetch'd", p.version .. ": Farfetch'd formatted")
    check(Pokemon3._names[122] == "Mr. Mime", p.version .. ": Mr. Mime formatted")
    check(Pokemon3._names[233] == "Porygon2", p.version .. ": Porygon2 formatted")
    check(Pokemon3._names[250] == "Ho-Oh", p.version .. ": Ho-Oh formatted")

    -- Check Pokemon.name
    check(Pokemon3.name(4) == "Charmander", p.version .. ": Pokemon.name(4)")
    check(Pokemon3.name(83) == "Farfetch'd", p.version .. ": Pokemon.name(83)")

    -- Check Pokemon.displayName
    -- 1. Unnicknamed (nil nickname)
    local monNoNick = { species = 4 }
    check(Pokemon3.displayName(monNoNick) == "Charmander", p.version .. ": displayName unnicknamed nil")

    -- 2. Legacy save unnicknamed (nickname == uppercase species name)
    local monUpperNick = { species = 4, nickname = "CHARMANDER" }
    check(Pokemon3.displayName(monUpperNick) == "Charmander", p.version .. ": displayName legacy uppercase")

    -- 3. Custom nickname: SPARKY
    local monCustomNick = { species = 25, nickname = "SPARKY" }
    check(Pokemon3.displayName(monCustomNick) == "SPARKY", p.version .. ": displayName custom nickname SPARKY preserved")

    -- 4. Custom nickname lowercase: fluffy
    local monLowerNick = { species = 4, nickname = "fluffy" }
    check(Pokemon3.displayName(monLowerNick) == "fluffy", p.version .. ": displayName custom nickname fluffy preserved")

    -- 5. Egg
    local monEgg = { isEgg = true }
    check(Pokemon3.displayName(monEgg):lower():find("egg"), p.version .. ": egg preserved")

    -- Check BattleState3 displayName
    local BattleState3 = require("src.core.game3.battle.state")
    local battlerUnnick = { species = 4, mon = { species = 4, nickname = "CHARMANDER" } }
    check(BattleState3.displayName(battlerUnnick) == "Charmander", p.version .. ": battler unnicknamed")
    local battlerNick = { species = 4, mon = { species = 4, nickname = "BLAZE" } }
    check(BattleState3.displayName(battlerNick) == "BLAZE", p.version .. ": battler custom nick")

    -- Check Evolution.renameMon
    local Evolution3 = require("src.core.game3.evolution")
    local evoMon = { species = 4, nickname = "CHARMANDER" }
    Evolution3.renameMon(evoMon, 4, 5)
    check(evoMon.nickname == "Charmeleon", p.version .. ": evo unnicknamed renamed to Charmeleon")

    local evoCustom = { species = 4, nickname = "SPARKY" }
    Evolution3.renameMon(evoCustom, 4, 5)
    check(evoCustom.nickname == "SPARKY", p.version .. ": evo custom nick kept SPARKY")

    -- Test rollback restores uppercase
    local restore = run.loader.exports.modern_names and run.loader.exports.modern_names.restore
    run.loader:_rollback("modern_names")
    if restore then restore() end
    check(Pokemon3._names[4] == "CHARMANDER", p.version .. ": rollback restored CHARMANDER")
    check(Pokemon3._names[29] == "NIDORAN\226\153\128" or Pokemon3._names[29] == "NIDORAN♀",
      p.version .. ": rollback restored NIDORAN")
  else
    -- Gen 1 & Gen 2
    local dp = opts.data.pokemon
    local exports = run.loader.exports.modern_names
    if exports and exports.applyDataPokemon then exports.applyDataPokemon(dp) end
    check(dp.BULBASAUR.name == "Bulbasaur", p.version .. ": data.pokemon Bulbasaur")
    check(dp.CHARMANDER.name == "Charmander", p.version .. ": data.pokemon Charmander")
    check(dp.FARFETCHD.name == "Farfetch'd", p.version .. ": data.pokemon Farfetch'd")
    check(dp.MR_MIME.name == "Mr. Mime", p.version .. ": data.pokemon Mr. Mime")
    check(dp.NIDORAN_F.name == "Nidoran♀", p.version .. ": data.pokemon Nidoran♀")
    check(dp.NIDORAN_M.name == "Nidoran♂", p.version .. ": data.pokemon Nidoran♂")
    check(dp.PORYGON2.name == "Porygon2", p.version .. ": data.pokemon Porygon2")
    check(dp.HO_OH.name == "Ho-Oh", p.version .. ": data.pokemon Ho-Oh")

    -- Dynamic insertion
    dp.MEWTWO = { name = "MEWTWO", id = "MEWTWO" }
    check(dp.MEWTWO.name == "Mewtwo", p.version .. ": dynamic insertion formatted Mewtwo")

    if p.gen == 2 then
      local Evolution2 = require("src.core.gen2.Evolution")
      local Mon2 = require("src.battle.gen2.Mon")
      local Battle2 = require("src.battle.gen2.Battle")

      -- Evolution.keptNickname
      local unnickMon = { species = "CYNDAQUIL", nickname = "CYNDAQUIL" }
      check(Evolution2.keptNickname(opts.data, unnickMon) == nil, p.version .. ": keptNickname legacy unnick returns nil")
      local nickMon = { species = "CYNDAQUIL", nickname = "SPARKY" }
      check(Evolution2.keptNickname(opts.data, nickMon) == "SPARKY", p.version .. ": keptNickname SPARKY kept")

      -- Mon.displayName
      check(Mon2.displayName(unnickMon) == "Cyndaquil", p.version .. ": Mon.displayName legacy unnick")
      check(Mon2.displayName(nickMon) == "SPARKY", p.version .. ": Mon.displayName SPARKY")

      -- Battle:monName
      local battle = setmetatable({ data = opts.data }, { __index = Battle2 })
      check(battle:monName(unnickMon) == "Cyndaquil", p.version .. ": Battle:monName legacy unnick")
      check(battle:monName(nickMon) == "SPARKY", p.version .. ": Battle:monName SPARKY")
    end

    if p.gen == 1 then
      -- Test pokemon.evolved clears legacy uppercase nickname
      local mon = { species = "CHARMANDER", nickname = "CHARMANDER" }
      Runtime.emit("pokemon.evolved", { mon = mon, fromSpecies = "CHARMANDER", toSpecies = "CHARMELEON" })
      check(mon.nickname == nil, p.version .. ": Gen 1 evolved cleared legacy nickname")

      local nickMon = { species = "CHARMANDER", nickname = "SPARKY" }
      Runtime.emit("pokemon.evolved", { mon = nickMon, fromSpecies = "CHARMANDER", toSpecies = "CHARMELEON" })
      check(nickMon.nickname == "SPARKY", p.version .. ": Gen 1 evolved kept SPARKY")
    end

    -- Test rollback restores uppercase
    local restore = run.loader.exports.modern_names and run.loader.exports.modern_names.restore
    run.loader:_rollback("modern_names")
    if restore then restore(dp) end
    check(dp.BULBASAUR.name == "BULBASAUR", p.version .. ": rollback restored BULBASAUR")
    check(dp.FARFETCHD.name == "FARFETCH'D", p.version .. ": rollback restored FARFETCH'D")
    check(dp.MR_MIME.name == "MR.MIME", p.version .. ": rollback restored MR.MIME")
  end
end

print(("PASS modern_names: %d integration assertions across 11 profiles"):format(total))
