package.path = "./?.lua;./?/init.lua;" .. package.path
-- Supply data compression only; native cache access remains headless.
love = {
  data = {
    compress = function(_, _, bytes, level) return deflate(bytes, level) end,
    decompress = function(_, _, bytes) return inflate(bytes) end,
  },
  graphics = {
    newQuad = function() return {} end,
    newImage = function() return { getDimensions = function() return 256, 256 end } end,
  },
}
local GameVersion = require("src.core.GameVersion")
GameVersion.set(TEST_VERSION)
assert(require("src.core.Version").engine == "0.3.96", "wrong installed engine")

local fs, overlay = {}, {}
function fs.read(p) return overlay[p] or fs_read(p) end
function fs.getInfo(p) return overlay[p] and { type = "file" } or fs_info(p) end
function fs.getDirectoryItems(p) return fs_list(p) end
function fs.load(p)
  local bytes = fs.read(p)
  return bytes and loadstring(bytes, "@" .. p)
end
function fs.write(p, bytes) overlay[p] = bytes return true end
function fs.createDirectory() return true end
fs.root = "."

local generation = GameVersion.generation()
local Loader = require("src.mods.Loader")
local game = { data = {} }

if generation == 3 then
  local Dataset = require("src.core.game3.dataset")
  Dataset.cacheRootOverride = CACHE_ROOT
  assert(Dataset.hydrate(game), "installed dataset did not hydrate")
else
  -- Load real extracted tables for Gen 1 (red) and Gen 2 (crystal)
  local dir = TEST_VERSION .. "/data/generated/"
  for _, name in ipairs({ "constants", "moves", "items", "pokemon", "type_chart" }) do
    local chunk = fs.load(dir .. name .. ".lua")
    if chunk then game.data[name] = chunk() end
  end
end

local loader = Loader.new({ fs = fs, generation = generation })
loader:load(game.data)
assert(#loader.errors == 0, table.concat(loader.errors, "\n"))
local mod = loader.mods.modern_names
assert(mod and mod.state == "loaded", "installed mod did not load for " .. TEST_VERSION)

if generation == 3 then
  local Pokemon3 = require("src.core.game3.pokemon")
  assert(Pokemon3.name(1) == "Bulbasaur", "Bulbasaur not formatted")
  assert(Pokemon3.name(4) == "Charmander", "Charmander not formatted")
  assert(Pokemon3.name(29) == "Nidoran♀", "Nidoran♀ not formatted")
  assert(Pokemon3.name(83) == "Farfetch'd", "Farfetch'd not formatted")
  assert(Pokemon3.name(122) == "Mr. Mime", "Mr. Mime not formatted")
  assert(Pokemon3.name(233) == "Porygon2", "Porygon2 not formatted")
  assert(Pokemon3.name(250) == "Ho-Oh", "Ho-Oh not formatted")

  -- Display name
  local unnick = { species = 4, nickname = "CHARMANDER" }
  assert(Pokemon3.displayName(unnick) == "Charmander", "legacy uppercase nickname did not display modern")
  local custom = { species = 4, nickname = "SPARKY" }
  assert(Pokemon3.displayName(custom) == "SPARKY", "custom nickname SPARKY was modified")
  local lower = { species = 4, nickname = "fluffy" }
  assert(Pokemon3.displayName(lower) == "fluffy", "custom nickname fluffy was modified")

  -- Rollback
  local restore = loader.exports.modern_names and loader.exports.modern_names.restore
  loader:_rollback("modern_names")
  if restore then restore(dp) end
  assert(Pokemon3.name(1) == "BULBASAUR", "rollback did not restore BULBASAUR")
  assert(Pokemon3.name(83) == "FARFETCH'D", "rollback did not restore FARFETCH'D")
  print("PASS installed " .. TEST_VERSION .. ": modern names, nicknames, and rollback")
  return
end

if generation == 1 then
  local dp = game.data.pokemon
  assert(dp and dp.BULBASAUR, "Gen 1 pokemon data missing")
  assert(dp.BULBASAUR.name == "Bulbasaur", "BULBASAUR not formatted")
  assert(dp.FARFETCHD.name == "Farfetch'd", "FARFETCHD not formatted")
  assert(dp.MR_MIME.name == "Mr. Mime", "MR_MIME not formatted")
  assert(dp.NIDORAN_F.name == "Nidoran♀", "NIDORAN_F not formatted")
  assert(dp.NIDORAN_M.name == "Nidoran♂", "NIDORAN_M not formatted")

  -- Rollback
  local restore = loader.exports.modern_names and loader.exports.modern_names.restore
  loader:_rollback("modern_names")
  if restore then restore(dp) end
  assert(dp.BULBASAUR.name == "BULBASAUR", "rollback did not restore BULBASAUR")
  assert(dp.FARFETCHD.name == "FARFETCH'D", "rollback did not restore FARFETCH'D")
  assert(dp.MR_MIME.name == "MR.MIME", "rollback did not restore MR.MIME")
  print("PASS installed " .. TEST_VERSION .. ": Gen 1 modern names and rollback")
  return
end

if generation == 2 then
  local dp = game.data.pokemon
  assert(dp and dp.CYNDAQUIL, "Gen 2 pokemon data missing")
  assert(dp.CYNDAQUIL.name == "Cyndaquil", "CYNDAQUIL not formatted")
  assert(dp.FARFETCH_D.name == "Farfetch'd", "FARFETCH_D not formatted")
  assert(dp.MR__MIME.name == "Mr. Mime", "MR__MIME not formatted")
  assert(dp.PORYGON2.name == "Porygon2", "PORYGON2 not formatted")
  assert(dp.HO_OH.name == "Ho-Oh", "HO_OH not formatted")

  local Evolution2 = require("src.core.gen2.Evolution")
  local Mon2 = require("src.battle.gen2.Mon")

  local unnick = { species = "CYNDAQUIL", nickname = "CYNDAQUIL" }
  assert(Evolution2.keptNickname(game.data, unnick) == nil, "keptNickname legacy did not return nil")
  assert(Mon2.displayName(unnick) == "Cyndaquil", "Mon.displayName legacy did not return Cyndaquil")

  local custom = { species = "CYNDAQUIL", nickname = "SPARKY" }
  assert(Evolution2.keptNickname(game.data, custom) == "SPARKY", "keptNickname custom did not keep SPARKY")
  assert(Mon2.displayName(custom) == "SPARKY", "Mon.displayName custom did not keep SPARKY")

  -- Rollback
  local restore = loader.exports.modern_names and loader.exports.modern_names.restore
  loader:_rollback("modern_names")
  if restore then restore(dp) end
  assert(dp.CYNDAQUIL.name == "CYNDAQUIL", "rollback did not restore CYNDAQUIL")
  assert(dp.MR__MIME.name == "MR.MIME", "rollback did not restore MR.MIME")
  print("PASS installed " .. TEST_VERSION .. ": Gen 2 modern names, keptNickname, and rollback")
  return
end
