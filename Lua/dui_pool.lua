-- DUI Pool Manager for DolphinNameTag
-- Manages a pool of DUI browser instances for efficient nametag rendering

local POOL_SIZE = 30
local DUI_WIDTH = 1024
local DUI_HEIGHT = 512
local DUI_URL = "nui://" .. GetCurrentResourceName() .. "/dui/nametag.html?resourceName=" .. GetCurrentResourceName()

local pool = {}           -- pool[i] = { duiObj, txdName, txnName, serverId, dataHash, dirty, sendCount }
local serverIdToSlot = {} -- serverId -> pool index
local freeSlots = {}      -- available slot stack
local poolReady = false

-- DUI 페이지 JS 로딩 완료 콜백 카운터
local duiReadyCount = 0

RegisterNuiCallback('duiReady', function(data, cb)
    duiReadyCount = duiReadyCount + 1
    cb('ok')
end)

function InitPool()
    for i = 1, POOL_SIZE do
        local duiObj = CreateDui(DUI_URL, DUI_WIDTH, DUI_HEIGHT)

        while not IsDuiAvailable(duiObj) do
            Citizen.Wait(100)
        end

        local duiHandle = GetDuiHandle(duiObj)
        local txdName = "nt_txd_" .. i
        local txnName = "nt_txn_" .. i
        local txd = CreateRuntimeTxd(txdName)
        CreateRuntimeTextureFromDuiHandle(txd, txnName, duiHandle)

        pool[i] = {
            duiObj = duiObj,
            txdName = txdName,
            txnName = txnName,
            serverId = nil,
            dataHash = nil,
            dirty = false,
            sendCount = 0
        }
        freeSlots[#freeSlots + 1] = i

        -- Yield every 5 slots to avoid blocking
        if i % 5 == 0 then
            Citizen.Wait(0)
        end
    end

    -- 모든 DUI 페이지의 JS 로딩 완료 대기 (명시적 콜백 + 타임아웃)
    local waitStart = GetGameTimer()
    while duiReadyCount < POOL_SIZE do
        Citizen.Wait(50)
        if GetGameTimer() - waitStart > 5000 then
            break -- 타임아웃: sendCount 안전장치로 진행
        end
    end
    poolReady = true
end

function IsPoolReady()
    return poolReady
end

function AllocateSlot(serverId)
    if not serverId then return nil end

    -- Already allocated
    local existing = serverIdToSlot[serverId]
    if existing then
        return pool[existing]
    end

    -- Pool exhausted
    if #freeSlots == 0 then
        return nil
    end

    local slotIdx = freeSlots[#freeSlots]
    freeSlots[#freeSlots] = nil

    local slot = pool[slotIdx]
    slot.serverId = serverId
    slot.dataHash = nil
    slot.dirty = true  -- Mark dirty until first data update renders
    slot.sendCount = 0
    serverIdToSlot[serverId] = slotIdx

    -- Clear old content
    SendDuiMessage(slot.duiObj, json.encode({ type = "clear" }))

    return slot
end

function ReleaseSlot(serverId)
    if not serverId then return end

    local slotIdx = serverIdToSlot[serverId]
    if not slotIdx then return end

    local slot = pool[slotIdx]
    SendDuiMessage(slot.duiObj, json.encode({ type = "clear" }))

    slot.serverId = nil
    slot.dataHash = nil
    slot.dirty = false
    serverIdToSlot[serverId] = nil
    freeSlots[#freeSlots + 1] = slotIdx
end

function ReleaseAllSlots()
    local toRelease = {}
    for serverId, _ in pairs(serverIdToSlot) do
        toRelease[#toRelease + 1] = serverId
    end
    for _, serverId in ipairs(toRelease) do
        ReleaseSlot(serverId)
    end
end

function UpdateSlotData(serverId, data)
    if not serverId or not data then return end

    local slotIdx = serverIdToSlot[serverId]
    if not slotIdx then return end

    local slot = pool[slotIdx]

    -- Build hash from data fields for change detection
    local hash = tostring(data.name or "") .. "|"
        .. tostring(data.user_id or "") .. "|"
        .. tostring(data.job or "") .. "|"
        .. tostring(data.rank or "") .. "|"
        .. tostring(data.color or "") .. "|"
        .. tostring(data.emoji or "") .. "|"
        .. tostring(data.title or "") .. "|"
        .. tostring(data.titleColor or "") .. "|"
        .. tostring(data.img or "") .. "|"
        .. tostring(data.chatId or "") .. "|"
        .. tostring(data.chatMsg or "") .. "|"
        .. tostring(data.talkState and "1" or "0") .. "|"
        .. tostring(data.imgClose and "1" or "0") .. "|"
        .. tostring(data.imgScale or "")

    if slot.dataHash == hash and slot.sendCount >= 2 then
        return -- No change, already sent at least twice
    end

    slot.dataHash = hash
    slot.dirty = false
    slot.sendCount = slot.sendCount + 1

    local msg = json.encode({
        type = "update",
        name = data.name,
        user_id = data.user_id,
        job = data.job,
        rank = data.rank,
        color = data.color,
        emoji = data.emoji,
        title = data.title,
        titleColor = data.titleColor,
        img = data.img,
        chatId = data.chatId,
        chatMsg = data.chatMsg,
        talkState = data.talkState,
        showName = data.showName,
        showJob = data.showJob,
        showTitle = data.showTitle,
        showEmoji = data.showEmoji,
        showChat = data.showChat,
        showHeadImg = data.showHeadImg,
        imgClose = data.imgClose,
        imgScale = data.imgScale
    })
    SendDuiMessage(slot.duiObj, msg)
end

function GetSlotByServerId(serverId)
    if not serverId then return nil end
    local slotIdx = serverIdToSlot[serverId]
    if not slotIdx then return nil end
    return pool[slotIdx]
end

function SendToSlot(serverId, message)
    if not serverId or not message then return end
    local slotIdx = serverIdToSlot[serverId]
    if not slotIdx then return end
    local slot = pool[slotIdx]
    SendDuiMessage(slot.duiObj, json.encode(message))
end

function GetAllocatedServerIds()
    local ids = {}
    for serverId, _ in pairs(serverIdToSlot) do
        ids[serverId] = true
    end
    return ids
end

function DestroyPool()
    for i = 1, #pool do
        if pool[i] and pool[i].duiObj then
            DestroyDui(pool[i].duiObj)
        end
    end
    pool = {}
    serverIdToSlot = {}
    freeSlots = {}
    poolReady = false
end
