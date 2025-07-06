import React, { useState } from 'react';
import axios from 'axios';
import { useNavigate } from 'react-router-dom';

function CreateAd() {
  const navigate = useNavigate();
  const [formData, setFormData] = useState({
    title: '',
    description: '',
    imageURL: '',
    linkURL: '',
    targetAnimes: [],
    targetCharacters: [],
    targetHashtags: [],
    expiresAt: ''
  });
  
  const [inputValues, setInputValues] = useState({
    anime: '',
    character: '',
    hashtag: ''
  });

  const handleChange = (e) => {
    const { name, value } = e.target;
    setFormData(prev => ({
      ...prev,
      [name]: value
    }));
  };

  const handleInputChange = (e) => {
    const { name, value } = e.target;
    setInputValues(prev => ({
      ...prev,
      [name]: value
    }));
  };

  const addItem = (type) => {
    const value = inputValues[type].trim();
    if (value && !formData[`target${type.charAt(0).toUpperCase() + type.slice(1)}s`].includes(value)) {
      setFormData(prev => ({
        ...prev,
        [`target${type.charAt(0).toUpperCase() + type.slice(1)}s`]: [...prev[`target${type.charAt(0).toUpperCase() + type.slice(1)}s`], value]
      }));
      setInputValues(prev => ({
        ...prev,
        [type]: ''
      }));
    }
  };

  const removeItem = (type, item) => {
    setFormData(prev => ({
      ...prev,
      [`target${type.charAt(0).toUpperCase() + type.slice(1)}s`]: prev[`target${type.charAt(0).toUpperCase() + type.slice(1)}s`].filter(i => i !== item)
    }));
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    
    try {
      await axios.post('/api/advertisements', formData);
      alert('広告が正常に作成されました！');
      navigate('/advertisements');
    } catch (error) {
      console.error('Error creating advertisement:', error);
      alert('広告の作成に失敗しました。');
    }
  };

  return (
    <div className="create-ad-page">
      <h2>広告作成</h2>
      
      <div className="form-container">
        <form onSubmit={handleSubmit}>
          <div className="form-group">
            <label>タイトル *</label>
            <input
              type="text"
              name="title"
              value={formData.title}
              onChange={handleChange}
              required
            />
          </div>

          <div className="form-group">
            <label>説明 *</label>
            <textarea
              name="description"
              value={formData.description}
              onChange={handleChange}
              required
            />
          </div>

          <div className="form-group">
            <label>画像URL *</label>
            <input
              type="url"
              name="imageURL"
              value={formData.imageURL}
              onChange={handleChange}
              placeholder="https://example.com/image.jpg"
              required
            />
          </div>

          <div className="form-group">
            <label>リンクURL *</label>
            <input
              type="url"
              name="linkURL"
              value={formData.linkURL}
              onChange={handleChange}
              placeholder="https://example.com"
              required
            />
          </div>

          <div className="form-group">
            <label>ターゲットアニメ</label>
            <div className="tag-input">
              <input
                type="text"
                name="anime"
                value={inputValues.anime}
                onChange={handleInputChange}
                placeholder="アニメ名を入力"
                onKeyPress={(e) => {
                  if (e.key === 'Enter') {
                    e.preventDefault();
                    addItem('anime');
                  }
                }}
              />
              <button type="button" className="btn btn-primary" onClick={() => addItem('anime')}>
                追加
              </button>
            </div>
            <div className="tag-list">
              {formData.targetAnimes.map(anime => (
                <div key={anime} className="tag-item">
                  {anime}
                  <button type="button" onClick={() => removeItem('anime', anime)}>×</button>
                </div>
              ))}
            </div>
          </div>

          <div className="form-group">
            <label>ターゲットキャラクター</label>
            <div className="tag-input">
              <input
                type="text"
                name="character"
                value={inputValues.character}
                onChange={handleInputChange}
                placeholder="キャラクター名を入力"
                onKeyPress={(e) => {
                  if (e.key === 'Enter') {
                    e.preventDefault();
                    addItem('character');
                  }
                }}
              />
              <button type="button" className="btn btn-primary" onClick={() => addItem('character')}>
                追加
              </button>
            </div>
            <div className="tag-list">
              {formData.targetCharacters.map(character => (
                <div key={character} className="tag-item">
                  {character}
                  <button type="button" onClick={() => removeItem('character', character)}>×</button>
                </div>
              ))}
            </div>
          </div>

          <div className="form-group">
            <label>ターゲットハッシュタグ</label>
            <div className="tag-input">
              <input
                type="text"
                name="hashtag"
                value={inputValues.hashtag}
                onChange={handleInputChange}
                placeholder="ハッシュタグを入力（#なし）"
                onKeyPress={(e) => {
                  if (e.key === 'Enter') {
                    e.preventDefault();
                    addItem('hashtag');
                  }
                }}
              />
              <button type="button" className="btn btn-primary" onClick={() => addItem('hashtag')}>
                追加
              </button>
            </div>
            <div className="tag-list">
              {formData.targetHashtags.map(hashtag => (
                <div key={hashtag} className="tag-item">
                  #{hashtag}
                  <button type="button" onClick={() => removeItem('hashtag', hashtag)}>×</button>
                </div>
              ))}
            </div>
          </div>

          <div className="form-group">
            <label>有効期限</label>
            <input
              type="datetime-local"
              name="expiresAt"
              value={formData.expiresAt}
              onChange={handleChange}
            />
          </div>

          <div style={{ display: 'flex', gap: '1rem', marginTop: '2rem' }}>
            <button type="submit" className="btn btn-primary">
              広告を作成
            </button>
            <button type="button" className="btn" onClick={() => navigate('/advertisements')}>
              キャンセル
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}

export default CreateAd;