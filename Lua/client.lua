NameTag = {}
Tunnel.bindInterface(GetCurrentResourceName(), NameTag)
NameTagS = Tunnel.getInterface(GetCurrentResourceName(), GetCurrentResourceName())

local player = {}
local chat_data = {}
local players = {}
local playerCount = 0
local nearbyPlayers = {}
local nearbyPlayerCount = 0

local isShowUI = true
local isShowUIRest = false
-- 상세 표시 설정 (KVP 저장)
local nametagSettings = {
    enabled = GetResourceKvpString("nametag_enabled") ~= "false",
    showName = GetResourceKvpString("nametag_showName") ~= "false",
    showJob = GetResourceKvpString("nametag_showJob") ~= "false",          -- 팩션/직업명
    showTitle = GetResourceKvpString("nametag_showTitle") ~= "false",      -- 칭호 (custom_titles)
    showEmoji = GetResourceKvpString("nametag_showEmoji") ~= "false",
    showChat = GetResourceKvpString("nametag_showChat") ~= "false",        -- 머리위 채팅
    showHeadImg = GetResourceKvpString("nametag_showHeadImg") ~= "false",  -- 다른 플레이어 머리위 이미지 보기
    useDUI = GetResourceKvpString("nametag_useDUI") ~= "false",           -- DUI/NUI 선택 (true=DUI, false=NUI)
    emojiMode = GetResourceKvpString("nametag_emojiMode") or "both",       -- 이모지 모드: faction/special/both
    renderTick = tonumber(GetResourceKvpString("nametag_renderTick")) or 18  -- 이름표 업데이트 주기 (ms)
}

-- toggle: 1=DUI, 2=NUI, 3=DrawText (F2로 UI↔DrawText 전환, DUI/NUI는 useDUI 설정으로 결정)
local toggle = nametagSettings.useDUI and 1 or 2

local PlayerPed = nil
local PlayerCoords = nil
local myServerId = nil
local nearbyPlayerCoords = {}

-- DUI 플레이어별 독립 렌더 스레드 관리
local duiActiveEntries = {}      -- serverId -> { ped, slot, visible, active, lerpH }
local duiRenderingActive = false -- pause/UI 상태 플래그

local NEARBY_CHECK_INTERVAL = 200
local RENDER_TICK_DRAW = 0  -- DrawText3D는 매 프레임 렌더링 필요 (깜빡임 방지)
local MAX_VISIBLE_PLAYERS = 30
local NEARBY_DISTANCE = 20.0
local NEARBY_DISTANCE_SQ = NEARBY_DISTANCE * NEARBY_DISTANCE
local DRAWTEXT_DISTANCE = 30.0

local chat_id = 0

-- 주사위 애니메이션 데이터 (상단에 선언)
local diceAnimations = {}

-- 주사위 이미지 URL (1~6)
local diceImages = {
    [1] = "https://cdn.dolp.kr/hud/dice-six-faces-one.svg",
    [2] = "https://cdn.dolp.kr/hud/dice-six-faces-two.svg",
    [3] = "https://cdn.dolp.kr/hud/dice-six-faces-three.svg",
    [4] = "https://cdn.dolp.kr/hud/dice-six-faces-four.svg",
    [5] = "https://cdn.dolp.kr/hud/dice-six-faces-five.svg",
    [6] = "https://cdn.dolp.kr/hud/dice-six-faces-six.svg",
}
-- 주사위 텍스트 이모지 (DrawText용)
local diceEmojis = {
    [1] = "[1]",
    [2] = "[2]",
    [3] = "[3]",
    [4] = "[4]",
    [5] = "[5]",
    [6] = "[6]",
}

RegisterFontFile('notosansm')
local fontId = RegisterFontId('notosansm')

local blockedRanges = {
    {0x0001F601, 0x0001F64F}, {0x00002702, 0x000027B0},
    {0x0001F680, 0x0001F6C0}, {0x0001F300, 0x0001F5FF},
    {0x00002194, 0x00002199}, {0x000023E9, 0x000023F3},
    {0x000025FB, 0x000026FD}, {0x0001F600, 0x0001F636},
    {0x0001F681, 0x0001F6C5}, {0x0001F30D, 0x0001F567}
}

local blockedSingles = {
    [0x000000A9] = true, [0x000000AE] = true, [0x0000203C] = true,
    [0x00002049] = true, [0x000020E3] = true, [0x00002122] = true,
    [0x00002139] = true, [0x000021A9] = true, [0x000021AA] = true,
    [0x0000231A] = true, [0x0000231B] = true, [0x000025AA] = true,
    [0x000025AB] = true, [0x000025B6] = true, [0x000025C0] = true,
    [0x00002934] = true, [0x00002935] = true, [0x00002B05] = true,
    [0x00002B06] = true, [0x00002B07] = true, [0x00002B1B] = true,
    [0x00002B1C] = true, [0x00002B50] = true, [0x00002B55] = true,
    [0x00003030] = true, [0x0000303D] = true, [0x00003297] = true,
    [0x00003299] = true, [0x0001F004] = true, [0x0001F0CF] = true,
    [0x0001F985] = true
}

