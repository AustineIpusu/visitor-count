class VisitorCounter {
    constructor() {
        // Use the exact working URL with trailing slash
        this.apiUrl = 'https://qifolf6l45.execute-api.us-east-1.amazonaws.com/prod/count';
        this.counterElement = document.getElementById('counter');
        this.messageElement = document.getElementById('message');
        console.log('API URL set to:', this.apiUrl);
    }

    async updateCounter() {
        await this.makeRequest('update');
    }

    async getCounter() {
        await this.makeRequest('get');
    }

    async makeRequest(action) {
        this.showLoading();
        this.clearMessage();

        try {
            console.log('Making request to:', this.apiUrl);
            
            const response = await fetch(this.apiUrl, {
                method: 'GET',
                mode: 'cors',
                headers: {
                    'Content-Type': 'application/json'
                }
            });

            console.log('Response status:', response.status);
            
            // Check if response is JSON
            const contentType = response.headers.get('content-type');
            if (!contentType || !contentType.includes('application/json')) {
                const text = await response.text();
                throw new Error(`Expected JSON but got: ${text.substring(0, 100)}`);
            }
            
            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`);
            }

            const data = await response.json();
            console.log('Response data:', data);
            
            this.counterElement.textContent = data.count;
            this.showMessage(`✅ Visitor count: ${data.count}`, 'success');
            
        } catch (error) {
            console.error('Error:', error);
            this.counterElement.textContent = 'Error';
            this.showMessage(`❌ Failed to ${action} counter: ${error.message}`, 'error');
        }

    // ... rest of your methods
}

    showLoading() {
        this.counterElement.textContent = '...';
        this.counterElement.className = 'counter loading';
    }

    showMessage(text, type) {
        this.messageElement.textContent = text;
        this.messageElement.className = type;
    }

    clearMessage() {
        this.messageElement.textContent = '';
        this.messageElement.className = '';
    }
}

// Initialize and make global
const visitorCounter = new VisitorCounter();

// Load counter when page loads
document.addEventListener('DOMContentLoaded', () => {
    visitorCounter.getCounter();
});
// Last updated: Thu Sep 25 15:53:45 WCAST 2025
// Updated: Thu Sep 25 16:10:31 WCAST 2025
// Debug version: Thu Sep 25 16:23:58 WCAST 2025
// Debug version: Thu Sep 25 16:26:35 WCAST 2025
