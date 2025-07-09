import React, { useState, useEffect } from 'react';
import axios from 'axios';
import { useNavigate, useLocation } from 'react-router-dom';

const PLACEMENT_OPTIONS = [
  { key: 'home', label: 'ホーム', icon: '🏠' },
  { key: 'character', label: 'キャラ', icon: '👤' },
  { key: 'product', label: 'プロダクト', icon: '📦' },
];

// ImgurページURL→画像直リンク変換関数
function convertImgurUrl(url) {
  if (!url) return '';
  try {
    const u = new URL(url);
    if (u.hostname === 'imgur.com' || u.hostname === 'www.imgur.com') {
      // /a/ や /gallery/ を除去
      const parts = u.pathname.split('/').filter(Boolean);
      let id = parts[0];
      if ((id === 'a' || id === 'gallery') && parts[1]) id = parts[1];
      if (id) return `https://i.imgur.com/${id}.png`;
    }
  } catch (e) {}
  return url;
}

// GitHub blob URL→raw URL変換関数
function convertGitHubUrl(url) {
  if (!url) return '';
  // GitHubのblobページURLパターン: https://github.com/user/repo/blob/branch/path
  // これをraw URLに変換: https://raw.githubusercontent.com/user/repo/branch/path
  if (url.includes('github.com') && url.includes('/blob/')) {
    return url
      .replace('github.com', 'raw.githubusercontent.com')
      .replace('/blob/', '/');
  }
  return url;
}

