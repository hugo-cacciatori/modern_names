-- Modern Names: formats default Pokémon species names in official Title Case
-- (Gen 4+ standard) across Generation 1, Generation 2, and Generation 3 while
-- strictly preserving player nicknames and unnicknamed evolution logic.
--
-- In-memory tables (data.pokemon in Gen 1/2, Pokemon._names in Gen 3) and display
-- bridges are updated while the mod is loaded. Rollback cleanly restores
-- original uppercase names. Saves are never mutated.
-- The logic lives in the bundled `species_names` lib (lib/species_names/); this file only wires it.
return function(mod)
  local use = assert(load(assert(mod:read("lib/init.lua"), "missing lib/init.lua"), "@lib/init.lua"))(mod)
  use("species_names").install(mod)
end
