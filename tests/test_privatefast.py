"""Offline test of the Private Fast ("Złoty Środek") fork changes:
  - R.hashFast fast-pulse mode in mpfever_refs.lua (counts, stations, lines only; zero heavy component reads);
  - MPFEVER_VEH_LIGHT=1 lightweight vehicles hash in mpfever_refs.lua (no MOVE_PATH dumpFn call, deterministic signature);
  - Upstream default compatibility when MPFEVER_PRIVATE_FAST / MPFEVER_VEH_LIGHT / R.hashFast are unset;
  - 9-group structural rotation in simHash (mpfever_bridge.script.lua) under MPFEVER_PRIVATE_FAST=1 with R.hashAuditN;
  - Launcher wiring: Updater.Repo, GameLink.ApplyPrivateFastEnv, MainForm Option B / RequestHashFast / SelfTest.

Run: python tests/test_privatefast.py
"""
import os
import sys

try:
    import lupa.lua52 as lupa
except ImportError:
    print("lupa is not installed (pip install lupa): test skipped")
    sys.exit(0)

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..")
REFS = os.path.join(ROOT, "mod", "mpfever_1", "content", "mpfever_refs.lua")
BRIDGE = os.path.join(ROOT, "mod", "mpfever_1", "content", "mpfever_bridge.script.lua")
CORE = os.path.join(ROOT, "launcher", "Core.cs")
MAINFORM = os.path.join(ROOT, "launcher", "MainForm.cs")
UPDATER = os.path.join(ROOT, "launcher", "Updater.cs")
SELFTEST = os.path.join(ROOT, "launcher", "SelfTest.cs")

fails = []


def check(name, cond, got=""):
    print(f"{'ok  ' if cond else 'FAIL'} {name}" + (f": {got}" if got != "" and not cond else ""))
    if not cond:
        fails.append(name)


def read(path):
    return open(path, encoding="utf-8-sig").read().replace("\r\n", "\n")


MOCK = r"""
ENV = {}
os.getenv = function(k) return ENV[k] end

COMP_READS = {}
DUMP_CALLS = 0

ENTITIES = {
  CONSTRUCTION = { 101, 102 },
  BASE_EDGE = { 201, 202, 203 },
  TRANSPORT_VEHICLE = { 301, 302 },
  TOWN_BUILDING = { 401 },
  STATION = { 501, 502 },
  STATION_GROUP = { 601 },
  LINE = { 701 },
  SIM_PERSON = { 801, 802, 803, 804 },
}

VEHICLES = {
  [301] = { state = 1, stopIndex = 2, line = 701, userStopped = false, sellOnArrival = false },
  [302] = { state = 0, stopIndex = 0, line = -1, userStopped = true, sellOnArrival = false },
}

MOVE_PATHS = {
  [301] = { dyn = { pos = 42, speed = 12 } },
}

NAMES = {
  [501] = "Warszawa",
  [502] = "Krakow",
  [601] = "Warszawa Centralna",
  [701] = "IC 1",
  [301] = "EP09-1",
  [302] = "EU07-2",
}

LINES = {
  [701] = { stops = {} },
}

NODES = { [1] = { x = 0, y = 0, z = 0 }, [2] = { x = 10, y = 20, z = 0 } }
EDGES = {
  [201] = { node0 = 1, node1 = 2, roadTemplate = "r", roadStyle = 1, roadType = 0, type = 0, typeIndex = -1, distance = 10, edgeDecorations = {}, laneConfigs = {} },
  [202] = { node0 = 1, node1 = 2, roadTemplate = "r", roadStyle = 1, roadType = 0, type = 0, typeIndex = -1, distance = 20, edgeDecorations = {}, laneConfigs = {} },
  [203] = { node0 = 1, node1 = 2, roadTemplate = "r", roadStyle = 1, roadType = 0, type = 0, typeIndex = -1, distance = 30, edgeDecorations = {}, laneConfigs = {} },
}
CONSTRUCTIONS = {
  [101] = { fileName = "station/rail.con", transf = { 1,0,0,0, 0,1,0,0, 0,0,1,0, 10,20,0,1 }, params = {} },
  [102] = { fileName = "depot/rail.con", transf = { 1,0,0,0, 0,1,0,0, 0,0,1,0, 30,40,0,1 }, params = {} },
}

local ctNames = {
  CONSTRUCTION = "CONSTRUCTION",
  BASE_EDGE = "BASE_EDGE",
  BASE_NODE = "BASE_NODE",
  BASE_NODE_CONFIG = "BASE_NODE_CONFIG",
  TRANSPORT_VEHICLE = "TRANSPORT_VEHICLE",
  MOVE_PATH = "MOVE_PATH",
  TOWN_BUILDING = "TOWN_BUILDING",
  SIM_PERSON = "SIM_PERSON",
  STATION = "STATION",
  STATION_GROUP = "STATION_GROUP",
  LINE = "LINE",
  NAME = "NAME",
  TICK_EPOCH = "TICK_EPOCH",
  EDGE_OBJECT = "EDGE_OBJECT",
}

api = {
  type = { ComponentType = ctNames },
  engine = {
    entityExists = function(e) return true end,
    getComponent = function(e, ct)
      COMP_READS[ct] = (COMP_READS[ct] or 0) + 1
      if ct == "TRANSPORT_VEHICLE" then return VEHICLES[e] end
      if ct == "MOVE_PATH" then return MOVE_PATHS[e] end
      if ct == "NAME" then return NAMES[e] and { name = NAMES[e] } or nil end
      if ct == "LINE" then return LINES[e] end
      if ct == "BASE_EDGE" then return EDGES[e] end
      if ct == "BASE_NODE" then return NODES[e] and { position = NODES[e] } or nil end
      if ct == "CONSTRUCTION" then return CONSTRUCTIONS[e] end
      return nil
    end,
    forEachEntityWithComponent = function(fn, ct)
      for _, e in ipairs(ENTITIES[ct] or {}) do fn(e) end
    end,
    system = {
      lineSystem = { getLines = function() return ENTITIES.LINE end },
      streetSystem = { getEdgeObject2EdgeMap = function() return {} end },
    },
  },
}

function HS(seed, s)
  local h = seed or 5381
  for i = 1, #s do h = (h * 33 + s:byte(i)) % 4294967296 end
  return h
end

function DUMP(v)
  DUMP_CALLS = DUMP_CALLS + 1
  if type(v) == "table" then
    return "pos=" .. tostring(v.pos) .. ",spd=" .. tostring(v.speed)
  end
  return tostring(v)
end
"""


