// API URL
const API_URL = 'http://localhost:3002/api';

// ユーザーデータのキャッシュ
let allUsers = [];
let allCharacters = new Map();
let allAnimes = new Map();

// 現在時刻の更新
function updateTime() {
    const now = new Date();
    const timeString = now.toLocaleString('ja-JP');
    document.getElementById('currentTime').textContent = timeString;
}
setInterval(updateTime, 1000);
updateTime();

// タブ切り替え
document.querySelectorAll('.tab-link').forEach(link => {
    link.addEventListener('click', (e) => {
        e.preventDefault();
        const tabName = link.dataset.tab;
        
        // アクティブクラスの切り替え
        document.querySelectorAll('.tab-link').forEach(l => l.classList.remove('active'));
        link.classList.add('active');
        
        // コンテンツの表示切り替え
        document.querySelectorAll('.tab-content').forEach(content => {
            content.classList.add('hidden');
        });
        document.getElementById(`${tabName}-tab`).classList.remove('hidden');
    });
});

// 統計情報の取得
async function loadStats() {
    try {
        const response = await fetch(`${API_URL}/stats`);
        const stats = await response.json();
        
        document.getElementById('totalPlans').textContent = stats.totalPlans;
        document.getElementById('totalSpots').textContent = stats.totalSpots;
        document.getElementById('oneDayPlans').textContent = stats.plansByDuration.oneDay;
        document.getElementById('totalUsers').textContent = stats.totalUsers || 0;
        document.getElementById('totalCharacters').textContent = stats.totalCharacters || 0;
        document.getElementById('totalAnimes').textContent = stats.totalAnimes || 0;
        
        // 期間別カウント
        document.getElementById('halfDayCount').textContent = stats.plansByDuration.halfDay;
        document.getElementById('oneDayCount').textContent = stats.plansByDuration.oneDay;
        document.getElementById('threeDaysCount').textContent = stats.plansByDuration.threeDays;
        
        // 最近のプラン
        const recentList = document.getElementById('recentPlansList');
        recentList.innerHTML = '';
        stats.recentPlans.forEach(plan => {
            const li = document.createElement('li');
            li.textContent = `${plan.title} (${plan.animeName})`;
            recentList.appendChild(li);
        });
    } catch (error) {
        console.error('統計情報の取得に失敗しました:', error);
    }
}

// プラン一覧の取得
async function loadPlans() {
    try {
        const response = await fetch(`${API_URL}/plans`);
        const plans = await response.json();
        
        const tbody = document.getElementById('plansTableBody');
        tbody.innerHTML = '';
        
        if (plans.length === 0) {
            tbody.innerHTML = '<tr><td colspan="6" class="text-center py-4 text-gray-500">プランがありません</td></tr>';
            return;
        }
        
        plans.forEach(plan => {
            const tr = document.createElement('tr');
            tr.className = 'border-b hover:bg-gray-50';
            tr.innerHTML = `
                <td class="py-3">${plan.title}</td>
                <td class="py-3">${plan.animeName}</td>
                <td class="py-3">${plan.duration}</td>
                <td class="py-3">${plan.spots ? plan.spots.length : 0}</td>
                <td class="py-3">${new Date(plan.createdAt).toLocaleDateString('ja-JP')}</td>
                <td class="py-3">
                    <button onclick="viewPlan('${plan.id}')" class="btn btn-sm btn-secondary mr-2">
                        <i class="fas fa-eye"></i>
                    </button>
                    <button onclick="deletePlan('${plan.id}')" class="btn btn-sm btn-danger">
                        <i class="fas fa-trash"></i>
                    </button>
                </td>
            `;
            tbody.appendChild(tr);
        });
    } catch (error) {
        console.error('プラン一覧の取得に失敗しました:', error);
    }
}

// プランの詳細表示
function viewPlan(id) {
    alert('プラン詳細機能は実装中です');
}

// プランの削除
async function deletePlan(id) {
    if (!confirm('このプランを削除してもよろしいですか？')) {
        return;
    }
    
    try {
        const response = await fetch(`${API_URL}/plans/${id}`, {
            method: 'DELETE'
        });
        
        if (response.ok) {
            alert('プランを削除しました');
            loadPlans();
            loadStats();
        } else {
            alert('削除に失敗しました');
        }
    } catch (error) {
        console.error('プランの削除に失敗しました:', error);
        alert('削除に失敗しました');
    }
}

