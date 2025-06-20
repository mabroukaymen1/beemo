import 'package:weather/weather.dart';

class WeatherService {
  final WeatherFactory wf;

  WeatherService(String apiKey) : wf = WeatherFactory(apiKey);

  Future<Weather> getCurrentWeather(double lat, double lon) async {
    try {
      return await wf.currentWeatherByLocation(lat, lon);
    } catch (e) {
      throw Exception('Failed to fetch weather data: $e');
    }
  }

  Future<List<Weather>> getForecast(double lat, double lon) async {
    try {
      return await wf.fiveDayForecastByLocation(lat, lon);
    } catch (e) {
      throw Exception('Failed to fetch forecast data: $e');
    }
  }
}
