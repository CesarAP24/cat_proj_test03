document.addEventListener('DOMContentLoaded', function() {
    const menuItems = document.querySelectorAll('.menu-item');
    const contentSections = document.querySelectorAll('.content-section');
    
    // Map menu items to content sections
    const contentMap = {
        0: 'exploration',
        1: 'gallery', 
        2: 'specs',
        3: 'files'
    };
    
    // Add click handlers to menu items
    menuItems.forEach((item, index) => {
        item.addEventListener('click', function() {
            // Remove active class from all menu items
            menuItems.forEach(mi => mi.classList.remove('active'));
            
            // Add active class to clicked item
            this.classList.add('active');
            
            // Show corresponding content section
            const targetContent = contentMap[index];
            if (targetContent) {
                showContent(targetContent);
            }
        });
        
        // Add hover sound effect (optional)
        item.addEventListener('mouseenter', function() {
            // You can add sound effects here if needed
            this.style.transform = 'translateX(10px) scale(1.02)';
        });
        
        item.addEventListener('mouseleave', function() {
            if (!this.classList.contains('active')) {
                this.style.transform = 'translateX(0) scale(1)';
            }
        });
    });
    
    function showContent(contentId) {
        // Hide all content sections
        contentSections.forEach(section => {
            section.style.display = 'none';
        });
        
        // Show target content section
        const targetSection = document.getElementById(contentId);
        if (targetSection) {
            targetSection.style.display = 'block';
            
            // Add close button if it doesn't exist
            if (!targetSection.querySelector('.close-btn')) {
                const closeBtn = document.createElement('button');
                closeBtn.className = 'close-btn';
                closeBtn.innerHTML = '✕';
                closeBtn.addEventListener('click', hideContent);
                targetSection.appendChild(closeBtn);
            }
            
            // Animate in
            targetSection.style.opacity = '0';
            targetSection.style.transform = 'translateY(50px)';
            
            setTimeout(() => {
                targetSection.style.transition = 'all 0.5s ease';
                targetSection.style.opacity = '1';
                targetSection.style.transform = 'translateY(0)';
            }, 10);
        }
    }
    
    function hideContent() {
        contentSections.forEach(section => {
            section.style.transition = 'all 0.3s ease';
            section.style.opacity = '0';
            section.style.transform = 'translateY(-50px)';
            
            setTimeout(() => {
                section.style.display = 'none';
            }, 300);
        });
        
        // Reset menu items
        menuItems.forEach(item => {
            item.classList.remove('active');
            item.style.transform = 'translateX(0) scale(1)';
        });
    }
    
    // Escape key to close content
    document.addEventListener('keydown', function(e) {
        if (e.key === 'Escape') {
            hideContent();
        }
    });
    
    // Add typing effect to title
    function addTypingEffect() {
        const title = document.querySelector('.main-title');
        const text = title.textContent;
        title.textContent = '';
        title.style.opacity = '1';
        
        let i = 0;
        const typeInterval = setInterval(() => {
            title.textContent += text[i];
            i++;
            if (i >= text.length) {
                clearInterval(typeInterval);
            }
        }, 150);
    }
    
    // Start typing effect after page load
    setTimeout(addTypingEffect, 500);
    
    // Add parallax effect to corner frames
    document.addEventListener('mousemove', function(e) {
        const frames = document.querySelectorAll('.corner-frame');
        const mouseX = e.clientX / window.innerWidth;
        const mouseY = e.clientY / window.innerHeight;
        
        frames.forEach((frame, index) => {
            const intensity = (index % 2 === 0) ? 5 : -5;
            const x = mouseX * intensity;
            const y = mouseY * intensity;
            frame.style.transform = `translate(${x}px, ${y}px)`;
        });
    });
    
    // Add glitch effect to title occasionally
    function addGlitchEffect() {
        const title = document.querySelector('.main-title');
        const originalText = title.textContent;
        
        // Random glitch characters
        const glitchChars = '█▓▒░▀▄▌▐█';
        
        let glitchText = '';
        for (let i = 0; i < originalText.length; i++) {
            if (Math.random() < 0.1) {
                glitchText += glitchChars[Math.floor(Math.random() * glitchChars.length)];
            } else {
                glitchText += originalText[i];
            }
        }
        
        title.textContent = glitchText;
        title.style.color = '#ff0080';
        
        setTimeout(() => {
            title.textContent = originalText;
            title.style.color = '';
        }, 100);
    }
    
    // Random glitch effect every 10-15 seconds
    setInterval(() => {
        if (Math.random() < 0.3) {
            addGlitchEffect();
        }
    }, Math.random() * 5000 + 10000);
});