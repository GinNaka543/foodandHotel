import React, { useState, useEffect } from 'react';
import axios from 'axios';

function SubscriptionManagement() {
  const [subscriptions, setSubscriptions] = useState([]);
  const [loading, setLoading] = useState(false);
  const [filter, setFilter] = useState('all'); // all, paid, unpaid, expiring

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
        const daysUntilPayment = Math.max(0, 60 - daysSinceInstall); // 60 days for production
        
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
    if (!window.confirm(`このユーザーの支払いステータスを${currentStatus ? '未払い' : '支払い済み'}に変更しますか？`)) {
      return;
    }

    try {
      const response = await axios.post('/api/subscriptions/toggle', {
        userId,
        hasPaid: !currentStatus
      });
      
      if (response.data.success) {
        alert(`ユーザー ${userId} のステータスを更新しました`);
        fetchSubscriptions();
      }
    } catch (error) {
      console.error('Error toggling subscription:', error);
      alert('ステータスの更新に失敗しました: ' + error.message);
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

      {loading ? (
        <div>読み込み中...</div>
      ) : (
        <div className="table-container">
          <table>
            <thead>
              <tr>
                <th>デバイスID</th>
                <th>現在のユーザー</th>
                <th>プレミアム</th>
                <th>初回インストール日</th>
                <th>経過日数</th>
                <th>支払いまで</th>
                <th>ステータス</th>
                <th>支払い日</th>
                <th>金額</th>
                <th>最終確認</th>
                <th>操作</th>
              </tr>
            </thead>
            <tbody>
              {getFilteredSubscriptions().map(sub => (
                <tr key={sub.deviceId || sub.userId} className={sub.requiresPaymentNow ? 'highlight-danger' : sub.requiresPaymentSoon ? 'highlight-warning' : ''}>
                  <td style={{ fontSize: '0.8rem', color: sub.deviceId ? '#333' : '#999' }}>
                    {sub.deviceId ? sub.deviceId.substring(0, 12) + '...' : '未設定'}
                  </td>
                  <td>{sub.username || '未設定'}</td>
                  <td>{getPremiumStatusBadge(sub)}</td>
                  <td>{formatDate(sub.firstInstallDate)}</td>
                  <td>{sub.daysSinceInstall}日</td>
                  <td>{getDaysDisplay(sub)}</td>
                  <td>{getStatusBadge(sub)}</td>
                  <td>{sub.hasPaid ? formatDate(sub.paymentDate) : '-'}</td>
                  <td>{sub.hasPaid ? `¥${sub.amount || 500}` : '-'}</td>
                  <td>{formatDate(sub.lastSeenAt || sub.createdAt)}</td>
                  <td>
                    <button
                      className={`btn btn-sm ${sub.hasPaid ? 'btn-danger' : 'btn-success'}`}
                      onClick={() => toggleSubscription(sub.deviceId || sub.userId, sub.hasPaid)}
                      title={sub.hasPaid ? '未払いに戻す' : '支払い済みにする'}
                    >
                      {sub.hasPaid ? '未払いに戻す' : '支払い済みに'}
                    </button>
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
      `}</style>
    </div>
  );
}

export default SubscriptionManagement;