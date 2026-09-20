local XP = _G.YayaSessionTrackerXP or {}
_G.YayaSessionTrackerXP = XP

XP.MAX_LEVEL = 80
XP.LEVEL_BAND_SIZE = 10
XP.IDLE_TIMEOUT_SECONDS = 3 * 60
XP.ACTIVE_GRACE_SECONDS = 60
XP.MAX_SESSIONS = 1000
XP.MODE_BELOW_80 = "below80"
XP.MODE_80_TO_90 = "80to90"
XP.MODE_CONFIG = {
    below80 = { minLevel = 1, maxLevel = 80, label = "Niveaux 1–80" },
    ["80to90"] = { minLevel = 80, maxLevel = 90, label = "Niveaux 80–90" },
}
XP.SOURCE_QUEST = "quest"
XP.SOURCE_COMBAT = "combat"
XP.SOURCE_DUNGEON = "dungeon"
XP.SOURCE_OTHER = "other"
XP.SOURCE_LABELS = {
    quest = "Quêtes",
    combat = "Combats",
    dungeon = "Donjons",
    other = "Autre / inconnue",
}
XP.ZONE_ALIASES = {
    ["Darkshire Town Hall"] = "Duskwood",
    ["Lakeshire Town Hall"] = "Redridge Mountains",
}

local function Number(value, fallback)
    value = tonumber(value)
    if value == nil then
        return fallback or 0
    end
    return value
end

local function Positive(value)
    return math.max(0, Number(value))
end

function XP.NormalizeMode(mode)
    if mode == XP.MODE_80_TO_90 then
        return XP.MODE_80_TO_90
    end
    return XP.MODE_BELOW_80
end

function XP.GetModeConfig(mode)
    return XP.MODE_CONFIG[XP.NormalizeMode(mode)]
end

function XP.GetSessionStoreField(mode)
    return XP.NormalizeMode(mode) == XP.MODE_80_TO_90
        and "xpSessions80to90" or "xpSessions"
end

function XP.GetActiveStoreField(mode)
    return XP.NormalizeMode(mode) == XP.MODE_80_TO_90
        and "activeXPSession80to90" or "activeXPSession"
end

function XP.NormalizeSource(source)
    if source == XP.SOURCE_QUEST or source == XP.SOURCE_COMBAT
        or source == XP.SOURCE_DUNGEON or source == XP.SOURCE_OTHER then
        return source
    end
    return XP.SOURCE_OTHER
end

function XP.GetSourceLabel(source)
    return XP.SOURCE_LABELS[XP.NormalizeSource(source)]
end

local function CopyTable(source)
    local copy = {}
    for key, value in pairs(source or {}) do
        if type(value) == "table" then
            local nested = {}
            for nestedKey, nestedValue in pairs(value) do
                nested[nestedKey] = nestedValue
            end
            copy[key] = nested
        else
            copy[key] = value
        end
    end
    return copy
end

function XP.GetZoneName(zone)
    if not zone or zone == "" then
        return zone or ""
    end
    return XP.ZONE_ALIASES[zone] or zone
end

local function NormalizeZoneMap(map)
    if type(map) ~= "table" then
        return map
    end
    local normalized = {}
    for key, value in pairs(map) do
        local text = tostring(key)
        local separator = string.find(text, "\31", 1, true)
        local normalizedKey
        if separator then
            normalizedKey = XP.GetZoneName(string.sub(text, 1, separator - 1))
                .. string.sub(text, separator)
        else
            normalizedKey = XP.GetZoneName(text)
        end
        normalized[normalizedKey] = (normalized[normalizedKey] or 0) + Number(value)
    end
    return normalized
end

local function NormalizeBandKey(key, mode)
    local first = tostring(key):match("^(%d+)%-%d+$")
    if not first then
        return key
    end
    return XP.GetLevelBand(tonumber(first), nil, mode)
end

