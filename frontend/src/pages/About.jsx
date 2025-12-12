import React, { useState, useEffect } from 'react';
import { motion } from 'framer-motion';

//random commendt to check cicd
const API_URL = process.env.API_URL;
const handleResumeDownload = async () => {
    // 1. Call the Django Backend API
    
    console.log("about page");
    try {
        const response = await fetch(API_URL, {
            method: 'GET',
            headers: { 'Content-Type': 'application/json' },
            // Include CSRF token if not using a session-less token 
        });

        if (response.ok) {
            const data = await response.json();
            const presignedUrl = data.presigned_url;
            
            // 2. Use the temporary secure URL to download the file
            window.location.href = presignedUrl; 
            
            // Optional: User feedback for security
            console.log("Secure download initiated. Link is valid for 60 seconds.");
            
        } else if (response.status === 429) {
            alert("Rate Limit Exceeded. Please try again in one minute. Security enforced.");
        } else {
            alert("Download failed. Backend error.");
        }
    } catch (error) {
        console.error("Network error fetching presigned URL:", error);
    }
};
const TechStackMarquee = () => {
    // Include all V1 technologies here
    const technologies = [
        "Django (Monolith)", "PostgreSQL (RDS)", "React.js", "Docker"
    ];

    // Duplicate the list to ensure seamless, continuous looping
    const doubledTechnologies = [...technologies,...technologies];

    return (
        <div className="mt-20">
            <h4 className="text-xl font-semibold mb-4 text-dark-grey text-center">
                Core V1 Technologies Demonstrated
            </h4>
            
            {/* Outer container: Hides overflow and sets the stage for scrolling */}
            <div className="overflow-hidden whitespace-nowrap py-4 ">
                
                {/* Inner container: Applies the continuous scrolling animation */}
                <div className="inline-block animate-marquee group hover:[animation-play-state:paused]">
                    {doubledTechnologies.map((tech, index) => (
                        <span 
                            key={index} 
                            // Space out the items, and use a responsive hidden class for mobile cleanliness
                            className="inline-block text-xl text-off-white mx-8 transition duration-150 hover:text-neon-green hover:scale-110
                                        sm:text-2xl sm:mx-12 md:text-3xl md:mx-16 
                                        last-of-type:hidden sm:last-of-type:inline-block"
                        >
                            {tech}
                        </span>
                    ))}
                </div>
            </div>
            
        </div>
    );
};

const About = () => {
  // 1. Terminal Typing Effect Logic
  const fullText = "Expert DevOps | Backend Architect | Cloud-Native Solutions";
const [displayedText, setDisplayedText] = useState('');
const [index, setIndex] = useState(0); 

useEffect(() => {
    // Check if we are done typing
    if (index >= fullText.length) return;

    const typingInterval = setInterval(() => {
        // 2. Append the new character using the current state index
        setDisplayedText(prev => prev + fullText.charAt(index)); 
        
        // 3. Increment the index for the next cycle
        setIndex(prev => prev + 1);

    }, 60);

    // Dependency array must include the index for the effect to re-run
    // and correctly capture the updated value of index in the closure.
    return () => clearInterval(typingInterval);
}, [index, fullText]);


  // Placeholder URL for your resume (will point to S3/CloudFront)
  const resumeUrl = `${API_URL}/api/resume/`
  // Placeholder URL for your YouTube video
  const videoUrl = "https://www.youtube.com/embed"; 
  
  return (
    <section className="py-16 md:py-24">
      
      {/* Hero Section with Typing Effect */}
      <div className="mb-16">
        <h2 className="text-4xl sm:text-6xl font-extrabold mb-4 text-off-white">
          {'Hello, I\'m Mridul'}
        </h2>
        <h3 className="text-2xl sm:text-4xl text-neon-green mb-8 overflow-hidden">
          {displayedText}
          {/* Blinking Cursor */}
          <span className="inline-block w-1 bg-neon-green h-full ml-1 align-bottom animate-pulse"></span>
        </h3>
        
        {/* Short Introduction */}
        <p className="text-lg text-off-white max-w-3xl mb-10">
          I design and deploy highly secure, scalable, and cost-efficient backend systems and cloud infrastructure. This site, V1, is a live demonstration of my commitment to production-grade best practices.
        </p>
        
        {/* Resume Download CTA (Animated) */}
        <motion.button
            onClick={handleResumeDownload} // <--- NEW HANDLER
            className="inline-block px-8 py-3 bg-neon-green text-deep-black font-bold rounded-lg transition duration-300 transform hover:scale-[1.02]"
            whileHover={{ scale: 1.05 }}
            whileTap={{ scale: 0.95 }}
        >
            Download Resume (Secure Link)
        </motion.button>
      </div>

      <hr className="border-dark-grey/30 my-16" />

      {/* Architecture Explanation Section */}
      <div id="architecture" className="mb-16">
        <h3 className="text-3xl font-bold mb-6 text-off-white">
          V1 Architecture: Scalable Monolith Deep Dive
        </h3>
        <p className="text-lg text-dark-grey mb-8">
          Watch this short video where I break down the V1 architecture, including why I chose Django/Postgres, how I implemented **Auto-Scaling, Secret Management**, and the **CI/CD** pipeline.
        </p>

        {/* YouTube Video Embed */}
        <div className="relative w-full overflow-hidden rounded-xl border-2 border-neon-green/50 shadow-2xl shadow-neon-green/20" style={{ paddingTop: '56.25%' }}> 
            {/* 16:9 Aspect Ratio (56.25% padding) */}
            <iframe
                className="absolute top-0 left-0 w-full h-full"
                src="https://www.youtube.com/embed/7iHl71nt49o"
                title="Portfolio V1 Architecture Explanation"
                allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
                allowFullScreen
            ></iframe>
        </div>
      </div>
      <TechStackMarquee />  


    </section>
  );
};

export default About;