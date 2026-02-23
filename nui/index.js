var chat_save = {};
var elementCache = {};
var diceAnimations = {};
var serverIdToElementId = {}; // 서버 ID -> element ID 매핑

window.addEventListener('message', function(event) {
    var data = event.data;

    // 주사위 애니메이션 처리
    if (data.type === "startDiceAnimation") {
        var serverId = data.serverId;
        diceAnimations[serverId] = {
            active: true,
            finalResult: data.finalResult,
            isDrawTextMode: data.isDrawTextMode || false
        };

        // DrawText 모드일 때만 독립 주사위 요소 생성
        if (data.isDrawTextMode && data.x !== undefined && data.y !== undefined) {
            var diceEl = document.getElementById('dice-standalone-' + serverId);
            if (!diceEl) {
                diceEl = document.createElement('div');
                diceEl.id = 'dice-standalone-' + serverId;
                diceEl.className = 'dice-standalone';
                // 이미지 요소를 미리 생성
                var img = document.createElement('img');
                img.className = 'dice-img';
                img.src = data.imageUrl || 'https://cdn.dolp.kr/hud/dice-six-faces-one.svg';
                diceEl.appendChild(img);
                document.body.appendChild(diceEl);
            }
            diceEl.style.top = data.y + '%';
            diceEl.style.left = data.x + '%';
            diceEl.style.display = '';
        }
        return;
    }

    if (data.type === "updateDiceImage") {
        var serverId = data.serverId;
        var anim = diceAnimations[serverId];
        var isDrawTextMode = anim && anim.isDrawTextMode;
        var elementId = serverIdToElementId[serverId];
        var el = elementId !== undefined ? elementCache[elementId] : null;

        // 이미지 HTML 생성
        var diceHTML;
        if (data.imageUrl && data.imageUrl !== "") {
            diceHTML = '<img src="' + data.imageUrl + '" class="dice-img" />';
        } else {
            diceHTML = data.diceNumber;
        }

        // 일반 이름표에 붙은 주사위 업데이트 (NUI 모드일 때만)
        if (el && !isDrawTextMode) {
            var diceEl = el.querySelector('.dice');
            if (!diceEl) {
                diceEl = document.createElement('div');
                diceEl.className = 'dice';
                // chat-box 다음, emoji 앞에 삽입
                var emojiEl = el.querySelector('.emoji');
                if (emojiEl) {
                    el.insertBefore(diceEl, emojiEl);
                } else {
                    el.appendChild(diceEl);
                }
            }

            diceEl.innerHTML = diceHTML;
            diceEl.style.display = '';

            if (data.isFinal) {
                diceEl.classList.add('final');
            } else {
                diceEl.classList.remove('final');
            }
        }

        // 독립 주사위 요소도 업데이트 (DrawText 모드용) - src만 변경하여 깜빡임 방지
        if (isDrawTextMode) {
            var standaloneDice = document.getElementById('dice-standalone-' + serverId);
            if (standaloneDice) {
                var standaloneImg = standaloneDice.querySelector('.dice-img');
                if (standaloneImg && data.imageUrl) {
                    standaloneImg.src = data.imageUrl;
                } else if (!standaloneImg && data.imageUrl) {
                    // img가 없으면 생성
                    var newImg = document.createElement('img');
                    newImg.className = 'dice-img';
                    newImg.src = data.imageUrl;
                    standaloneDice.innerHTML = '';
                    standaloneDice.appendChild(newImg);
                }
                if (data.isFinal) {
                    standaloneDice.classList.add('final');
                } else {
                    standaloneDice.classList.remove('final');
                }
            }
        }
        return;
    }

    if (data.type === "hideDiceEmoji") {
        var serverId = data.serverId;
        var elementId = serverIdToElementId[serverId];
        var el = elementId !== undefined ? elementCache[elementId] : null;
        if (el) {
            var diceEl = el.querySelector('.dice');
            if (diceEl) {
                diceEl.style.display = 'none';
                diceEl.classList.remove('final');
            }
        }
        // 독립 주사위 요소도 제거
        var standaloneDice = document.getElementById('dice-standalone-' + serverId);
        if (standaloneDice) {
            standaloneDice.remove();
        }
        delete diceAnimations[serverId];
        return;
    }

    // 모드 전환 시 독립 주사위 모두 제거
    if (data.type === "clearStandaloneDice") {
        var standalones = document.querySelectorAll('.dice-standalone');
        standalones.forEach(function(el) {
            el.remove();
        });
        return;
    }

    // 주사위 모드 전환 (개별 serverId 처리)
    if (data.type === "switchDiceMode") {
        var serverId = data.serverId;
        var anim = diceAnimations[serverId];
        if (!anim) return;

        var wasDrawTextMode = anim.isDrawTextMode;
        anim.isDrawTextMode = data.isDrawTextMode;

        // 현재 이미지 정보 저장
        if (data.imageUrl) {
            anim.currentImageUrl = data.imageUrl;
            anim.currentDiceNumber = data.diceNumber;
            anim.isFinal = data.isFinal;
        }

        if (data.isDrawTextMode && !wasDrawTextMode) {
            // NUI -> DrawText: 이름표에 붙은 주사위 숨기기
            var elementId = serverIdToElementId[serverId];
            var el = elementId !== undefined ? elementCache[elementId] : null;
            if (el) {
                var diceEl = el.querySelector('.dice');
                if (diceEl) {
                    diceEl.style.display = 'none';
                }
            }
            // 독립 주사위 즉시 생성 (현재 이미지로)
            var standaloneDice = document.getElementById('dice-standalone-' + serverId);
            if (!standaloneDice) {
                standaloneDice = document.createElement('div');
                standaloneDice.id = 'dice-standalone-' + serverId;
                standaloneDice.className = 'dice-standalone';
                var img = document.createElement('img');
                img.className = 'dice-img';
                img.src = data.imageUrl || 'https://cdn.dolp.kr/hud/dice-six-faces-one.svg';
                standaloneDice.appendChild(img);
                document.body.appendChild(standaloneDice);
            } else {
                var standaloneImg = standaloneDice.querySelector('.dice-img');
                if (standaloneImg && data.imageUrl) {
                    standaloneImg.src = data.imageUrl;
                }
            }
            // 위치 적용
            if (data.x !== undefined && data.y !== undefined) {
                standaloneDice.style.top = data.y + '%';
                standaloneDice.style.left = data.x + '%';
            }
            standaloneDice.style.display = '';
            if (data.isFinal) {
                standaloneDice.classList.add('final');
            } else {
                standaloneDice.classList.remove('final');
            }
        } else if (!data.isDrawTextMode && wasDrawTextMode) {
            // DrawText -> NUI: 독립 주사위는 clearStandaloneDice에서 이미 제거됨
            // 이름표 주사위 즉시 생성 시도
            var elementId = serverIdToElementId[serverId];
            var el = elementId !== undefined ? elementCache[elementId] : null;
            if (el) {
                var diceEl = el.querySelector('.dice');
                if (!diceEl) {
                    diceEl = document.createElement('div');
                    diceEl.className = 'dice';
                    var emojiEl = el.querySelector('.emoji');
                    if (emojiEl) {
                        el.insertBefore(diceEl, emojiEl);
                    } else {
                        el.appendChild(diceEl);
                    }
                }
                if (data.imageUrl) {
                    diceEl.innerHTML = '<img src="' + data.imageUrl + '" class="dice-img" />';
                }
                diceEl.style.display = '';
                if (data.isFinal) {
                    diceEl.classList.add('final');
                } else {
                    diceEl.classList.remove('final');
                }
            }
        }
        return;
    }

    // DrawText 모드에서 주사위 위치 업데이트 (독립적인 주사위 요소)
    if (data.type === "updateDicePosition") {
        var serverId = data.serverId;
        var anim = diceAnimations[serverId];
        if (!anim || !anim.isDrawTextMode) return;

        var diceEl = document.getElementById('dice-standalone-' + serverId);
        if (!diceEl) {
            diceEl = document.createElement('div');
            diceEl.id = 'dice-standalone-' + serverId;
            diceEl.className = 'dice-standalone';
            // 이미지 요소도 함께 생성
            var img = document.createElement('img');
            img.className = 'dice-img';
            img.src = 'https://cdn.dolp.kr/hud/dice-six-faces-one.svg';
            diceEl.appendChild(img);
            document.body.appendChild(diceEl);
        }
        diceEl.style.top = data.y + '%';
        diceEl.style.left = data.x + '%';
        diceEl.style.display = '';
        return;
    }

    // 그림 채팅 표시 (chat-box 스타일로 표시)
    if (data.type === "showDrawing") {
        var playerId = data.playerId;
        var el = elementCache[playerId];
        // 화면에 이름표가 없는 플레이어면 표시하지 않음 (멀리 있는 플레이어)
        if (!el) {
            return;
        }

        var chatBox = el.querySelector('.chat-box');
        if (!chatBox) return;

        // 기존 타이머 정리
        if (chat_save[playerId] && chat_save[playerId].hideTimer) {
            clearTimeout(chat_save[playerId].hideTimer);
        }
        if (chat_save[playerId] && chat_save[playerId].fadeTimer) {
            clearTimeout(chat_save[playerId].fadeTimer);
        }

        // 그림으로 chat-box 내용 교체
        chatBox.innerHTML = '<img src="' + data.imageData + '" class="drawing-img" />';
        chatBox.classList.add('drawing-mode');
        chatBox.style.opacity = '1';
        chatBox.style.transform = 'scale(1)';

        // 8초 후 페이드아웃
        (function(pid, box) {
            chat_save[pid] = chat_save[pid] || {};
            chat_save[pid].hideTimer = setTimeout(function() {
                box.style.opacity = '0';
                box.style.transform = 'scale(0.6)';
                chat_save[pid].fadeTimer = setTimeout(function() {
                    box.innerHTML = '';
                    box.classList.remove('drawing-mode');
                }, 300);
            }, 8000);
        })(playerId, chatBox);

        return;
    }

    // 낚시 결과 표시
    if (data.type === "showFishingResult") {
        var playerId = data.playerId;
        var el = elementCache[playerId];
        // 화면에 이름표가 없는 플레이어면 표시하지 않음 (멀리 있는 플레이어)
        if (!el) {
            return;
        }

        // 기존 낚시 결과 제거
        var existingFish = el.querySelector('.fishing-result');
        if (existingFish) existingFish.remove();

        // 낚시 결과 UI 생성 (깔끔한 디자인)
        var fishEl = document.createElement('div');
        fishEl.className = 'fishing-result ' + (data.rarity || 'common');

        // 아이콘 HTML 생성 (이미지만, URL 없으면 wrapper 자체를 숨김)
        var iconHTML = '';
        if (data.icon) {
            // icon이 URL인지 파일명인지 확인
            var iconSrc = data.icon;
            if (!iconSrc.startsWith('http://') && !iconSrc.startsWith('https://')) {
                // 파일명이면 nui://리소스/아이콘폴더/파일명 형식으로
                iconSrc = 'nui://DolphinFishing/nui/icons/' + iconSrc;
            }
            iconHTML = '<div class="fish-icon-wrapper"><img src="' + iconSrc + '" class="fish-icon-img' + (data.isJunk ? ' junk' : '') + '" onerror="this.parentElement.style.display=\'none\';" /></div>';
        }

        // HTML 구조 (세로 배치: 이미지 위, 정보 아래)
        fishEl.innerHTML =
            iconHTML +
            '<div class="fish-info">' +
                '<span class="fish-title">' +
                    '<span class="fish-rarity">' + getRarityText(data.rarity, data.isJunk) + '</span> ' +
                    '<span class="fish-name">' + (data.name || '???') + '</span>' +
                '</span>' +
                (data.size ? '<span class="fish-size">' + data.size + '</span>' : '') +
                (data.exp ? '<span class="fish-exp">+' + data.exp + ' EXP</span>' : '') +
            '</div>';

        // chat-box 앞에 삽입
        var chatBox = el.querySelector('.chat-box');
        if (chatBox) {
            el.insertBefore(fishEl, chatBox);
        } else {
            el.insertBefore(fishEl, el.firstChild);
        }

        // 5초 후 제거
        setTimeout(function() {
            if (fishEl && fishEl.parentNode) {
                fishEl.classList.add('fade-out');
                setTimeout(function() {
                    if (fishEl && fishEl.parentNode) {
                        fishEl.remove();
                    }
                }, 300);
            }
        }, 5000);
        return;
    }

    if (data.type !== "updateNameTag") return;

    var activePlayers = data.table || {};

    for (var id in elementCache) {
        if (!activePlayers[id]) {
            elementCache[id].style.display = 'none';
        }
    }

    // 매핑 초기화 (매 업데이트마다 갱신)
    serverIdToElementId = {};

    for (var id in activePlayers) {
        var playerData = activePlayers[id];
        if (!playerData) continue;

        // 서버 ID -> element ID 매핑 업데이트
        if (playerData.serverId) {
            serverIdToElementId[playerData.serverId] = id;
        }

        var el = elementCache[id];
        if (!el) {
            el = document.createElement('div');
            el.id = 'player-' + id;
            el.className = 'namestyle';
            el.innerHTML = '<img class="icon"><div class="chat-box default" style="padding:0"></div><div class="emoji"></div><div class="title"></div><div class="job"></div><div class="nickname"></div>';
            document.body.appendChild(el);
            elementCache[id] = el;
        }

        el.style.display = '';
        el.style.top = playerData.y + '%';
        el.style.left = playerData.x + '%';
        el.style.transform = 'translate(-50%,-100%)';

        var icon = el.querySelector('.icon');
        var chatBox = el.querySelector('.chat-box');
        var emoji = el.querySelector('.emoji');
        var title = el.querySelector('.title');
        var job = el.querySelector('.job');
        var nickname = el.querySelector('.nickname');

        var pData = playerData.data;
        var settings = playerData.settings || {};
        var showName = settings.showName !== false;
        var showJob = settings.showJob !== false;
        var showTitle = settings.showTitle !== false;
        var showEmoji = settings.showEmoji !== false;
        var showChat = settings.showChat !== false;

        var playerName = pData ? removeEmoji(pData.name) + ' ( ' + pData.user_id + ' )' : (playerData.name || 'Unknown');

        var displayHTML;
        if (pData && pData.job && showJob) {
            // RGB 문자열 파싱 (예: "0, 100, 200")
            var r = 30, g = 30, b = 30; // 기본값 (검정)
            if (pData.color) {
                var parts = pData.color.split(',').map(function(x) { return parseInt(x.trim()); });
                if (parts.length >= 3) {
                    r = parts[0]; g = parts[1]; b = parts[2];
                }
            }
            // 설정 색상 기반 그라데이션 배경 (위 진함 → 아래 투명)
            var jobBg = 'linear-gradient(180deg, rgba(' + r + ',' + g + ',' + b + ', 1) 0%, rgba(' + r + ',' + g + ',' + b + ', 0.95) 60%, rgba(' + r + ',' + g + ',' + b + ', 0.5) 100%)';
            displayHTML = '<span class="job-text" style="background:' + jobBg + '">' + pData.job + '</span>' + (showName ? ' <span class="name-text">' + playerName + '</span>' : '');
        } else if (showName) {
            displayHTML = '<span class="name-text">' + playerName + '</span>';
        } else {
            displayHTML = '';
        }
        nickname.innerHTML = displayHTML;
        nickname.style.display = displayHTML ? '' : 'none';

        var nameText = nickname.querySelector('.name-text');
        if (nameText) {
            nameText.style.color = playerData.talk ? 'rgb(0, 217, 255)' : '';
        }

        if (pData && pData.title && showTitle) {
            title.textContent = pData.title;
            title.style.color = pData.titleColor ? 'rgb(' + pData.titleColor + ')' : 'rgb(255, 215, 0)';
            title.style.display = '';
        } else {
            title.style.display = 'none';
        }

        job.style.display = 'none';

        if (pData && pData.emoji && showEmoji) {
            emoji.textContent = pData.emoji;
            emoji.style.display = '';
        } else {
            emoji.style.display = 'none';
        }

        var showHeadImg = settings.showHeadImg !== false;
        if (pData && pData.img && showHeadImg && playerData.imgClose) {
            var imgSrc = pData.img.startsWith('http') ? pData.img : './img/' + pData.img + '.png';
            if (icon.getAttribute('src') !== imgSrc) {
                icon.src = imgSrc;
            }
            var imgScale = playerData.imgScale || 1;
            icon.style.width = Math.round(180 * imgScale) + 'px';
            icon.style.display = '';
        } else {
            icon.style.display = 'none';
        }

        // 채팅 표시 (pData 없어도 표시 - 동기화 지연 시에도 채팅은 보여야 함)
        if (playerData.chat && showChat) {
            var chatId = playerData.chat[0];
            var chatMessage = playerData.chat[1];

            // 빈 메시지는 무시
            if (!chatMessage || chatMessage === '') {
                return;
            }

            if (!chat_save[id]) chat_save[id] = { lastId: null, hideTimer: null, fadeTimer: null };

            if (chat_save[id].lastId !== chatId) {
                chat_save[id].lastId = chatId;

                // 기존 타이머 모두 제거
                if (chat_save[id].hideTimer) clearTimeout(chat_save[id].hideTimer);
                if (chat_save[id].fadeTimer) clearTimeout(chat_save[id].fadeTimer);

                // 즉시 표시
                chatBox.textContent = chatMessage;
                chatBox.style.opacity = '1';
                chatBox.style.transform = 'scale(1)';
                chatBox.style.padding = '';

                // 클로저로 현재 id 캡처
                (function(playerId, box) {
                    chat_save[playerId].hideTimer = setTimeout(function() {
                        box.style.opacity = '0';
                        box.style.transform = 'scale(0.5)';
                        box.style.padding = '0';

                        chat_save[playerId].fadeTimer = setTimeout(function() {
                            box.textContent = '';
                        }, 250);

                        chat_save[playerId].hideTimer = null;
                    }, 10000);
                })(id, chatBox);
            }
        } else if (!playerData.chat && chat_save[id] && chat_save[id].hideTimer === null) {
            // 채팅 데이터가 없고, 이미 타이머가 완료된 경우에만 정리
            delete chat_save[id];
        }
    }

    for (var id in elementCache) {
        if (!activePlayers[id]) {
            elementCache[id].remove();
            delete elementCache[id];
            if (chat_save[id]) {
                if (chat_save[id].hideTimer) clearTimeout(chat_save[id].hideTimer);
                if (chat_save[id].fadeTimer) clearTimeout(chat_save[id].fadeTimer);
                delete chat_save[id];
            }
        }
    }
});