// プランの更新
function refreshPlans() {
    loadPlans();
    loadStats();
}


// ユーザー一覧の取得
async function loadUsers(searchParams = null) {
    try {
        const response = await fetch(`${API_URL}/firebase/users`);
        const data = await response.json();
        
        const tbody = document.getElementById('usersTableBody');
        tbody.innerHTML = '';
        
        if (!data.users || data.users.length === 0) {
            tbody.innerHTML = '<tr><td colspan="4" class="text-center py-4 text-gray-500">ユーザーがいません</td></tr>';
            return;
        }
        
        // 全ユーザーデータを保存
        allUsers = data.users;
        
        // 検索フィルタリング
        let filteredUsers = data.users;
        if (searchParams) {
            filteredUsers = await filterUsers(data.users, searchParams);
        }
        
        if (filteredUsers.length === 0) {
            tbody.innerHTML = '<tr><td colspan="4" class="text-center py-4 text-gray-500">検索条件に一致するユーザーがいません</td></tr>';
            return;
        }
        
        for (const user of filteredUsers) {
            // キャラクター名とアニメ名を取得
            let characterNames = 'なし';
            let animeNames = 'なし';
            
            try {
                const [charResponse, animeResponse] = await Promise.all([
                    fetch(`${API_URL}/firebase/users/${user.id}/characters`),
                    fetch(`${API_URL}/firebase/users/${user.id}/animes`)
                ]);
                
                const charData = await charResponse.json();
                const animeData = await animeResponse.json();
                
                // キャラクターとアニメデータをキャッシュ
                allCharacters.set(user.id, charData.characters || []);
                allAnimes.set(user.id, animeData.animes || []);
                
                if (charData.characters && charData.characters.length > 0) {
                    characterNames = charData.characters.map(char => `${char.name}#${char.tag || ''}`).join(', ');
                    if (characterNames.length > 50) {
                        characterNames = characterNames.substring(0, 50) + '...';
                    }
                }
                
                if (animeData.animes && animeData.animes.length > 0) {
                    animeNames = animeData.animes.map(anime => `${anime.title}#${anime.hashtag || ''}`).join(', ');
                    if (animeNames.length > 50) {
                        animeNames = animeNames.substring(0, 50) + '...';
                    }
                }
            } catch (error) {
                console.log('ユーザーコンテンツの取得に失敗:', error);
            }
            
            const tr = document.createElement('tr');
            tr.className = 'border-b hover:bg-gray-50';
            tr.innerHTML = `
                <td class="py-3">${user.username || 'Unknown'}</td>
                <td class="py-3">${user.birthday || '未設定'}</td>
                <td class="py-3 text-sm">${characterNames}</td>
                <td class="py-3 text-sm">${animeNames}</td>
                <td class="py-3">
                    <button onclick="viewUserDetail('${user.id}')" class="btn btn-sm btn-secondary">
                        <i class="fas fa-eye"></i> 詳細
                    </button>
                </td>
            `;
            tbody.appendChild(tr);
        }
    } catch (error) {
        console.error('ユーザー一覧の取得に失敗しました:', error);
    }
}

