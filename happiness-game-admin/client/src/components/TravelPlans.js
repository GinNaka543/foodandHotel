import React, { useState, useEffect } from 'react';
import './TravelPlans.css';

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

const TravelPlans = () => {
  const [plans, setPlans] = useState([]);
  const [loading, setLoading] = useState(true);
  const [showCreateForm, setShowCreateForm] = useState(false);
  const [editingPlan, setEditingPlan] = useState(null);
  const [formData, setFormData] = useState({
    title: '',
    animeName: '',
    duration: '',
    description: '',
    spots: [],
    price: 0,
    tags: [],
    imageUrl: '',
    thumbnailUrl: '',
    numberOfDays: 1,
    startTime: '09:00'
  });
  const [currentSpot, setCurrentSpot] = useState({
    name: '',
    address: '',
    stayDuration: 60,
    notes: '',
    nearestStation: '',
    imageUrl: '',
    images: [], // 複数の画像をサポート
    timeRange: '',
    activity: '',
    dayNumber: 1,
    spotCost: 0,
    arrivalTime: '',
    departureTime: '',
    transportToNext: {
      method: '電車',
      duration: 30,
      cost: 0,
      route: ''
    }
  });

  useEffect(() => {
    fetchPlans();
  }, []);

  const fetchPlans = async () => {
    try {
      const response = await fetch('http://localhost:5002/api/travel-plans');
      const data = await response.json();
      setPlans(data);
    } catch (error) {
      console.error('旅行プラン取得エラー:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleInputChange = (e) => {
    const { name, value } = e.target;
    setFormData(prev => ({
      ...prev,
      [name]: value
    }));
  };

  const handleSpotChange = (e) => {
    const { name, value } = e.target;
    setCurrentSpot(prev => ({
      ...prev,
      [name]: value
    }));
  };

  const handleTransportChange = (e) => {
    const { name, value } = e.target;
    setCurrentSpot(prev => ({
      ...prev,
      transportToNext: {
        ...prev.transportToNext,
        [name]: value
      }
    }));
  };

  const addSpot = () => {
    if (currentSpot.name && currentSpot.address) {
      setFormData(prev => ({
        ...prev,
        spots: [...prev.spots, { ...currentSpot, id: Date.now() }]
      }));
      setCurrentSpot({
        name: '',
        address: '',
        stayDuration: 60,
        notes: '',
        nearestStation: '',
        imageUrl: '',
        images: [],
        timeRange: '',
        activity: '',
        dayNumber: 1,
        spotCost: 0,
        arrivalTime: '',
        departureTime: '',
        transportToNext: {
          method: '電車',
          duration: 30,
          cost: 0,
          route: ''
        }
      });
    }
  };

  const removeSpot = (spotId) => {
    setFormData(prev => ({
      ...prev,
      spots: prev.spots.filter(spot => spot.id !== spotId)
    }));
  };

  // スポットに画像を追加
  const addImageToSpot = () => {
    const imageUrl = prompt('画像のGitHub URLを入力してください:');
    if (imageUrl) {
      // GitHub URLを自動的に変換
      const convertedUrl = convertGitHubUrl(imageUrl);
      setCurrentSpot(prev => ({
        ...prev,
        images: [...prev.images, convertedUrl]
      }));
    }
  };

  // スポットから画像を削除
  const removeImageFromSpot = (imageIndex) => {
    setCurrentSpot(prev => ({
      ...prev,
      images: prev.images.filter((_, index) => index !== imageIndex)
    }));
  };

  // スポット画像を編集
  const editImageInSpot = (imageIndex) => {
    const currentUrl = currentSpot.images[imageIndex];
    const newUrl = prompt('新しい画像のGitHub URLを入力してください:', currentUrl);
    if (newUrl && newUrl !== currentUrl) {
      // GitHub URLを自動的に変換
      const convertedUrl = convertGitHubUrl(newUrl);
      setCurrentSpot(prev => ({
        ...prev,
        images: prev.images.map((url, index) => 
          index === imageIndex ? convertedUrl : url
        )
      }));
    }
  };

  const startEditPlan = (plan) => {
    setEditingPlan(plan);
    setFormData({
      title: plan.title,
      animeName: plan.animeName,
      duration: plan.duration,
      description: plan.description || '',
      spots: plan.spots || [],
      price: plan.price || 0,
      tags: plan.tags || [],
      imageUrl: plan.imageUrl || '',
      thumbnailUrl: plan.thumbnailUrl || '',
      numberOfDays: plan.numberOfDays || 1,
      startTime: plan.startTime || '09:00'
    });
    setShowCreateForm(true);
  };

  const cancelEdit = () => {
    setEditingPlan(null);
    setShowCreateForm(false);
    setFormData({
      title: '',
      animeName: '',
      duration: '',
      description: '',
      spots: [],
      price: 0,
      tags: [],
      imageUrl: '',
      thumbnailUrl: '',
      numberOfDays: 1,
      startTime: '09:00'
    });
    setCurrentSpot({
      name: '',
      address: '',
      stayDuration: 60,
      notes: '',
      nearestStation: '',
      imageUrl: '',
      images: [],
      timeRange: '',
      activity: '',
      dayNumber: 1,
      spotCost: 0,
      arrivalTime: '',
      departureTime: '',
      transportToNext: {
        method: '電車',
        duration: 30,
        cost: 0,
        route: ''
      }
    });
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    
    // 空のcurrentSpotがある場合、バリデーションエラーを防ぐため
    if (currentSpot.name.trim() !== '' || currentSpot.address.trim() !== '') {
      if (!currentSpot.name.trim() || !currentSpot.address.trim()) {
        alert('未完成のスポットがあります。完成してからプランを作成してください。');
        return;
      }
    }
    
    try {
      // GitHub URLsを変換してからサーバーに送信
      const processedFormData = {
        ...formData,
        imageUrl: convertGitHubUrl(formData.imageUrl),
        thumbnailUrl: convertGitHubUrl(formData.thumbnailUrl),
        spots: formData.spots.map(spot => ({
          ...spot,
          imageUrl: convertGitHubUrl(spot.imageUrl),
          images: spot.images ? spot.images.map(url => convertGitHubUrl(url)) : []
        }))
      };

      const url = editingPlan 
        ? `http://localhost:5002/api/travel-plans/${editingPlan.id}`
        : 'http://localhost:5002/api/travel-plans';
      
      const method = editingPlan ? 'PUT' : 'POST';

      const response = await fetch(url, {
        method: method,
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(processedFormData),
      });

      if (response.ok) {
        alert(editingPlan ? '旅行プランが更新されました！' : '旅行プランが作成されました！');
        cancelEdit();
        fetchPlans();
      } else {
        alert(editingPlan ? '更新に失敗しました' : '作成に失敗しました');
      }
    } catch (error) {
      console.error(editingPlan ? '更新エラー:' : '作成エラー:', error);
      alert('エラーが発生しました');
    }
  };

  const deletePlan = async (planId) => {
    if (window.confirm('このプランを削除しますか？')) {
      try {
        const response = await fetch(`http://localhost:5002/api/travel-plans/${planId}`, {
          method: 'DELETE',
        });

        if (response.ok) {
          alert('プランが削除されました');
          fetchPlans();
        } else {
          alert('削除に失敗しました');
        }
      } catch (error) {
        console.error('削除エラー:', error);
        alert('エラーが発生しました');
      }
    }
  };

  if (loading) {
    return <div className="loading">読み込み中...</div>;
  }

  return (
    <div className="travel-plans-container">
      <div className="travel-plans-header">
        <h2>旅行プラン管理</h2>
        <button 
          className="create-btn"
          onClick={() => setShowCreateForm(true)}
        >
          新しいプラン作成
        </button>
      </div>

      {showCreateForm && (
        <div className="create-form-overlay">
          <div className="create-form">
            <h3>{editingPlan ? '旅行プラン編集' : '新しい旅行プラン作成'}</h3>
            <form onSubmit={handleSubmit}>
              <div className="form-group">
                <label>プラン名:</label>
                <input
                  type="text"
                  name="title"
                  value={formData.title}
                  onChange={handleInputChange}
                  required
                />
              </div>

              <div className="form-group">
                <label>アニメ名:</label>
                <input
                  type="text"
                  name="animeName"
                  value={formData.animeName}
                  onChange={handleInputChange}
                  required
                />
              </div>

              <div className="form-group">
                <label>所要時間:</label>
                <input
                  type="text"
                  name="duration"
                  value={formData.duration}
                  onChange={handleInputChange}
                  placeholder="例: 4時間30分"
                  required
                />
              </div>

              <div className="form-group">
                <label>説明:</label>
                <textarea
                  name="description"
                  value={formData.description}
                  onChange={handleInputChange}
                  rows="3"
                />
              </div>

              <div className="form-group">
                <label>価格 (円):</label>
                <input
                  type="number"
                  name="price"
                  value={formData.price}
                  onChange={handleInputChange}
                  min="0"
                />
              </div>

              <div className="form-group">
                <label>旅行日数:</label>
                <input
                  type="number"
                  name="numberOfDays"
                  value={formData.numberOfDays}
                  onChange={handleInputChange}
                  min="1"
                  max="7"
                />
              </div>

              <div className="form-group">
                <label>開始時間:</label>
                <input
                  type="time"
                  name="startTime"
                  value={formData.startTime}
                  onChange={handleInputChange}
                />
              </div>

              <div className="form-group">
                <label>サムネイル画像URL:</label>
                <div className="url-input-group">
                  <input
                    type="url"
                    name="thumbnailUrl"
                    value={formData.thumbnailUrl}
                    onChange={handleInputChange}
                    placeholder="https://github.com/your-repo/blob/main/image.jpg"
                  />
                  <button 
                    type="button" 
                    className="preview-btn"
                    onClick={() => {
                      const convertedUrl = convertGitHubUrl(formData.thumbnailUrl);
                      setFormData(prev => ({ ...prev, thumbnailUrl: convertedUrl }));
                    }}
                    disabled={!formData.thumbnailUrl.includes('github.com') || !formData.thumbnailUrl.includes('/blob/')}
                  >
                    変換
                  </button>
                </div>
                {formData.thumbnailUrl && formData.thumbnailUrl.includes('raw.githubusercontent.com') && (
                  <img 
                    src={formData.thumbnailUrl} 
                    alt="サムネイルプレビュー" 
                    className="image-preview"
                  />
                )}
              </div>

              <div className="spots-section">
                <h4>スポット追加</h4>
                <div className="spot-form">
                  <input
                    type="text"
                    name="name"
                    value={currentSpot.name}
                    onChange={handleSpotChange}
                    placeholder="スポット名"
                  />
                  <input
                    type="text"
                    name="address"
                    value={currentSpot.address}
                    onChange={handleSpotChange}
                    placeholder="住所"
                  />
                  <input
                    type="number"
                    name="stayDuration"
                    value={currentSpot.stayDuration}
                    onChange={handleSpotChange}
                    placeholder="滞在時間(分)"
                    min="1"
                  />
                  <select
                    name="dayNumber"
                    value={currentSpot.dayNumber}
                    onChange={handleSpotChange}
                  >
                    {Array.from({ length: formData.numberOfDays }, (_, i) => (
                      <option key={i + 1} value={i + 1}>
                        {i + 1}日目
                      </option>
                    ))}
                  </select>
                  <input
                    type="text"
                    name="nearestStation"
                    value={currentSpot.nearestStation}
                    onChange={handleSpotChange}
                    placeholder="最寄り駅"
                  />
                  <input
                    type="text"
                    name="activity"
                    value={currentSpot.activity}
                    onChange={handleSpotChange}
                    placeholder="アクティビティ"
                  />
                  <input
                    type="number"
                    name="spotCost"
                    value={currentSpot.spotCost}
                    onChange={handleSpotChange}
                    placeholder="スポット料金(円)"
                    min="0"
                  />
                  
                  <div className="time-inputs">
                    <input
                      type="time"
                      name="arrivalTime"
                      value={currentSpot.arrivalTime}
                      onChange={handleSpotChange}
                      placeholder="到着時刻"
                    />
                    <input
                      type="time"
                      name="departureTime"
                      value={currentSpot.departureTime}
                      onChange={handleSpotChange}
                      placeholder="出発時刻"
                    />
                  </div>
                  
                  <div className="transport-section">
                    <h5>次のスポットへの移動</h5>
                    <select
                      name="method"
                      value={currentSpot.transportToNext.method}
                      onChange={handleTransportChange}
                    >
                      <option value="電車">電車</option>
                      <option value="バス">バス</option>
                      <option value="徒歩">徒歩</option>
                      <option value="車">車</option>
                      <option value="タクシー">タクシー</option>
                    </select>
                    <input
                      type="number"
                      name="duration"
                      value={currentSpot.transportToNext.duration}
                      onChange={handleTransportChange}
                      placeholder="移動時間(分)"
                      min="0"
                    />
                    <input
                      type="number"
                      name="cost"
                      value={currentSpot.transportToNext.cost}
                      onChange={handleTransportChange}
                      placeholder="交通費(円)"
                      min="0"
                    />
                    <input
                      type="text"
                      name="route"
                      value={currentSpot.transportToNext.route}
                      onChange={handleTransportChange}
                      placeholder="経路情報（例：JR山手線）"
                    />
                  </div>
                  
                  <textarea
                    name="notes"
                    value={currentSpot.notes}
                    onChange={handleSpotChange}
                    placeholder="メモ・説明"
                    rows="2"
                  />
                  <div className="spot-url-input">
                    <input
                      type="url"
                      name="imageUrl"
                      value={currentSpot.imageUrl}
                      onChange={handleSpotChange}
                      placeholder="https://github.com/your-repo/blob/main/image.jpg"
                    />
                    <button 
                      type="button" 
                      className="convert-btn"
                      onClick={() => {
                        const convertedUrl = convertGitHubUrl(currentSpot.imageUrl);
                        setCurrentSpot(prev => ({ ...prev, imageUrl: convertedUrl }));
                      }}
                      disabled={!currentSpot.imageUrl.includes('github.com') || !currentSpot.imageUrl.includes('/blob/')}
                    >
                      変換
                    </button>
                  </div>
                  {currentSpot.imageUrl && currentSpot.imageUrl.includes('raw.githubusercontent.com') && (
                    <div className="spot-image-preview">
                      <img 
                        src={currentSpot.imageUrl} 
                        alt="スポット画像プレビュー" 
                        className="image-preview"
                      />
                    </div>
                  )}
                  
                  {/* 複数画像管理セクション */}
                  <div className="spot-images-section">
                    <h5>追加画像</h5>
                    <button 
                      type="button" 
                      onClick={addImageToSpot}
                      className="add-image-btn"
                    >
                      画像を追加
                    </button>
                    {currentSpot.images.length > 0 && (
                      <div className="spot-images-list">
                        {currentSpot.images.map((imageUrl, index) => (
                          <div key={index} className="spot-image-item">
                            <img 
                              src={imageUrl} 
                              alt={`スポット画像 ${index + 1}`} 
                              className="image-preview-small"
                              onClick={() => editImageInSpot(index)}
                              style={{ cursor: 'pointer' }}
                              title="クリックして編集"
                            />
                            <div className="image-controls">
                              <button 
                                type="button" 
                                onClick={() => editImageInSpot(index)}
                                className="edit-image-btn"
                                title="編集"
                              >
                                ✏️
                              </button>
                              <button 
                                type="button" 
                                onClick={() => removeImageFromSpot(index)}
                                className="remove-image-btn"
                                title="削除"
                              >
                                ×
                              </button>
                            </div>
                          </div>
                        ))}
                      </div>
                    )}
                  </div>
                  
                  <button type="button" onClick={addSpot} className="add-spot-btn">スポット追加</button>
                </div>

                <div className="spots-list">
                  {formData.spots.map((spot, index) => (
                    <div key={spot.id} className="spot-item">
                      <div className="spot-content">
                        <div className="spot-header">
                          <h5>{index + 1}. {spot.name}</h5>
                          <button 
                            type="button" 
                            onClick={() => removeSpot(spot.id)}
                            className="remove-btn"
                          >
                            削除
                          </button>
                        </div>
                        <div className="spot-details">
                          <p><strong>住所:</strong> {spot.address}</p>
                          <p><strong>滞在時間:</strong> {spot.stayDuration}分</p>
                          {spot.nearestStation && <p><strong>最寄り駅:</strong> {spot.nearestStation}</p>}
                          {spot.activity && <p><strong>アクティビティ:</strong> {spot.activity}</p>}
                          {spot.spotCost > 0 && <p><strong>料金:</strong> {spot.spotCost}円</p>}
                          {spot.arrivalTime && <p><strong>到着時刻:</strong> {spot.arrivalTime}</p>}
                          {spot.departureTime && <p><strong>出発時刻:</strong> {spot.departureTime}</p>}
                          {spot.transportToNext && spot.transportToNext.method && (
                            <p><strong>次への移動:</strong> {spot.transportToNext.method} ({spot.transportToNext.duration}分)
                              {spot.transportToNext.route && ` - ${spot.transportToNext.route}`}
                              {spot.transportToNext.cost > 0 && ` - ${spot.transportToNext.cost}円`}
                            </p>
                          )}
                          {spot.notes && <p><strong>メモ:</strong> {spot.notes}</p>}
                        </div>
                        {spot.imageUrl && (
                          <div className="spot-image">
                            <img 
                              src={spot.imageUrl} 
                              alt={spot.name} 
                              className="spot-thumbnail"
                            />
                          </div>
                        )}
                      </div>
                    </div>
                  ))}
                </div>
              </div>

              <div className="form-actions">
                <button type="submit" className="submit-btn">{editingPlan ? '更新' : '作成'}</button>
                <button 
                  type="button" 
                  onClick={cancelEdit}
                  className="cancel-btn"
                >
                  キャンセル
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      <div className="plans-grid">
        {plans.map(plan => (
          <div key={plan.id} className="plan-card">
            <div className="plan-header">
              <h3>{plan.title}</h3>
              <div className="plan-actions">
                <button 
                  className="edit-btn"
                  onClick={() => startEditPlan(plan)}
                >
                  編集
                </button>
                <button 
                  className="delete-btn"
                  onClick={() => deletePlan(plan.id)}
                >
                  削除
                </button>
              </div>
            </div>
            <div className="plan-info">
              <p><strong>アニメ:</strong> {plan.animeName}</p>
              <p><strong>所要時間:</strong> {plan.duration}</p>
              <p><strong>日数:</strong> {plan.numberOfDays || 1}日</p>
              <p><strong>開始時間:</strong> {plan.startTime || '09:00'}</p>
              <p><strong>スポット数:</strong> {plan.spots?.length || 0}</p>
              <p><strong>価格:</strong> {plan.price}円</p>
              <p><strong>作成日:</strong> {new Date(plan.createdAt).toLocaleDateString()}</p>
            </div>
            {plan.thumbnailUrl && (
              <img 
                src={plan.thumbnailUrl} 
                alt={plan.title}
                className="plan-thumbnail"
              />
            )}
          </div>
        ))}
      </div>

      {plans.length === 0 && (
        <div className="no-plans">
          <p>まだ旅行プランがありません。</p>
        </div>
      )}
    </div>
  );
};

export default TravelPlans;