import React, { useState, useEffect } from 'react';
import axios from 'axios';

function PointsManagement() {
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(false);
  const [searchTerm, setSearchTerm] = useState('');
  const [selectedUser, setSelectedUser] = useState(null);
  const [pointAmount, setPointAmount] = useState('');
  const [transactionType, setTransactionType] = useState('admin_grant');
  const [description, setDescription] = useState('');
  const [showAddPointsModal, setShowAddPointsModal] = useState(false);

  useEffect(() => {
    fetchUsers();
  }, []);

  const fetchUsers = async () => {
    setLoading(true);
    try {
      const response = await axios.get('/api/users');
      setUsers(response.data);
    } catch (error) {
      console.error('Error fetching users:', error);
    }
    setLoading(false);
  };

  const filteredUsers = users.filter(user =>
    (user.username || '').toLowerCase().includes(searchTerm.toLowerCase()) ||
    user.id.toLowerCase().includes(searchTerm.toLowerCase())
  );

  const handleAddPoints = async () => {
    if (!selectedUser || !pointAmount || !description) {
      alert('すべてのフィールドを入力してください');
      return;
    }

    try {
      const response = await axios.post('/api/admin/add-points', {
        userId: selectedUser.id,
        amount: parseInt(pointAmount),
        type: transactionType,
        description: description
      });
      
      console.log('ポイント追加成功:', response.data);
      alert(`ポイントを追加しました。新しい残高: ${response.data.newPoints}pt`);
      setShowAddPointsModal(false);
      setSelectedUser(null);
      setPointAmount('');
      setDescription('');
      fetchUsers(); // リフレッシュ
    } catch (error) {
      console.error('Error adding points:', error);
      console.error('エラー詳細:', error.response?.data || error.message);
      const errorMessage = error.response?.data?.error || error.message || 'ポイントの追加に失敗しました';
      alert(`エラー: ${errorMessage}`);
    }
  };

  const handleUserSelect = (user) => {
    setSelectedUser(user);
    setShowAddPointsModal(true);
  };

  return (
    <div className="points-management-page">
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '2rem' }}>
        <h2>ポイント管理</h2>
      </div>

      {/* 検索バー */}
      <div className="search-container">
        <input
          type="text"
          placeholder="ユーザー名またはIDで検索"
          value={searchTerm}
          onChange={(e) => setSearchTerm(e.target.value)}
          style={{
            width: '100%',
            padding: '0.75rem',
            border: '1px solid #ddd',
            borderRadius: '4px',
            fontSize: '1rem',
            marginBottom: '1rem'
          }}
        />
      </div>

      {loading ? (
        <div>読み込み中...</div>
      ) : (
        <div className="table-container">
          <table>
            <thead>
              <tr>
                <th>ユーザー名</th>
                <th>ユーザーID</th>
                <th>現在のポイント</th>
                <th>お気に入りアニメ</th>
                <th>お気に入りキャラクター</th>
                <th>アクション</th>
              </tr>
            </thead>
            <tbody>
              {filteredUsers.map(user => (
                <tr key={user.id}>
                  <td>{user.username || '未設定'}</td>
                  <td>
                    <div style={{ fontSize: '0.8rem', fontFamily: 'monospace' }}>
                      {user.id.substring(0, 8)}...
                    </div>
                  </td>
                  <td>
                    <span style={{ 
                      fontWeight: 'bold', 
                      color: '#6a0dad',
                      fontSize: '1.1rem'
                    }}>
                      {user.points || 0}pt
                    </span>
                  </td>
                  <td>
                    <div style={{ maxWidth: '200px', overflow: 'hidden' }}>
                      {(user.favoriteAnimes || []).slice(0, 2).map(anime => (
                        <span key={anime} className="tag" style={{ margin: '2px' }}>
                          {anime}
                        </span>
                      ))}
                      {(user.favoriteAnimes || []).length > 2 && (
                        <span style={{ color: '#666', fontSize: '0.8rem' }}>
                          +{(user.favoriteAnimes || []).length - 2}件
                        </span>
                      )}
                    </div>
                  </td>
                  <td>
                    <div style={{ maxWidth: '200px', overflow: 'hidden' }}>
                      {(user.favoriteCharacters || []).slice(0, 2).map(character => (
                        <span key={character} className="tag" style={{ margin: '2px' }}>
                          {character}
                        </span>
                      ))}
                      {(user.favoriteCharacters || []).length > 2 && (
                        <span style={{ color: '#666', fontSize: '0.8rem' }}>
                          +{(user.favoriteCharacters || []).length - 2}件
                        </span>
                      )}
                    </div>
                  </td>
                  <td>
                    <button
                      onClick={() => handleUserSelect(user)}
                      className="btn btn-primary"
                      style={{ fontSize: '0.9rem', padding: '0.5rem 1rem' }}
                    >
                      ポイント付与
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          {filteredUsers.length === 0 && (
            <div style={{ padding: '2rem', textAlign: 'center', color: '#666' }}>
              {searchTerm ? '該当するユーザーが見つかりませんでした' : 'ユーザーが見つかりませんでした'}
            </div>
          )}
        </div>
      )}

      {/* ポイント追加モーダル */}
      {showAddPointsModal && selectedUser && (
        <div style={{
          position: 'fixed',
          top: 0,
          left: 0,
          right: 0,
          bottom: 0,
          backgroundColor: 'rgba(0, 0, 0, 0.5)',
          display: 'flex',
          justifyContent: 'center',
          alignItems: 'center',
          zIndex: 1000
        }}>
          <div style={{
            backgroundColor: 'white',
            padding: '2rem',
            borderRadius: '8px',
            width: '90%',
            maxWidth: '500px',
            maxHeight: '80vh',
            overflow: 'auto'
          }}>
            <h3 style={{ marginBottom: '1.5rem' }}>ポイント付与</h3>
            
            <div style={{ marginBottom: '1rem' }}>
              <label style={{ display: 'block', marginBottom: '0.5rem', fontWeight: 'bold' }}>
                対象ユーザー
              </label>
              <div style={{ 
                padding: '0.75rem',
                backgroundColor: '#f5f5f5',
                borderRadius: '4px',
                border: '1px solid #ddd'
              }}>
                <div style={{ fontWeight: 'bold' }}>{selectedUser.username || '未設定'}</div>
                <div style={{ fontSize: '0.8rem', color: '#666', fontFamily: 'monospace' }}>
                  ID: {selectedUser.id}
                </div>
                <div style={{ fontSize: '0.9rem', color: '#6a0dad', marginTop: '0.25rem' }}>
                  現在のポイント: {selectedUser.points || 0}pt
                </div>
              </div>
            </div>

            <div style={{ marginBottom: '1rem' }}>
              <label style={{ display: 'block', marginBottom: '0.5rem', fontWeight: 'bold' }}>
                付与ポイント数
              </label>
              <input
                type="number"
                value={pointAmount}
                onChange={(e) => setPointAmount(e.target.value)}
                placeholder="1000"
                style={{
                  width: '100%',
                  padding: '0.75rem',
                  border: '1px solid #ddd',
                  borderRadius: '4px',
                  fontSize: '1rem'
                }}
                min="1"
              />
            </div>

            <div style={{ marginBottom: '1rem' }}>
              <label style={{ display: 'block', marginBottom: '0.5rem', fontWeight: 'bold' }}>
                取引タイプ
              </label>
              <select
                value={transactionType}
                onChange={(e) => setTransactionType(e.target.value)}
                style={{
                  width: '100%',
                  padding: '0.75rem',
                  border: '1px solid #ddd',
                  borderRadius: '4px',
                  fontSize: '1rem'
                }}
              >
                <option value="admin_grant">管理者付与</option>
                <option value="bonus">ボーナス</option>
                <option value="compensation">補償</option>
                <option value="event_reward">イベント報酬</option>
              </select>
            </div>

            <div style={{ marginBottom: '1.5rem' }}>
              <label style={{ display: 'block', marginBottom: '0.5rem', fontWeight: 'bold' }}>
                説明
              </label>
              <textarea
                value={description}
                onChange={(e) => setDescription(e.target.value)}
                placeholder="ポイント付与の理由を入力してください"
                style={{
                  width: '100%',
                  padding: '0.75rem',
                  border: '1px solid #ddd',
                  borderRadius: '4px',
                  fontSize: '1rem',
                  minHeight: '80px',
                  resize: 'vertical'
                }}
              />
            </div>

            <div style={{ display: 'flex', gap: '1rem', justifyContent: 'flex-end' }}>
              <button
                onClick={() => {
                  setShowAddPointsModal(false);
                  setSelectedUser(null);
                  setPointAmount('');
                  setDescription('');
                }}
                className="btn"
                style={{ 
                  backgroundColor: '#6c757d',
                  color: 'white',
                  border: 'none'
                }}
              >
                キャンセル
              </button>
              <button
                onClick={handleAddPoints}
                className="btn btn-primary"
                disabled={!pointAmount || !description}
              >
                ポイント付与
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

export default PointsManagement;