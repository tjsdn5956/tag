cfg = {}

cfg.permission = {
    {"dolphin.staff.oncall", "⭐", "STAFF", nil, "255, 140, 0"},  -- 출근 시에만 표시 (oncall은 출근 그룹에만 있음)
}

cfg.factionPermissions = {
    -- 운영진
    {"dolphin.admin.whitelist", "운영자", "35, 35, 45", "🐬"},
    {"dolphin.staff.oncall", "스태프", "180, 90, 30", "⭐"},

    -- 공무직
    {"dolphin.police.whitelist", "경찰청", "30, 80, 150", "👮"},
    {"dolphin.sheriff.whitelist", "보안국", "100, 65, 35", "🕋"},
    {"dolphin.smarket.whitelist", "에스마켓", "180, 140, 90", "🎁"},

    -- 갱/마피아
    {"dolphin.mafia1.whitelist", "백사회", "220, 220, 230", "🐍"},
    {"dolphin.mafia2.whitelist", "흑야", "40, 40, 50", "⚔️"},
    {"dolphin.mafia3.whitelist", "청월", "190, 62, 254", "🌕"},
    {"dolphin.mafia4.whitelist", "적귀", "180, 40, 40", "⛩️"},

    -- 사업체
    {"dolphin.buffshop.whitelist", "버프샵", "150, 70, 90", "🏪"},
    {"dolphin.oceantow.whitelist", "오션렉카", "40, 85, 140", "🌊"},
    {"dolphin.chungeum.whitelist", "천금", "120, 90, 70", "👑"},
    {"dolphin.kingtheland.whitelist", "킹더랜드", "80, 180, 70", "💎"},

}

cfg.requireFactionPermission = false

cfg.factions = {
    -- 공무직
    {"경찰청", "30, 80, 150", "👮"},
    {"보안국", "100, 65, 35", "🕋"},
    {"에스마켓", "180, 140, 90", "🎁"},

    -- 갱/마피아
    {"백사회", "220, 220, 230", "🐍"},
    {"흑야", "40, 40, 50", "⚔️"},
    {"청월", "190, 62, 254", "🌕"},
    {"적귀", "180, 40, 40", "⛩️"},

    -- 사업체
    {"버프샵", "150, 70, 90", "🏪"},
    {"오션렉카", "40, 85, 140", "🌊"},
    {"천금", "120, 90, 70", "👑"},
    {"킹더랜드", "80, 180, 70", "💎"},

}

cfg.organizations = {
    -- 공무직
    "경찰청", "보안국", "에스마켓",
    -- 갱/마피아
    "백사회", "흑야", "청월", "적귀",
    -- 사업체
    "버프샵", "오션렉카", "천금", "킹더랜드",
}

cfg.custom_emoji = {}

-- 퍼미션 기반 이모지 (사용하지 않음 - 뉴비는 server.lua에서 직접 처리)
cfg.custom_emoji_permission = {}

-- 커플 이모지 관리 권한
cfg.coupleAdminPermission = "dolphin.admin.whitelist"

-- 시민직업 이모지 (직업명 기반, 퍼미션 없이 직업명으로 체크)
cfg.citizenJobEmojis = {
    -- ["배달부"] = "🏍️",
    -- ["트럭기사"] = "🚚",
    -- ["택비공"] = "🚕",
}

cfg.custom_img = {
    {"nameicon.admin2", "nameicon.admin2", "admin2.nameicon"},
    {"https://cdn.dolp.kr/headtitle/staff.webp", "staff", "dolphin.staff.oncall"},
    -- 개인 머리위 칭호 (등급 칭호보다 우선)
    {"https://cdn.dolp.kr/headtitle/bium.webp", "bium", "dolphin.headtitle.personal.bium"},
    {"https://cdn.dolp.kr/headtitle/hansi.webp", "hansi", "dolphin.headtitle.personal.hansi"},
    {"https://cdn.dolp.kr/headtitle/bt.webp", "bt", "dolphin.headtitle.personal.bt"},
    {"https://cdn.dolp.kr/headtitle/kain.webp", "kain", "dolphin.headtitle.personal.kain"},
    {"https://cdn.dolp.kr/headtitle/neodex.webp", "neodex", "dolphin.headtitle.personal.neodex"},
    {"https://cdn.dolp.kr/headtitle/hwarang.webp", "hwarang", "dolphin.headtitle.personal.hwarang"},

    {"https://cdn.dolp.kr/headtitle/crown.webp", "crown", "dolphin.headtitle.crown"},
    {"https://cdn.dolp.kr/headtitle/signature.webp", "signature", "dolphin.headtitle.signature"},
    {"https://cdn.dolp.kr/headtitle/prestige.webp", "prestige", "dolphin.headtitle.prestige"},
    {"https://cdn.dolp.kr/headtitle/dolphin.webp", "dolphin", "dolphin.headtitle.dolphin"},
    {"https://cdn.dolp.kr/headtitle/superstar.webp", "superstar", "dolphin.headtitle.superstar"},
    {"https://cdn.dolp.kr/headtitle/diamond.webp", "diamond", "dolphin.headtitle.diamond"},
    {"https://cdn.dolp.kr/headtitle/custom.webp", "custom", "dolphin.headtitle.custom"},
    {"https://cdn.dolp.kr/headtitle/master.webp", "master", "dolphin.headtitle.master"},
    {"https://cdn.dolp.kr/headtitle/svip.webp", "svip", "dolphin.headtitle.svip"},
    {"https://cdn.dolp.kr/headtitle/vvip.webp", "vvip", "dolphin.headtitle.vvip"},
    {"https://cdn.dolp.kr/headtitle/vip.webp", "vip", "dolphin.headtitle.vip"},
}

cfg.custom_titles = {
    {{1}, "빌려온고양이", "255, 215, 0"},
    {{2}, "헤이마마", "255, 215, 0"},
    {{3}, "米津玄師", "255, 215, 0"},
    {{4}, "진진자라", "255, 215, 0"},
    {{6587}, "돌핀전력공사", "255, 215, 0"},
}

cfg.custom_titles_permission = {}
