import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;

void main() {
  runApp(const WeatherApp());
}

class WeatherApp extends StatelessWidget {
  const WeatherApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Weather App',
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF2C3E50),
        scaffoldBackgroundColor: const Color(0xFF1A1A2E),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF16213E),
          secondary: Color(0xFF0F3460),
          surface: Color(0xFF16213E),
          background: Color(0xFF1A1A2E),
        ),
      ),
      home: const WeatherHomePage(),
    );
  }
}

class WeatherService {
  // Get your free API key from: https://openweathermap.org/api
  static const String _apiKey = 'ee6fc2c4fd08a7f80fb6f94fda9726a1';
  static const String _baseUrl = 'https://api.openweathermap.org/data/2.5';

  // City coordinates for accurate weather data
  static const Map<String, Map<String, double>> _cityCoordinates = {
    'Aydın': <String, double>{'lat': 37.8444, 'lon': 27.8458},
    'Berlin': <String, double>{'lat': 52.5200, 'lon': 13.4050},
    'Kuşadası': <String, double>{'lat': 37.8583, 'lon': 27.2611},
    'Mersin': <String, double>{'lat': 36.8121, 'lon': 34.6415},
  };

  static Future<Map<String, WeatherData>> getWeatherData(String city) async {
    if (_apiKey == 'YOUR_API_KEY_HERE') {
      print('Using mock data - API key not configured');
      // Return mock data if API key not set
      return _getMockData(city);
    }

    try {
      final coords = _cityCoordinates[city];
      if (coords == null) throw Exception('City not found: $city');

      final lat = coords['lat'] ?? 0.0;
      final lon = coords['lon'] ?? 0.0;

      if (lat == 0.0 && lon == 0.0)
        throw Exception('Invalid coordinates for $city');

      print('Fetching weather data for $city (lat: $lat, lon: $lon)');

      // Get current weather
      final currentUrl =
          '$_baseUrl/weather?lat=$lat&lon=$lon&appid=$_apiKey&units=metric';
      final currentResponse = await http
          .get(Uri.parse(currentUrl))
          .timeout(const Duration(seconds: 10));

      print('Current weather API response: ${currentResponse.statusCode}');

      if (currentResponse.statusCode == 401) {
        throw Exception(
            'Invalid API key - Please check your OpenWeatherMap API key');
      }

      if (currentResponse.statusCode == 429) {
        throw Exception('API quota exceeded - Please try again later');
      }

      // Get 5-day forecast (we'll use tomorrow's data)
      final forecastUrl =
          '$_baseUrl/forecast?lat=$lat&lon=$lon&appid=$_apiKey&units=metric';
      final forecastResponse = await http
          .get(Uri.parse(forecastUrl))
          .timeout(const Duration(seconds: 10));

      print('Forecast API response: ${forecastResponse.statusCode}');

      if (currentResponse.statusCode == 200 &&
          forecastResponse.statusCode == 200) {
        final currentData =
            json.decode(currentResponse.body) as Map<String, dynamic>? ?? {};
        final forecastData =
            json.decode(forecastResponse.body) as Map<String, dynamic>? ?? {};

        print('Successfully parsed weather data for $city');
        return _parseWeatherData(currentData, forecastData);
      } else {
        throw Exception(
            'API Error - Current: ${currentResponse.statusCode}, Forecast: ${forecastResponse.statusCode}');
      }
    } on TimeoutException {
      print('Weather API timeout for $city');
      return _getMockData(city);
    } catch (e) {
      print('Weather API error for $city: $e');
      // Return mock data as fallback
      return _getMockData(city);
    }
  }

