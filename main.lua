-- Modern Names: formats default Pokémon species names in official Title Case
-- (Gen 4+ standard) across Generation 1, Generation 2, and Generation 3 while
-- strictly preserving player nicknames and unnicknamed evolution logic.
--
-- In-memory tables (data.pokemon in Gen 1/2, Pokemon._names in Gen 3) and display
-- bridges are updated while the mod is loaded. Rollback cleanly restores
-- original uppercase names. Saves are never mutated.

local EXCEPTIONS = {
  ["NIDORAN♀"] = "Nidoran♀",
  ["NIDORAN♂"] = "Nidoran♂",
  ["NIDORAN F"] = "Nidoran♀",
  ["NIDORAN M"] = "Nidoran♂",
  ["NIDORAN_F"] = "Nidoran♀",
  ["NIDORAN_M"] = "Nidoran♂",
  ["FARFETCH'D"] = "Farfetch'd",
  ["FARFETCH’D"] = "Farfetch'd",
  ["MR. MIME"] = "Mr. Mime",
  ["MR.MIME"] = "Mr. Mime",
  ["MR_MIME"] = "Mr. Mime",
  ["MIME JR."] = "Mime Jr.",
  ["MIME JR"] = "Mime Jr.",
  ["MIME_JR"] = "Mime Jr.",
  ["HO-OH"] = "Ho-Oh",
  ["HO_OH"] = "Ho-Oh",
  ["PORYGON2"] = "Porygon2",
  ["PORYGON-Z"] = "Porygon-Z",
  ["PORYGON_Z"] = "Porygon-Z",
  ["TYPE: NULL"] = "Type: Null",
  ["TYPE:NULL"] = "Type: Null",
  ["TYPE:_NULL"] = "Type: Null",
}

local function formatModernSpeciesName(name)
  if type(name) ~= "string" or name == "" then return name end
  local upper = name:upper()
  if EXCEPTIONS[upper] then return EXCEPTIONS[upper] end
  if name:match("^%?+$") then return name end

  -- Preserve gender glyphs if attached
  if name:find("♀", 1, true) then
    local base = name:gsub("♀", "")
    return formatModernSpeciesName(base) .. "♀"
  end
  if name:find("♂", 1, true) then
    local base = name:gsub("♂", "")
    return formatModernSpeciesName(base) .. "♂"
  end

  -- Standard title casing across word boundaries (space, hyphen, period)
  local lower = name:lower()
  local title = lower:gsub("(%a)([%w_']*)", function(first, rest)
    return first:upper() .. rest
  end)

  -- Specific post-processing: lowercase 'd after apostrophe (e.g. Farfetch'd)
  title = title:gsub("'([A-Z])", function(c) return "'" .. c:lower() end)
  title = title:gsub("’([A-Z])", function(c) return "’" .. c:lower() end)

  -- Re-check exceptions
  return EXCEPTIONS[title:upper()] or title
end

local globalDataPokemonRef = nil

