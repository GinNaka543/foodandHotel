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
  List,
  ListItem,
  ListItemText,
  ListItemAvatar,
  Avatar,
  TextField,
  Chip,
  Box,
  Alert,
  IconButton,
  Input
} from '@mui/material';
import {
  Add as AddIcon,
  Delete as DeleteIcon,
  Search as SearchIcon,
  Star as StarIcon,
  Upload as UploadIcon,
  Image as ImageIcon
} from '@mui/icons-material';

const CharacterRanking = () => {
  const [rankings, setRankings] = useState([]);
  const [characters, setCharacters] = useState([]);
  const [open, setOpen] = useState(false);
  const [selectedRank, setSelectedRank] = useState(1);
  const [searchTerm, setSearchTerm] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  const [selectedImage, setSelectedImage] = useState(null);
  const [imagePreview, setImagePreview] = useState(null);

  useEffect(() => {
    fetchRankings();
    fetchCharacters();
  }, []);

  const fetchRankings = async () => {
    try {
      const response = await fetch('/api/character-rankings');
      if (response.ok) {
        const data = await response.json();
        setRankings(data);
      }
    } catch (error) {
      console.error('ランキング取得エラー:', error);
    }
  };

  const fetchCharacters = async () => {
    try {
      const response = await fetch('/api/characters');
      if (response.ok) {
        const data = await response.json();
        setCharacters(data);
      }
    } catch (error) {
      console.error('キャラクター取得エラー:', error);
    }
  };

  const handleSetRanking = async (characterId, rank) => {
    setLoading(true);
    try {
      const character = characters.find(c => c.id === characterId);
      
      // 画像ファイルがある場合はBase64に変換
      let imageFile = null;
      if (selectedImage) {
        const reader = new FileReader();
        const base64Promise = new Promise((resolve, reject) => {
          reader.onload = () => resolve(reader.result.split(',')[1]); // Base64データのみ
          reader.onerror = reject;
        });
        reader.readAsDataURL(selectedImage);
        
        try {
          const base64Data = await base64Promise;
          imageFile = {
            data: base64Data,
            name: selectedImage.name,
            size: selectedImage.size,
            type: selectedImage.type
          };
        } catch (error) {
          console.error('画像の読み込みに失敗しました:', error);
          setError('画像の読み込みに失敗しました');
          setLoading(false);
          return;
        }
      }
      
      const response = await fetch('/api/character-rankings', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          characterId,
          rank,
          characterName: character.name,
          characterImagePath: character.imageIdentifier,
          imageFile: imageFile
        })
      });

      if (response.ok) {
        setSuccess(`${rank}位にキャラクターを設定しました`);
        fetchRankings();
        setOpen(false);
        setSelectedImage(null);
        setImagePreview(null);
      } else {
        setError('ランキング設定に失敗しました');
      }
    } catch (error) {
      setError('エラーが発生しました');
    }
    setLoading(false);
  };

  const handleRemoveRanking = async (rank) => {
    setLoading(true);
    try {
      const response = await fetch(`/api/character-rankings/${rank}`, {
        method: 'DELETE'
      });

      if (response.ok) {
        setSuccess(`${rank}位のランキングを削除しました`);
        fetchRankings();
      } else {
        setError('ランキング削除に失敗しました');
      }
    } catch (error) {
      setError('エラーが発生しました');
    }
    setLoading(false);
  };

  const filteredCharacters = characters.filter(character =>
    character.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
    character.tag.toLowerCase().includes(searchTerm.toLowerCase())
  );

  const getRankColor = (rank) => {
    switch (rank) {
      case 1: return '#FFD700'; // Gold
      case 2: return '#C0C0C0'; // Silver
      case 3: return '#CD7F32'; // Bronze
      default: return '#1976d2'; // Blue
    }
  };

  const getRankingForPosition = (rank) => {
    return rankings.find(r => r.rank === rank);
  };

  const handleImageSelect = (event) => {
    const file = event.target.files[0];
    if (file) {
      setSelectedImage(file);
      
      // プレビュー用のURLを作成
      const reader = new FileReader();
      reader.onload = (e) => {
        setImagePreview(e.target.result);
      };
      reader.readAsDataURL(file);
    }
  };

  const handleDialogClose = () => {
    setOpen(false);
    setSelectedImage(null);
    setImagePreview(null);
  };

  return (
    <div style={{ padding: '20px' }}>
      <Typography variant="h4" gutterBottom>
        人気キャラランキング管理
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

      <Grid container spacing={3}>
        {[1, 2, 3, 4, 5, 6, 7].map(rank => {
          const ranking = getRankingForPosition(rank);
          return (
            <Grid item xs={12} md={6} lg={4} key={rank}>
              <Card style={{ minHeight: '200px' }}>
                <CardContent>
                  <Box display="flex" alignItems="center" marginBottom={2}>
                    <Chip
                      icon={<StarIcon />}
                      label={`${rank}位`}
                      style={{
                        backgroundColor: getRankColor(rank),
                        color: 'white',
                        fontWeight: 'bold'
                      }}
                    />
                  </Box>

                  {ranking ? (
                    <Box>
                      <Box display="flex" alignItems="center" marginBottom={2}>
                        <Avatar
                          src={ranking.characterImagePath}
                          style={{ width: 60, height: 60, marginRight: 16 }}
                        >
                          {ranking.characterName.charAt(0)}
                        </Avatar>
                        <Box>
                          <Typography variant="h6">
                            {ranking.characterName}
                          </Typography>
                          <Typography variant="body2" color="textSecondary">
                            {rank}位
                          </Typography>
                        </Box>
                      </Box>
                      <Box display="flex" gap={1}>
                        <Button
                          variant="outlined"
                          size="small"
                          onClick={() => {
                            setSelectedRank(rank);
                            setOpen(true);
                          }}
                        >
                          変更
                        </Button>
                        <IconButton
                          size="small"
                          color="error"
                          onClick={() => handleRemoveRanking(rank)}
                          disabled={loading}
                        >
                          <DeleteIcon />
                        </IconButton>
                      </Box>
                    </Box>
                  ) : (
                    <Box textAlign="center" py={4}>
                      <Typography variant="body2" color="textSecondary" gutterBottom>
                        キャラクターが設定されていません
                      </Typography>
                      <Button
                        variant="contained"
                        startIcon={<AddIcon />}
                        onClick={() => {
                          setSelectedRank(rank);
                          setOpen(true);
                        }}
                        disabled={loading}
                      >
                        キャラクターを設定
                      </Button>
                    </Box>
                  )}
                </CardContent>
              </Card>
            </Grid>
          );
        })}
      </Grid>

      {/* キャラクター選択ダイアログ */}
      <Dialog open={open} onClose={handleDialogClose} maxWidth="md" fullWidth>
        <DialogTitle>
          {selectedRank}位のキャラクターを選択
        </DialogTitle>
        <DialogContent>
          <Box marginBottom={2}>
            <Typography variant="h6" gutterBottom>
              カスタム画像をアップロード（オプション）
            </Typography>
            <Box display="flex" alignItems="center" gap={2}>
              <Input
                type="file"
                accept="image/*"
                onChange={handleImageSelect}
                style={{ display: 'none' }}
                id="image-upload"
              />
              <label htmlFor="image-upload">
                <Button
                  variant="outlined"
                  component="span"
                  startIcon={<UploadIcon />}
                >
                  画像をアップロード
                </Button>
              </label>
              {imagePreview && (
                <Box>
                  <img 
                    src={imagePreview} 
                    alt="プレビュー" 
                    style={{ 
                      width: 80, 
                      height: 80, 
                      objectFit: 'cover', 
                      borderRadius: 8 
                    }} 
                  />
                </Box>
              )}
            </Box>
            <Typography variant="body2" color="textSecondary" style={{ marginTop: 8 }}>
              画像をアップロードしない場合、キャラクターの既存画像が使用されます
            </Typography>
          </Box>
          
          <TextField
            fullWidth
            placeholder="キャラクターを検索..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            InputProps={{
              startAdornment: <SearchIcon style={{ marginRight: 8, color: '#999' }} />
            }}
            style={{ marginBottom: 16 }}
          />
          
          <List style={{ maxHeight: 400, overflow: 'auto' }}>
            {filteredCharacters.map(character => (
              <ListItem
                key={character.id}
                button
                onClick={() => handleSetRanking(character.id, selectedRank)}
                disabled={loading}
              >
                <ListItemAvatar>
                  <Avatar src={character.imageIdentifier}>
                    {character.name.charAt(0)}
                  </Avatar>
                </ListItemAvatar>
                <ListItemText
                  primary={character.name}
                  secondary={`#${character.tag}`}
                />
              </ListItem>
            ))}
          </List>
        </DialogContent>
        <DialogActions>
          <Button onClick={handleDialogClose}>
            キャンセル
          </Button>
        </DialogActions>
      </Dialog>
    </div>
  );
};

export default CharacterRanking;