local function NormalizeLevelMap(map, mode)
    if type(map) ~= "table" then
        return map
    end
    local normalized = {}
    for key, value in pairs(map) do
        local normalizedKey = NormalizeBandKey(key, mode)
        normalized[normalizedKey] = (normalized[normalizedKey] or 0) + Number(value)
    end
    return normalized
end

local function NormalizeZoneLevelMap(map, mode)
    if type(map) ~= "table" then
        return map
    end
    local normalized = {}
    for key, value in pairs(map) do
        local text = tostring(key)
        local separator = string.find(text, "\31", 1, true)
        local normalizedKey
        if separator then
            normalizedKey = XP.GetZoneName(string.sub(text, 1, separator - 1))
                .. "\31" .. NormalizeBandKey(string.sub(text, separator + 1), mode)
        else
            normalizedKey = XP.GetZoneName(text)
        end
        normalized[normalizedKey] = (normalized[normalizedKey] or 0) + Number(value)
    end
    return normalized
end

local function NormalizeSourceMap(map)
    if type(map) ~= "table" then
        return {}
    end
    local normalized = {}
    for key, value in pairs(map) do
        local source = XP.NormalizeSource(key)
        normalized[source] = (normalized[source] or 0) + Positive(value)
    end
    return normalized
end

function XP.NormalizeSessionZones(session)
    if type(session) ~= "table" then
        return session
    end
    session.trackingMode = XP.NormalizeMode(session.trackingMode)
    session.startZone = XP.GetZoneName(session.startZone)
    session.endZone = XP.GetZoneName(session.endZone)
    session.lastSampleZone = XP.GetZoneName(session.lastSampleZone)
    session.zones = NormalizeZoneMap(session.zones)
    session.zoneXP = NormalizeZoneMap(session.zoneXP)
    session.zoneSeconds = NormalizeZoneMap(session.zoneSeconds)
    session.zoneLevelsGained = NormalizeZoneMap(session.zoneLevelsGained)
    session.levelXP = NormalizeLevelMap(session.levelXP, session.trackingMode)
    session.levelSeconds = NormalizeLevelMap(session.levelSeconds, session.trackingMode)
    session.levelGains = NormalizeLevelMap(session.levelGains, session.trackingMode)
    session.zoneLevelXP = NormalizeZoneLevelMap(session.zoneLevelXP, session.trackingMode)
    session.zoneLevelSeconds = NormalizeZoneLevelMap(session.zoneLevelSeconds, session.trackingMode)
    session.zoneLevelGains = NormalizeZoneLevelMap(session.zoneLevelGains, session.trackingMode)
    return session
end

function XP.NormalizeSessionSources(session)
    if type(session) ~= "table" then
        return session
    end
    session.sourceXP = NormalizeSourceMap(session.sourceXP)
    session.sourceSeconds = NormalizeSourceMap(session.sourceSeconds)
    session.sourceLevelsGained = NormalizeSourceMap(session.sourceLevelsGained)
    local recorded = 0
    for _, amount in pairs(session.sourceXP) do
        recorded = recorded + Positive(amount)
    end
    local total = Positive(session.xpGained)
    if total > recorded then
        session.sourceXP[XP.SOURCE_OTHER] = (session.sourceXP[XP.SOURCE_OTHER] or 0)
            + (total - recorded)
    end
    if total > 0 and next(session.sourceXP) == nil then
        session.sourceXP[XP.SOURCE_OTHER] = total
    end
    if session.durationSeconds and next(session.sourceSeconds) == nil then
        session.sourceSeconds[XP.SOURCE_OTHER] = Positive(session.durationSeconds)
    end
    session.lastSource = XP.NormalizeSource(session.lastSource)
    return session
end

function XP.SetLevelBandSize(size)
    size = math.floor(Number(size, 10))
    if size ~= 5 and size ~= 10 and size ~= 20 then
        size = 10
    end
    XP.LEVEL_BAND_SIZE = size
    return size
end

