import React, { useState, useEffect } from 'react';
import {
  Container,
  Typography,
  Box,
  Paper,
  Button,
  TextField,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  IconButton,
  LinearProgress,
  Chip,
  Alert,
  Card,
  CardContent,
  Grid,
  Divider,
  CircularProgress
} from '@mui/material';
import {
  Add as AddIcon,
  Delete as DeleteIcon,
  Edit as EditIcon,
  Refresh as RefreshIcon,
  CheckCircle as CheckCircleIcon,
  Warning as WarningIcon,
  GitHub as GitHubIcon
} from '@mui/icons-material';
import axios from 'axios';

const GitHubRepositories = () => {
  const [repositories, setRepositories] = useState([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [openDialog, setOpenDialog] = useState(false);
  const [editingRepo, setEditingRepo] = useState(null);
  const [activeRepoId, setActiveRepoId] = useState(null);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  
  // フォームデータ
  const [formData, setFormData] = useState({
    owner: '',
    name: '',
    token: '',
    branch: 'main',
    basePath: 'visit-plans'
  });

  useEffect(() => {
    fetchRepositories();
  }, []);

  const fetchRepositories = async () => {
    try {
      setLoading(true);
      const response = await axios.get('/api/github-repositories');
      setRepositories(response.data.repositories || []);
      setActiveRepoId(response.data.activeRepoId);
    } catch (error) {
      console.error('リポジトリ取得エラー:', error);
      setError('リポジトリ情報の取得に失敗しました');
    } finally {
      setLoading(false);
    }
  };

  const refreshCapacity = async () => {
    try {
      setRefreshing(true);
      const response = await axios.post('/api/github-repositories/refresh-capacity');
      setRepositories(response.data.repositories || []);
      setSuccess('容量情報を更新しました');
    } catch (error) {
      console.error('容量更新エラー:', error);
      setError('容量情報の更新に失敗しました');
    } finally {
      setRefreshing(false);
    }
  };

  const handleSubmit = async () => {
    try {
      if (editingRepo) {
        await axios.put(`/api/github-repositories/${editingRepo.id}`, formData);
        setSuccess('リポジトリを更新しました');
      } else {
        await axios.post('/api/github-repositories', formData);
        setSuccess('リポジトリを追加しました');
      }
      setOpenDialog(false);
      resetForm();
      fetchRepositories();
    } catch (error) {
      console.error('保存エラー:', error);
      setError(error.response?.data?.error || '保存に失敗しました');
    }
  };

  const handleSetActive = async (repoId) => {
    try {
      await axios.post(`/api/github-repositories/${repoId}/activate`);
      setActiveRepoId(repoId);
      setSuccess('アクティブリポジトリを変更しました');
      fetchRepositories();
    } catch (error) {
      console.error('アクティブ化エラー:', error);
      setError('アクティブ化に失敗しました');
    }
  };

  const handleDelete = async (repoId) => {
    if (!window.confirm('このリポジトリを削除しますか？')) return;
    
    try {
      await axios.delete(`/api/github-repositories/${repoId}`);
      setSuccess('リポジトリを削除しました');
      fetchRepositories();
    } catch (error) {
      console.error('削除エラー:', error);
      setError('削除に失敗しました');
    }
  };

  const handleEdit = (repo) => {
    setEditingRepo(repo);
    setFormData({
      owner: repo.owner,
      name: repo.name,
      token: repo.token,
      branch: repo.branch,
      basePath: repo.basePath
    });
    setOpenDialog(true);
  };

  const resetForm = () => {
    setFormData({
      owner: '',
      name: '',
      token: '',
      branch: 'main',
      basePath: 'visit-plans'
    });
    setEditingRepo(null);
  };

  const formatBytes = (bytes) => {
    if (bytes === 0) return '0 Bytes';
    const k = 1024;
    const sizes = ['Bytes', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
  };

  const getUsageColor = (percentage) => {
    if (percentage >= 90) return 'error';
    if (percentage >= 70) return 'warning';
    return 'primary';
  };

  if (loading) {
    return (
      <Box display="flex" justifyContent="center" alignItems="center" minHeight="400px">
        <CircularProgress />
      </Box>
    );
  }

  return (
    <Container maxWidth="lg">
      <Box mb={4}>
        <Typography variant="h4" gutterBottom>
          GitHubリポジトリ管理
        </Typography>
        <Typography variant="body1" color="textSecondary">
          画像保存用のGitHubリポジトリを管理します。各リポジトリの容量は10GBまでです。
        </Typography>
      </Box>

      {error && (
        <Alert severity="error" onClose={() => setError('')} sx={{ mb: 2 }}>
          {error}
        </Alert>
      )}
      
      {success && (
        <Alert severity="success" onClose={() => setSuccess('')} sx={{ mb: 2 }}>
          {success}
        </Alert>
      )}

      <Box mb={3} display="flex" gap={2}>
        <Button
          variant="contained"
          startIcon={<AddIcon />}
          onClick={() => {
            resetForm();
            setOpenDialog(true);
          }}
        >
          新規リポジトリ追加
        </Button>
        <Button
          variant="outlined"
          startIcon={<RefreshIcon />}
          onClick={refreshCapacity}
          disabled={refreshing}
        >
          容量を更新
        </Button>
      </Box>

      <Grid container spacing={3}>
        {repositories.map((repo) => (
          <Grid item xs={12} md={6} key={repo.id}>
            <Card elevation={3}>
              <CardContent>
                <Box display="flex" justifyContent="space-between" alignItems="flex-start" mb={2}>
                  <Box display="flex" alignItems="center" gap={1}>
                    <GitHubIcon />
                    <Typography variant="h6">
                      {repo.owner}/{repo.name}
                    </Typography>
                  </Box>
                  <Box display="flex" gap={1}>
                    {repo.id === activeRepoId ? (
                      <Chip
                        label="アクティブ"
                        color="success"
                        size="small"
                        icon={<CheckCircleIcon />}
                      />
                    ) : (
                      <Button
                        size="small"
                        variant="outlined"
                        onClick={() => handleSetActive(repo.id)}
                      >
                        有効化
                      </Button>
                    )}
                  </Box>
                </Box>

                <Typography variant="body2" color="textSecondary" gutterBottom>
                  ブランチ: {repo.branch} | パス: {repo.basePath}
                </Typography>

                <Divider sx={{ my: 2 }} />

                <Box mb={2}>
                  <Box display="flex" justifyContent="space-between" alignItems="center" mb={1}>
                    <Typography variant="body2">使用容量</Typography>
                    <Typography variant="body2" fontWeight="bold">
                      {formatBytes(repo.currentSize)} / {formatBytes(repo.maxSize)}
                    </Typography>
                  </Box>
                  <LinearProgress
                    variant="determinate"
                    value={repo.usagePercentage || 0}
                    color={getUsageColor(repo.usagePercentage || 0)}
                    sx={{ height: 8, borderRadius: 4 }}
                  />
                  <Box display="flex" justifyContent="space-between" alignItems="center" mt={1}>
                    <Typography variant="caption" color="textSecondary">
                      {repo.imageCount || 0} 枚の画像
                    </Typography>
                    <Typography 
                      variant="caption" 
                      color={repo.usagePercentage >= 90 ? 'error' : 'textSecondary'}
                    >
                      {(repo.usagePercentage || 0).toFixed(1)}% 使用中
                    </Typography>
                  </Box>
                  {repo.usagePercentage >= 90 && (
                    <Box display="flex" alignItems="center" gap={1} mt={1}>
                      <WarningIcon color="warning" fontSize="small" />
                      <Typography variant="caption" color="warning.main">
                        容量が90%を超えています
                      </Typography>
                    </Box>
                  )}
                </Box>

                <Box display="flex" justifyContent="flex-end" gap={1}>
                  <IconButton
                    size="small"
                    onClick={() => handleEdit(repo)}
                    color="primary"
                  >
                    <EditIcon />
                  </IconButton>
                  <IconButton
                    size="small"
                    onClick={() => handleDelete(repo.id)}
                    color="error"
                    disabled={repo.id === activeRepoId}
                  >
                    <DeleteIcon />
                  </IconButton>
                </Box>
              </CardContent>
            </Card>
          </Grid>
        ))}
      </Grid>

      {repositories.length === 0 && (
        <Paper sx={{ p: 4, textAlign: 'center' }}>
          <Typography variant="h6" color="textSecondary" gutterBottom>
            リポジトリが登録されていません
          </Typography>
          <Typography variant="body2" color="textSecondary">
            「新規リポジトリ追加」ボタンからリポジトリを追加してください
          </Typography>
        </Paper>
      )}

      {/* リポジトリ追加/編集ダイアログ */}
      <Dialog open={openDialog} onClose={() => setOpenDialog(false)} maxWidth="sm" fullWidth>
        <DialogTitle>
          {editingRepo ? 'リポジトリを編集' : '新規リポジトリを追加'}
        </DialogTitle>
        <DialogContent>
          <Box py={2}>
            <TextField
              fullWidth
              label="オーナー名"
              value={formData.owner}
              onChange={(e) => setFormData({ ...formData, owner: e.target.value })}
              margin="normal"
              helperText="例: your-username"
            />
            <TextField
              fullWidth
              label="リポジトリ名"
              value={formData.name}
              onChange={(e) => setFormData({ ...formData, name: e.target.value })}
              margin="normal"
              helperText="例: happiness-game-images"
            />
            <TextField
              fullWidth
              label="Personal Access Token"
              type="password"
              value={formData.token}
              onChange={(e) => setFormData({ ...formData, token: e.target.value })}
              margin="normal"
              helperText="repo権限を持つトークンが必要です"
            />
            <TextField
              fullWidth
              label="ブランチ"
              value={formData.branch}
              onChange={(e) => setFormData({ ...formData, branch: e.target.value })}
              margin="normal"
              helperText="例: main"
            />
            <TextField
              fullWidth
              label="ベースパス"
              value={formData.basePath}
              onChange={(e) => setFormData({ ...formData, basePath: e.target.value })}
              margin="normal"
              helperText="画像を保存するディレクトリパス"
            />
          </Box>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setOpenDialog(false)}>キャンセル</Button>
          <Button
            onClick={handleSubmit}
            variant="contained"
            disabled={!formData.owner || !formData.name || !formData.token}
          >
            {editingRepo ? '更新' : '追加'}
          </Button>
        </DialogActions>
      </Dialog>
    </Container>
  );
};

export default GitHubRepositories;