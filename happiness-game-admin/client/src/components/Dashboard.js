import React, { useState, useEffect } from 'react';
import axios from 'axios';

function Dashboard() {
  const [statistics, setStatistics] = useState({
    totalUsers: 0,
    totalAds: 0,
    totalSubscriptions: 0,
    totalPoints: 0,
    animeStats: {},
    characterStats: {},
    voiceActorStats: {},
    hashtagStats: {}
  });
  const [subscriptionStats, setSubscriptionStats] = useState(null);
  const [debugInfo, setDebugInfo] = useState(null);

  useEffect(() => {
    fetchStatistics();
    fetchSubscriptionStats();
  }, []);

  const fetchStatistics = async () => {
    try {
      console.log('🎯 統計データ取得開始');
      const response = await axios.get('/api/statistics');
      console.log('🎯 サーバーから受信したデータ:', response.data);
      console.log('🎯 animeStats:', response.data.animeStats);
      console.log('🎯 characterStats:', response.data.characterStats);
      console.log('🎯 voiceActorStats:', response.data.voiceActorStats);
      console.log('🎯 hashtagStats:', response.data.hashtagStats);
      setStatistics(response.data);
    } catch (error) {
      console.error('Error fetching statistics:', error);
    }
  };

  const fetchSubscriptionStats = async () => {
    try {
      const response = await axios.get('/api/subscriptions/stats');
      setSubscriptionStats(response.data);
    } catch (error) {
      console.error('Error fetching subscription stats:', error);
    }
  };

  const getTop10List = (data) => {
    if (!data || typeof data !== 'object') return [];
    return Object.entries(data)
      .sort(([, a], [, b]) => b - a)
      .slice(0, 10);
  };

  const testConnection = async () => {
    try {
      console.log('🧪 サーバー接続テスト開始');
      const response = await axios.get('/api/debug/test');
      console.log('🧪 テスト成功:', response.data);
      alert(`サーバー接続成功: ${response.data.message}`);
    } catch (error) {
      console.error('🧪 接続テストエラー:', error);
      alert(`サーバー接続エラー: ${error.message}`);
    }
  };

  const fetchDebugInfo = async () => {
    try {
      console.log('🔍 デバッグ情報取得開始');
      console.log('🔍 リクエストURL: /api/debug/collections');
      
      const response = await axios.get('/api/debug/collections');
      console.log('🔍 レスポンス成功:', response.status);
      console.log('🔍 デバッグ情報:', response.data);
      setDebugInfo(response.data);
      alert('デバッグ情報を取得しました。コンソールログを確認してください。');
    } catch (error) {
      console.error('🔍 デバッグ情報取得エラー:', error);
      console.error('🔍 エラー詳細:', error.response?.data);
      alert(`デバッグ情報の取得に失敗しました: ${error.message}`);
      setDebugInfo({ error: error.message, details: error.response?.data });
    }
  };

  return (
    <div className="dashboard">
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '2rem' }}>
        <h2>ダッシュボード</h2>
        <div>
          <button 
            onClick={testConnection}
            style={{ 
              padding: '0.5rem 1rem', 
              backgroundColor: '#4caf50', 
              color: 'white', 
              border: 'none', 
              borderRadius: '4px',
              marginRight: '0.5rem',
              cursor: 'pointer'
            }}
          >
            🧪 接続テスト
          </button>
          <button 
            onClick={fetchDebugInfo}
            style={{ 
              padding: '0.5rem 1rem', 
              backgroundColor: '#ff9800', 
              color: 'white', 
              border: 'none', 
              borderRadius: '4px',
              marginRight: '0.5rem',
              cursor: 'pointer'
            }}
          >
            🔍 デバッグ情報を取得
          </button>
          <button 
            onClick={fetchStatistics}
            style={{ 
              padding: '0.5rem 1rem', 
              backgroundColor: '#2196f3', 
              color: 'white', 
              border: 'none', 
              borderRadius: '4px',
              cursor: 'pointer'
            }}
          >
            🔄 データ再読み込み
          </button>
        </div>
      </div>

      {debugInfo && (
        <div style={{ 
          backgroundColor: '#f5f5f5', 
          padding: '1rem', 
          borderRadius: '8px', 
          marginBottom: '2rem',
          fontFamily: 'monospace',
          fontSize: '12px',
          maxHeight: '300px',
          overflow: 'auto'
        }}>
          <h4>🔍 Firebase コレクション デバッグ情報</h4>
          <pre>{JSON.stringify(debugInfo, null, 2)}</pre>
        </div>
      )}
      
      <div className="dashboard-grid">
        <div className="stat-card">
          <h3>総ユーザー数</h3>
          <div className="value">{statistics.totalUsers}</div>
        </div>
        
        <div className="stat-card">
          <h3>アクティブ広告数</h3>
          <div className="value">{statistics.totalAds}</div>
        </div>
        
        {subscriptionStats && (
          <>
            <div className="stat-card">
              <h3>総サブスクリプション</h3>
              <div className="value">{subscriptionStats.total || 0}</div>
              <div className="sub-value">デバイス登録数</div>
            </div>
            
            <div className="stat-card">
              <h3>アクティブ</h3>
              <div className="value">{subscriptionStats.active || 0}</div>
              <div className="sub-value">稼働中のサブスクリプション</div>
            </div>
            
            <div className="stat-card">
              <h3>非アクティブ</h3>
              <div className="value" style={{ color: subscriptionStats.inactive > 0 ? '#ff9800' : '#4caf50' }}>
                {subscriptionStats.inactive || 0}
              </div>
              <div className="sub-value">停止中のサブスクリプション</div>
            </div>
            
            <div className="stat-card">
              <h3>デバイス種類</h3>
              <div className="value">{Object.keys(subscriptionStats.deviceTypes || {}).length}</div>
              <div className="sub-value">登録デバイス種類数</div>
            </div>
          </>
        )}
        
        <div className="stat-card">
          <h3>総ポイント</h3>
          <div className="value">{statistics.totalPoints || 0}</div>
        </div>
        
        <div className="stat-card">
          <h3>総サブスクリプション</h3>
          <div className="value">{statistics.totalSubscriptions || 0}</div>
        </div>
      </div>

      <div className="list-container">
        <h3>人気アニメ トップ10</h3>
        <table className="ranking-table">
          <thead>
            <tr>
              <th>順位</th>
              <th>アニメ名</th>
              <th>ユーザー数</th>
            </tr>
          </thead>
          <tbody>
            {getTop10List(statistics.animeStats || {}).length > 0 ? (
              getTop10List(statistics.animeStats || {}).map(([anime, count], index) => (
                <tr key={anime}>
                  <td>{index + 1}</td>
                  <td>{anime}</td>
                  <td>{count}</td>
                </tr>
              ))
            ) : (
              <tr>
                <td colSpan="3" style={{ textAlign: 'center', color: '#666' }}>
                  データが見つかりませんでした
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>

      <div className="list-container">
        <h3>人気キャラクター トップ10</h3>
        <table className="ranking-table">
          <thead>
            <tr>
              <th>順位</th>
              <th>キャラクター名</th>
              <th>ユーザー数</th>
            </tr>
          </thead>
          <tbody>
            {getTop10List(statistics.characterStats || {}).length > 0 ? (
              getTop10List(statistics.characterStats || {}).map(([character, count], index) => (
                <tr key={character}>
                  <td>{index + 1}</td>
                  <td>{character}</td>
                  <td>{count}</td>
                </tr>
              ))
            ) : (
              <tr>
                <td colSpan="3" style={{ textAlign: 'center', color: '#666' }}>
                  データが見つかりませんでした
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>

      <div className="list-container">
        <h3>人気声優 トップ10</h3>
        <table className="ranking-table">
          <thead>
            <tr>
              <th>順位</th>
              <th>声優名</th>
              <th>ユーザー数</th>
            </tr>
          </thead>
          <tbody>
            {getTop10List(statistics.voiceActorStats || {}).length > 0 ? (
              getTop10List(statistics.voiceActorStats || {}).map(([voiceActor, count], index) => (
                <tr key={voiceActor}>
                  <td>{index + 1}</td>
                  <td>{voiceActor}</td>
                  <td>{count}</td>
                </tr>
              ))
            ) : (
              <tr>
                <td colSpan="3" style={{ textAlign: 'center', color: '#666' }}>
                  データが見つかりませんでした
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>

      <div className="list-container">
        <h3>人気ハッシュタグ トップ10</h3>
        <table className="ranking-table">
          <thead>
            <tr>
              <th>順位</th>
              <th>ハッシュタグ</th>
              <th>ユーザー数</th>
            </tr>
          </thead>
          <tbody>
            {getTop10List(statistics.hashtagStats || {}).length > 0 ? (
              getTop10List(statistics.hashtagStats || {}).map(([hashtag, count], index) => (
                <tr key={hashtag}>
                  <td>{index + 1}</td>
                  <td>{hashtag}</td>
                  <td>{count}</td>
                </tr>
              ))
            ) : (
              <tr>
                <td colSpan="3" style={{ textAlign: 'center', color: '#666' }}>
                  データが見つかりませんでした
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}

export default Dashboard;