function XP.GetLevelBand(level, bandSize, mode)
    local config = XP.GetModeConfig(mode)
    level = math.max(config.minLevel, math.min(Number(level), config.maxLevel))
    bandSize = math.max(1, math.min(math.floor(Number(bandSize, XP.LEVEL_BAND_SIZE)),
        config.maxLevel - config.minLevel + 1))
    local first = config.minLevel
        + math.floor((level - config.minLevel) / bandSize) * bandSize
    local last = math.min(first + bandSize - 1, config.maxLevel)
    return ("%d-%d"):format(first, last)
end

function XP.NewCursor(level, currentXP, currentXPMax)
    return {
        level = Number(level),
        xp = Positive(currentXP),
        xpMax = Positive(currentXPMax),
    }
end

function XP.CalculateDelta(previous, current, mode)
    if type(previous) ~= "table" or type(current) ~= "table" then
        return 0
    end

    local config = XP.GetModeConfig(mode)
    local previousLevel = Number(previous.level)
    local currentLevel = Number(current.level)
    if previousLevel < config.minLevel or currentLevel < config.minLevel
        or previousLevel > config.maxLevel then
        return 0
    end
    if currentLevel > config.maxLevel then
        return 0
    end
    if currentLevel == config.maxLevel and previousLevel == config.maxLevel then
        return 0
    end

    local previousXP = Positive(previous.xp)
    local currentXP = Positive(current.xp)
    if currentLevel == previousLevel then
        return math.max(0, currentXP - previousXP)
    end
    if currentLevel < previousLevel then
        return 0
    end

    -- Les evenements de niveau remettent l'XP courante a zero. On ne compte
    -- que la fin du niveau precedent et, si necessaire, la progression du
    -- nouveau niveau. Au niveau 80, la progression suivante est ignoree.
    local delta = Positive(previous.xpMax - previousXP)
    if currentLevel < config.maxLevel then
        delta = delta + currentXP
    end
    return delta
end

function XP.NewSession(context)
    context = context or {}
    local trackingMode = XP.NormalizeMode(context.trackingMode or context.mode)
    local config = XP.GetModeConfig(trackingMode)
    local level = math.max(config.minLevel,
        math.min(Number(context.startLevel or context.level), config.maxLevel))
    local zone = XP.GetZoneName(context.zone or "")
    local session = {
        trackingMode = trackingMode,
        playerKey = context.playerKey,
        playerName = context.playerName,
        playerFullName = context.playerFullName,
        realm = context.realm,
        loginSessionID = context.loginSessionID,
        startedAt = Number(context.now),
        lastGainAt = Number(context.now),
        startLevel = level,
        endLevel = math.max(config.minLevel,
            math.min(Number(context.level or level), config.maxLevel)),
        specKey = context.specKey or "unknown",
        specID = context.specID,
        specName = context.specName or "Inconnue",
        role = context.role,
        classID = context.classID,
        className = context.className,
        classToken = context.classToken,
        startZone = zone,
        endZone = zone,
        lastSampleZone = zone,
        lastSampleLevelBand = XP.GetLevelBand(level, nil, trackingMode),
        zones = {},
        zoneXP = {},
        zoneSeconds = {},
        zoneLevelsGained = {},
        levelXP = {},
        levelSeconds = {},
        levelGains = {},
        zoneLevelXP = {},
        zoneLevelSeconds = {},
        zoneLevelGains = {},
        sourceXP = {},
        sourceSeconds = {},
        sourceLevelsGained = {},
        lastSource = XP.NormalizeSource(context.source),
        xpGained = 0,
        gainEvents = 0,
        largestGain = 0,
    }
    return session
end

