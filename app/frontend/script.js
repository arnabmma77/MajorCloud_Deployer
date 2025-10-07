// Weather App JavaScript - Backend Integration
class WeatherApp {
    constructor() {
        this.initializeApp();
        this.checkBackendHealth();
        this.setupEventListeners();
    }

    initializeApp() {
        // Check if we have a saved city in localStorage
        const savedCity = localStorage.getItem('lastSearchedCity');
        if (savedCity) {
            document.getElementById('cityInput').value = savedCity;
            this.searchWeather();
        }
    }

    setupEventListeners() {
        const cityInput = document.getElementById('cityInput');
        const searchBtn = document.getElementById('searchBtn');

        // Enter key press event
        cityInput.addEventListener('keypress', (e) => {
            if (e.key === 'Enter') {
                this.searchWeather();
            }
        });

        // Search button click event
        searchBtn.addEventListener('click', () => {
            this.searchWeather();
        });

        // Auto-complete functionality (optional enhancement)
        cityInput.addEventListener('input', (e) => {
            // Clear any previous search timeouts
            if (this.searchTimeout) {
                clearTimeout(this.searchTimeout);
            }
        });
    }

    async checkBackendHealth() {
        const statusElement = document.getElementById('backendStatus');
        
        try {
            const response = await fetch('/health');
            
            if (response.ok) {
                const data = await response.json();
                statusElement.textContent = 'Healthy';
                statusElement.className = 'status-indicator status-healthy';
                console.log('Backend health check:', data);
            } else {
                throw new Error(`Health check failed: ${response.status}`);
            }
        } catch (error) {
            console.error('Backend health check failed:', error);
            statusElement.textContent = 'Error';
            statusElement.className = 'status-indicator status-error';
        }
    }

    async searchWeather() {
        const cityInput = document.getElementById('cityInput');
        const city = cityInput.value.trim();

        if (!city) {
            this.showError('Please enter a city name');
            return;
        }

        // Save the searched city to localStorage
        localStorage.setItem('lastSearchedCity', city);

        // Show loading state
        this.showLoading();
        this.hideError();
        this.hideWeatherContainer();

        try {
            // Fetch current weather data from backend
            const weatherData = await this.fetchWeatherData(city);
            
            // Fetch forecast data from backend
            const forecastData = await this.fetchForecastData(city);

            // Display the weather data
            this.displayWeatherData(weatherData);
            this.displayForecastData(forecastData);
            
            // Show weather container
            this.showWeatherContainer();

        } catch (error) {
            console.error('Weather search error:', error);
            this.showError(error.message);
        } finally {
            this.hideLoading();
        }
    }

    async fetchWeatherData(city) {
        const response = await fetch(`/api/weather?city=${encodeURIComponent(city)}`);
        
        if (!response.ok) {
            const errorData = await response.json();
            throw new Error(errorData.error || 'Failed to fetch weather data');
        }
        
        return await response.json();
    }

    async fetchForecastData(city) {
        try {
            const response = await fetch(`/api/forecast?city=${encodeURIComponent(city)}`);
            
            if (!response.ok) {
                console.warn('Forecast data not available');
                return null;
            }
            
            return await response.json();
        } catch (error) {
            console.warn('Failed to fetch forecast data:', error);
            return null;
        }
    }

    displayWeatherData(data) {
        // Update city and country
        document.getElementById('cityName').textContent = data.city || 'Unknown';
        document.getElementById('country').textContent = data.country ? `(${data.country})` : '';

        // Update temperature and weather info
        document.getElementById('temperature').textContent = Math.round(data.temperature);
        document.getElementById('feelsLike').textContent = Math.round(data.feels_like);
        document.getElementById('description').textContent = data.description || 'No description';

        // Update weather icon
        const weatherIcon = document.getElementById('weatherIcon');
        if (data.icon) {
            weatherIcon.src = `https://openweathermap.org/img/wn/${data.icon}@2x.png`;
            weatherIcon.alt = data.description;
        } else {
            weatherIcon.src = '';
            weatherIcon.alt = 'No icon available';
        }

        // Update weather details
        document.getElementById('humidity').textContent = `${data.humidity}%`;
        document.getElementById('pressure').textContent = `${data.pressure} hPa`;
        document.getElementById('windSpeed').textContent = `${data.wind_speed} m/s`;
        document.getElementById('visibility').textContent = `${data.visibility} km`;
    }

