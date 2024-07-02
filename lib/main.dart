import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: MapScreen(),
      ),
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController mapController = MapController();
  List<LatLng> routePoints = [];
  LatLng? currentLocation;
  LatLng? destinationLocation;
  bool navigating = false;
  bool directionReady = false;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    getCurrentLocation();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Map App'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(
          10,
        ),
        child: currentLocation == null
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : Column(
                children: [
                  Expanded(
                    child: FlutterMap(
                      mapController: mapController,
                      options: MapOptions(
                        initialCenter: currentLocation!,
                        initialZoom: 18,
                        onTap: (tapPosition, point) {
                          navigating ? null : selectDestination(point);
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.example.app',
                          subdomains: ['a', 'b', 'c'],
                        ),
                        if (directionReady)
                          PolylineLayer(
                            polylines: [
                              Polyline(
                                points: routePoints,
                                strokeWidth: 8.0,
                                color: directionReady
                                    ? Colors.blue
                                    : Colors.orange,
                              )
                            ],
                          ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              width: 80.0,
                              height: 80.0,
                              point: currentLocation!,
                              child: const Icon(
                                Icons.my_location_rounded,
                                color: Colors.blue,
                                size: 30.0,
                              ),
                            ),
                            if (destinationLocation != null)
                              Marker(
                                width: 80.0,
                                height: 80.0,
                                point: destinationLocation!,
                                child: const Icon(
                                  Icons.location_on,
                                  color: Colors.red,
                                  size: 50.0,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: navigating
            ? Colors.red[700]
            : destinationLocation != null
                ? Colors.blue
                : Colors.grey,
        onPressed: () => navigating
            ? outNavigating()
            : directionReady
                ? startNavigation()
                : showRoute(),
        child: navigating
            ? Icon(
                Icons.stop_circle_outlined,
                color: Colors.white,
              )
            : directionReady
                ? Icon(
                    Icons.navigation,
                    color: Colors.black,
                  )
                : Icon(
                    Icons.directions,
                    color: Colors.black,
                  ),
      ),
    );
  }

  Future<void> getCurrentLocation() async {
    var status = await Permission.location.request();
    if (status.isGranted) {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        currentLocation = LatLng(position.latitude, position.longitude);
      });
    }
  }

  void showRoute() async {
    if (currentLocation != null && destinationLocation != null) {
      print("Routing");
      final start = currentLocation!;
      final end = destinationLocation!;

      final route = await getRoute(start, end);

      setState(() {
        routePoints = route;
        directionReady = true;
      });
      mapController.move(start, 14.0);
    }
  }

  Future<List<LatLng>> getRoute(LatLng start, LatLng end) async {
    final url =
        'http://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List<LatLng> route = [];

      for (final point in data['routes'][0]['geometry']['coordinates']) {
        route.add(LatLng(point[1], point[0]));
      }

      return route;
    } else {
      throw Exception('Failed to load route');
    }
  }

  void startNavigation() {
    if (currentLocation != null && destinationLocation != null) {
      print("Navigating");
      Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
        ),
      ).listen((Position position) {
        setState(() {
          navigating = true;
          currentLocation = LatLng(position.latitude, position.longitude);
        });
        mapController.move(currentLocation!, 18.0);
      });
    }
  }

  outNavigating() {
    print("out Navigating");
    setState(() {
      routePoints = [currentLocation!];
      destinationLocation = null;
      directionReady = false;
      navigating = false;
      mapController.move(currentLocation!, 18.0);
    });
  }

  void selectDestination(LatLng point) {
    setState(() {
      navigating = false;
      directionReady = false;
      destinationLocation = point;
      routePoints = [currentLocation!, destinationLocation!];
    });
  }
}