return function(mod)
  local GameVersion = require("src.core.GameVersion")
  local Runtime = require("src.mods.Runtime")
  local generation = tonumber(mod and mod.generation)
    or tonumber(mod and mod.game and mod.game.generation)
    or tonumber(GameVersion.generation())

  local HOOK = "modern_names.enabled"
  local MARK = "_modernNamesBridge"
  local function no() return false end
  local function enabled()
    return Runtime.wantsHook(HOOK) and Runtime.call(HOOK, no) == true
  end

  local function optional(pkg)
    local ok, res = pcall(require, pkg)
    return ok and type(res) == "table" and res or nil
  end

  local function bridge(t, key, build)
    if type(t) ~= "table" or type(t[key]) ~= "function" then return false end
    t[MARK] = t[MARK] or {}
    if not t[MARK][key] then
      t[key] = build(t[key])
      t[MARK][key] = t[key]
    end
    return true
  end

  -- Restoration registers
  local origRegistryNames = {}
  local origDataPokemonNames = {}
  local origGen3Names = {}
  local dataPokemonRef = nil
  local origNewIndex = nil

  local function restoreOriginalNames(dp)
    local target = dp or globalDataPokemonRef or dataPokemonRef
    if target then
      for def, orig in pairs(origDataPokemonNames) do
        if type(def) == "table" then def.name = orig end
      end
      for id, orig in pairs(origRegistryNames) do
        if target[id] and target[id].name then target[id].name = orig end
      end
      local mt = getmetatable(target)
      if mt then mt.__newindex = origNewIndex end
    end
    globalDataPokemonRef = nil
    dataPokemonRef = nil
    local Pokemon = optional("src.core.game3.pokemon")
    if Pokemon and Pokemon._names then
      for id, orig in pairs(origGen3Names) do
        Pokemon._names[id] = orig
      end
    end
    if Pokemon and Pokemon.onReload then
      Pokemon.onReload(nil, "modern_names")
    end
  end

  -- ------------------------------------------------------------ Registry patch
  if mod and mod.content and mod.content.pokemon then
    for id, row in mod.content.pokemon:each() do
      if type(row) == "table" and type(row.name) == "string" and row.name ~= "" then
        origRegistryNames[id] = row.name
        local modern = formatModernSpeciesName(row.name)
        if modern ~= row.name then
          mod.content.pokemon:patch(id, { name = modern })
        end
      end
    end
  end

  -- ------------------------------------------------------------ Gen 1 & Gen 2
  local function applyToDataPokemon(dp)
    if type(dp) ~= "table" then return end
    globalDataPokemonRef = dp
    dataPokemonRef = dp
    for k, def in pairs(dp) do
      if type(def) == "table" and type(def.name) == "string" and def.name ~= "" then
        if not origDataPokemonNames[def] then
          origDataPokemonNames[def] = origRegistryNames[k] or def.name
        end
        def.name = formatModernSpeciesName(origDataPokemonNames[def])
      end
    end
    local mt = getmetatable(dp) or {}
    origNewIndex = origNewIndex or mt.__newindex
    mt.__newindex = function(t, k, v)
      if type(v) == "table" and type(v.name) == "string" and v.name ~= "" then
        if not origDataPokemonNames[v] then
          origDataPokemonNames[v] = v.name
        end
        v.name = formatModernSpeciesName(origDataPokemonNames[v])
      end
      if origNewIndex then
        origNewIndex(t, k, v)
      else
        rawset(t, k, v)
      end
    end
    setmetatable(dp, mt)
  end

  if generation == 1 then
    if mod and mod.events and mod.events.on then
      mod.events:on("pokemon.evolved", function(ctx)
        if not enabled() then return end
        if ctx and ctx.mon and ctx.mon.nickname and ctx.fromSpecies then
          local pdata = (mod.game and mod.game.data and mod.game.data.pokemon)
          local oldDef = pdata and pdata[ctx.fromSpecies]
          local oldName = oldDef and (origDataPokemonNames[oldDef] or origRegistryNames[ctx.fromSpecies] or oldDef.name) or tostring(ctx.fromSpecies)
          if ctx.mon.nickname:upper() == oldName:upper() then
            ctx.mon.nickname = nil
          end
        end
      end)
    end
  elseif generation == 2 then
    local Evolution2 = optional("src.core.gen2.Evolution")
    if Evolution2 then
      bridge(Evolution2, "keptNickname", function(original)
        return function(evData, mon)
          if not enabled() then return original(evData, mon) end
          local nickname = mon and mon.nickname
          if not nickname or nickname == "" then return nil end
          local spName = Evolution2.speciesName(evData, mon.species)
          if spName and nickname:upper() == spName:upper() then return nil end
          return original(evData, mon)
        end
      end)
    end

    local Mon2 = optional("src.battle.gen2.Mon")
    if Mon2 then
      bridge(Mon2, "displayName", function(original)
        return function(mon)
          if not enabled() then return original(mon) end
          if type(mon) ~= "table" then return original(mon) end
          local nick = mon.nickname
          local pdata = globalDataPokemonRef or dataPokemonRef or (mod.game and mod.game.data and mod.game.data.pokemon)
          local def = pdata and pdata[mon.species]
          local defName = (def and def.name) or formatModernSpeciesName(mon.species)
          if nick and nick ~= "" then
            if defName and nick:upper() == defName:upper() then
              return defName
            end
            return nick
          end
          if mon.name and mon.name ~= "" then
            if defName then return defName end
            return formatModernSpeciesName(mon.name)
          end
          return defName or original(mon)
        end
      end)
    end

    local Battle2 = optional("src.battle.gen2.Battle")
    if Battle2 then
      bridge(Battle2, "monName", function(original)
        return function(self, mon)
          if not enabled() then return original(self, mon) end
          if not mon then return "?" end
          local nick = mon.nickname
          local pdata = (self.data and self.data.pokemon) or globalDataPokemonRef or dataPokemonRef
          local def = pdata and pdata[mon.species]
          local defName = (def and def.name) or formatModernSpeciesName(mon.species)
          if nick and nick ~= "" then
            if defName and nick:upper() == defName:upper() then
              return defName
            end
            return nick
          end
          if mon.name and mon.name ~= "" then
            if defName then return defName end
            return formatModernSpeciesName(mon.name)
          end
          return defName or original(self, mon)
        end
      end)
    end
  end

  -- ------------------------------------------------------------ Gen 3
  local Pokemon3 = optional("src.core.game3.pokemon")

  local function formatGen3NamesTable(names)
    if type(names) ~= "table" then return end
    for id, name in pairs(names) do
      if type(id) == "number" and type(name) == "string" and name ~= "" then
        if not origGen3Names[id] then
          origGen3Names[id] = name
        end
        names[id] = formatModernSpeciesName(origGen3Names[id])
      end
    end
  end

  if Pokemon3 then
    if Pokemon3._names then
      formatGen3NamesTable(Pokemon3._names)
    end

    if Pokemon3.onReload then
      Pokemon3.onReload(function(P)
        if not enabled() then return end
        if P and P._names then
          formatGen3NamesTable(P._names)
        end
      end, "modern_names")
    end

    bridge(Pokemon3, "displayName", function(original)
      return function(mon)
        if not enabled() then return original(mon) end
        if not mon then return "?????" end
        if Pokemon3.isEgg and Pokemon3.isEgg(mon) then return original(mon) end
        local nick = mon.nickname
        if nick and nick ~= "" then
          local sp = Pokemon3.speciesOf and Pokemon3.speciesOf(mon)
          if sp then
            local ok, spName = pcall(Pokemon3.name, sp)
            if ok and spName and nick:upper() == spName:upper() then
              return spName
            end
          end
          if mon.name and mon.name ~= "" and nick:upper() == mon.name:upper() then
            local sp2 = Pokemon3.speciesFromName and Pokemon3.speciesFromName(mon.name)
            local ok2, spName2 = sp2 and pcall(Pokemon3.name, sp2)
            if ok2 and spName2 then return spName2 end
            return formatModernSpeciesName(mon.name)
          end
          return tostring(nick)
        end
        return original(mon)
      end
    end)

    local BattleState3 = optional("src.core.game3.battle.state")
    if BattleState3 then
      bridge(BattleState3, "displayName", function(original)
        return function(battler)
          if not enabled() then return original(battler) end
          if not battler then return original(battler) end
          local mon = battler.mon
          local sp = battler.species or (mon and Pokemon3.speciesOf and Pokemon3.speciesOf(mon))
          if mon and mon.nickname and mon.nickname ~= "" and sp then
            local ok, spName = pcall(Pokemon3.name, sp)
            if ok and spName and mon.nickname:upper() == spName:upper() then
              return spName
            end
          end
          return original(battler)
        end
      end)
    end
  end

  local origRuntimeReset = Runtime.reset
  Runtime.reset = function()
    restoreOriginalNames()
    return origRuntimeReset()
  end

  mod.hooks:wrap(HOOK, function() return true end)
  mod.exports = {
    format = formatModernSpeciesName,
    restore = restoreOriginalNames,
    applyDataPokemon = applyToDataPokemon,
  }
end