    displayForecastData(forecastData) {
        const forecastContainer = document.getElementById('forecastContainer');
        
        if (!forecastData || !forecastData.forecasts) {
            forecastContainer.innerHTML = '<p>Forecast data not available</p>';
            return;
        }

        forecastContainer.innerHTML = '';

        forecastData.forecasts.forEach((forecast, index) => {
            const forecastItem = document.createElement('div');
            forecastItem.className = 'forecast-item';

            // Format the date
            const date = new Date(forecast.date);
            const options = { weekday: 'short', month: 'short', day: 'numeric' };
            const formattedDate = date.toLocaleDateString('en-US', options);

            forecastItem.innerHTML = `
                <div class="forecast-date">${formattedDate}</div>
                <div class="forecast-icon">
                    <img src="https://openweathermap.org/img/wn/${forecast.icon}@2x.png" 
                         alt="${forecast.description}">
                </div>
                <div class="forecast-temp">${Math.round(forecast.temperature)}°C</div>
                <div class="forecast-desc">${forecast.description}</div>
                <div class="forecast-humidity">💧 ${forecast.humidity}%</div>
            `;

            forecastContainer.appendChild(forecastItem);
        });
    }

    showLoading() {
        document.getElementById('loading').style.display = 'block';
    }

    hideLoading() {
        document.getElementById('loading').style.display = 'none';
    }

    showError(message) {
        const errorMessage = document.getElementById('errorMessage');
        const errorText = document.getElementById('errorText');
        
        errorText.textContent = message;
        errorMessage.style.display = 'block';

        // Auto-hide error after 5 seconds
        setTimeout(() => {
            this.hideError();
        }, 5000);
    }

    hideError() {
        document.getElementById('errorMessage').style.display = 'none';
    }

    showWeatherContainer() {
        document.getElementById('weatherContainer').style.display = 'block';
    }

    hideWeatherContainer() {
        document.getElementById('weatherContainer').style.display = 'none';
    }
}

// Utility functions
function formatDate(dateString) {
    const date = new Date(dateString);
    return date.toLocaleDateString('en-US', {
        weekday: 'short',
        month: 'short',
        day: 'numeric'
    });
}

function capitalizeWords(str) {
    return str.replace(/\w\S*/g, (txt) => {
        return txt.charAt(0).toUpperCase() + txt.substr(1).toLowerCase();
    });
}

// Initialize the weather app when the DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    const weatherApp = new WeatherApp();
    
    // Make the search function globally available
    window.searchWeather = () => weatherApp.searchWeather();
    
    console.log('Weather App initialized successfully');
    console.log('Backend proxy integration active');
});

// Service Worker registration for offline functionality (optional)
if ('serviceWorker' in navigator) {
    window.addEventListener('load', () => {
        // Note: Service worker implementation would be added here for production
        console.log('Service Worker support detected');
    });
}

// Error handling for uncaught errors
window.addEventListener('error', (event) => {
    console.error('Global error caught:', event.error);
    
    // Show user-friendly error message
    const errorMessage = document.getElementById('errorMessage');
    const errorText = document.getElementById('errorText');
    
    if (errorMessage && errorText) {
        errorText.textContent = 'An unexpected error occurred. Please try again.';
        errorMessage.style.display = 'block';
    }
});

// Network status monitoring
window.addEventListener('online', () => {
    console.log('Network connection restored');
    const statusElement = document.getElementById('backendStatus');
    if (statusElement) {
        // Re-check backend health when network is restored
        setTimeout(() => {
            const app = new WeatherApp();
            app.checkBackendHealth();
        }, 1000);
    }
});

window.addEventListener('offline', () => {
    console.log('Network connection lost');
    const statusElement = document.getElementById('backendStatus');
    if (statusElement) {
        statusElement.textContent = 'Offline';
        statusElement.className = 'status-indicator status-error';
    }
});