// ユーザー詳細の表示
async function viewUserDetail(userId) {
    try {
        const [userResponse, charactersResponse, animesResponse] = await Promise.all([
            fetch(`${API_URL}/firebase/users`),
            fetch(`${API_URL}/firebase/users/${userId}/characters`),
            fetch(`${API_URL}/firebase/users/${userId}/animes`)
        ]);
        
        const userData = await userResponse.json();
        const charactersData = await charactersResponse.json();
        const animesData = await animesResponse.json();
        
        const user = userData.users.find(u => u.id === userId);
        if (!user) {
            alert('ユーザーが見つかりません');
            return;
        }
        
        const modal = document.getElementById('userDetailModal');
        const content = document.getElementById('userDetailContent');
        
        content.innerHTML = `
            <div class="space-y-6">
                <div class="border-b pb-4">
                    <h4 class="text-lg font-semibold mb-2">基本情報</h4>
                    <div class="grid grid-cols-2 gap-4">
                        <div>
                            <span class="text-gray-600">ユーザー名:</span>
                            <span class="ml-2 font-medium">${user.username || 'Unknown'}</span>
                        </div>
                        <div>
                            <span class="text-gray-600">誕生日:</span>
                            <span class="ml-2">${user.birthday || '未設定'}</span>
                        </div>
                        <div>
                            <span class="text-gray-600">プラットフォーム:</span>
                            <span class="ml-2">${user.platform || 'Unknown'}</span>
                        </div>
                    </div>
                </div>
                
                <div class="border-b pb-4">
                    <h4 class="text-lg font-semibold mb-2">登録キャラクター (${charactersData.characters ? charactersData.characters.length : 0}件)</h4>
                    <div class="max-h-40 overflow-y-auto">
                        ${charactersData.characters && charactersData.characters.length > 0 ? 
                            charactersData.characters.map(char => `
                                <div class="bg-gray-50 p-2 rounded mb-2">
                                    <div class="font-medium">${char.name}</div>
                                    <div class="text-sm text-gray-600">タグ: ${char.tag || 'なし'}</div>
                                    <div class="text-sm text-gray-600">アニメ: ${char.anime || 'なし'}</div>
                                </div>
                            `).join('') : 
                            '<p class="text-gray-500">登録されたキャラクターがありません</p>'
                        }
                    </div>
                </div>
                
                <div>
                    <h4 class="text-lg font-semibold mb-2">登録アニメ (${animesData.animes ? animesData.animes.length : 0}件)</h4>
                    <div class="max-h-40 overflow-y-auto">
                        ${animesData.animes && animesData.animes.length > 0 ? 
                            animesData.animes.map(anime => `
                                <div class="bg-gray-50 p-2 rounded mb-2">
                                    <div class="font-medium">${anime.title}</div>
                                    <div class="text-sm text-gray-600">ハッシュタグ: ${anime.hashtag || 'なし'}</div>
                                </div>
                            `).join('') : 
                            '<p class="text-gray-500">登録されたアニメがありません</p>'
                        }
                    </div>
                </div>
            </div>
        `;
        
        modal.classList.remove('hidden');
    } catch (error) {
        console.error('ユーザー詳細の取得に失敗しました:', error);
        alert('ユーザー詳細の取得に失敗しました');
    }
}

// ユーザー詳細モーダルを閉じる
function closeUserDetail() {
    document.getElementById('userDetailModal').classList.add('hidden');
}

// ユーザー一覧の更新
function refreshUsers() {
    clearSearch();
    loadUsers();
    loadStats();
}