local function AddElapsed(session, seconds)
    seconds = Positive(seconds)
    if seconds <= 0 then
        return
    end

    local zone = session.lastSampleZone or ""
    local levelBand = session.lastSampleLevelBand
        or XP.GetLevelBand(session.endLevel, nil, session.trackingMode)
    if zone ~= "" then
        session.zoneSeconds[zone] = (session.zoneSeconds[zone] or 0) + seconds
    end
    session.levelSeconds[levelBand] = (session.levelSeconds[levelBand] or 0) + seconds
    if zone ~= "" then
        local key = zone .. "\31" .. levelBand
        session.zoneLevelSeconds[key] = (session.zoneLevelSeconds[key] or 0) + seconds
    end
    local source = XP.NormalizeSource(session.lastSource)
    session.sourceSeconds[source] = (session.sourceSeconds[source] or 0) + seconds
end

local function AddZoneXP(session, zone, amount)
    zone = zone or ""
    if zone == "" then
        return
    end
    session.zones[zone] = (session.zones[zone] or 0) + 1
    session.zoneXP[zone] = (session.zoneXP[zone] or 0) + amount
end

function XP.Finalize(session, endedAt, reason)
    if type(session) ~= "table" or not session.startedAt then
        return
    end
    XP.NormalizeSessionZones(session)
    XP.NormalizeSessionSources(session)
    if session.durationSeconds then
        session.endReason = reason or session.endReason
        return session
    end

    local lastGainAt = Number(session.lastGainAt, session.startedAt)
    local maxEndedAt = lastGainAt + XP.ACTIVE_GRACE_SECONDS
    endedAt = math.min(Number(endedAt, maxEndedAt), maxEndedAt)
    endedAt = math.max(endedAt, Number(session.startedAt))
    AddElapsed(session, endedAt - lastGainAt)

    session.endedAt = endedAt
    session.endReason = reason or session.endReason
    session.durationSeconds = math.max(1, endedAt - Number(session.startedAt))
    session.xpGained = Positive(session.xpGained)
    session.xpPerHour = math.floor((session.xpGained * 3600 / session.durationSeconds) + 0.5)
    session.levelsGained = math.max(0, Number(session.endLevel) - Number(session.startLevel))
    session.levelsPerHour = session.levelsGained * 3600 / session.durationSeconds
    session.averageGain = session.gainEvents > 0
        and math.floor((session.xpGained / session.gainEvents) + 0.5)
        or 0
    return session
end

function XP.AddGain(session, context, amount)
    context = context or {}
    amount = Positive(amount)
    local trackingMode = XP.NormalizeMode(context.trackingMode or context.mode
        or (session and session.trackingMode))
    local config = XP.GetModeConfig(trackingMode)
    local zone = XP.GetZoneName(context.zone)
    if amount <= 0 or Number(context.level) < config.minLevel
        or Number(context.level) > config.maxLevel then
        return session
    end

    local closed
    local previousLevel
    local now = Number(context.now)
    if session then
        if session.trackingMode ~= trackingMode then
            closed = XP.Finalize(session, now, "mode_changed")
            session = nil
        elseif now - Number(session.lastGainAt, now) > XP.IDLE_TIMEOUT_SECONDS then
            closed = XP.Finalize(session, Number(session.lastGainAt) + XP.ACTIVE_GRACE_SECONDS, "idle_timeout")
            session = nil
        elseif context.specKey and session.specKey ~= context.specKey then
            closed = XP.Finalize(session, now, "spec_changed")
            session = nil
        else
            AddElapsed(session, now - Number(session.lastGainAt, now))
        end
    end

    if not session then
        session = XP.NewSession(context)
        previousLevel = session.endLevel
    else
        previousLevel = Number(session.endLevel)
    end

    local currentLevel = math.max(config.minLevel,
        math.min(Number(context.level or session.endLevel), config.maxLevel))
    session.xpGained = Positive(session.xpGained) + amount
    session.gainEvents = Number(session.gainEvents) + 1
    session.largestGain = math.max(Number(session.largestGain), amount)
    session.lastGainAt = now
    session.lastSource = XP.NormalizeSource(context.source)
    session.endLevel = currentLevel
    session.endZone = zone ~= "" and zone or session.endZone
    session.lastSampleZone = zone ~= "" and zone or session.lastSampleZone
    session.lastSampleLevelBand = XP.GetLevelBand(session.endLevel, nil, trackingMode)
    AddZoneXP(session, zone, amount)
    local levelBand = XP.GetLevelBand(session.endLevel, nil, trackingMode)
    session.levelXP[levelBand] = (session.levelXP[levelBand] or 0) + amount
    session.sourceXP[session.lastSource] = (session.sourceXP[session.lastSource] or 0) + amount
    if zone ~= "" then
        local zoneLevelKey = zone .. "\31" .. levelBand
        session.zoneLevelXP[zoneLevelKey] = (session.zoneLevelXP[zoneLevelKey] or 0) + amount
    end

    if currentLevel > previousLevel then
        for reachedLevel = previousLevel + 1, currentLevel do
            local reachedBand = XP.GetLevelBand(reachedLevel, nil, trackingMode)
            session.levelGains[reachedBand] = (session.levelGains[reachedBand] or 0) + 1
            session.sourceLevelsGained[session.lastSource] =
                (session.sourceLevelsGained[session.lastSource] or 0) + 1
            if zone ~= "" then
                session.zoneLevelsGained[zone] = (session.zoneLevelsGained[zone] or 0) + 1
                local reachedKey = zone .. "\31" .. reachedBand
                session.zoneLevelGains[reachedKey] = (session.zoneLevelGains[reachedKey] or 0) + 1
            end
        end
    end

    return session, closed
