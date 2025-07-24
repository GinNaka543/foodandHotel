// Example server endpoint for YouTube download proxy
// This should be implemented on your backend server (happiness-game.onrender.com)

// POST /api/youtube-download
app.post('/api/youtube-download', async (req, res) => {
  try {
    const { youtubeUrl } = req.body;
    
    if (!youtubeUrl) {
      return res.status(400).json({ error: 'YouTube URL is required' });
    }
    
    // Your RapidAPI key should be stored as an environment variable on the server
    const RAPIDAPI_KEY = process.env.RAPIDAPI_KEY;
    
    const encodedURL = encodeURIComponent(youtubeUrl);
    const apiURL = `https://youtube-info-download-api.p.rapidapi.com/ajax/download.php?format=mp4&add_info=0&url=${encodedURL}&audio_quality=128&allow_extended_duration=false`;
    
    const response = await fetch(apiURL, {
      method: 'GET',
      headers: {
        'x-rapidapi-host': 'youtube-info-download-api.p.rapidapi.com',
        'x-rapidapi-key': RAPIDAPI_KEY
      }
    });
    
    if (!response.ok) {
      throw new Error('Failed to fetch from RapidAPI');
    }
    
    const data = await response.json();
    
    // Return the download link to the iOS app
    res.json(data);
    
  } catch (error) {
    console.error('YouTube download proxy error:', error);
    res.status(500).json({ error: 'Failed to process YouTube download' });
  }
});