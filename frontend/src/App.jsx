import React from 'react';
import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import Layout from './components/Layout.jsx';
import About from './pages/About.jsx'; 
import Booking from './pages/Booking.jsx'; 

const App = () => {
  return (
    <Router>
      <Layout>
        <Routes>
          {/* Default Route */}
          <Route path="/" element={<About />} /> 
          {/* Booking Route */}
          <Route path="/book" element={<Booking />} />
        </Routes>
      </Layout>
    </Router>
  );
};

export default App; 