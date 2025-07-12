import React, { useState, useEffect } from 'react';
import {
  Card,
  CardContent,
  Typography,
  Grid,
  Button,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  TextField,
  Slider,
  Switch,
  FormControlLabel,
  List,
  ListItem,
  ListItemText,
  ListItemAvatar,
  ListItemSecondaryAction,
  Avatar,
  IconButton,
  Box,
  Alert,
  Chip,
  Tabs,
  Tab,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Paper,
  Input
} from '@mui/material';
import {
  Add as AddIcon,
  Delete as DeleteIcon,
  Edit as EditIcon,
  Save as SaveIcon,
  Cancel as CancelIcon,
  Link as LinkIcon,
  Star as StarIcon,
  Search as SearchIcon
} from '@mui/icons-material';

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

// 画像を動的に読み込むコンポーネント
const RankingItemAvatar = ({ item }) => {
  const [imageError, setImageError] = React.useState(false);
  
  // 画像URLを取得して変換（正しいフィールド名を使用）
  const imageUrl = item.customImageURL || item.characterImageURL || item.characterImagePath;
  const convertedUrl = imageUrl ? convertGitHubUrl(imageUrl) : '';
  
  console.log('Avatar for', item.characterName, '- Original URL:', imageUrl);
  console.log('Avatar for', item.characterName, '- Converted URL:', convertedUrl);
  console.log('Full item data:', item);

  // 画像URLが存在し、まだエラーが発生していない場合
  if (convertedUrl && !imageError) {
    return (
      <img
        src={convertedUrl}
        alt={item.characterName}
        style={{ 
          width: 40, 
          height: 40, 
          borderRadius: '50%',
          objectFit: 'cover',
          border: '1px solid #ddd'
        }}
        onError={(e) => {
          console.error('Image failed to load:', e.target.src);
          setImageError(true);
        }}
      />
    );
  }

  // フォールバック表示
  return (
    <Avatar style={{ width: 40, height: 40 }}>
      {item.characterName ? item.characterName.charAt(0) : '?'}
    </Avatar>
  );
};

