// API URL
const API_URL = 'http://localhost:3000/api';

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

// スポット入力フィールドの追加
function addSpotInput() {
    const container = document.getElementById('spotsContainer');
    const div = document.createElement('div');
    div.className = 'spot-input mb-2 flex items-center';
    div.innerHTML = `
        <input type="text" name="spots[]" class="form-input flex-1" placeholder="スポット名">
        <button type="button" onclick="removeSpotInput(this)" class="ml-2 text-red-500 hover:text-red-700">
            <i class="fas fa-times"></i>
        </button>
    `;
    container.appendChild(div);
}

// スポット入力フィールドの削除
function removeSpotInput(button) {
    button.parentElement.remove();
}

// プラン作成フォームの送信
document.getElementById('createPlanForm').addEventListener('submit', async (e) => {
    e.preventDefault();
    
    const formData = new FormData(e.target);
    const spots = [];
    formData.getAll('spots[]').forEach(spot => {
        if (spot.trim()) {
            spots.push({
                name: spot,
                address: '',
                notes: '',
                event: null
            });
        }
    });
    
    const planData = {
        animeName: formData.get('animeName'),
        title: formData.get('title'),
        duration: formData.get('duration'),
        spots: spots
    };
    
    try {
        const response = await fetch(`${API_URL}/plans`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(planData)
        });
        
        if (response.ok) {
            alert('プランを作成しました');
            e.target.reset();
            document.getElementById('spotsContainer').innerHTML = `
                <div class="spot-input mb-2">
                    <input type="text" name="spots[]" class="form-input" placeholder="スポット名">
                </div>
            `;
            
            // プラン管理タブに切り替え
            document.querySelector('[data-tab="plans"]').click();
            loadPlans();
            loadStats();
        } else {
            alert('プランの作成に失敗しました');
        }
    } catch (error) {
        console.error('プランの作成に失敗しました:', error);
        alert('プランの作成に失敗しました');
    }
});

// 初期データの読み込み
loadStats();
loadPlans();