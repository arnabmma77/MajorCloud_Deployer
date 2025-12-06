import os
import requests
from flask import Flask, request, jsonify, send_from_directory
from flask_cors import CORS
from dotenv import load_dotenv

load_dotenv()

print("API Key Loaded:", os.getenv("OPENWEATHER_API_KEY"))

app = Flask(__name__, static_folder='../frontend', static_url_path='')
CORS(app)

# Get OpenWeather API key from environment variables
OPENWEATHER_API_KEY = os.getenv('OPENWEATHER_API_KEY', 'your_api_key_here')
OPENWEATHER_BASE_URL = 'http://api.openweathermap.org/data/2.5'

@app.route('/')
def serve_frontend():
    """Serve the frontend index.html file"""
    return send_from_directory(app.static_folder, 'index.html')

@app.route('/<path:filename>')
def serve_static_files(filename):
    """Serve static files (CSS, JS, etc.)"""
    return send_from_directory(app.static_folder, filename)

@app.route('/health')
def health_check():
    """Health check endpoint for monitoring"""
    import datetime
    return jsonify({
        'status': 'healthy',
        'message': 'Server is healthy',
        'timestamp': datetime.datetime.utcnow().isoformat()
    }), 200

@app.route('/api/weather')
def get_weather():
    """Proxy endpoint for OpenWeather API requests"""
    try:
        city = request.args.get('city')
        if not city:
            return jsonify({
                'error': 'City parameter is required'
            }), 400

        # Make request to OpenWeather API
        url = f"{OPENWEATHER_BASE_URL}/weather"
        params = {
            'q': city,
            'appid': OPENWEATHER_API_KEY,
            'units': 'metric'
        }
        
        response = requests.get(url, params=params)
        
        if response.status_code == 200:
            weather_data = response.json()
            
            # Format the response to include only necessary data
            formatted_data = {
                'city': weather_data.get('name', ''),
                'country': weather_data.get('sys', {}).get('country', ''),
                'temperature': weather_data.get('main', {}).get('temp', 0),
                'feels_like': weather_data.get('main', {}).get('feels_like', 0),
                'humidity': weather_data.get('main', {}).get('humidity', 0),
                'pressure': weather_data.get('main', {}).get('pressure', 0),
                'description': weather_data.get('weather', [{}])[0].get('description', ''),
                'icon': weather_data.get('weather', [{}])[0].get('icon', ''),
                'wind_speed': weather_data.get('wind', {}).get('speed', 0),
                'visibility': weather_data.get('visibility', 0) / 1000  # Convert to km
            }
            
            return jsonify(formatted_data)
        else:
            # Handle API errors
            error_data = response.json() if response.content else {}
            return jsonify({
                'error': error_data.get('message', 'Weather data not found'),
                'status_code': response.status_code
            }), response.status_code
            
    except requests.exceptions.RequestException as e:
        return jsonify({
            'error': 'Failed to fetch weather data',
            'message': str(e)
        }), 503
    except Exception as e:
        return jsonify({
            'error': 'Internal server error',
            'message': str(e)
        }), 500

@app.route('/api/forecast')
def get_forecast():
    """Proxy endpoint for OpenWeather 5-day forecast API"""
    try:
        city = request.args.get('city')
        if not city:
            return jsonify({
                'error': 'City parameter is required'
            }), 400

        # Make request to OpenWeather 5-day forecast API
        url = f"{OPENWEATHER_BASE_URL}/forecast"
        params = {
            'q': city,
            'appid': OPENWEATHER_API_KEY,
            'units': 'metric'
        }
        
        response = requests.get(url, params=params)
        
        if response.status_code == 200:
            forecast_data = response.json()
            
            # Format forecast data (take every 8th item to get daily forecast)
            daily_forecasts = []
            for i in range(0, len(forecast_data.get('list', [])), 8):
                item = forecast_data['list'][i]
                daily_forecasts.append({
                    'date': item.get('dt_txt', ''),
                    'temperature': item.get('main', {}).get('temp', 0),
                    'description': item.get('weather', [{}])[0].get('description', ''),
                    'icon': item.get('weather', [{}])[0].get('icon', ''),
                    'humidity': item.get('main', {}).get('humidity', 0)
                })
            
            return jsonify({
                'city': forecast_data.get('city', {}).get('name', ''),
                'country': forecast_data.get('city', {}).get('country', ''),
                'forecasts': daily_forecasts[:5]  # Limit to 5 days
            })
        else:
            error_data = response.json() if response.content else {}
            return jsonify({
                'error': error_data.get('message', 'Forecast data not found'),
                'status_code': response.status_code
            }), response.status_code
            
    except requests.exceptions.RequestException as e:
        return jsonify({
            'error': 'Failed to fetch forecast data',
            'message': str(e)
        }), 503
    except Exception as e:
        return jsonify({
            'error': 'Internal server error',
            'message': str(e)
        }), 500

if __name__ == '__main__':
    port = int(os.getenv('PORT', 5000))
    app.run(host='0.0.0.0', port=port, debug=False)