def make_refs_env():
    L = lupa.LuaRuntime(unpack_returned_tuples=True)
    L.execute(MOCK)
    refs_src = read(REFS)
    L.execute("R = (function()\n" + refs_src + "\nend)()")
    L.execute("R.allEdges = function() return ENTITIES.BASE_EDGE end")
    L.execute("R.allNodes = function() return { 1, 2 } end")
    L.execute("R.tickEpochsOn = function() return true end")
    return L


def main():
    # 1. Fast Pulse mode (R.hashFast = true)
    L = make_refs_env()
    L.execute("ENV.MPFEVER_PRIVATE_FAST = '1'; R.hashFast = true; COMP_READS = {}; DUMP_CALLS = 0")
    keys = L.eval("(function() local p = R.contentHash(HS, DUMP); local t = {}; for k in pairs(p) do t[#t+1] = k end; table.sort(t); return table.concat(t, ',') end)()")
    check("Fast Pulse: R.contentHash returns only counts,lines,stations", keys == "counts,lines,stations", keys)

    counts = L.eval("R.contentHash(HS, DUMP).counts")
    check("Fast Pulse: counts matches entity totals (2/3/2/1/2/1)", counts == "2/3/2/1/2/1", counts)

    L.execute("COMP_READS = {}; DUMP_CALLS = 0; R.contentHash(HS, DUMP)")
    heavy_reads = {
        k: int(L.eval(f"COMP_READS.{k} or 0"))
        for k in ("BASE_EDGE", "MOVE_PATH", "BASE_NODE_CONFIG", "CONSTRUCTION", "TOWN_BUILDING", "SIM_PERSON")
    }
    check("Fast Pulse: zero heavy component reads", all(v == 0 for v in heavy_reads.values()), str(heavy_reads))
    check("Fast Pulse: zero dumpFn calls", int(L.eval("DUMP_CALLS")) == 0)

    L.execute("ENTITIES.CONSTRUCTION[#ENTITIES.CONSTRUCTION + 1] = 103")
    counts2 = L.eval("R.contentHash(HS, DUMP).counts")
    check("Fast Pulse: counts detects new construction", counts2 == "3/3/2/1/2/1", counts2)

    # 2. Lightweight vehicles hash (MPFEVER_VEH_LIGHT=1)
    L2 = make_refs_env()
    L2.execute("ENV.MPFEVER_VEH_LIGHT = '1'; R.hashFast = nil; COMP_READS = {}; DUMP_CALLS = 0")
    v1 = L2.eval("R.contentHash(HS, DUMP).vehicles")
    v1_again = L2.eval("R.contentHash(HS, DUMP).vehicles")
    check("MPFEVER_VEH_LIGHT=1: deterministic vehicles signature", v1 == v1_again and v1.startswith("2/"), v1)
    check("MPFEVER_VEH_LIGHT=1: does not read MOVE_PATH", int(L2.eval("COMP_READS.MOVE_PATH or 0")) == 0)
    check("MPFEVER_VEH_LIGHT=1: does not call dumpFn for vehicles", int(L2.eval("DUMP_CALLS")) == 0)

    L2.execute("VEHICLES[301].stopIndex = 3")
    v2 = L2.eval("R.contentHash(HS, DUMP).vehicles")
    check("MPFEVER_VEH_LIGHT=1: detects stopIndex change", v2 != v1, f"{v1} vs {v2}")

    # 3. Upstream default behavior (no MPFEVER_PRIVATE_FAST, no MPFEVER_VEH_LIGHT)
    L3 = make_refs_env()
    L3.execute("ENV = {}; R.hashFast = nil; COMP_READS = {}; DUMP_CALLS = 0")
    p3_has_counts = L3.eval("R.contentHash(HS, DUMP).counts ~= nil")
    check("Upstream default: counts part absent when R.hashFast is nil", not p3_has_counts)
    check("Upstream default: MOVE_PATH read for vehicles", int(L3.eval("COMP_READS.MOVE_PATH or 0")) > 0)
    check("Upstream default: dumpFn called for MOVE_PATH.dyn", int(L3.eval("DUMP_CALLS")) > 0)

    # 4. simHash 9-group rotation under MPFEVER_PRIVATE_FAST=1 + R.hashAuditN
    br = read(BRIDGE)
    sh = br[br.index("local function simHash(terrainSig, reg, n, buildIds, at)"):]
    a = sh.index('\tlocal rot = os.getenv("MPFEVER_HASHROT")')
    b = sh.index("\t-- ((0.7.13) the check's number, for the persons' digest")
    rotcode = sh[a:b]

    L4 = lupa.LuaRuntime(unpack_returned_tuples=True)
    L4.execute("ENV = {}; os.getenv = function(k) return ENV[k] end; R = {}")
    L4.execute("ROT = function(n) " + rotcode + " return R.hashSkip end")

    # Under MPFEVER_PRIVATE_FAST=1, R.hashAuditN = 1..9 hits all 9 groups (including vehicles and edgeObjects/townBuildings/persons)
    L4.execute("ENV = { MPFEVER_PRIVATE_FAST = '1' }")
    unskipped_by_audit = []
    for an in range(1, 10):
        # Even if check number n advances by 3 (2 fast + 1 audit), R.hashAuditN ensures all 9 groups are visited!
        L4.execute(f"R.hashAuditN = {an}; R.hashFast = nil")
        kept = L4.eval(f"(function() local s = ROT({an * 3}); local all = {{'conParams','edges','constructions','nodeConfigs','conParams2','edges2','owners','ages','vehicles','edgeObjects','townBuildings','persons'}}; local k = {{}}; for _, p in ipairs(all) do if not s[p] then k[#k+1] = p end end; return table.concat(k, ',') end)()")
        unskipped_by_audit.append(kept)
    check("PrivateFast rotation: 9 distinct structural groups visited sequentially with R.hashAuditN",
          len(set(unskipped_by_audit)) == 9 and "vehicles" in unskipped_by_audit and "edgeObjects,townBuildings,persons" in unskipped_by_audit,
          str(unskipped_by_audit))

    # Without MPFEVER_PRIVATE_FAST, vehicles/edgeObjects/townBuildings/persons are NOT skipped (7 upstream groups)
    L4.execute("ENV = {}; R.hashAuditN = nil; R.hashFast = nil")
    up_skipped = L4.eval("(function() local s = ROT(1); return (s.vehicles and 'v' or '') .. (s.edgeObjects and 'e' or '') .. (s.townBuildings and 't' or '') .. (s.persons and 'p' or '') end)()")
    check("Upstream rotation: vehicles/edgeObjects/townBuildings/persons remain unrotated", up_skipped == "", up_skipped)

    # 5. Launcher source wiring checks
    up = read(UPDATER)
    core = read(CORE)
    mf = read(MAINFORM)
    st = read(SELFTEST)
    check('Updater.Repo points to Dan1el-19/MPFever', 'public const string Repo = "Dan1el-19/MPFever";' in up)
    check("Core.cs applies PrivateFast env defaults in Launch", "ApplyPrivateFastEnv(psi.EnvironmentVariables," in core)
    check("MainForm.cs has RequestHashFast and DecideResync Option B",
          "void RequestHashFast()" in mf and "internal static string DecideResync(" in mf)
    check("SelfTest.cs runs RunPrivateFast", "ok &= RunPrivateFast();" in st and "static bool RunPrivateFast()" in st)

    print(f"\n{len(fails)} failure(s)" if fails else "\nall passed")
    sys.exit(1 if fails else 0)


if __name__ == "__main__":
    main()