function removeEmoji(str) {
    if (!str) return '';
    return str.replace(/[\u{1F600}-\u{1F64F}\u{1F300}-\u{1F5FF}\u{1F680}-\u{1F6FF}\u{1F700}-\u{1F77F}\u{1F780}-\u{1F7FF}\u{1F800}-\u{1F8FF}\u{1F900}-\u{1F9FF}\u{1FA00}-\u{1FA6F}\u{1FA70}-\u{1FAFF}\u{1FB00}-\u{1FBFF}\u{1F004}-\u{1F0CF}\u{1F170}-\u{1F251}\u{200D}\u{FE0F}]/gu, '');
}

// 등급별 물고기 아이콘 반환 (폴백용 이모지)
function getFishIconByRarity(rarity, isJunk) {
    if (isJunk) return '🗑️';

    var icons = {
        'common': '🐟',
        'uncommon': '🐠',
        'rare': '🐡',
        'epic': '🦈',
        'legendary': '🐋'
    };
    return icons[rarity] || '🐟';
}

// 등급 한글 텍스트 반환
function getRarityText(rarity, isJunk) {
    if (isJunk) return '쓰레기';

    var texts = {
        'common': '일반',
        'uncommon': '고급',
        'rare': '희귀',
        'epic': '영웅',
        'legendary': '전설'
    };
    return texts[rarity] || '일반';
}
