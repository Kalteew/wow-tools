-- Tests de la logique XP de YayaSessionTracker, executes hors du jeu.

assert(loadfile("YayaSessionTrackerXP.lua"))("YayaSessionTrackerXP")
local XP = _G.YayaSessionTrackerXP
local passed, failed = 0, 0

local function check(name, condition, detail)
    if condition then
        passed = passed + 1
        print(("  OK    %s"):format(name))
    else
        failed = failed + 1
        print(("  ECHEC %s%s"):format(name, detail and (" -> " .. tostring(detail)) or ""))
    end
end

local function equals(name, actual, expected)
    check(name, actual == expected, ("attendu %s, obtenu %s"):format(tostring(expected), tostring(actual)))
end

print("XP tracker")
equals("tranche basse", XP.GetLevelBand(1), "1-10")
equals("tranche haute", XP.GetLevelBand(80), "71-80")
equals("reglage tranche 20", XP.SetLevelBandSize(20), 20)
equals("tranche 20 configurable", XP.GetLevelBand(21), "21-40")
XP.SetLevelBandSize(10)
equals("sous-zone Darkshire canonisee", XP.GetZoneName("Darkshire Town Hall"), "Duskwood")
local legacyZones = {
    zoneXP = { ["Darkshire Town Hall"] = 10 },
    zoneSeconds = { ["Darkshire Town Hall"] = 5 },
    levelXP = { ["61-65"] = 25 },
    levelSeconds = { ["61-65"] = 4 },
    zoneLevelXP = { ["Darkshire Town Hall\31" .. "61-65"] = 25 },
}
XP.NormalizeSessionZones(legacyZones)
equals("ancienne zone fusionnee", legacyZones.zoneXP.Duskwood, 10)
equals("ancienne tranche fusionnee", legacyZones.levelXP["61-70"], 25)
equals("ancienne zone/tranche fusionnee", legacyZones.zoneLevelXP["Duskwood\31" .. "61-70"], 25)
equals("delta dans un niveau", XP.CalculateDelta(
    XP.NewCursor(10, 100, 1000), XP.NewCursor(10, 350, 1000)), 250)
equals("delta de passage au niveau 80", XP.CalculateDelta(
    XP.NewCursor(79, 900, 1000), XP.NewCursor(80, 0, 1000)), 100)
equals("XP ignoree au-dessus du plafond", XP.CalculateDelta(
    XP.NewCursor(80, 0, 1000), XP.NewCursor(80, 100, 1000)), 0)
equals("mode 80-90 conserve", XP.NormalizeMode("80to90"), XP.MODE_80_TO_90)
equals("tranche post-80", XP.GetLevelBand(80, 10, XP.MODE_80_TO_90), "80-89")
equals("delta post-80", XP.CalculateDelta(
    XP.NewCursor(80, 900, 1000), XP.NewCursor(81, 0, 1000), XP.MODE_80_TO_90), 100)
equals("delta post-90 ignore", XP.CalculateDelta(
    XP.NewCursor(90, 0, 1000), XP.NewCursor(90, 100, 1000), XP.MODE_80_TO_90), 0)
local levelRateSession = XP.NewSession({ now = 0, startLevel = 5, level = 6 })
levelRateSession.xpGained = 100
XP.Finalize(levelRateSession, 60, "test")
equals("niveaux par heure", levelRateSession.levelsPerHour, 60)

local context = {
    now = 100,
    level = 5,
    startLevel = 5,
    zone = "Foret d'Elwynn",
    playerKey = "Royaume.Test",
    specKey = "1:2",
    specID = 2,
    specName = "Test",
    classID = 1,
    className = "Classe test",
    classToken = "TEST",
}
local session = XP.AddGain(nil, context, 100)
equals("premier gain ouvre une session", session.xpGained, 100)
session = XP.AddGain(session, { now = 130, level = 5, zone = "Foret d'Elwynn", specKey = "1:2" }, 200)
equals("gains cumules", session.xpGained, 300)
equals("temps inter-gains conserve", session.levelSeconds["1-10"], 30)

local nextSession, closed = XP.AddGain(session, {
    now = 500,
    level = 6,
    zone = "Marche de l'Ouest",
    specKey = "1:2",
    classID = 1,
    className = "Classe test",
    classToken = "TEST",
}, 400)
equals("pause longue ferme la session", closed.endReason, "idle_timeout")
equals("pause longue exclue du temps", closed.durationSeconds, 90)
equals("nouvelle session apres pause", nextSession.startZone, "Marche de l'Ouest")
equals("zone de la nouvelle session", nextSession.zoneXP["Marche de l'Ouest"], 400)

