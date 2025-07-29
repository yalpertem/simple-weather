import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

class WeatherHomePage extends StatefulWidget {
  const WeatherHomePage({Key? key}) : super(key: key);

  @override
  State<WeatherHomePage> createState() => _WeatherHomePageState();
}

class _WeatherHomePageState extends State<WeatherHomePage> {
  final List<String> locations = ['Aydın', 'Berlin', 'Kuşadası', 'Mersin'];
  String selectedLocation = 'Berlin';

  // Mock weather data
  final Map<String, Map<String, WeatherData>> weatherData = {
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

  @override
  void initState() {
    super.initState();
    _loadSavedLocation();
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
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          selectedLocation = newValue;
                        });
                        _saveLocation(newValue);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Weather Cards
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: WeatherCard(
                        title: 'Today',
                        weatherData: weatherData[selectedLocation]!['today']!,
                        backgroundColor: const Color(0xFF2C3E50),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: WeatherCard(
                        title: 'Tomorrow',
                        weatherData:
                            weatherData[selectedLocation]!['tomorrow']!,
                        backgroundColor: const Color(0xFF34495E),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
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