end

function XP.CopyForPreview(session)
    return CopyTable(session)
end

local function NewAggregate(source)
    return {
        sessions = 0,
        xpGained = 0,
        durationSeconds = 0,
        levelsGained = 0,
        bestXPH = 0,
        bestLevelsPerHour = 0,
        specKey = source and source.specKey,
        specID = source and source.specID,
        specName = source and source.specName or "Inconnue",
        role = source and source.role,
        classID = source and source.classID,
        className = source and source.className,
        classToken = source and source.classToken,
        byZone = {},
        byLevelBand = {},
        byZoneLevelBand = {},
        bySource = {},
    }
end

local function AddAggregateBucket(container, key, xp, seconds, levels)
    local bucket = container[key]
    if not bucket then
        bucket = { xpGained = 0, durationSeconds = 0, levelsGained = 0 }
        container[key] = bucket
    end
    bucket.xpGained = bucket.xpGained + Positive(xp)
    bucket.durationSeconds = bucket.durationSeconds + Positive(seconds)
    bucket.levelsGained = bucket.levelsGained + Positive(levels)
end

local function FinishMetricBuckets(buckets)
    for _, bucket in pairs(buckets or {}) do
        bucket.xpPerHour = bucket.durationSeconds > 0
            and math.floor((bucket.xpGained * 3600 / bucket.durationSeconds) + 0.5)
            or 0
        bucket.levelsPerHour = bucket.durationSeconds > 0
            and bucket.levelsGained * 3600 / bucket.durationSeconds
            or 0
    end
end

