import React, { createContext, useContext, useState, useEffect } from 'react';

const AuthContext = createContext();

export function useAuth() {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
}

export function AuthProvider({ children }) {
  const [currentUser, setCurrentUser] = useState(null);
  const [loading, setLoading] = useState(true);

  // 管理者認証情報
  const ADMIN_CREDENTIALS = {
    username: 'anicolle',
    password: '20050424'
  };

  useEffect(() => {
    // Check if user is already logged in
    const savedUser = localStorage.getItem('adminUser');
    if (savedUser) {
      setCurrentUser(JSON.parse(savedUser));
    }
    setLoading(false);
  }, []);

  const login = async (username, password) => {
    if (username === ADMIN_CREDENTIALS.username && password === ADMIN_CREDENTIALS.password) {
      const user = {
        id: 'admin',
        username: 'anicolle',
        loginTime: new Date().toISOString()
      };
      setCurrentUser(user);
      localStorage.setItem('adminUser', JSON.stringify(user));
      return user;
    } else {
      throw new Error('Invalid credentials');
    }
  };

  const logout = () => {
    setCurrentUser(null);
    localStorage.removeItem('adminUser');
  };

  const value = {
    currentUser,
    login,
    logout,
    loading
  };

  return (
    <AuthContext.Provider value={value}>
      {children}
    </AuthContext.Provider>
  );
}