local specSession, specClosed = XP.AddGain(nextSession, {
    now = 560,
    level = 6,
    zone = "Marche de l'Ouest",
    specKey = "9:9",
    specID = 9,
    specName = "Autre",
    classID = 1,
    className = "Classe test",
    classToken = "TEST",
}, 50)
equals("changement de spe ferme la session", specClosed.endReason, "spec_changed")
XP.Finalize(specSession, 610, "test")
equals("temps final de la nouvelle session", specSession.durationSeconds, 50)

local stats = XP.BuildStats({ closed, specClosed, specSession })
equals("agregat par classe", stats.byClass.TEST.xpGained, 750)
check("XP/h par classe calcule", stats.byClass.TEST.xpPerHour > 0)
equals("agregat par spe", stats.bySpec["1:2"].xpGained, 700)
equals("agregat par zone", stats.byZone["Foret d'Elwynn"].xpGained, 300)
equals("agregat par tranche", stats.byLevelBand["1-10"].xpGained, 750)
check("agregat zone/tranche",
    stats.byZoneLevelBand["Foret d'Elwynn\31" .. "1-10"].xpGained == 300)

local sourceSession = XP.AddGain(nil, {
    now = 800,
    level = 5,
    startLevel = 5,
    zone = "Elwynn",
    specKey = "source:test",
    source = XP.SOURCE_QUEST,
}, 100)
sourceSession = XP.AddGain(sourceSession, {
    now = 830,
    level = 5,
    zone = "Elwynn",
    specKey = "source:test",
    source = XP.SOURCE_COMBAT,
}, 200)
sourceSession = XP.AddGain(sourceSession, {
    now = 860,
    level = 6,
    zone = "Elwynn",
    specKey = "source:test",
    source = XP.SOURCE_DUNGEON,
}, 300)
XP.Finalize(sourceSession, 920, "test")
local sourceStats = XP.BuildStats({ sourceSession })
equals("XP quête par source", sourceStats.bySource.quest.xpGained, 100)
equals("XP combat par source", sourceStats.bySource.combat.xpGained, 200)
equals("XP donjon par source", sourceStats.bySource.dungeon.xpGained, 300)
check("XP/h par source calcule", sourceStats.bySource.dungeon.xpPerHour > 0)
check("niveaux/h par source calcule", sourceStats.bySource.dungeon.levelsPerHour > 0)

local legacySession = {
    trackingMode = XP.MODE_BELOW_80,
    startedAt = 1000,
    endedAt = 1090,
    startLevel = 5,
    endLevel = 5,
    xpGained = 900,
    durationSeconds = 90,
    xpPerHour = 36000,
    levelsGained = 0,
    levelsPerHour = 0,
}
local legacyStats = XP.BuildStats({ legacySession })
equals("ancienne session classee autre", legacyStats.bySource.other.xpGained, 900)
check("ancienne session garde son XP/h", legacyStats.bySource.other.xpPerHour > 0)
check("consolidation sans mutation", legacySession.sourceXP == nil and legacySession.sourceSeconds == nil)

local levelSession = XP.AddGain(nil, {
    now = 700,
    level = 5,
    startLevel = 5,
    zone = "Duskwood",
    specKey = "level:test",
}, 100)
levelSession = XP.AddGain(levelSession, {
    now = 730,
    level = 6,
    zone = "Duskwood",
    specKey = "level:test",
}, 100)
XP.Finalize(levelSession, 790, "test")
local levelStats = XP.BuildStats({ levelSession })
equals("niveau gagne par tranche", levelStats.byLevelBand["1-10"].levelsGained, 1)
check("niveaux/h par tranche calcule", levelStats.byLevelBand["1-10"].levelsPerHour > 0)
equals("niveau gagne par zone", levelStats.byZone.Duskwood.levelsGained, 1)

local post80Session = XP.AddGain(nil, {
    now = 900,
    level = 80,
    startLevel = 80,
    zone = "Outreterre",
    specKey = "post:test",
    trackingMode = XP.MODE_80_TO_90,
}, 100)
post80Session = XP.AddGain(post80Session, {
    now = 930,
    level = 81,
    zone = "Outreterre",
    specKey = "post:test",
    trackingMode = XP.MODE_80_TO_90,
}, 100)
XP.Finalize(post80Session, 990, "test")
local post80Stats = XP.BuildStats({ post80Session }, XP.MODE_80_TO_90)
equals("dataset post-80 conserve", post80Stats.sessions, 1)
check("niveaux/h post-80 calcule", post80Stats.byLevelBand["80-89"].levelsPerHour > 0)
equals("dataset 1-80 isole", XP.BuildStats({ levelSession, post80Session }, XP.MODE_BELOW_80).sessions, 1)

print("")
print(("%d reussis, %d echoues"):format(passed, failed))
if failed > 0 then
    os.exit(1)
end
