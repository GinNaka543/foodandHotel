import React, { useState, useEffect } from 'react';
import axios from 'axios';
import { Chart as ChartJS, CategoryScale, LinearScale, BarElement, Title, Tooltip, Legend } from 'chart.js';
import { Bar } from 'react-chartjs-2';

ChartJS.register(CategoryScale, LinearScale, BarElement, Title, Tooltip, Legend);

function Dashboard() {
  const [statistics, setStatistics] = useState({
    totalUsers: 0,
    totalAds: 0,
    animeStats: {},
    characterStats: {},
    hashtagStats: {}
  });

  useEffect(() => {
    fetchStatistics();
  }, []);

  const fetchStatistics = async () => {
    try {
      const response = await axios.get('/api/statistics');
      setStatistics(response.data);
    } catch (error) {
      console.error('Error fetching statistics:', error);
    }
  };

  const prepareChartData = (data, label, color) => {
    const sorted = Object.entries(data)
      .sort(([, a], [, b]) => b - a)
      .slice(0, 10);

    return {
      labels: sorted.map(([key]) => key),
      datasets: [
        {
          label: label,
          data: sorted.map(([, value]) => value),
          backgroundColor: color,
          borderColor: color,
          borderWidth: 1,
        },
      ],
    };
  };

  const chartOptions = {
    responsive: true,
    plugins: {
      legend: {
        position: 'top',
      },
      title: {
        display: true,
        text: 'トップ10',
      },
    },
    scales: {
      y: {
        beginAtZero: true,
      },
    },
  };

  return (
    <div className="dashboard">
      <h2>ダッシュボード</h2>
      
      <div className="dashboard-grid">
        <div className="stat-card">
          <h3>総ユーザー数</h3>
          <div className="value">{statistics.totalUsers}</div>
        </div>
        
        <div className="stat-card">
          <h3>アクティブ広告数</h3>
          <div className="value">{statistics.totalAds}</div>
        </div>
        
        <div className="stat-card">
          <h3>登録アニメ数</h3>
          <div className="value">{Object.keys(statistics.animeStats).length}</div>
        </div>
      </div>

      <div className="chart-container">
        <h3>人気アニメ トップ10</h3>
        {Object.keys(statistics.animeStats).length > 0 && (
          <Bar 
            data={prepareChartData(statistics.animeStats, 'ユーザー数', 'rgba(54, 162, 235, 0.6)')} 
            options={chartOptions} 
          />
        )}
      </div>

      <div className="chart-container">
        <h3>人気キャラクター トップ10</h3>
        {Object.keys(statistics.characterStats).length > 0 && (
          <Bar 
            data={prepareChartData(statistics.characterStats, 'ユーザー数', 'rgba(255, 99, 132, 0.6)')} 
            options={chartOptions} 
          />
        )}
      </div>

      <div className="chart-container">
        <h3>人気ハッシュタグ トップ10</h3>
        {Object.keys(statistics.hashtagStats).length > 0 && (
          <Bar 
            data={prepareChartData(statistics.hashtagStats, 'ユーザー数', 'rgba(75, 192, 192, 0.6)')} 
            options={chartOptions} 
          />
        )}
      </div>
    </div>
  );
}

export default Dashboard;