// ユーザーのフィルタリング
async function filterUsers(users, searchParams) {
    const filteredUsers = [];
    
    for (const user of users) {
        let match = true;
        
        // 全てで検索（ユーザー名、キャラクター、アニメ、ハッシュタグを含む）
        if (searchParams.all && match) {
            const searchTerm = searchParams.all.toLowerCase();
            let userMatch = false;
            
            // ユーザー名で検索
            if (user.username && user.username.toLowerCase().includes(searchTerm)) {
                userMatch = true;
            }
            
            // キャラクターで検索
            if (!userMatch) {
                const characters = allCharacters.get(user.id) || [];
                if (characters.length === 0) {
                    // キャラクターデータをフェッチ
                    try {
                        const response = await fetch(`${API_URL}/firebase/users/${user.id}/characters`);
                        const data = await response.json();
                        allCharacters.set(user.id, data.characters || []);
                        const userChars = data.characters || [];
                        userMatch = userChars.some(char => {
                            const charStr = `${char.name}${char.tag ? '#' + char.tag : ''}`.toLowerCase();
                            return charStr.includes(searchTerm);
                        });
                    } catch (error) {
                        // エラーの場合はスキップ
                    }
                } else {
                    userMatch = characters.some(char => {
                        const charStr = `${char.name}${char.tag ? '#' + char.tag : ''}`.toLowerCase();
                        return charStr.includes(searchTerm);
                    });
                }
            }
            
            // アニメで検索
            if (!userMatch) {
                const animes = allAnimes.get(user.id) || [];
                if (animes.length === 0) {
                    // アニメデータをフェッチ
                    try {
                        const response = await fetch(`${API_URL}/firebase/users/${user.id}/animes`);
                        const data = await response.json();
                        allAnimes.set(user.id, data.animes || []);
                        const userAnimes = data.animes || [];
                        userMatch = userAnimes.some(anime => {
                            const animeStr = `${anime.title}${anime.hashtag ? '#' + anime.hashtag : ''}`.toLowerCase();
                            return animeStr.includes(searchTerm);
                        });
                    } catch (error) {
                        // エラーの場合はスキップ
                    }
                } else {
                    userMatch = animes.some(anime => {
                        const animeStr = `${anime.title}${anime.hashtag ? '#' + anime.hashtag : ''}`.toLowerCase();
                        return animeStr.includes(searchTerm);
                    });
                }
            }
            
            match = userMatch;
        }
        
        // ユーザー名で検索
        if (searchParams.username && match) {
            match = user.username && user.username.toLowerCase().includes(searchParams.username.toLowerCase());
        }
        
        // キャラクターで検索
        if (searchParams.character && match) {
            const characters = allCharacters.get(user.id) || [];
            if (characters.length === 0) {
                // キャラクターデータをフェッチ
                try {
                    const response = await fetch(`${API_URL}/firebase/users/${user.id}/characters`);
                    const data = await response.json();
                    allCharacters.set(user.id, data.characters || []);
                    const userChars = data.characters || [];
                    match = userChars.some(char => {
                        const charStr = `${char.name}${char.tag ? '#' + char.tag : ''}`.toLowerCase();
                        return charStr.includes(searchParams.character.toLowerCase());
                    });
                } catch (error) {
                    match = false;
                }
            } else {
                match = characters.some(char => {
                    const charStr = `${char.name}${char.tag ? '#' + char.tag : ''}`.toLowerCase();
                    return charStr.includes(searchParams.character.toLowerCase());
                });
            }
        }
        
        // アニメで検索
        if (searchParams.anime && match) {
            const animes = allAnimes.get(user.id) || [];
            if (animes.length === 0) {
                // アニメデータをフェッチ
                try {
                    const response = await fetch(`${API_URL}/firebase/users/${user.id}/animes`);
                    const data = await response.json();
                    allAnimes.set(user.id, data.animes || []);
                    const userAnimes = data.animes || [];
                    match = userAnimes.some(anime => {
                        const animeStr = `${anime.title}${anime.hashtag ? '#' + anime.hashtag : ''}`.toLowerCase();
                        return animeStr.includes(searchParams.anime.toLowerCase());
                    });
                } catch (error) {
                    match = false;
                }
            } else {
                match = animes.some(anime => {
                    const animeStr = `${anime.title}${anime.hashtag ? '#' + anime.hashtag : ''}`.toLowerCase();
                    return animeStr.includes(searchParams.anime.toLowerCase());
                });
            }
        }
        
        if (match) {
            filteredUsers.push(user);
        }
    }
    
    return filteredUsers;
}

// ユーザー検索
function searchUsers() {
    const all = document.getElementById('searchAll').value.trim();
    const username = document.getElementById('searchUsername').value.trim();
    const character = document.getElementById('searchCharacter').value.trim();
    const anime = document.getElementById('searchAnime').value.trim();
    
    if (!all && !username && !character && !anime) {
        alert('検索条件を入力してください');
        return;
    }
    
    const searchParams = {};
    if (all) searchParams.all = all;
    if (username) searchParams.username = username;
    if (character) searchParams.character = character;
    if (anime) searchParams.anime = anime;
    
    loadUsers(searchParams);
}

// 検索フォームのクリア
function clearSearch() {
    document.getElementById('searchAll').value = '';
    document.getElementById('searchUsername').value = '';
    document.getElementById('searchCharacter').value = '';
    document.getElementById('searchAnime').value = '';
    loadUsers();
}

// 初期データの読み込み
loadStats();
loadPlans();
loadUsers();