function removeEmoji(str)
    if not str or type(str) ~= "string" or str == "" then return "" end

    local codepoints = {}
    local ok, err = pcall(function()
        for _, codepoint in utf8.codes(str) do
            local dominated = blockedSingles[codepoint]
            if not dominated then
                for _, range in ipairs(blockedRanges) do
                    if codepoint >= range[1] and codepoint <= range[2] then
                        dominated = true
                        break
                    end
                end
            end
            if not dominated then
                codepoints[#codepoints + 1] = codepoint
            end
        end
    end)

    if not ok then return str end
    if #codepoints == 0 then return "" end

    local charOk, result = pcall(utf8.char, table.unpack(codepoints))
    return charOk and result or str
end

local function distanceSquared(c1, c2)
    local dx, dy, dz = c1.x - c2.x, c1.y - c2.y, c1.z - c2.z
    return dx * dx + dy * dy + dz * dz
end

function DrawText3D(x, y, z, text, r, g, b, a, s)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    if not onScreen then return end

    local camCoords = GetGameplayCamCoords()
    local dx, dy, dz = camCoords.x - x, camCoords.y - y, camCoords.z - z
    local dist = math.sqrt(dx * dx + dy * dy + dz * dz)
    if dist > DRAWTEXT_DISTANCE then return end

    local scale = (1 / dist) * s
    local fov = (1 / GetGameplayCamFov()) * 100
    scale = scale * fov
    if scale < 0.25 then scale = 0.25 end

    SetTextScale(0.0 * scale, 0.6 * scale)
    SetTextFont(fontId)
    SetTextProportional(1)
    SetTextColour(r, g, b, a)
    SetTextDropShadow(0, 0, 0, 0, 255) 
    SetTextEdge(2, 0, 0, 0, 255)
    SetTextOutline()
    SetTextEntry("STRING")
    SetTextCentre(1)
    AddTextComponentString(text)
    DrawText(_x, _y)
end

-- ==================== DUI 렌더 (플레이어별 독립 스레드) ====================

-- FOV/해상도 캐시 (독립 스레드에서 갱신)
local cachedFovScale = 2.0
local cachedAspectRatio = 16 / 9

local LERP_SPEED = 0.25  -- 프레임당 25% 접근
local SCALE_DEADZONE = 0.03  -- 목표와 차이가 이 이하이면 보간 스킵

-- FOV/해상도 캐시 독립 스레드
Citizen.CreateThread(function()
    while true do
        cachedFovScale = (1 / GetGameplayCamFov()) * 100
        local sw, sh = GetActiveScreenResolution()
        cachedAspectRatio = sw / sh
        Citizen.Wait(500)
    end
end)

-- 플레이어별 독립 렌더 스레드 생성
local function spawnPlayerRenderThread(entry)
    Citizen.CreateThread(function()
        while entry.active do
            if duiRenderingActive and entry.visible and entry.ped and entry.slot and PlayerCoords then
                local ped = entry.ped
                local slot = entry.slot

                local bone = GetPedBoneCoords(ped, 31086)
                local onScreen, sx, sy = World3dToScreen2d(bone.x, bone.y, bone.z + 0.3)
                if onScreen then
                    local ar = cachedAspectRatio

                    local spriteH = 0.23
                    local spriteW = spriteH * 2.0 / ar

                    DrawSprite(slot.txdName, slot.txnName, sx, sy - spriteH * 0.5,
                        spriteW, spriteH, 0.0, 255, 255, 255, 255)
                end
            end
            Citizen.Wait(0)
        end
        entry.lerpH = nil
    end)
end

-- ==================== NUI 렌더 함수 ====================

local NUIdata = {}

local function renderNUI()
    local visiblePlayers = 0
    for k in pairs(NUIdata) do NUIdata[k] = nil end

    for i = 1, nearbyPlayerCount do
        local v = nearbyPlayers[i]
        if v then
            local ped = GetPlayerPed(v)
            if ped and ped ~= 0 then
                local pedCoords = nearbyPlayerCoords[v] or GetEntityCoords(ped, false)

                if IsEntityVisible(ped) and GetEntityAlpha(ped) > 60 then
                    local pedBone = GetPedBoneCoords(ped, 31086)
                    local onScreen, x, y = World3dToScreen2d(pedBone.x, pedBone.y, pedBone.z + 0.3)

                    if onScreen then
                        visiblePlayers = visiblePlayers + 1
                        if visiblePlayers > MAX_VISIBLE_PLAYERS then break end

                        local serverID = GetPlayerServerId(v)
                        local data = player[serverID]
                        local talk = NetworkIsPlayerTalking(v)
                        local chat = chat_data[serverID]
                        local scale = 1.4
                        local dist = #(PlayerCoords - pedCoords)
                        local imgScale = 1.0 - 0.35 * (dist / 15.0)
                        if imgScale < 0.65 then imgScale = 0.65 end
                        if imgScale > 1.0 then imgScale = 1.0 end

                        NUIdata[v] = {
                            id = v,
                            serverId = serverID,
                            x = x * 100,
                            y = y * 100,
                            talk = talk,
                            chat = nametagSettings.showChat and chat or nil,
                            scale = scale,
                            imgClose = dist <= 15.0,
                            imgScale = imgScale,
                            data = data,
                            name = data and nil or GetPlayerName(v),
                            settings = nametagSettings
                        }
                    end
                end
            end
        end
    end

    SendNUIMessage({ type = "updateNameTag", table = NUIdata })
end

-- ==================== DrawText 렌더 함수 ====================

local function renderDrawText()
    for i = 1, nearbyPlayerCount do
        local v = nearbyPlayers[i]
        if not v then goto dt_continue end
        local ped = GetPlayerPed(v)
        if not ped or ped == 0 then goto dt_continue end
        local pedCoords = nearbyPlayerCoords[v] or GetEntityCoords(ped, false)
        if not (IsEntityVisible(ped) and GetEntityAlpha(ped) > 60) then goto dt_continue end

        local pedBone = GetPedBoneCoords(ped, 31086)
        local onScreen = World3dToScreen2d(pedBone.x, pedBone.y, pedBone.z + 0.3)
        if not onScreen then goto dt_continue end

        local serverID = GetPlayerServerId(v)
        local data = player[serverID]
        local talk = NetworkIsPlayerTalking(v)
        local scale = 1.4

        if data then
            local r, g, b = 255, 194, 61
            if data.color and data.color ~= "" then
                if data.job == "흑야" then
                    r, g, b = 255, 211, 176
                else
                    local parts = {}
                    for part in string.gmatch(data.color, "%d+") do
                        parts[#parts + 1] = tonumber(part)
                    end
                    r, g, b = parts[1] or 255, parts[2] or 255, parts[3] or 255
                end
            end

            local tr, tg, tb = talk and 0 or 255, talk and 216 or 255, talk and 255 or 255
            local camDist = #(GetGameplayCamCoords() - vector3(pedBone.x, pedBone.y, pedBone.z))
            local lineGap = 0.0425 + camDist * 0.008
            local zOffset = 0.4 + (camDist > 5.0 and (camDist - 5.0) * 0.0175 or 0.0)

            if nametagSettings.showName then
                DrawText3D(pedBone.x, pedBone.y, pedBone.z + zOffset, removeEmoji(data.name) .. " ( " .. data.user_id .. " )", tr, tg, tb, 255, scale)
                zOffset = zOffset + lineGap
            end

            if nametagSettings.showJob then
                local displayText = nil
                if data.rank and data.rank ~= "" and data.job and data.job ~= "" then
                    displayText = data.job .. " " .. data.rank
                elseif data.rank and data.rank ~= "" then
                    displayText = data.rank
                elseif data.job and data.job ~= "" then
                    displayText = data.job
                end

                if displayText then
                    DrawText3D(pedBone.x, pedBone.y, pedBone.z + zOffset, displayText, r, g, b, 255, scale)
                    zOffset = zOffset + lineGap
                end
            end

            if nametagSettings.showEmoji and data.emoji then
                DrawText3D(pedBone.x, pedBone.y, pedBone.z + zOffset, data.emoji, 255, 194, 61, 255, scale)
            end
        else
            local tr, tg, tb = talk and 0 or 255, talk and 216 or 255, talk and 255 or 255
            if nametagSettings.showName then
                DrawText3D(pedBone.x, pedBone.y, pedBone.z + 0.4, GetPlayerName(v), tr, tg, tb, 255, scale)
            end
        end
        ::dt_continue::
    end
end

-- ==================== 스레드 ====================

-- 플레이어 수 모니터링
Citizen.CreateThread(function()
    while true do
        players = GetActivePlayers()
        playerCount = #players
        myServerId = PlayerId()

        if playerCount > 200 then
            NEARBY_CHECK_INTERVAL = 500
            Citizen.Wait(15000)
        elseif playerCount > 100 then
            NEARBY_CHECK_INTERVAL = 300
            Citizen.Wait(10000)
        elseif playerCount > 50 then
            NEARBY_CHECK_INTERVAL = 200
            Citizen.Wait(7000)
        else
            NEARBY_CHECK_INTERVAL = 150
            Citizen.Wait(3000)
        end
    end
end)

Citizen.CreateThread(function()
    while true do
        PlayerPed = PlayerPedId()
        if PlayerPed and PlayerPed ~= 0 then
            PlayerCoords = GetEntityCoords(PlayerPed, false)
        end

        local temp, tempCoords, count = {}, {}, 0

        -- 항상 자기 자신 포함
        local myIdx = PlayerId()
        count = 1
        temp[1] = myIdx
        tempCoords[myIdx] = PlayerCoords

        -- 다른 플레이어들도 추가
        if PlayerCoords and playerCount > 0 then
            local maxDistSq = (toggle == 1 or toggle == 2) and (DRAWTEXT_DISTANCE * DRAWTEXT_DISTANCE) or NEARBY_DISTANCE_SQ
            for i = 1, playerCount do
                local v = players[i]
                if v and v ~= myServerId then
                    local ped = GetPlayerPed(v)
                    if ped and ped ~= 0 and DoesEntityExist(ped) then
                        local pedCoords = GetEntityCoords(ped, false)
                        if distanceSquared(PlayerCoords, pedCoords) < maxDistSq then
                            count = count + 1
                            temp[count] = v
                            tempCoords[v] = pedCoords
                            if count >= 50 then break end
                        end
                    end
                end
            end
        end

        nearbyPlayers = temp
        nearbyPlayerCount = count
        nearbyPlayerCoords = tempCoords

        Citizen.Wait(NEARBY_CHECK_INTERVAL)
    end
end)

Citizen.CreateThread(function()
    Citizen.Wait(1000)

    players = GetActivePlayers()
    playerCount = #players
    myServerId = PlayerId()

    local NUIdata = {}

    while true do
        local ticks = nametagSettings.renderTick
        local visiblePlayers = 0

        local isPauseOpen = IsPauseMenuActive()
        pcall(function()
            isPauseOpen = isPauseOpen or exports["DolphinPause"]:isPauseOpen()
        end)
        if not isShowUI or isPauseOpen or not nametagSettings.enabled then
            duiRenderingActive = false
            if toggle == 2 then
                SendNUIMessage({ type = "updateNameTag", table = {} })
            end
            Citizen.Wait(100)
        else
            if toggle == 1 then
                -- DUI 모드: 플레이어별 독립 스레드가 렌더링, 여기서는 플래그만 관리
                duiRenderingActive = true
                Citizen.Wait(50)
            elseif toggle == 2 then
                -- NUI 모드: 기존 NUI 렌더링
                renderNUI()
                Citizen.Wait(nametagSettings.renderTick)
            else
                -- DrawText 모드: 네이티브 DrawText3D 렌더링
                renderDrawText()
                Citizen.Wait(RENDER_TICK_DRAW)
            end
        end
    end
end)

-- DUI 풀 할당 관리 스레드
Citizen.CreateThread(function()
    -- DUI 모드가 아니면 풀 생성 대기
    while toggle ~= 1 do
        Citizen.Wait(500)
    end
    InitPool()

    while true do
        if toggle == 1 and isShowUI and nametagSettings.enabled and IsPoolReady() then
            -- 현재 할당된 슬롯의 serverId 세트 구축
            local activeServerIds = {}
            local visiblePlayers = 0

            for i = 1, nearbyPlayerCount do
                local v = nearbyPlayers[i]
                if v then
                    local ped = GetPlayerPed(v)
                    if ped and ped ~= 0 then
                        local pedCoords = nearbyPlayerCoords[v] or GetEntityCoords(ped, false)

                        if IsEntityVisible(ped) and GetEntityAlpha(ped) > 60 then
                            local pedBone = GetPedBoneCoords(ped, 31086)
                            local onScreen, x, y = World3dToScreen2d(pedBone.x, pedBone.y, pedBone.z + 0.3)

                            if onScreen then
                                visiblePlayers = visiblePlayers + 1
                                if visiblePlayers > MAX_VISIBLE_PLAYERS then break end

                                local serverID = GetPlayerServerId(v)
                                local data = player[serverID]
                                local talk = NetworkIsPlayerTalking(v)
                                local chat = chat_data[serverID]

                                -- 거리 기반 이미지 스케일 계산 (NUI와 동일)
                                local dist = #(PlayerCoords - pedCoords)
                                local imgScale = 1.0 - 0.35 * (dist / 15.0)
                                if imgScale < 0.65 then imgScale = 0.65 end
                                if imgScale > 1.0 then imgScale = 1.0 end
                                imgScale = math.floor(imgScale * 20 + 0.5) / 20 -- 0.05 단위로 양자화

                                -- DUI 슬롯 할당
                                local slot = AllocateSlot(serverID)
                                if slot then
                                    activeServerIds[serverID] = true

                                    -- 슬롯 데이터 업데이트
                                    UpdateSlotData(serverID, {
                                        name = data and data.name or GetPlayerName(v),
                                        user_id = data and data.user_id or nil,
                                        job = data and data.job or nil,
                                        rank = data and data.rank or nil,
                                        color = data and data.color or nil,
                                        emoji = data and data.emoji or nil,
                                        title = data and data.title or nil,
                                        titleColor = data and data.titleColor or nil,
                                        img = data and data.img or nil,
                                        chatId = chat and chat[1] or nil,
                                        chatMsg = chat and chat[2] or nil,
                                        talkState = talk,
                                        imgClose = dist <= 15.0,
                                        imgScale = imgScale,
                                        showName = nametagSettings.showName,
                                        showJob = nametagSettings.showJob,
                                        showTitle = nametagSettings.showTitle,
                                        showEmoji = nametagSettings.showEmoji,
                                        showChat = nametagSettings.showChat,
                                        showHeadImg = nametagSettings.showHeadImg
                                    })

                                    -- duiActiveEntries 관리: 신규면 렌더 스레드 생성, 기존이면 업데이트
                                    local isVisible = not slot.dirty and IsEntityVisible(ped) and GetEntityAlpha(ped) > 60
                                    local entry = duiActiveEntries[serverID]
                                    if not entry then
                                        entry = {
                                            ped = ped,
                                            slot = slot,
                                            visible = isVisible,
                                            active = true,
                                            lerpH = nil
                                        }
                                        duiActiveEntries[serverID] = entry
                                        spawnPlayerRenderThread(entry)
                                    else
                                        entry.ped = ped
                                        entry.slot = slot
                                        entry.visible = isVisible
                                    end
                                end
                            end
                        end
                    end
                end
            end

            -- 범위 밖 플레이어: 렌더 스레드 정지 + 슬롯 해제
            local releaseList = {}
            local allocatedIds = GetAllocatedServerIds()
            for serverId, _ in pairs(allocatedIds) do
                if not activeServerIds[serverId] then
                    releaseList[#releaseList + 1] = serverId
                end
            end
            for _, serverId in ipairs(releaseList) do
                local entry = duiActiveEntries[serverId]
                if entry then
                    entry.active = false
                    duiActiveEntries[serverId] = nil
                end
                ReleaseSlot(serverId)
            end
        elseif toggle ~= 1 then
            -- DUI 모드가 아닐 때: 모든 렌더 스레드 정지 + 슬롯 해제
            for serverId, entry in pairs(duiActiveEntries) do
                entry.active = false
            end
            duiActiveEntries = {}
            duiRenderingActive = false
            ReleaseAllSlots()
        end
        Citizen.Wait(50)
    end
end)

function NameTag.ToSendData(data)
    if not data then return end

    local playersData = type(data) == "table" and data[1] or data

    if type(playersData) == "table" then
        for source, playerData in pairs(playersData) do
            if type(playerData) == "table" and playerData.user_id then
                local src = tonumber(source)
                if src then
                    player[src] = playerData
                end
            end
        end
    end
end

Citizen.CreateThread(function()
    Citizen.Wait(5000)
    if not next(player) then NameTagS.RequestDataSync() end
    Citizen.Wait(5000)
    if not next(player) then NameTagS.RequestDataSync() end

    while true do
        if IsControlPressed(0, 21) and IsControlJustPressed(0, 29) then
            NameTagS.ImgHide()
        end
        Citizen.Wait(50)
    end
end)

-- 머리 위 채팅용 멘션 마커 처리 함수
-- [[MENTION:ID:name]] -> @name 형식으로 변환
local function processOverheadMentions(message)
    if not message then return message end
    -- [[MENTION:ID:name]] 마커를 @name 형식으로 변환
    return message:gsub("%[%[MENTION:%d+:([^%]]+)%]%]", "@%1")
end

RegisterNetEvent("sendProximityMessage")
AddEventHandler("sendProximityMessage", function(source, user_id, name, message)
    -- 빈 메시지는 무시 (배경만 뜨는 버그 방지)
    if not message or message == "" or message:match("^%s*$") then
        return
    end

    -- 멘션 마커 처리 (머리 위 표시용)
    local processedMessage = processOverheadMentions(message)

    chat_id = chat_id + 1
    local save_chatid = chat_id
    chat_data[source] = {chat_id, processedMessage}
    SetTimeout(5000, function()
        if chat_data[source] and chat_data[source][1] == save_chatid then
            chat_data[source] = nil
        end
    end)
end)

local function handleChangeShowUI(isShow)
    if not isShowUIRest then
        isShowUI = isShow
    end
end

local function handleChangeShowUIRest(isRest)
    isShowUIRest = isRest
    if isRest then
        isShowUI = false
    end
end

-- 로컬 이벤트 (TriggerEvent)
AddEventHandler("vrp_names_ex:changeShowUI", handleChangeShowUI)
AddEventHandler("vrp_names_ex:changeShowUIRest", handleChangeShowUIRest)

-- 네트워크 이벤트 (TriggerClientEvent)
RegisterNetEvent("vrp_names_ex:changeShowUI", handleChangeShowUI)
RegisterNetEvent("vrp_names_ex:changeShowUIRest", handleChangeShowUIRest)

-- ==================== F2 토글: UI ↔ DrawText ====================

RegisterKeyMapping("ChangeToName", "이름표 변경", "keyboard", "F2")

RegisterCommand("ChangeToName", function()
    if toggle == 1 or toggle == 2 then
        -- UI(DUI/NUI) -> DrawText
        if toggle == 1 then
            -- DUI 정리: 렌더 스레드 정지 + 슬롯 해제
            for serverId, entry in pairs(duiActiveEntries) do
                entry.active = false
            end
            duiActiveEntries = {}
            duiRenderingActive = false
            ReleaseAllSlots()
        else
            -- NUI 정리
            SendNUIMessage({ type = "updateNameTag", table = {} })
        end

        SendNUIMessage({ type = "clearStandaloneDice" })
        toggle = 3

        -- 진행 중인 주사위를 DrawText 모드로 전환
        if next(diceAnimations) then
            for source, anim in pairs(diceAnimations) do
                anim.duiSent = nil
                local currentNum = anim.currentNumber or 1
                local isFinal = anim.finished or false
                -- 위치 계산
                local x, y = nil, nil
                local targetPlayer = GetPlayerFromServerId(source)
                if targetPlayer then
                    local targetPed = GetPlayerPed(targetPlayer)
                    if targetPed and targetPed ~= 0 then
                        local pedBone = GetPedBoneCoords(targetPed, 31086)
                        local onScreen, screenX, screenY = World3dToScreen2d(pedBone.x, pedBone.y, pedBone.z + 0.7)
                        if onScreen then
                            x = screenX * 100
                            y = screenY * 100
                        end
                    end
                end
                SendNUIMessage({
                    type = "switchDiceMode",
                    serverId = source,
                    isDrawTextMode = true,
                    imageUrl = diceImages[currentNum],
                    diceNumber = currentNum,
                    isFinal = isFinal,
                    x = x,
                    y = y
                })
            end
        end
    else
        -- DrawText -> UI (useDUI 설정에 따라 DUI 또는 NUI)
        SendNUIMessage({ type = "clearStandaloneDice" })

        if nametagSettings.useDUI then
            toggle = 1
            -- 활성 주사위를 DUI 슬롯으로 전달 (슬롯 할당 후)
            local now = GetGameTimer()
            for source, anim in pairs(diceAnimations) do
                if now < anim.showUntil and not anim.duiSent then
                    anim.duiSent = true
                end
            end
        else
            toggle = 2
            -- 활성 주사위를 NUI로 전달
            local now = GetGameTimer()
            for source, anim in pairs(diceAnimations) do
                if now < anim.showUntil then
                    anim.duiSent = nil
                    SendNUIMessage({
                        type = "startDiceAnimation",
                        serverId = source,
                        finalResult = anim.finalResult,
                        isDrawTextMode = false
                    })
                end
            end
        end
    end
end, false)

RegisterCommand("checknametag", function()
    local count = 0
    for _ in pairs(player) do count = count + 1 end
    local myServerIdReal = GetPlayerServerId(PlayerId())

    
    if nearbyPlayerCount > 0 then
        -- print("[NameTag] Nearby list:")
        for i = 1, nearbyPlayerCount do
            local v = nearbyPlayers[i]
            if v then
                local sid = GetPlayerServerId(v)
                local hasData = player[sid] and "YES" or "NO"
                -- print("  - Player " .. v .. " (ServerID: " .. sid .. ") HasData: " .. hasData)
            end
        end
    end

end, false)


AddEventHandler("onResourceStop", function(res)
    if res == GetCurrentResourceName() then
        -- 모든 렌더 스레드 정지
        for serverId, entry in pairs(duiActiveEntries) do
            entry.active = false
        end
        duiActiveEntries = {}
        duiRenderingActive = false
        SendNUIMessage({ type = "updateNameTag", table = {} })
    end
end)

-- exports (DolphinPause 연동용)
exports("SetSetting", function(key, value)
    if nametagSettings[key] ~= nil then
        nametagSettings[key] = value
        SetResourceKvp("nametag_" .. key, tostring(value))

        -- 이모지 모드는 서버에도 전달
        if key == "emojiMode" then
            TriggerServerEvent("DolphinNameTag:setEmojiMode", value)
        elseif key == "useDUI" then
            -- UI 모드 중 DUI↔NUI 실시간 전환
            if value and toggle == 2 then
                -- NUI → DUI
                SendNUIMessage({ type = "updateNameTag", table = {} })
                toggle = 1
            elseif not value and toggle == 1 then
                -- DUI → NUI
                for serverId, entry in pairs(duiActiveEntries) do
                    entry.active = false
                end
                duiActiveEntries = {}
                duiRenderingActive = false
                ReleaseAllSlots()
                toggle = 2
            end
        end
    end
end)

exports("GetSettings", function()
    return nametagSettings
end)

-- 이모지 모드 전용 설정 함수
exports("SetEmojiMode", function(mode)
    if mode == "faction" or mode == "special" or mode == "both" then
        nametagSettings.emojiMode = mode
        SetResourceKvp("nametag_emojiMode", mode)
        TriggerServerEvent("DolphinNameTag:setEmojiMode", mode)
        return true
    end
    return false
end)

exports("GetEmojiMode", function()
    return nametagSettings.emojiMode or "both"
end)

exports("IsShowUI", function()
    return isShowUI
end)

-- 주사위 애니메이션 이벤트 수신
RegisterNetEvent("DolphinNameTag:showDiceAnimation")
AddEventHandler("DolphinNameTag:showDiceAnimation", function(targetSource, finalResult)
    -- targetSource는 서버 ID
    local targetPlayer = GetPlayerFromServerId(targetSource)
    if not targetPlayer then return end

    -- 거리 체크: 15m 이내에 있을 때만 표시
    local myPed = PlayerPedId()
    local targetPed = GetPlayerPed(targetPlayer)
    if not targetPed or targetPed == 0 then return end

    local myPos = GetEntityCoords(myPed)
    local targetPos = GetEntityCoords(targetPed)
    local distance = #(myPos - targetPos)

    if distance > NEARBY_DISTANCE then return end

    -- 이전 주사위가 있으면 먼저 제거
    if diceAnimations[targetSource] then
        SendNUIMessage({
            type = "hideDiceEmoji",
            serverId = targetSource
        })
    end

    -- 초기 위치 계산 (DrawText 모드용)
    local pedBone = GetPedBoneCoords(targetPed, 31086)
    local onScreen, screenX, screenY = World3dToScreen2d(pedBone.x, pedBone.y, pedBone.z + 0.7)

    -- 애니메이션 시작 (서버 ID를 key로 사용)
    diceAnimations[targetSource] = {
        startTime = GetGameTimer(),
        duration = 2000, -- 2초 동안 애니메이션
        finalResult = finalResult,
        serverId = targetSource, -- 서버 ID 저장
        currentNumber = math.random(1, 6), -- 현재 표시할 숫자 (DrawText용)
        showUntil = GetGameTimer() + 5000 -- 5초간 표시 (애니메이션 2초 + 결과 3초)
    }

    -- NUI로 주사위 애니메이션 시작 메시지 전송
    -- DrawText 모드(toggle == 2)일 때만 초기 위치 포함
    if toggle == 2 and onScreen then
        SendNUIMessage({
            type = "startDiceAnimation",
            serverId = targetSource,
            finalResult = finalResult,
            isDrawTextMode = true,
            x = screenX * 100,
            y = screenY * 100,
            imageUrl = diceImages[math.random(1, 6)]
        })
    else
        SendNUIMessage({
            type = "startDiceAnimation",
            serverId = targetSource,
            finalResult = finalResult,
            isDrawTextMode = (toggle == 2)
        })
    end
end)

-- 주사위 애니메이션 상태 업데이트 스레드 (이미지/숫자 변경만)
Citizen.CreateThread(function()
    while true do
        local hasAnim = false
        local now = GetGameTimer()
        local myPed = PlayerPedId()
        local myPos = GetEntityCoords(myPed)

        for source, anim in pairs(diceAnimations) do
            hasAnim = true
            local elapsed = now - anim.startTime

            -- 거리 체크: 대상이 멀어지면 주사위 제거
            local targetPlayer = GetPlayerFromServerId(source)
            local shouldRemove = false

            if not targetPlayer then
                shouldRemove = true
            else
                local targetPed = GetPlayerPed(targetPlayer)
                if not targetPed or targetPed == 0 then
                    shouldRemove = true
                else
                    local targetPos = GetEntityCoords(targetPed)
                    local distance = #(myPos - targetPos)
                    if distance > NEARBY_DISTANCE then
                        shouldRemove = true
                    end
                end
            end

            -- 표시 시간 완전 종료 또는 거리 초과
            if now >= anim.showUntil or shouldRemove then
                SendNUIMessage({
                    type = "hideDiceEmoji",
                    serverId = source
                })
                diceAnimations[source] = nil
            elseif elapsed >= anim.duration then
                -- 애니메이션 종료 - 최종 결과 표시
                anim.currentNumber = anim.finalResult
                anim.finished = true

                if not anim.nuiFinished then
                    anim.nuiFinished = true
                    SendNUIMessage({
                        type = "updateDiceImage",
                        serverId = source,
                        imageUrl = diceImages[anim.finalResult],
                        diceNumber = anim.finalResult,
                        isFinal = true
                    })
                end
            else
                -- 랜덤 주사위 이미지 표시 (서버 ID 사용)
                local randomNum = math.random(1, 6)
                anim.currentNumber = randomNum
                SendNUIMessage({
                    type = "updateDiceImage",
                    serverId = source,
                    imageUrl = diceImages[randomNum],
                    diceNumber = randomNum,
                    isFinal = false
                })
            end
        end

        if hasAnim then
            Citizen.Wait(100) -- 애니메이션 중일 때 빠르게 업데이트
        else
            Citizen.Wait(500) -- 아닐 때는 천천히
        end
    end
end)

-- DrawText 모드에서 주사위 위치 업데이트 스레드 (매 프레임)
Citizen.CreateThread(function()
    while true do
        if toggle == 2 and next(diceAnimations) then
            local now = GetGameTimer()
            local myPed = PlayerPedId()
            local myPos = GetEntityCoords(myPed)

            for source, anim in pairs(diceAnimations) do
                if anim and now < anim.showUntil then
                    local targetPlayer = GetPlayerFromServerId(source)
                    if targetPlayer then
                        local targetPed = GetPlayerPed(targetPlayer)
                        if targetPed and targetPed ~= 0 then
                            -- 거리 체크
                            local targetPos = GetEntityCoords(targetPed)
                            local distance = #(myPos - targetPos)

                            if distance <= NEARBY_DISTANCE then
                                local pedBone = GetPedBoneCoords(targetPed, 31086)
                                local onScreen, screenX, screenY = World3dToScreen2d(pedBone.x, pedBone.y, pedBone.z + 0.7)
                                if onScreen then
                                    SendNUIMessage({
                                        type = "updateDicePosition",
                                        serverId = source,
                                        x = screenX * 100,
                                        y = screenY * 100
                                    })
                                end
                            end
                        end
                    end
                end
            end
            Citizen.Wait(0) -- 매 프레임 위치 업데이트
        else
            Citizen.Wait(100) -- DrawText 모드 아니거나 주사위 없으면 대기
        end
    end
end)

-- 낚시 결과 표시 이벤트
RegisterNetEvent("DolphinNameTag:showFishingResult")
AddEventHandler("DolphinNameTag:showFishingResult", function(targetSource, resultData)
    local targetPlayer = GetPlayerFromServerId(targetSource)
    if not targetPlayer then return end

    -- 거리 체크: 채팅과 동일한 15m 이내에 있을 때만 표시
    local myPed = PlayerPedId()
    local targetPed = GetPlayerPed(targetPlayer)
    local myPos = GetEntityCoords(myPed)
    local targetPos = GetEntityCoords(targetPed)
    local distance = #(myPos - targetPos)

    if distance > NEARBY_DISTANCE then return end

    SendNUIMessage({
        type = "showFishingResult",
        playerId = targetPlayer,
        name = resultData.name,
        size = resultData.size,
        rarity = resultData.rarity,
        exp = resultData.exp,
        isJunk = resultData.isJunk
    })
end)

-- 그림 채팅 표시 이벤트
RegisterNetEvent("DolphinNameTag:showDrawing")
AddEventHandler("DolphinNameTag:showDrawing", function(targetSource, imageData)
    local targetPlayer = GetPlayerFromServerId(targetSource)
    if not targetPlayer then return end

    -- NUI 모드일 때만 표시 (toggle == 1)
    if toggle ~= 1 then return end

    -- 거리 체크: 20m 이내에 있을 때만 표시
    local myPed = PlayerPedId()
    local targetPed = GetPlayerPed(targetPlayer)
    if not targetPed or targetPed == 0 then return end

    local myPos = GetEntityCoords(myPed)
    local targetPos = GetEntityCoords(targetPed)
    local distance = #(myPos - targetPos)

    if distance > NEARBY_DISTANCE then return end

    SendNUIMessage({
        type = "showDrawing",
        playerId = targetPlayer,
        imageData = imageData
    })
end)