local function AddToAggregate(aggregate, session)
    aggregate.sessions = aggregate.sessions + 1
    aggregate.xpGained = aggregate.xpGained + Positive(session.xpGained)
    aggregate.durationSeconds = aggregate.durationSeconds + Number(session.durationSeconds, 1)
    aggregate.levelsGained = aggregate.levelsGained + Number(session.levelsGained)
    aggregate.bestXPH = math.max(aggregate.bestXPH, Number(session.xpPerHour))
    aggregate.bestLevelsPerHour = math.max(aggregate.bestLevelsPerHour, Number(session.levelsPerHour))
    for zone, amount in pairs(session.zoneXP or {}) do
        local levels
        if session.zoneLevelsGained then
            levels = session.zoneLevelsGained[zone]
        elseif zone == session.endZone then
            levels = session.levelsGained
        end
        AddAggregateBucket(aggregate.byZone, zone, amount,
            session.zoneSeconds and session.zoneSeconds[zone], levels)
    end
    for levelBand, amount in pairs(session.levelXP or {}) do
        local levels
        if session.levelGains then
            levels = session.levelGains[levelBand]
        elseif levelBand == XP.GetLevelBand(session.endLevel, nil, session.trackingMode) then
            levels = session.levelsGained
        end
        AddAggregateBucket(aggregate.byLevelBand, levelBand, amount,
            session.levelSeconds and session.levelSeconds[levelBand], levels)
    end
    for key, amount in pairs(session.zoneLevelXP or {}) do
        local levels
        if session.zoneLevelGains then
            levels = session.zoneLevelGains[key]
        elseif key == (session.endZone or "") .. "\31"
            .. XP.GetLevelBand(session.endLevel, nil, session.trackingMode) then
            levels = session.levelsGained
        end
        AddAggregateBucket(aggregate.byZoneLevelBand, key, amount,
            session.zoneLevelSeconds and session.zoneLevelSeconds[key], levels)
    end
    for source, amount in pairs(session.sourceXP or {}) do
        AddAggregateBucket(aggregate.bySource, XP.NormalizeSource(source), amount,
            session.sourceSeconds and session.sourceSeconds[source],
            session.sourceLevelsGained and session.sourceLevelsGained[source])
    end
end

local function FinishAggregate(aggregate)
    aggregate.xpPerHour = aggregate.durationSeconds > 0
        and math.floor((aggregate.xpGained * 3600 / aggregate.durationSeconds) + 0.5)
        or 0
    aggregate.levelsPerHour = aggregate.durationSeconds > 0
        and aggregate.levelsGained * 3600 / aggregate.durationSeconds
        or 0
    FinishMetricBuckets(aggregate.byZone)
    FinishMetricBuckets(aggregate.byLevelBand)
    FinishMetricBuckets(aggregate.byZoneLevelBand)
    FinishMetricBuckets(aggregate.bySource)
    return aggregate
end

function XP.BuildStats(sessions, trackingMode)
    trackingMode = trackingMode and XP.NormalizeMode(trackingMode) or nil
    local stats = NewAggregate()
    stats.byClass = {}
    stats.bySpec = {}
    stats.byCharacter = {}
    stats.bySource = {}

    for _, session in ipairs(sessions or {}) do
        if type(session) == "table" and Positive(session.xpGained) > 0 then
            local aggregateSession = CopyTable(session)
            XP.NormalizeSessionZones(aggregateSession)
            XP.NormalizeSessionSources(aggregateSession)
            if (not trackingMode or aggregateSession.trackingMode == trackingMode)
                and not aggregateSession.durationSeconds then
                XP.Finalize(aggregateSession, aggregateSession.endedAt, aggregateSession.endReason)
            end
            if not trackingMode or aggregateSession.trackingMode == trackingMode then
                AddToAggregate(stats, aggregateSession)
                local classKey = aggregateSession.classToken or tostring(aggregateSession.classID or "unknown")
                stats.byClass[classKey] = stats.byClass[classKey] or NewAggregate(aggregateSession)
                AddToAggregate(stats.byClass[classKey], aggregateSession)
                local specKey = aggregateSession.specKey or "unknown"
                stats.bySpec[specKey] = stats.bySpec[specKey] or NewAggregate(aggregateSession)
                AddToAggregate(stats.bySpec[specKey], aggregateSession)

                local characterKey = aggregateSession.playerKey or aggregateSession.playerFullName
                    or aggregateSession.playerName or "unknown"
                stats.byCharacter[characterKey] = stats.byCharacter[characterKey]
                    or NewAggregate(aggregateSession)
                AddToAggregate(stats.byCharacter[characterKey], aggregateSession)
            end
        end
    end

    FinishAggregate(stats)
    for _, aggregate in pairs(stats.bySpec) do
        FinishAggregate(aggregate)
    end
    for _, aggregate in pairs(stats.byClass) do
        FinishAggregate(aggregate)
    end
    for _, aggregate in pairs(stats.byCharacter) do
        FinishAggregate(aggregate)
    end
    return stats
end
