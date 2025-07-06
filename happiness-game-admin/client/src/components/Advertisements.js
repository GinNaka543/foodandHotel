import React, { useState, useEffect } from 'react';
import axios from 'axios';
import { Link } from 'react-router-dom';

function Advertisements() {
  const [advertisements, setAdvertisements] = useState([]);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    fetchAdvertisements();
  }, []);

  const fetchAdvertisements = async () => {
    setLoading(true);
    try {
      const response = await axios.get('/api/advertisements');
      setAdvertisements(response.data);
    } catch (error) {
      console.error('Error fetching advertisements:', error);
    }
    setLoading(false);
  };

  const handleDeactivate = async (id) => {
    if (window.confirm('この広告を非アクティブ化しますか？')) {
      try {
        await axios.delete(`/api/advertisements/${id}`);
        fetchAdvertisements();
      } catch (error) {
        console.error('Error deactivating advertisement:', error);
      }
    }
  };

  const formatDate = (timestamp) => {
    if (!timestamp) return '-';
    const date = timestamp.toDate ? timestamp.toDate() : new Date(timestamp);
    return date.toLocaleDateString('ja-JP');
  };

  return (
    <div className="advertisements-page">
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '2rem' }}>
        <h2>広告管理</h2>
        <Link to="/create-ad" className="btn btn-primary">
          新規広告作成
        </Link>
      </div>

      {loading ? (
        <div>読み込み中...</div>
      ) : (
        <div className="table-container">
          <table>
            <thead>
              <tr>
                <th>タイトル</th>
                <th>説明</th>
                <th>ターゲット</th>
                <th>表示回数</th>
                <th>クリック数</th>
                <th>CTR</th>
                <th>ステータス</th>
                <th>作成日</th>
                <th>アクション</th>
              </tr>
            </thead>
            <tbody>
              {advertisements.map(ad => (
                <tr key={ad.id}>
                  <td>{ad.title}</td>
                  <td>{ad.description.length > 50 ? ad.description.substring(0, 50) + '...' : ad.description}</td>
                  <td>
                    <div style={{ fontSize: '0.875rem' }}>
                      {ad.targetAnimes.length > 0 && (
                        <div>アニメ: {ad.targetAnimes.join(', ')}</div>
                      )}
                      {ad.targetCharacters.length > 0 && (
                        <div>キャラ: {ad.targetCharacters.join(', ')}</div>
                      )}
                      {ad.targetHashtags.length > 0 && (
                        <div>タグ: {ad.targetHashtags.map(tag => `#${tag}`).join(', ')}</div>
                      )}
                    </div>
                  </td>
                  <td>{ad.impressions || 0}</td>
                  <td>{ad.clicks || 0}</td>
                  <td>
                    {ad.impressions > 0 
                      ? ((ad.clicks / ad.impressions) * 100).toFixed(2) + '%'
                      : '0%'}
                  </td>
                  <td>
                    <span className={`tag ${ad.isActive ? '' : 'tag-inactive'}`}>
                      {ad.isActive ? 'アクティブ' : '非アクティブ'}
                    </span>
                  </td>
                  <td>{formatDate(ad.createdAt)}</td>
                  <td>
                    {ad.isActive && (
                      <button
                        className="btn btn-danger"
                        onClick={() => handleDeactivate(ad.id)}
                        style={{ fontSize: '0.875rem', padding: '0.25rem 0.75rem' }}
                      >
                        停止
                      </button>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          {advertisements.length === 0 && (
            <div style={{ padding: '2rem', textAlign: 'center', color: '#666' }}>
              広告がありません
            </div>
          )}
        </div>
      )}
    </div>
  );
}

export default Advertisements;