const CustomRankings = () => {
  const [rankings, setRankings] = useState([]);
  const [openDialog, setOpenDialog] = useState(false);
  const [openItemDialog, setOpenItemDialog] = useState(false);
  const [selectedRanking, setSelectedRanking] = useState(null);
  const [selectedRank, setSelectedRank] = useState(1);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  const [tabValue, setTabValue] = useState(0);
  const [githubImageUrl, setGithubImageUrl] = useState('');
  const [customCharacterName, setCustomCharacterName] = useState('');
  const [imagePreviewUrl, setImagePreviewUrl] = useState('');
  
  // 新規ランキング作成用のstate
  const [newRanking, setNewRanking] = useState({
    title: '',
    displayProbability: 0.5,
    isActive: true,
    imageURL: ''
  });
  const [rankingImagePreviewUrl, setRankingImagePreviewUrl] = useState('');
  
  // ランキング編集用のstate
  const [openEditDialog, setOpenEditDialog] = useState(false);
  const [editingRanking, setEditingRanking] = useState(null);
  const [editRankingImagePreviewUrl, setEditRankingImagePreviewUrl] = useState('');

  useEffect(() => {
    fetchRankings();
  }, []);

  // 画像プレビューURL更新
  useEffect(() => {
    if (!githubImageUrl) {
      setImagePreviewUrl('');
      return;
    }
    // GitHub URLを自動変換してプレビュー
    const convertedUrl = convertGitHubUrl(githubImageUrl);
    setImagePreviewUrl(convertedUrl);
  }, [githubImageUrl]);

  // ランキング画像プレビューURL更新
  useEffect(() => {
    if (!newRanking.imageURL) {
      setRankingImagePreviewUrl('');
      return;
    }
    // GitHub URLを自動変換してプレビュー
    const convertedUrl = convertGitHubUrl(newRanking.imageURL);
    setRankingImagePreviewUrl(convertedUrl);
  }, [newRanking.imageURL]);

  // 編集ランキング画像プレビューURL更新
  useEffect(() => {
    if (!editingRanking?.imageURL) {
      setEditRankingImagePreviewUrl('');
      return;
    }
    // GitHub URLを自動変換してプレビュー
    const convertedUrl = convertGitHubUrl(editingRanking.imageURL);
    setEditRankingImagePreviewUrl(convertedUrl);
  }, [editingRanking?.imageURL]);

  const fetchRankings = async () => {
    try {
      const response = await fetch('/api/custom-rankings');
      if (response.ok) {
        const data = await response.json();
        console.log('Fetched rankings:', data);
        // Log each ranking's items to see the structure
        data.forEach(ranking => {
          console.log(`Ranking "${ranking.title}" items:`, ranking.items);
        });
        setRankings(data);
      }
    } catch (error) {
      console.error('カスタムランキング取得エラー:', error);
    }
  };


  // 新規ランキング作成
  const handleCreateRanking = async () => {
    if (!newRanking.title) {
      setError('タイトルを入力してください');
      return;
    }

    try {
      const response = await fetch('/api/custom-rankings', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(newRanking)
      });

      if (response.ok) {
        setSuccess('ランキングを作成しました');
        setOpenDialog(false);
        setNewRanking({ title: '', displayProbability: 0.5, isActive: true });
        fetchRankings();
      } else {
        setError('ランキング作成に失敗しました');
      }
    } catch (error) {
      setError('エラーが発生しました');
    }
  };

  // ランキング更新
  const handleUpdateRanking = async (rankingId, updates) => {
    try {
      const response = await fetch(`/api/custom-rankings/${rankingId}`, {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(updates)
      });

      if (response.ok) {
        setSuccess('ランキングを更新しました');
        fetchRankings();
      } else {
        setError('ランキング更新に失敗しました');
      }
    } catch (error) {
      setError('エラーが発生しました');
    }
  };

  // ランキング削除
  const handleDeleteRanking = async (rankingId) => {
    if (!window.confirm('このランキングを削除してよろしいですか？')) {
      return;
    }

    try {
      const response = await fetch(`/api/custom-rankings/${rankingId}`, {
        method: 'DELETE'
      });

      if (response.ok) {
        setSuccess('ランキングを削除しました');
        fetchRankings();
      } else {
        setError('ランキング削除に失敗しました');
      }
    } catch (error) {
      setError('エラーが発生しました');
    }
  };

  // ランキング編集保存
  const handleSaveEditRanking = async () => {
    if (!editingRanking?.title.trim()) {
      setError('ランキングタイトルを入力してください');
      return;
    }

    try {
      const response = await fetch(`/api/custom-rankings/${editingRanking.id}`, {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          title: editingRanking.title,
          imageURL: editingRanking.imageURL,
          displayProbability: editingRanking.displayProbability,
          isActive: editingRanking.isActive
        })
      });

      if (response.ok) {
        setSuccess('ランキングを更新しました');
        setOpenEditDialog(false);
        setEditingRanking(null);
        fetchRankings();
      } else {
        setError('ランキング更新に失敗しました');
      }
    } catch (error) {
      setError('エラーが発生しました');
    }
  };

  // ランキングアイテム追加
  const handleAddRankingItem = async () => {
    if (!customCharacterName) {
      setError('キャラクター名を入力してください');
      return;
    }

    if (!githubImageUrl) {
      setError('画像URLを入力してください');
      return;
    }

    // GitHub URLを自動変換
    const convertedUrl = convertGitHubUrl(githubImageUrl);

    try {
      const requestData = {
        rank: selectedRank,
        characterId: null,
        characterName: customCharacterName,
        characterImagePath: null,
        githubImageUrl: convertedUrl
      };
      
      console.log('Sending request data:', requestData);
      
      const response = await fetch(`/api/custom-rankings/${selectedRanking.id}/items`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(requestData)
      });

      if (response.ok) {
        setSuccess(`${selectedRank}位にキャラクターを設定しました`);
        setOpenItemDialog(false);
        setGithubImageUrl('');
        setCustomCharacterName('');
        fetchRankings();
      } else {
        setError('キャラクター設定に失敗しました');
      }
    } catch (error) {
      setError('エラーが発生しました');
    }
  };

  // ランキングアイテム削除
  const handleRemoveRankingItem = async (rankingId, rank) => {
    try {
      const response = await fetch(`/api/custom-rankings/${rankingId}/items/${rank}`, {
        method: 'DELETE'
      });

      if (response.ok) {
        setSuccess(`${rank}位のキャラクターを削除しました`);
        fetchRankings();
      } else {
        setError('キャラクター削除に失敗しました');
      }
    } catch (error) {
      setError('エラーが発生しました');
    }
  };


  const handleItemDialogClose = () => {
    setOpenItemDialog(false);
    setGithubImageUrl('');
    setCustomCharacterName('');
    setImagePreviewUrl('');
  };


  const getRankColor = (rank) => {
    switch (rank) {
      case 1: return '#FFD700';
      case 2: return '#C0C0C0';
      case 3: return '#CD7F32';
      default: return '#1976d2';
    }
  };

  // 表示確率の合計を計算
  const totalProbability = rankings.reduce((sum, r) => sum + (r.isActive ? r.displayProbability : 0), 0);

  return (
    <div style={{ padding: '20px' }}>
      <Typography variant="h4" gutterBottom>
        カスタムランキング管理
      </Typography>

      {error && (
        <Alert severity="error" style={{ marginBottom: '20px' }} onClose={() => setError('')}>
          {error}
        </Alert>
      )}

      {success && (
        <Alert severity="success" style={{ marginBottom: '20px' }} onClose={() => setSuccess('')}>
          {success}
        </Alert>
      )}

      <Box display="flex" justifyContent="space-between" alignItems="center" marginBottom={3}>
        <Typography variant="body2" color="textSecondary">
          アクティブなランキングの表示確率合計: {(totalProbability * 100).toFixed(1)}%
        </Typography>
        <Button
          variant="contained"
          startIcon={<AddIcon />}
          onClick={() => setOpenDialog(true)}
        >
          新規ランキング作成
        </Button>
      </Box>

      <Tabs value={tabValue} onChange={(e, newValue) => setTabValue(newValue)} style={{ marginBottom: 20 }}>
        <Tab label="ランキング一覧" />
        <Tab label="表示確率設定" />
      </Tabs>

      {tabValue === 0 && (
        <Grid container spacing={3}>
          {rankings.map(ranking => (
            <Grid item xs={12} key={ranking.id}>
              <Card>
                <CardContent>
                  <Box display="flex" justifyContent="space-between" alignItems="center" marginBottom={2}>
                    <Box display="flex" alignItems="center" gap={2}>
                      <Typography variant="h6">
                        {ranking.title}
                      </Typography>
                      <Chip
                        label={ranking.isActive ? 'アクティブ' : '非アクティブ'}
                        color={ranking.isActive ? 'success' : 'default'}
                        size="small"
                      />
                      <Chip
                        label={`表示確率: ${(ranking.displayProbability * 100).toFixed(0)}%`}
                        size="small"
                      />
                    </Box>
                    <Box>
                      <IconButton
                        title="ランキングを編集"
                        color="primary"
                        onClick={() => {
                          setEditingRanking({ ...ranking });
                          setOpenEditDialog(true);
                        }}
                      >
                        <EditIcon />
                      </IconButton>
                      <IconButton
                        title="キャラクターを編集"
                        color="secondary"
                        onClick={() => {
                          setSelectedRanking(ranking);
                          setOpenItemDialog(true);
                          setSelectedRank(1);
                        }}
                      >
                        <StarIcon />
                      </IconButton>
                      <IconButton
                        color="error"
                        onClick={() => handleDeleteRanking(ranking.id)}
                      >
                        <DeleteIcon />
                      </IconButton>
                    </Box>
                  </Box>

                  {/* ランキングアイテム表示 */}
                  <Grid container spacing={2}>
                    {[1, 2, 3, 4, 5, 6, 7].map(rank => {
                      const item = ranking.items?.find(i => i.rank === rank);
                      return (
                        <Grid item xs={12} sm={6} md={4} lg={3} key={rank}>
                          <Box
                            border={1}
                            borderColor="divider"
                            borderRadius={2}
                            padding={2}
                            minHeight={120}
                          >
                            <Box display="flex" alignItems="center" marginBottom={1}>
                              <Chip
                                icon={<StarIcon />}
                                label={`${rank}位`}
                                size="small"
                                style={{
                                  backgroundColor: getRankColor(rank),
                                  color: 'white'
                                }}
                              />
                            </Box>
                            {item ? (
                              <Box>
                                <Box display="flex" alignItems="center" gap={1}>
                                  <RankingItemAvatar item={item} />
                                  <Typography variant="body2">
                                    {item.characterName}
                                  </Typography>
                                </Box>
                                <Box marginTop={1}>
                                  <IconButton
                                    size="small"
                                    color="error"
                                    onClick={() => handleRemoveRankingItem(ranking.id, rank)}
                                  >
                                    <DeleteIcon fontSize="small" />
                                  </IconButton>
                                </Box>
                              </Box>
                            ) : (
                              <Box textAlign="center">
                                <Button
                                  size="small"
                                  onClick={() => {
                                    setSelectedRanking(ranking);
                                    setSelectedRank(rank);
                                    setOpenItemDialog(true);
                                  }}
                                >
                                  設定
                                </Button>
                              </Box>
                            )}
                          </Box>
                        </Grid>
                      );
                    })}
                  </Grid>
                </CardContent>
              </Card>
            </Grid>
          ))}
        </Grid>
      )}

      {tabValue === 1 && (
        <TableContainer component={Paper}>
          <Table>
            <TableHead>
              <TableRow>
                <TableCell>ランキング名</TableCell>
                <TableCell align="center">ステータス</TableCell>
                <TableCell align="center">表示確率</TableCell>
                <TableCell align="center">実際の確率</TableCell>
                <TableCell align="center">操作</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {rankings.map(ranking => (
                <TableRow key={ranking.id}>
                  <TableCell>{ranking.title}</TableCell>
                  <TableCell align="center">
                    <Switch
                      checked={ranking.isActive}
                      onChange={(e) => handleUpdateRanking(ranking.id, { isActive: e.target.checked })}
                    />
                  </TableCell>
                  <TableCell align="center" style={{ width: 300 }}>
                    <Box display="flex" alignItems="center" gap={2}>
                      <Slider
                        value={ranking.displayProbability}
                        onChange={(e, value) => handleUpdateRanking(ranking.id, { displayProbability: value })}
                        min={0}
                        max={1}
                        step={0.05}
                        valueLabelDisplay="auto"
                        valueLabelFormat={(value) => `${(value * 100).toFixed(0)}%`}
                        disabled={!ranking.isActive}
                      />
                      <Typography variant="body2" style={{ minWidth: 50 }}>
                        {(ranking.displayProbability * 100).toFixed(0)}%
                      </Typography>
                    </Box>
                  </TableCell>
                  <TableCell align="center">
                    {ranking.isActive && totalProbability > 0 
                      ? `${((ranking.displayProbability / totalProbability) * 100).toFixed(1)}%`
                      : '-'
                    }
                  </TableCell>
                  <TableCell align="center">
                    <Box display="flex" gap={1} justifyContent="center">
                      <IconButton
                        size="small"
                        color="primary"
                        onClick={() => {
                          setEditingRanking({ ...ranking });
                          setOpenEditDialog(true);
                        }}
                      >
                        <EditIcon />
                      </IconButton>
                      <IconButton
                        size="small"
                        onClick={() => {
                          const newProbability = 1 / rankings.filter(r => r.isActive).length;
                          rankings.filter(r => r.isActive).forEach(r => {
                            handleUpdateRanking(r.id, { displayProbability: newProbability });
                          });
                        }}
                      >
                        <SaveIcon />
                      </IconButton>
                    </Box>
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </TableContainer>
      )}

      {/* 新規ランキング作成ダイアログ */}
      <Dialog open={openDialog} onClose={() => setOpenDialog(false)} maxWidth="sm" fullWidth>
        <DialogTitle>新規ランキング作成</DialogTitle>
        <DialogContent>
          <TextField
            autoFocus
            margin="dense"
            label="ランキングタイトル"
            fullWidth
            value={newRanking.title}
            onChange={(e) => setNewRanking({ ...newRanking, title: e.target.value })}
            placeholder="例: 鬼滅の刃人気キャラランキング"
            style={{ marginBottom: 20 }}
          />
          
          <TextField
            margin="dense"
            label="ランキング画像URL（GitHub）"
            fullWidth
            value={newRanking.imageURL}
            onChange={(e) => setNewRanking({ ...newRanking, imageURL: e.target.value })}
            placeholder="GitHub blob URLを入力（自動でraw URLに変換されます）"
            style={{ marginBottom: 10 }}
          />
          
          {newRanking.imageURL && (
            <Button
              variant="outlined"
              onClick={() => setNewRanking({ ...newRanking, imageURL: convertGitHubUrl(newRanking.imageURL) })}
              style={{ marginBottom: 10 }}
            >
              GitHubリンクを修正
            </Button>
          )}
          
          {rankingImagePreviewUrl && (
            <Box sx={{ textAlign: 'center', marginBottom: 2 }}>
              <Typography variant="body2" gutterBottom>ランキング画像プレビュー:</Typography>
              <img 
                src={rankingImagePreviewUrl} 
                alt="ランキング画像プレビュー" 
                style={{ 
                  maxWidth: '200px', 
                  maxHeight: '200px', 
                  objectFit: 'cover',
                  border: '2px solid #ddd',
                  borderRadius: '8px'
                }}
              />
            </Box>
          )}
          
          <Typography gutterBottom>
            表示確率: {(newRanking.displayProbability * 100).toFixed(0)}%
          </Typography>
          <Slider
            value={newRanking.displayProbability}
            onChange={(e, value) => setNewRanking({ ...newRanking, displayProbability: value })}
            min={0}
            max={1}
            step={0.05}
            valueLabelDisplay="auto"
            valueLabelFormat={(value) => `${(value * 100).toFixed(0)}%`}
          />
          
          <FormControlLabel
            control={
              <Switch
                checked={newRanking.isActive}
                onChange={(e) => setNewRanking({ ...newRanking, isActive: e.target.checked })}
              />
            }
            label="アクティブにする"
          />
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setOpenDialog(false)}>キャンセル</Button>
          <Button onClick={handleCreateRanking} variant="contained">作成</Button>
        </DialogActions>
      </Dialog>

      {/* ランキング編集ダイアログ */}
      <Dialog open={openEditDialog} onClose={() => setOpenEditDialog(false)} maxWidth="sm" fullWidth>
        <DialogTitle>ランキング編集</DialogTitle>
        <DialogContent>
          <TextField
            autoFocus
            margin="dense"
            label="ランキングタイトル"
            fullWidth
            value={editingRanking?.title || ''}
            onChange={(e) => setEditingRanking({ ...editingRanking, title: e.target.value })}
            placeholder="例: 鬼滅の刃人気キャラランキング"
            style={{ marginBottom: 20 }}
          />
          
          <TextField
            margin="dense"
            label="ランキング画像URL（GitHub）"
            fullWidth
            value={editingRanking?.imageURL || ''}
            onChange={(e) => setEditingRanking({ ...editingRanking, imageURL: e.target.value })}
            placeholder="GitHub blob URLを入力（自動でraw URLに変換されます）"
            style={{ marginBottom: 10 }}
          />
          
          {editingRanking?.imageURL && (
            <Button
              variant="outlined"
              onClick={() => setEditingRanking({ ...editingRanking, imageURL: convertGitHubUrl(editingRanking.imageURL) })}
              style={{ marginBottom: 10 }}
            >
              GitHubリンクを修正
            </Button>
          )}
          
          {editRankingImagePreviewUrl && (
            <Box sx={{ textAlign: 'center', marginBottom: 2 }}>
              <Typography variant="body2" gutterBottom>ランキング画像プレビュー:</Typography>
              <img 
                src={editRankingImagePreviewUrl} 
                alt="ランキング画像プレビュー" 
                style={{ 
                  maxWidth: '200px', 
                  maxHeight: '200px', 
                  objectFit: 'cover',
                  border: '2px solid #ddd',
                  borderRadius: '8px'
                }}
              />
            </Box>
          )}
          
          <Typography gutterBottom>
            表示確率: {((editingRanking?.displayProbability || 0) * 100).toFixed(0)}%
          </Typography>
          <Slider
            value={editingRanking?.displayProbability || 0}
            onChange={(e, value) => setEditingRanking({ ...editingRanking, displayProbability: value })}
            min={0}
            max={1}
            step={0.05}
            valueLabelDisplay="auto"
            valueLabelFormat={(value) => `${(value * 100).toFixed(0)}%`}
          />
          
          <FormControlLabel
            control={
              <Switch
                checked={editingRanking?.isActive || false}
                onChange={(e) => setEditingRanking({ ...editingRanking, isActive: e.target.checked })}
              />
            }
            label="アクティブにする"
          />
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setOpenEditDialog(false)}>キャンセル</Button>
          <Button onClick={handleSaveEditRanking} variant="contained">保存</Button>
        </DialogActions>
      </Dialog>

      {/* キャラクター選択ダイアログ */}
      <Dialog open={openItemDialog} onClose={handleItemDialogClose} maxWidth="md" fullWidth>
        <DialogTitle>
          {selectedRanking?.title} - {selectedRank}位のキャラクター設定
        </DialogTitle>
        <DialogContent>
          <Box marginBottom={3}>
            <Typography variant="h6" gutterBottom>
              キャラクター名
            </Typography>
            <TextField
              fullWidth
              placeholder="キャラクター名を入力..."
              value={customCharacterName}
              onChange={(e) => setCustomCharacterName(e.target.value)}
              style={{ marginBottom: 20 }}
            />
          </Box>

          <Box marginBottom={2}>
            <Typography variant="h6" gutterBottom>
              画像URL（必須）
            </Typography>
            <Box display="flex" alignItems="flex-start" gap={1}>
              <TextField
                fullWidth
                placeholder="https://github.com/... または https://raw.githubusercontent.com/..."
                value={githubImageUrl}
                onChange={(e) => setGithubImageUrl(e.target.value)}
                InputProps={{
                  startAdornment: <LinkIcon style={{ marginRight: 8, color: '#999' }} />
                }}
                helperText="GitHubの画像URLを入力してください"
              />
              <Button
                variant="outlined"
                onClick={() => {
                  const convertedUrl = convertGitHubUrl(githubImageUrl);
                  if (convertedUrl !== githubImageUrl) {
                    setGithubImageUrl(convertedUrl);
                    alert('GitHub URLをraw URLに変換しました');
                  }
                }}
                disabled={!githubImageUrl.includes('github.com') || !githubImageUrl.includes('/blob/')}
                style={{ minWidth: 120 }}
              >
                GitHub URL修正
              </Button>
            </Box>
            {imagePreviewUrl && (
              <Box marginTop={2}>
                <Typography variant="body2" color="textSecondary" gutterBottom>
                  プレビュー:
                </Typography>
                <img 
                  src={imagePreviewUrl} 
                  alt="プレビュー" 
                  style={{ 
                    maxWidth: 200,
                    maxHeight: 200,
                    objectFit: 'contain',
                    borderRadius: 8,
                    border: '1px solid #ddd'
                  }} 
                  onError={(e) => {
                    e.target.style.display = 'none';
                  }}
                />
              </Box>
            )}
          </Box>
        </DialogContent>
        <DialogActions>
          <Button onClick={handleItemDialogClose}>キャンセル</Button>
          <Button onClick={handleAddRankingItem} variant="contained">
            設定
          </Button>
        </DialogActions>
      </Dialog>
    </div>
  );
};

export default CustomRankings;