/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    // Extend the default theme to add our custom colors and font
    extend: {
      colors: {
        // Define our custom colors for the Matrix Architect theme
        'deep-black': '#0A0A0A',
        'off-white': '#F0F0F0',
        'neon-green': '#D2FF00', // The primary accent color
        'dark-grey': '#5F5F5F',
        'electric-red': '#FF4141', // For errors/alerts 
      },
      fontFamily: {
        // Use a monospace font for the "terminal" feel
        'mono': ['Source Code Pro', 'monospace'], 
      },
      keyframes: {
        // Define a subtle cursor blink animation for the terminal effect
        cursor: {
          '0%, 100%': { 'border-right-color': 'transparent' },
          '50%': { 'border-right-color': 'currentColor' },
        },
        marquee: {
          '0%': { transform: 'translateX(0%)' },
          '100%': { transform: 'translateX(-50%)' },
        },
      },
      animation: {
        // Apply the marquee keyframe for a duration of 30 seconds
        marquee: 'marquee 30s linear infinite', 
      }
        
      },
      
    },
  
  plugins: [],
}