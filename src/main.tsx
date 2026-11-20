import React from 'react'
import ReactDOM from 'react-dom/client'
import App from './App'
import './index.css'
import storageService from './services/storage/storageService'
import { demoProducts } from './services/data/demoProducts'

// Inicializar datos de demostración si están vacíos
const initializeApp = () => {
  const products = storageService.getProducts();
  
  if (products.length === 0) {
    console.log('Initializing demo data...');
    storageService.setProducts(demoProducts);
    
    // Crear一些 initial audit log
    storageService.addAuditLog({
      id: 'audit-1',
      timestamp: new Date(),
      user: 'Sistema',
      action: 'INICIO',
      details: 'Datos de demostración inicializados',
      category: 'SYSTEM',
      severity: 'INFO'
    });
  }
};

initializeApp();

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);