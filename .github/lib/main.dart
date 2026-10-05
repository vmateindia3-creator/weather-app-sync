import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const WeatherApp());
}

class WeatherApp extends StatelessWidget {
  const WeatherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Dynamic Weather App',
      home: WeatherHomeScreen(),
    );
  }
}

class WeatherHomeScreen extends StatefulWidget {
  const WeatherHomeScreen({super.key});

  @override
  State<WeatherHomeScreen> createState() => _WeatherHomeScreenState();
}

class _WeatherHomeScreenState extends State<WeatherHomeScreen> {
  final TextEditingController _cityController = TextEditingController();
  
  String _liveWeatherInfo = "Live location track ho rahi hai...";
  String _searchedWeatherInfo = "City search karne ke liye naam dalein";
  String _globalData = "Firebase se global data load ho raha hai...";
  
  double _currentTemperature = 20.0; // Default temp
  final String apiKey = "YOUR_OPENWEATHER_API_KEY";

  @override
  void initState() {
    super.initState();
    _fetchLiveLocationWeather();
    _fetchGlobalDataFromFirebase();
  }

  // Dynamic Colors: 28°C se zyada par White background, kam par Black background
  Color get backgroundColor => _currentTemperature > 28 ? Colors.white : Colors.black;
  Color get textColor => _currentTemperature > 28 ? Colors.black : Colors.white;
  Color get containerColor => _currentTemperature > 28 ? Colors.grey[200]! : Colors.grey[900]!;

  // 1. Live GPS Location Track karke Weather nikalna
  Future<void> _fetchLiveLocationWeather() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      String? cityName = placemarks.isNotEmpty ? placemarks[0].locality : "Current Location";
      
      final url = Uri.parse('https://api.openweathermap.org/data/2.5/weather?lat=${position.latitude}&lon=${position.longitude}&units=metric&appid=$apiKey');
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        double temp = data['main']['temp'].toDouble();
        setState(() {
          _currentTemperature = temp; // Background color update hoga
          _liveWeatherInfo = "$cityName: $temp°C, ${data['weather'][0]['description']}";
        });
      }
    } catch (e) {
      setState(() => _liveWeatherInfo = "Live weather fetch karne me error aayi.");
    }
  }

  // 2. City Type karke Search karna
  Future<void> _searchCityWeather(String cityName) async {
    if (cityName.isEmpty) return;
    try {
      final url = Uri.parse('https://api.openweathermap.org/data/2.5/weather?q=$cityName&units=metric&appid=$apiKey');
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        double temp = data['main']['temp'].toDouble();
        setState(() {
          _currentTemperature = temp; // Search kiye gaye city ke temp par background change hoga
          _searchedWeatherInfo = "$cityName: $temp°C, ${data['weather'][0]['description']}";
        });
      } else {
        setState(() => _searchedWeatherInfo = "City nahi mili.");
      }
    } catch (e) {
      setState(() => _searchedWeatherInfo = "Connection error.");
    }
  }

  // 3. Firebase se Global Data Read Karna (GitHub Actions sync data)
  void _fetchGlobalDataFromFirebase() {
    DatabaseReference ref = FirebaseDatabase.instance.ref().child("global_temperatures");
    ref.onValue.listen((event) {
      if (event.snapshot.value != null) {
        Map data = event.snapshot.value as Map;
        setState(() {
          _globalData = "${data['city']}: ${data['temperature']}°C (${data['condition']})";
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 600), // Smooth color transition effect
      color: backgroundColor,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text("Live Weather & Tracker", style: TextStyle(color: textColor)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: textColor),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("📍 Live Location Weather", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _currentTemperature > 28 ? Colors.blue[800] : Colors.blueAccent)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: containerColor, borderRadius: BorderRadius.circular(12)),
                child: Text(_liveWeatherInfo, style: TextStyle(fontSize: 16, color: textColor)),
              ),
              const SizedBox(height: 24),
              Text("🔍 Search City Weather", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _currentTemperature > 28 ? Colors.blue[800] : Colors.blueAccent)),
              const SizedBox(height: 8),
              TextField(
                controller: _cityController,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  hintText: "City ka naam likhein...",
                  hintStyle: TextStyle(color: textColor.withOpacity(0.6)),
                  filled: true,
                  fillColor: containerColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  suffixIcon: IconButton(
                    icon: Icon(Icons.search, color: textColor),
                    onPressed: () => _searchCityWeather(_cityController.text.trim()),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: containerColor, borderRadius: BorderRadius.circular(12)),
                child: Text(_searchedWeatherInfo, style: TextStyle(fontSize: 16, color: textColor)),
              ),
              const SizedBox(height: 24),
              Text("🌍 Global Data (Firebase Sync)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _currentTemperature > 28 ? Colors.blue[800] : Colors.blueAccent)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: containerColor, borderRadius: BorderRadius.circular(12)),
                child: Text(_globalData, style: TextStyle(fontSize: 14, color: textColor)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