  static Map<String, WeatherData> _parseWeatherData(
      Map<String, dynamic> current, Map<String, dynamic> forecast) {
    // Parse current weather with null safety
    final currentTemp = (current['main']?['temp'] ?? 20).round();
    final currentRain =
        current['weather']?[0]?['main']?.toLowerCase().contains('rain') ??
            false;

    // For today, use current temp for day, estimate night temp as 8 degrees lower
    final todayDayTemp = currentTemp;
    final todayNightTemp = (currentTemp - 8).clamp(-50, 60);

    // Parse tomorrow's forecast (find tomorrow's weather in forecast list)
    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));

    WeatherData? tomorrowWeather;

    // Find tomorrow's weather data with null safety
    final forecastList = (forecast['list'] as List?) ?? [];
    Map<String, dynamic>? tomorrowDay;
    Map<String, dynamic>? tomorrowNight;

    for (final item in forecastList) {
      try {
        if (item is! Map<String, dynamic>) continue;

        final timestamp = item['dt'] as int?;
        if (timestamp == null) continue;

        final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);

        if (dateTime.day == tomorrow.day) {
          final hour = dateTime.hour;
          if (hour >= 12 && hour <= 15 && tomorrowDay == null) {
            tomorrowDay = item;
          }
          if (hour >= 21 && hour <= 23 && tomorrowNight == null) {
            tomorrowNight = item;
          }
        }
      } catch (e) {
        // Skip invalid forecast items
        continue;
      }
    }

    // Fallback to first available tomorrow data
    if (tomorrowDay == null && forecastList.isNotEmpty) {
      try {
        for (final item in forecastList) {
          if (item is! Map<String, dynamic>) continue;

          final timestamp = item['dt'] as int?;
          if (timestamp == null) continue;

          final itemDate =
              DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
          if (itemDate.day == tomorrow.day) {
            tomorrowDay = item;
            break;
          }
        }

        // If still no tomorrow data, use data from 24 hours later (index 8 in 3-hour intervals)
        if (tomorrowDay == null) {
          final fallbackIndex = forecastList.length > 8 ? 8 : 0;
          final fallbackItem = forecastList[fallbackIndex];
          if (fallbackItem is Map<String, dynamic>) {
            tomorrowDay = fallbackItem;
          }
        }
      } catch (e) {
        // Final fallback - create synthetic data
        tomorrowDay = null;
      }
    }

    // Ensure we have fallback data
    tomorrowNight ??= tomorrowDay;

    // Final fallback if everything is null - create synthetic data
    if (tomorrowDay == null) {
      tomorrowDay = <String, dynamic>{
        'main': <String, dynamic>{'temp': currentTemp - 2},
        'weather': <Map<String, dynamic>>[
          <String, dynamic>{'main': 'Clear'}
        ]
      };
    }

    if (tomorrowNight == null) {
      tomorrowNight = <String, dynamic>{
        'main': <String, dynamic>{'temp': currentTemp - 8},
        'weather': <Map<String, dynamic>>[
          <String, dynamic>{'main': 'Clear'}
        ]
      };
    }

    final tomorrowDayTemp =
        (tomorrowDay?['main']?['temp']?.round() ?? (currentTemp - 2))
            .clamp(-50, 60);
    final tomorrowNightTemp =
        (tomorrowNight?['main']?['temp']?.round() ?? (currentTemp - 8))
            .clamp(-50, 60);
    final tomorrowDayRain =
        tomorrowDay?['weather']?[0]?['main']?.toLowerCase().contains('rain') ??
            false;
    final tomorrowNightRain = tomorrowNight?['weather']?[0]?['main']
            ?.toLowerCase()
            .contains('rain') ??
        false;

    return {
      'today': WeatherData(
        dayTemp: todayDayTemp,
        nightTemp: todayNightTemp,
        dayRain: currentRain,
        nightRain: currentRain, // Use current condition for night as well
      ),
      'tomorrow': WeatherData(
        dayTemp: tomorrowDayTemp,
        nightTemp: tomorrowNightTemp,
        dayRain: tomorrowDayRain,
        nightRain: tomorrowNightRain,
      ),
    };
  }

  static Map<String, WeatherData> _getMockData(String city) {
    // Fallback mock data
    final mockData = <String, Map<String, WeatherData>>{
      'Aydın': {
        'today': WeatherData(
            dayTemp: 28, nightTemp: 18, dayRain: false, nightRain: false),
        'tomorrow': WeatherData(
            dayTemp: 30, nightTemp: 19, dayRain: false, nightRain: true),
      },
      'Berlin': {
        'today': WeatherData(
            dayTemp: 22, nightTemp: 14, dayRain: true, nightRain: false),
        'tomorrow': WeatherData(
            dayTemp: 20, nightTemp: 13, dayRain: true, nightRain: true),
      },
      'Kuşadası': {
        'today': WeatherData(
            dayTemp: 26, nightTemp: 20, dayRain: false, nightRain: false),
        'tomorrow': WeatherData(
            dayTemp: 27, nightTemp: 21, dayRain: false, nightRain: false),
      },
      'Mersin': {
        'today': WeatherData(
            dayTemp: 32, nightTemp: 24, dayRain: false, nightRain: false),
        'tomorrow': WeatherData(
            dayTemp: 31, nightTemp: 23, dayRain: true, nightRain: false),
      },
    };

    final defaultData = {
      'today': WeatherData(
          dayTemp: 22, nightTemp: 14, dayRain: false, nightRain: false),
      'tomorrow': WeatherData(
          dayTemp: 20, nightTemp: 13, dayRain: false, nightRain: false),
    };

    return mockData[city] ?? defaultData;
  }
}

class WeatherHomePage extends StatefulWidget {
  const WeatherHomePage({Key? key}) : super(key: key);

