import React, { useState, useEffect } from 'react';
import axios from 'axios';
import { Link, useNavigate } from 'react-router-dom';

const PLACEMENT_ICONS = {
  home: '🏠',
  character: '👤',
  product: '📦',
  visit: '✈️',
  anime: '🎬',
};
const GENERAL_PAGES = [
  { key: 'home', label: 'ホーム', icon: '🏠', max: 2 },
  { key: 'character', label: 'キャラ', icon: '👤', max: 1 },
  { key: 'product', label: 'プロダクト', icon: '📦', max: null },
  { key: 'visit', label: 'ビジット', icon: '✈️', max: 1 },
  { key: 'anime', label: 'アニメ', icon: '🎬', max: 5 },
];

function Advertisements() {
  const [advertisements, setAdvertisements] = useState([]);
  const [loading, setLoading] = useState(false);
  const [activeTab, setActiveTab] = useState('target'); // 'target' or 'general'
  const [generalPage, setGeneralPage] = useState('home'); // 'home' | 'character' | 'product'
  const navigate = useNavigate();

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

  const handleDelete = async (id) => {
    if (window.confirm('この広告を完全に削除しますか？（元に戻せません）')) {
      try {
        await axios.delete(`/api/advertisements/${id}?force=true`);
        fetchAdvertisements();
      } catch (error) {
        console.error('Error deleting advertisement:', error);
      }
    }
  };

  const handleActivate = async (id) => {
    try {
      await axios.put(`/api/advertisements/${id}`, { isActive: true });
      fetchAdvertisements();
    } catch (error) {
      console.error('Error activating advertisement:', error);
    }
  };

  const formatDate = (timestamp) => {
    if (!timestamp) return '-';
    const date = timestamp.toDate ? timestamp.toDate() : new Date(timestamp);
    return date.toLocaleDateString('ja-JP');
  };

  // フィルタリング
  const filteredAds = advertisements.filter(ad => {
    const isGeneral =
      (!ad.targetAnimes || ad.targetAnimes.length === 0) &&
      (!ad.targetCharacters || ad.targetCharacters.length === 0) &&
      (!ad.targetHashtags || ad.targetHashtags.length === 0);
    if (activeTab === 'general') {
      // サブタブでページごとに絞り込み
      return isGeneral && (ad.placements || []).includes(generalPage);
    }
    return !isGeneral;
  });

  // 一般広告の上限チェック
  const currentGeneralCount = advertisements.filter(ad =>
    (!ad.targetAnimes || ad.targetAnimes.length === 0) &&
    (!ad.targetCharacters || ad.targetCharacters.length === 0) &&
    (!ad.targetHashtags || ad.targetHashtags.length === 0) &&
    (ad.placements || []).includes(generalPage)
  ).length;
  const pageConfig = GENERAL_PAGES.find(p => p.key === generalPage);
  const isGeneralLimit = pageConfig.max !== null && currentGeneralCount >= pageConfig.max;

  return (
    <div className="advertisements-page">
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '2rem' }}>
        <h2>広告管理</h2>
        {activeTab === 'target' ? (
          <Link to="/create-ad" className="btn btn-primary">
            新規広告作成
          </Link>
        ) : (
          <button
            className="btn btn-primary"
            disabled={isGeneralLimit}
            onClick={() => navigate(`/create-ad?generalPage=${generalPage}`)}
          >
            {pageConfig.icon} {pageConfig.label}ページ用の広告を作成
          </button>
        )}
      </div>

      {/* タブUI */}
      <div style={{ display: 'flex', gap: '1rem', marginBottom: '1.5rem' }}>
        <button
          className={activeTab === 'target' ? 'btn btn-primary' : 'btn btn-secondary'}
          onClick={() => setActiveTab('target')}
        >
          ターゲット広告
        </button>
        <button
          className={activeTab === 'general' ? 'btn btn-primary' : 'btn btn-secondary'}
          onClick={() => setActiveTab('general')}
        >
          一般広告（全ユーザー向け）
        </button>
      </div>

      {/* 一般広告サブタブ */}
      {activeTab === 'general' && (
        <div style={{ display: 'flex', gap: '1rem', marginBottom: '1.5rem' }}>
          {GENERAL_PAGES.map(page => (
            <button
              key={page.key}
              className={generalPage === page.key ? 'btn btn-primary' : 'btn btn-secondary'}
              onClick={() => setGeneralPage(page.key)}
            >
              <span style={{ fontSize: '1.2rem', marginRight: '0.3rem' }}>{page.icon}</span>
              {page.label}ページ
              {page.max !== null && (
                <span style={{ fontSize: '0.9rem', color: '#888', marginLeft: 6 }}>
                  （最大{page.max}件）
                </span>
              )}
            </button>
          ))}
        </div>
      )}

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
                <th>配置場所</th>
                <th>表示率</th>
                <th>表示回数</th>
                <th>クリック数</th>
                <th>CTR</th>
                <th>ステータス</th>
                <th>作成日</th>
                <th>アクション</th>
              </tr>
            </thead>
            <tbody>
              {filteredAds.map(ad => (
                <tr key={ad.id}>
                  <td>{ad.title}</td>
                  <td>{ad.description.length > 50 ? ad.description.substring(0, 50) + '...' : ad.description}</td>
                  <td>
                    <div
                      style={{
                        fontSize: '0.875rem',
                        whiteSpace: 'nowrap',
                        overflowX: 'auto',
                        maxWidth: '250px',
                        WebkitOverflowScrolling: 'touch',
                        display: 'block'
                      }}
                    >
                      {[
                        ad.targetAnimes && ad.targetAnimes.length > 0 ? `アニメ: ${ad.targetAnimes.join(', ')}` : null,
                        ad.targetCharacters && ad.targetCharacters.length > 0 ? `キャラ: ${ad.targetCharacters.join(', ')}` : null,
                        ad.targetHashtags && ad.targetHashtags.length > 0 ? `タグ: ${ad.targetHashtags.map(tag => `#${tag}`).join(', ')}` : null
                      ].filter(Boolean).join('  ')}
                    </div>
                  </td>
                  <td>
                    <div style={{ display: 'flex', gap: '0.5rem', fontSize: '1.3rem' }}>
                      {(ad.placements || []).map(p => (
                        <span key={p} title={p}>{PLACEMENT_ICONS[p] || p}</span>
                      ))}
                    </div>
                  </td>
                  <td>
                    <span style={{ 
                      backgroundColor: ad.displayRate === 100 ? '#e8f5e9' : '#fff8e1',
                      color: ad.displayRate === 100 ? '#2e7d32' : '#f57c00',
                      padding: '0.25rem 0.5rem',
                      borderRadius: '4px',
                      fontSize: '0.875rem',
                      fontWeight: '500'
                    }}>
                      {ad.displayRate || 100}%
                    </span>
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
                    <>
                      <button
                        className="btn btn-danger"
                        onClick={() => handleDeactivate(ad.id)}
                        style={{ fontSize: '0.875rem', padding: '0.25rem 0.75rem', marginRight: '0.5rem' }}
                        disabled={!ad.isActive}
                      >
                        停止
                      </button>
                      <button
                        className="btn btn-primary"
                        onClick={() => navigate(`/create-ad?id=${ad.id}`)}
                        style={{ fontSize: '0.875rem', padding: '0.25rem 0.75rem', marginRight: '0.5rem' }}
                      >
                        編集
                      </button>
                      <button
                        className="btn btn-danger"
                        onClick={() => handleDelete(ad.id)}
                        style={{ fontSize: '0.875rem', padding: '0.25rem 0.75rem', marginRight: '0.5rem' }}
                      >
                        削除
                      </button>
                      {!ad.isActive && (
                        <button
                          className="btn btn-primary"
                          onClick={() => handleActivate(ad.id)}
                          style={{ fontSize: '0.875rem', padding: '0.25rem 0.75rem' }}
                        >
                          アクティブ化
                        </button>
                      )}
                    </>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          {filteredAds.length === 0 && (
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