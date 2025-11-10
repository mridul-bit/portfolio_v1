import React, { useState } from 'react';
import { motion } from 'framer-motion';

const Booking = () => {
  const [formData, setFormData] = useState({ name: '', email: '', date: '', time: '' });
  const [loading, setLoading] = useState(false);
  const [message, setMessage] = useState(null);

  const handleChange = (e) => {
    setFormData({ ...formData, [e.target.name]: e.target.value });
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);
    setMessage(null);

    // Placeholder: This is where the actual API call to the Django monolith /api/book endpoint will go
    try {
        const response = await fetch('/api/book', { 
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(formData),
        });
        
        const data = await response.json();

        if (response.ok) {
            setMessage({ type: 'success', text: 'Meeting booked successfully! Check your email for confirmation (via AWS Lambda).'});
        } else if (response.status === 429) {
            // This explicitly demonstrates the Rate Limiting/Throttling feature
            setMessage({ type: 'error', text: '429: Rate Limit Exceeded. Please try again in one minute. This API is aggressively throttled for stability.' });
        } else {
            setMessage({ type: 'error', text: data.error || 'Booking failed due to a backend error.' });
        }
    } catch (error) {
        console.error('Booking API error:', error);
        setMessage({ type: 'error', text: 'Network error. Could not reach the API Gateway.' });
    }
    
    setLoading(false);
  };
  
  return (
    <section className="py-16">
      <h2 className="text-4xl font-bold mb-2 text-off-white">Book a Meeting</h2>
      <p className="text-lg text-dark-grey mb-10">
        Schedule a 30-minute chat to discuss your requirements or my architecture. All bookings are handled by the **Secure Django Backend** and **AWS Lambda**.
      </p>

      <form onSubmit={handleSubmit} className="max-w-xl mx-auto p-8 border border-dark-grey/50 rounded-lg shadow-xl bg-deep-black/70">
        
        {/* Status Message */}
        {message && (
            <div className={`p-4 mb-6 rounded-lg font-semibold ${message.type === 'success' ? 'bg-neon-green text-deep-black' : 'bg-electric-red text-off-white'}`}>
                {message.text}
            </div>
        )}

        {/* Form Fields */}
        {['name', 'email'].map((field) => (
            <div className="mb-6" key={field}>
                <label htmlFor={field} className="block text-off-white mb-2 capitalize">
                    {field}
                </label>
                <input
                    type={field}
                    id={field}
                    name={field}
                    value={formData[field]}
                    onChange={handleChange}
                    required
                    className="w-full p-3 bg-deep-black border border-dark-grey focus:border-neon-green focus:ring-1 focus:ring-neon-green outline-none rounded-md text-off-white transition duration-200"
                    placeholder={`Enter your ${field}`}
                />
            </div>
        ))}
        
        <div className="grid grid-cols-2 gap-4 mb-6">
            <div>
                <label htmlFor="date" className="block text-off-white mb-2">
                    Date
                </label>
                <input
                    type="date"
                    id="date"
                    name="date"
                    value={formData.date}
                    onChange={handleChange}
                    required
                    className="w-full p-3 bg-deep-black border border-dark-grey focus:border-neon-green focus:ring-1 focus:ring-neon-green outline-none rounded-md text-off-white transition duration-200"
                />
            </div>
            <div>
                <label htmlFor="time" className="block text-off-white mb-2">
                    Time
                </label>
                <input
                    type="time"
                    id="time"
                    name="time"
                    value={formData.time}
                    onChange={handleChange}
                    required
                    className="w-full p-3 bg-deep-black border border-dark-grey focus:border-neon-green focus:ring-1 focus:ring-neon-green outline-none rounded-md text-off-white transition duration-200"
                />
            </div>
        </div>
        
        {/* Submit Button */}
        <motion.button
            type="submit"
            className="w-full py-3 bg-neon-green text-deep-black font-bold rounded-md transition duration-300 hover:bg-off-white disabled:opacity-50 flex items-center justify-center"
            disabled={loading}
            whileHover={{ scale: 1.02 }}
            whileTap={{ scale: 0.98 }}
        >
            {loading ? (
                <>
                    <svg className="animate-spin -ml-1 mr-3 h-5 w-5 text-deep-black" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                        <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                        <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                    </svg>
                    Processing...
                </>
            ) : (
                'Confirm Booking'
            )}
        </motion.button>
        
        {/* Rate Limiting Disclosure (The professional touch) */}
        <p className="mt-6 text-center text-sm text-dark-grey/80">
            <span className="text-neon-green font-bold mr-1">🔒 Security Note:</span> 
            This API endpoint is protected by **Rate Limiting** (max 5 requests/min) and a **Web Application Firewall (WAF)** for stability.
        </p>

      </form>
    </section>
  );
};

export default Booking;