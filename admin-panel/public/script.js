// API URL
const API_URL = 'http://localhost:3002/api';

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
async function loadUsers() {
    try {
        const response = await fetch(`${API_URL}/users`);
        const data = await response.json();
        
        const tbody = document.getElementById('usersTableBody');
        tbody.innerHTML = '';
        
        if (!data.users || data.users.length === 0) {
            tbody.innerHTML = '<tr><td colspan="5" class="text-center py-4 text-gray-500">ユーザーがいません</td></tr>';
            return;
        }
        
        for (const user of data.users) {
            // キャラクター名とアニメ名を取得
            let characterNames = 'なし';
            let animeNames = 'なし';
            
            try {
                const [charResponse, animeResponse] = await Promise.all([
                    fetch(`${API_URL}/users/${user.id}/characters`),
                    fetch(`${API_URL}/users/${user.id}/animes`)
                ]);
                
                const charData = await charResponse.json();
                const animeData = await animeResponse.json();
                
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
            fetch(`${API_URL}/users`),
            fetch(`${API_URL}/users/${userId}/characters`),
            fetch(`${API_URL}/users/${userId}/animes`)
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
                            <span class="text-gray-600">作成日:</span>
                            <span class="ml-2">${user.createdAt || '-'}</span>
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
                                    <div class="text-xs text-gray-400">作成: ${char.createdAt || '-'}</div>
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
                                    <div class="text-xs text-gray-400">作成: ${anime.createdAt || '-'}</div>
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
    loadUsers();
    loadStats();
}

// 初期データの読み込み
loadStats();
loadPlans();
loadUsers();