function CreateAd() {
  const navigate = useNavigate();
  const location = useLocation();
  const params = new URLSearchParams(location.search);
  const editId = params.get('id');
  const generalPage = params.get('generalPage'); // 'home' | 'character' | 'product' or null
  const [formData, setFormData] = useState({
    title: '',
    description: '',
    imageURL: '',
    linkURL: '',
    targetAnimes: [],
    targetCharacters: [],
    targetHashtags: [],
    expiresAt: '',
    placements: generalPage ? [generalPage] : []
  });
  
  const [inputValues, setInputValues] = useState({
    anime: '',
    character: '',
    hashtag: ''
  });

  const [imagePreviewUrl, setImagePreviewUrl] = useState('');

  useEffect(() => {
    if (editId) {
      // 編集モード: 既存データ取得
      axios.get(`/api/advertisements`).then(res => {
        const ad = res.data.find(a => a.id === editId);
        if (ad) {
          setFormData({
            ...ad,
            placements: Array.isArray(ad.placements) ? ad.placements : [],
            expiresAt: (ad.expiresAt && !isNaN(new Date(ad.expiresAt)))
              ? new Date(ad.expiresAt).toISOString().slice(0, 16)
              : ''
          });
        }
      });
    } else if (generalPage) {
      setFormData(prev => ({ ...prev, placements: [generalPage] }));
    }
  }, [editId, generalPage]);

  useEffect(() => {
    async function fetchPreview() {
      if (!formData.imageURL) {
        setImagePreviewUrl('');
        return;
      }
      // URLがimgur.comや他のページURLの場合はAPIで画像抽出
      try {
        const url = formData.imageURL.trim();
        if (/^https?:\/\//.test(url) && !url.match(/\.(jpg|jpeg|png|gif|webp)$/i)) {
          const res = await axios.get(`/api/extract-image?url=${encodeURIComponent(url)}`);
          if (res.data && res.data.imageUrl) {
            setImagePreviewUrl(res.data.imageUrl);
            return;
          }
        }
        setImagePreviewUrl(url);
      } catch {
        setImagePreviewUrl(formData.imageURL);
      }
    }
    fetchPreview();
  }, [formData.imageURL]);

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
    
    // 配置場所の必須チェック
    if (formData.placements.length === 0) {
      alert('配置場所を少なくとも1つ選択してください');
      return;
    }
    
    const updatedFormData = { ...formData };
    // Imgur URLとGitHub URLの両方を変換
    updatedFormData.imageURL = convertGitHubUrl(convertImgurUrl(updatedFormData.imageURL));
    if (inputValues.anime.trim() && !updatedFormData.targetAnimes.includes(inputValues.anime.trim())) {
      updatedFormData.targetAnimes = [...updatedFormData.targetAnimes, inputValues.anime.trim()];
    }
    if (inputValues.character.trim() && !updatedFormData.targetCharacters.includes(inputValues.character.trim())) {
      updatedFormData.targetCharacters = [...updatedFormData.targetCharacters, inputValues.character.trim()];
    }
    if (inputValues.hashtag.trim() && !updatedFormData.targetHashtags.includes(inputValues.hashtag.trim())) {
      updatedFormData.targetHashtags = [...updatedFormData.targetHashtags, inputValues.hashtag.trim()];
    }
    
    try {
      if (editId) {
        await axios.put(`/api/advertisements/${editId}`, updatedFormData);
        alert('広告が正常に更新されました！');
      } else {
        await axios.post('/api/advertisements', updatedFormData);
        alert('広告が正常に作成されました！');
      }
      navigate('/advertisements');
    } catch (error) {
      console.error('Error creating/updating advertisement:', error);
      alert('広告の作成/更新に失敗しました。');
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
            <div style={{ display: 'flex', gap: '0.5rem', alignItems: 'center' }}>
              <input
                type="url"
                name="imageURL"
                value={formData.imageURL}
                onChange={handleChange}
                placeholder="https://example.com/image.jpg"
                required
                style={{ flex: 1 }}
              />
              <button
                type="button"
                className="btn btn-secondary"
                onClick={() => {
                  const convertedUrl = convertGitHubUrl(formData.imageURL);
                  if (convertedUrl !== formData.imageURL) {
                    setFormData(prev => ({ ...prev, imageURL: convertedUrl }));
                    alert('GitHub URLをraw URLに変換しました');
                  }
                }}
                disabled={!formData.imageURL.includes('github.com') || !formData.imageURL.includes('/blob/')}
                style={{ fontSize: '0.875rem', padding: '0.5rem 1rem' }}
              >
                GitHub URL修正
              </button>
            </div>
          </div>

          {/* 画像プレビュー部分で変換を適用 */}
          {formData.imageURL && (
            <div style={{ margin: '1rem 0' }}>
              <label>画像プレビュー</label>
              <div style={{ border: '1px solid #eee', borderRadius: 8, padding: 8, display: 'inline-block' }}>
                <img src={imagePreviewUrl} alt="ad preview" style={{ maxWidth: 200, maxHeight: 120 }} />
              </div>
            </div>
          )}

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

          {/* ターゲット入力欄（一般広告の場合は非表示） */}
          {!generalPage && (
            <>
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
            </>
          )}

          {/* 配置場所選択 */}
          <div className="form-group">
            <label>配置場所（複数選択可）<span style={{ color: 'red' }}>*</span></label>
            <div style={{ display: 'flex', gap: '1rem', marginBottom: '0.5rem' }}>
              {PLACEMENT_OPTIONS.map(opt => (
                <button
                  type="button"
                  key={opt.key}
                  onClick={() => {
                    if (generalPage && opt.key !== generalPage) return; // 一般広告時は他のページは選択不可
                    const newPlacements = formData.placements.includes(opt.key)
                      ? formData.placements.filter(p => p !== opt.key)
                      : [...formData.placements, opt.key];
                    setFormData(prev => ({ ...prev, placements: newPlacements }));
                  }}
                  style={{
                    padding: '0.5rem 1rem',
                    border: formData.placements.includes(opt.key) ? '2px solid #007bff' : '1px solid #ddd',
                    borderRadius: '8px',
                    backgroundColor: formData.placements.includes(opt.key) ? '#e3f2fd' : 'white',
                    cursor: generalPage && opt.key !== generalPage ? 'not-allowed' : 'pointer',
                    opacity: generalPage && opt.key !== generalPage ? 0.4 : 1,
                    display: 'flex',
                    alignItems: 'center',
                    gap: '0.5rem',
                    fontSize: '0.875rem'
                  }}
                  disabled={generalPage && opt.key !== generalPage}
                >
                  <span>{opt.icon}</span>
                  {opt.label}
                </button>
              ))}
            </div>
            {formData.placements.length === 0 && (
              <div style={{ color: 'red', fontSize: '0.875rem', marginTop: '0.25rem' }}>
                配置場所を少なくとも1つ選択してください
              </div>
            )}
            {generalPage && (
              <div style={{ color: '#666', fontSize: '0.875rem', marginTop: '0.25rem' }}>
                ※ このページ専用の一般広告として作成されます
              </div>
            )}
            {!generalPage && (
              <div style={{ color: '#666', fontSize: '0.875rem', marginTop: '0.25rem' }}>
                ※ ターゲット指定なしで保存すると一般広告（全ユーザー向け）として作成されます
              </div>
            )}
          </div>

          {/* ターゲット指定なしの場合の案内 */}
          <div style={{ margin: '1rem 0', padding: '0.75rem', background: '#f8fafc', borderRadius: '6px', color: '#333', fontSize: '0.97rem' }}>
            <b>「ターゲットアニメ」「ターゲットキャラクター」「ターゲットタグ」を全て空欄にすると、この広告は「一般広告（全ユーザー向け）」として作成されます。</b>
            {generalPage && <div style={{ marginTop: 4 }}>※この広告は「{PLACEMENT_OPTIONS.find(opt => opt.key === generalPage)?.label}ページ」専用の一般広告です。</div>}
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