  @override
  State<WeatherHomePage> createState() => _WeatherHomePageState();
}

class _WeatherHomePageState extends State<WeatherHomePage> {
  final List<String> locations = ['Aydın', 'Berlin', 'Kuşadası', 'Mersin'];
  String selectedLocation = 'Berlin';
  Map<String, WeatherData>? weatherData;
  bool isLoading = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await _loadSavedLocation();
    await _loadWeatherData();
  }

  Future<void> _loadSavedLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLocation = prefs.getString('selectedLocation');
    if (savedLocation != null && locations.contains(savedLocation)) {
      setState(() {
        selectedLocation = savedLocation;
      });
    }
  }

  Future<void> _saveLocation(String location) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedLocation', location);
  }

  Future<void> _loadWeatherData() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final data = await WeatherService.getWeatherData(selectedLocation);
      setState(() {
        weatherData = data;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to load weather data';
        isLoading = false;
      });
    }
  }

  Future<void> _onLocationChanged(String newLocation) async {
    setState(() {
      selectedLocation = newLocation;
    });
    await _saveLocation(newLocation);
    await _loadWeatherData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Location Dropdown
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF2C3E50),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF34495E), width: 1),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: selectedLocation,
                    icon: const Icon(Icons.arrow_drop_down,
                        color: Color(0xFF7F8C8D)),
                    style:
                        const TextStyle(color: Color(0xFFECF0F1), fontSize: 18),
                    dropdownColor: const Color(0xFF2C3E50),
                    items: locations.map((String location) {
                      return DropdownMenuItem<String>(
                        value: location,
                        child: Text(location),
                      );
                    }).toList(),
                    onChanged: isLoading
                        ? null
                        : (String? newValue) {
                            if (newValue != null) {
                              _onLocationChanged(newValue);
                            }
                          },
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Refresh Button
              if (!isLoading)
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    onPressed: _loadWeatherData,
                    icon: const Icon(Icons.refresh, color: Color(0xFF7F8C8D)),
                    tooltip: 'Refresh weather data',
                  ),
                ),

              // Weather Cards or Loading/Error States
              Expanded(
                child: _buildContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF7F8C8D)),
            SizedBox(height: 16),
            Text(
              'Loading weather data...',
              style: TextStyle(color: Color(0xFF7F8C8D), fontSize: 16),
            ),
          ],
        ),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Color(0xFFE74C3C),
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              errorMessage!,
              style: const TextStyle(color: Color(0xFFE74C3C), fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadWeatherData,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2C3E50),
                foregroundColor: const Color(0xFFECF0F1),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (weatherData == null) {
      return const Center(
        child: Text(
          'No weather data available',
          style: TextStyle(color: Color(0xFF7F8C8D), fontSize: 16),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: WeatherCard(
            title: 'Today',
            weatherData: weatherData?['today'] ??
                WeatherData(
                  dayTemp: 20,
                  nightTemp: 15,
                  dayRain: false,
                  nightRain: false,
                ),
            backgroundColor: const Color(0xFF2C3E50),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: WeatherCard(
            title: 'Tomorrow',
            weatherData: weatherData?['tomorrow'] ??
                WeatherData(
                  dayTemp: 18,
                  nightTemp: 12,
                  dayRain: false,
                  nightRain: false,
                ),
            backgroundColor: const Color(0xFF34495E),
          ),
        ),
      ],
    );
  }
}

class WeatherCard extends StatelessWidget {
  final String title;
  final WeatherData weatherData;
  final Color backgroundColor;

  const WeatherCard({
    Key? key,
    required this.title,
    required this.weatherData,
    required this.backgroundColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFFECF0F1),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              children: [
                // Day Section
                Expanded(
                  child: _buildWeatherSection(
                    'Day',
                    weatherData.dayTemp,
                    weatherData.dayRain,
                    const Color(0xFFF39C12),
                  ),
                ),
                const SizedBox(width: 12),
                // Night Section
                Expanded(
                  child: _buildWeatherSection(
                    'Night',
                    weatherData.nightTemp,
                    weatherData.nightRain,
                    const Color(0xFF8E44AD),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherSection(
      String timeOfDay, int temp, bool isRaining, Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withOpacity(0.3), width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              timeOfDay,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: accentColor,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                isRaining ? '🌧️' : '☀️',
                style: const TextStyle(fontSize: 36),
              ),
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '$temp°C',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFFECF0F1),
              ),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              isRaining ? 'Rainy' : 'Clear',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFFBDC3C7),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class WeatherData {
  final int dayTemp;
  final int nightTemp;
  final bool dayRain;
  final bool nightRain;

  WeatherData({
    required this.dayTemp,
    required this.nightTemp,
    required this.dayRain,
    required this.nightRain,
  });
}
