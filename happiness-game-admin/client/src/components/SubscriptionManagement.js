import React, { useState, useEffect } from 'react';
import axios from 'axios';

function SubscriptionManagement() {
  const [subscriptions, setSubscriptions] = useState([]);
  const [loading, setLoading] = useState(false);
  const [filter, setFilter] = useState('all'); // all, paid, unpaid, expiring
  const [testMode, setTestMode] = useState(false);
  const [testDays, setTestDays] = useState(60);

  useEffect(() => {
    fetchSubscriptions();
  }, []);

  const fetchSubscriptions = async () => {
    setLoading(true);
    try {
      const response = await axios.get('/api/subscriptions');
      const subs = response.data.map(sub => {
        const firstInstallDate = new Date(sub.firstInstallDate * 1000);
        const now = new Date();
        const daysSinceInstall = Math.floor((now - firstInstallDate) / (1000 * 60 * 60 * 24));
        const daysUntilPayment = Math.max(0, testDays - daysSinceInstall); // 60 days for production
        
        return {
          ...sub,
          daysSinceInstall,
          daysUntilPayment,
          requiresPaymentSoon: daysUntilPayment <= 7 && !sub.hasPaid,
          requiresPaymentNow: daysUntilPayment === 0 && !sub.hasPaid
        };
      });
      setSubscriptions(subs);
    } catch (error) {
      console.error('Error fetching subscriptions:', error);
    }
    setLoading(false);
  };

  const getFilteredSubscriptions = () => {
    switch (filter) {
      case 'paid':
        return subscriptions.filter(sub => sub.hasPaid);
      case 'unpaid':
        return subscriptions.filter(sub => !sub.hasPaid);
      case 'expiring':
        return subscriptions.filter(sub => sub.requiresPaymentSoon || sub.requiresPaymentNow);
      default:
        return subscriptions;
    }
  };

  const formatDate = (timestamp) => {
    if (!timestamp) return '未設定';
    const date = new Date(timestamp * 1000);
    return date.toLocaleDateString('ja-JP', { 
      year: 'numeric', 
      month: '2-digit', 
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit'
    });
  };

  const getPremiumStatusBadge = (sub) => {
    if (sub.isPremiumUser) {
      return <span className="badge badge-premium">プレミアム</span>;
    } else {
      return <span className="badge badge-regular">一般</span>;
    }
  };

  const getStatusBadge = (sub) => {
    if (sub.hasPaid) {
      return <span className="badge badge-success">支払い済み</span>;
    } else if (sub.requiresPaymentNow) {
      return <span className="badge badge-danger">支払い必要</span>;
    } else if (sub.requiresPaymentSoon) {
      return <span className="badge badge-warning">まもなく支払い</span>;
    } else {
      return <span className="badge badge-info">試用期間中</span>;
    }
  };

  const getDaysDisplay = (sub) => {
    if (sub.hasPaid) {
      return <span style={{ color: 'green' }}>無制限</span>;
    } else if (sub.daysUntilPayment === 0) {
      return <span style={{ color: 'red', fontWeight: 'bold' }}>期限切れ</span>;
    } else {
      return <span>あと{sub.daysUntilPayment}日</span>;
    }
  };

  const toggleSubscription = async (userId, currentStatus) => {
    try {
      const response = await axios.post('/api/subscriptions', {
        userId,
        hasPaid: !currentStatus
      });
      
      if (response.data.success) {
        // 即座にローカルステートを更新
        setSubscriptions(prevSubs => 
          prevSubs.map(sub => 
            (sub.currentUserId === userId || sub.userId === userId) 
              ? { ...sub, hasPaid: !currentStatus }
              : sub
          )
        );
        
        // バックグラウンドでデータを再取得
        setTimeout(() => fetchSubscriptions(), 500);
      }
    } catch (error) {
      console.error('Error toggling subscription:', error);
      alert('ステータスの更新に失敗しました: ' + error.message);
      // エラー時は元の状態に戻す
      fetchSubscriptions();
    }
  };

  const updateInstallDate = async (userId, daysAgo) => {
    try {
      const newDate = Math.floor(Date.now() / 1000) - (daysAgo * 24 * 60 * 60);
      
      // ローカルで即座に更新
      setSubscriptions(prevSubs => 
        prevSubs.map(sub => {
          if (sub.currentUserId === userId || sub.userId === userId) {
            const daysSinceInstall = daysAgo;
            const daysUntilPayment = Math.max(0, testDays - daysSinceInstall);
            return {
              ...sub,
              firstInstallDate: newDate,
              daysSinceInstall,
              daysUntilPayment,
              requiresPaymentSoon: daysUntilPayment <= 7 && !sub.hasPaid,
              requiresPaymentNow: daysUntilPayment === 0 && !sub.hasPaid
            };
          }
          return sub;
        })
      );
      
      alert(`ユーザー ${userId} のインストール日を${daysAgo}日前に変更しました`);
    } catch (error) {
      console.error('Error updating install date:', error);
      alert('インストール日の更新に失敗しました');
    }
  };

  return (
    <div className="subscription-management">
      <h2>サブスクリプション管理</h2>
      
      <div className="controls">
        <div className="filter-buttons">
          <button 
            className={`btn ${filter === 'all' ? 'btn-primary' : ''}`}
            onClick={() => setFilter('all')}
          >
            全て ({subscriptions.length})
          </button>
          <button 
            className={`btn ${filter === 'paid' ? 'btn-primary' : ''}`}
            onClick={() => setFilter('paid')}
          >
            支払い済み ({subscriptions.filter(s => s.hasPaid).length})
          </button>
          <button 
            className={`btn ${filter === 'unpaid' ? 'btn-primary' : ''}`}
            onClick={() => setFilter('unpaid')}
          >
            未払い ({subscriptions.filter(s => !s.hasPaid).length})
          </button>
          <button 
            className={`btn ${filter === 'expiring' ? 'btn-primary' : ''}`}
            onClick={() => setFilter('expiring')}
          >
            期限間近 ({subscriptions.filter(s => s.requiresPaymentSoon || s.requiresPaymentNow).length})
          </button>
        </div>
        <button className="btn" onClick={fetchSubscriptions}>
          更新
        </button>
      </div>

      <div style={{ marginBottom: '1.5rem', padding: '1rem', backgroundColor: '#f0f0f0', borderRadius: '8px' }}>
        <h4 style={{ marginBottom: '0.5rem' }}>テストモード</h4>
        <div style={{ display: 'flex', alignItems: 'center', gap: '1rem' }}>
          <label>
            <input
              type="checkbox"
              checked={testMode}
              onChange={(e) => setTestMode(e.target.checked)}
            />
            テストモード有効
          </label>
          {testMode && (
            <>
              <label>
                試用期間日数:
                <input
                  type="number"
                  value={testDays}
                  onChange={(e) => setTestDays(parseInt(e.target.value) || 60)}
                  style={{ marginLeft: '0.5rem', width: '60px' }}
                />
              </label>
              <button
                className="btn btn-sm"
                onClick={() => {
                  const userId = prompt('ユーザーIDを入力してください');
                  if (userId) {
                    const daysAgo = prompt('何日前にインストールしたことにしますか？（例: 58）');
                    if (daysAgo) {
                      updateInstallDate(userId, parseInt(daysAgo));
                    }
                  }
                }}
              >
                インストール日を変更
              </button>
              <div style={{ marginTop: '0.5rem', fontSize: '0.85rem', color: '#666' }}>
                <strong>テストシナリオ例:</strong>
                <ul style={{ margin: '0.25rem 0 0 1.5rem', paddingLeft: 0 }}>
                  <li>58日前: 「まもなく支払い」状態になります</li>
                  <li>60日前: 「期限切れ」状態になります（支払い必要）</li>
                  <li>61日前: 既に期限切れの状態になります</li>
                </ul>
              </div>
            </>
          )}
        </div>
      </div>

      {loading ? (
        <div>読み込み中...</div>
      ) : (
        <div className="table-container">
          <table>
            <thead>
              <tr>
                <th>ユーザー名</th>
                <th>初回インストール日</th>
                <th>経過日数</th>
                <th>支払いまで</th>
                <th>ステータス</th>
                <th>支払い済み</th>
                <th>金額</th>
                <th>最終確認</th>
                <th>操作</th>
              </tr>
            </thead>
            <tbody>
              {getFilteredSubscriptions().map(sub => (
                <tr key={sub.currentUserId || sub.userId} className={sub.requiresPaymentNow ? 'highlight-danger' : sub.requiresPaymentSoon ? 'highlight-warning' : ''}>
                  <td style={{ fontWeight: 'bold' }}>{sub.username || '未設定'}</td>
                  <td>{formatDate(sub.firstInstallDate)}</td>
                  <td>{sub.daysSinceInstall}日</td>
                  <td>{getDaysDisplay(sub)}</td>
                  <td>{getStatusBadge(sub)}</td>
                  <td>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                      <label className="toggle-switch">
                        <input
                          type="checkbox"
                          checked={sub.hasPaid}
                          onChange={() => toggleSubscription(sub.currentUserId || sub.userId, sub.hasPaid)}
                        />
                        <span className="toggle-slider"></span>
                      </label>
                      <span style={{ fontSize: '0.9rem' }}>
                        {sub.hasPaid ? '支払い済み' : '未払い'}
                      </span>
                    </div>
                  </td>
                  <td>{sub.hasPaid ? `¥${sub.amount || 600}` : '-'}</td>
                  <td>{formatDate(sub.lastSeenAt || sub.createdAt)}</td>
                  <td>
                    {sub.isPremiumUser && (
                      <span className="badge badge-premium">プレミアム</span>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          {getFilteredSubscriptions().length === 0 && (
            <div style={{ padding: '2rem', textAlign: 'center', color: '#666' }}>
              該当するサブスクリプションが見つかりませんでした
            </div>
          )}
        </div>
      )}
      
      <style jsx>{`
        .subscription-management {
          padding: 2rem;
        }
        
        .controls {
          display: flex;
          justify-content: space-between;
          align-items: center;
          margin-bottom: 1.5rem;
        }
        
        .filter-buttons {
          display: flex;
          gap: 0.5rem;
        }
        
        .badge {
          padding: 0.25rem 0.5rem;
          border-radius: 0.25rem;
          font-size: 0.875rem;
          font-weight: 500;
        }
        
        .badge-success {
          background-color: #28a745;
          color: white;
        }
        
        .badge-danger {
          background-color: #dc3545;
          color: white;
        }
        
        .badge-warning {
          background-color: #ffc107;
          color: #212529;
        }
        
        .badge-info {
          background-color: #17a2b8;
          color: white;
        }
        
        .badge-premium {
          background-color: #ffd700;
          color: #333;
          font-weight: bold;
        }
        
        .badge-regular {
          background-color: #6c757d;
          color: white;
        }
        
        .highlight-danger {
          background-color: #ffebee !important;
        }
        
        .highlight-warning {
          background-color: #fff8e1 !important;
        }
        
        table {
          width: 100%;
          border-collapse: collapse;
        }
        
        th, td {
          padding: 0.75rem;
          text-align: left;
          border-bottom: 1px solid #dee2e6;
        }
        
        th {
          background-color: #f8f9fa;
          font-weight: 600;
        }
        
        tr:hover {
          background-color: #f8f9fa;
        }
        
        .btn-sm {
          padding: 0.25rem 0.5rem;
          font-size: 0.875rem;
        }
        
        .btn-success {
          background-color: #28a745;
          color: white;
          border: none;
          cursor: pointer;
        }
        
        .btn-danger {
          background-color: #dc3545;
          color: white;
          border: none;
          cursor: pointer;
        }
        
        .btn-success:hover {
          background-color: #218838;
        }
        
        .btn-danger:hover {
          background-color: #c82333;
        }
        
        .toggle-switch {
          position: relative;
          display: inline-block;
          width: 50px;
          height: 24px;
        }
        
        .toggle-switch input {
          opacity: 0;
          width: 0;
          height: 0;
        }
        
        .toggle-slider {
          position: absolute;
          cursor: pointer;
          top: 0;
          left: 0;
          right: 0;
          bottom: 0;
          background-color: #ccc;
          transition: .4s;
          border-radius: 24px;
        }
        
        .toggle-slider:before {
          position: absolute;
          content: "";
          height: 18px;
          width: 18px;
          left: 3px;
          bottom: 3px;
          background-color: white;
          transition: .4s;
          border-radius: 50%;
        }
        
        input:checked + .toggle-slider {
          background-color: #28a745;
        }
        
        input:checked + .toggle-slider:before {
          transform: translateX(26px);
        }
      `}</style>
    </div>
  );
}

export default SubscriptionManagement;