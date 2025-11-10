import React from 'react';
import { NavLink } from 'react-router-dom';

const navItems = [
  { name: 'About/Resume', path: '/' },
  { name: 'Book a Meeting', path: '/book' },
  // { name: 'Monitoring Dashboard', path: '/monitor' }, // For V2+
];

const Layout = ({ children }) => {
  return (
    // Main container with max-width for readability
    <div className="min-h-screen">
      
      {/* Fixed Header/Navigation Bar */}
      <header className="fixed top-0 left-0 right-0 z-50 bg-deep-black bg-opacity-95 shadow-lg border-b border-dark-grey/50">
        <nav className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-4 flex justify-between items-center">
          
          {/* Logo/Title */}
          <h1 className="text-xl font-bold tracking-widest text-neon-green">
            {'<myPortfolio.v1/>'}
          </h1>
          
          {/* Desktop Navigation Links */}
          <div className="hidden md:flex space-x-8">
            {navItems.map((item) => (
              <NavLink
                key={item.name}
                to={item.path}
                className={({ isActive }) => 
                  `text-off-white transition duration-200 hover:text-neon-green 
                   ${isActive ? 'text-neon-green border-b-2 border-neon-green' : 'border-b-2 border-transparent'}`
                }
              >
                {item.name}
              </NavLink>
            ))}
          </div>
          <div className="md:hidden">
          
            <span className="text-neon-green text-lg">[ Menu ]</span>
          </div>


        </nav>
      </header>
      
      {/* Main Content Area - Padding accounts for the fixed header */}
      <main className="pt-20 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        {children}
      </main>
      
      {/* Subtle Footer */}
      <footer className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8 mt-12 border-t border-dark-grey/30 text-center text-dark-grey text-sm">
        <p>© {new Date().getFullYear()} Monolithic V1 - Deployed via Terraform/AWS CI/CD. Backend stability guaranteed.</p>
      </footer>
    </div>
  );
};

export default Layout;