import React, { useState, useEffect } from 'react';
import axios from 'axios';

function Users() {
  const [users, setUsers] = useState([]);
  const [searchParams, setSearchParams] = useState({
    all: '',
    anime: '',
    character: '',
    voiceActor: '',
    hashtag: ''
  });
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    fetchAllUsers();
  }, []);

  const fetchAllUsers = async () => {
    setLoading(true);
    try {
      const response = await axios.get('/api/users');
      // Deduplicate users by ID, keeping the most recent one
      const usersMap = new Map();
      response.data.forEach(user => {
        if (!usersMap.has(user.id) || 
            (user.updatedAt && (!usersMap.get(user.id).updatedAt || 
             new Date(user.updatedAt) > new Date(usersMap.get(user.id).updatedAt)))) {
          usersMap.set(user.id, user);
        }
      });
      setUsers(Array.from(usersMap.values()));
    } catch (error) {
      console.error('Error fetching users:', error);
    }
    setLoading(false);
  };

  const handleSearch = async (e) => {
    e.preventDefault();
    setLoading(true);
    
    try {
      const params = new URLSearchParams();
      if (searchParams.all) params.append('all', searchParams.all);
      if (searchParams.anime) params.append('anime', searchParams.anime);
      if (searchParams.character) params.append('character', searchParams.character);
      if (searchParams.voiceActor) params.append('voiceActor', searchParams.voiceActor);
      if (searchParams.hashtag) params.append('hashtag', searchParams.hashtag);
      
      const response = await axios.get(`/api/users/search?${params}`);
      // Deduplicate users by ID, keeping the most recent one
      const usersMap = new Map();
      response.data.forEach(user => {
        if (!usersMap.has(user.id) || 
            (user.updatedAt && (!usersMap.get(user.id).updatedAt || 
             new Date(user.updatedAt) > new Date(usersMap.get(user.id).updatedAt)))) {
          usersMap.set(user.id, user);
        }
      });
      setUsers(Array.from(usersMap.values()));
    } catch (error) {
      console.error('Error searching users:', error);
    }
    setLoading(false);
  };

  const handleInputChange = (e) => {
    const { name, value } = e.target;
    setSearchParams(prev => ({
      ...prev,
      [name]: value
    }));
  };

  const formatDate = (timestamp) => {
    if (!timestamp) return '-';
    const date = timestamp.toDate ? timestamp.toDate() : new Date(timestamp);
    return date.toLocaleDateString('ja-JP');
  };

  return (
    <div className="users-page">
      <h2>ユーザー管理</h2>
      
      <div className="search-container">
        <h3>ユーザー検索</h3>
        <form onSubmit={handleSearch} className="search-form">
          <input
            type="text"
            name="all"
            placeholder="全てで検索（ユーザー名、キャラクター、アニメ、声優、ハッシュタグ）"
            value={searchParams.all}
            onChange={handleInputChange}
          />
          <input
            type="text"
            name="anime"
            placeholder="アニメ名で検索"
            value={searchParams.anime}
            onChange={handleInputChange}
          />
          <input
            type="text"
            name="character"
            placeholder="キャラクター名で検索"
            value={searchParams.character}
            onChange={handleInputChange}
          />
          <input
            type="text"
            name="voiceActor"
            placeholder="声優名で検索"
            value={searchParams.voiceActor}
            onChange={handleInputChange}
          />
          <input
            type="text"
            name="hashtag"
            placeholder="ハッシュタグで検索"
            value={searchParams.hashtag}
            onChange={handleInputChange}
          />
          <button type="submit" className="btn btn-primary">検索</button>
          <button type="button" className="btn" onClick={() => {
            setSearchParams({ all: '', anime: '', character: '', voiceActor: '', hashtag: '' });
            fetchAllUsers();
          }}>
            リセット
          </button>
        </form>
      </div>

      {loading ? (
        <div>読み込み中...</div>
      ) : (
        <div className="table-container">
          <table>
            <thead>
              <tr>
                <th>ユーザー名</th>
                <th>お気に入りアニメ</th>
                <th>お気に入りキャラクター</th>
                <th>お気に入り声優</th>
                <th>ハッシュタグ</th>
              </tr>
            </thead>
            <tbody>
              {users.map(user => (
                <tr key={user.id}>
                  <td><div className="scroll-x-cell">{user.username || '未設定'}</div></td>
                  <td>
                    <div className="scroll-x-cell">
                      {(user.favoriteAnimes || []).map(anime => (
                        <span key={anime} className="tag">{anime}</span>
                      ))}
                    </div>
                  </td>
                  <td>
                    <div className="scroll-x-cell">
                      {(user.favoriteCharacters || []).map(character => (
                        <span key={character} className="tag">{character}</span>
                      ))}
                    </div>
                  </td>
                  <td>
                    <div className="scroll-x-cell">
                      {(user.favoriteVoiceActors || []).map(voiceActor => (
                        <span key={voiceActor} className="tag">{voiceActor}</span>
                      ))}
                    </div>
                  </td>
                  <td>
                    <div className="scroll-x-cell">
                      {(user.hashtags || []).map(tag => (
                        <span key={tag} className="tag">#{tag}</span>
                      ))}
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          {users.length === 0 && (
            <div style={{ padding: '2rem', textAlign: 'center', color: '#666' }}>
              ユーザーが見つかりませんでした
            </div>
          )}
        </div>
      )}
    </div>
  );
}

export default Users;