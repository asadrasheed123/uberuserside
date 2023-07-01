import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Completer<GoogleMapController> _controller = Completer();
  StreamSubscription<LocationData>? _locationSubscription;
  LatLng? _userLocation;
  LatLng? _riderLocation;
  Map<String, Marker> _markers = {};
  Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    // Start listening to location updates
    _startLocationUpdates();
  }

  @override
  void dispose() {
    _stopLocationUpdates();
    super.dispose();
  }

  void _updateLocation(LatLng newLocation, String personId) {
    final marker = _markers[personId];
    if (marker != null) {
      _markers[personId] = marker.copyWith(positionParam: newLocation);
    } else {
      _markers[personId] = Marker(
        markerId: MarkerId(personId),
        position: newLocation,
      );
    }
    setState(() {});
  }

  void _updatePolylines() async {
    if (_userLocation != null && _riderLocation != null) {
      // Fetch the polyline representing the route between user and rider
      final polylinePoints = await _getPolylinePoints(_userLocation!, _riderLocation!);
      if (polylinePoints != null && polylinePoints.isNotEmpty) {
        final polyline = Polyline(
          polylineId: PolylineId('route'),
          color: Colors.blue,
          points: polylinePoints,
        );
        _polylines = {polyline};
      } else {
        _polylines = {};
      }
      setState(() {});
    }
  }

  Future<List<LatLng>?> _getPolylinePoints(LatLng origin, LatLng destination) async {
    final apiKey = 'YOUR_API_KEY'; // Replace with your Google Maps Directions API key
    final url =
        'https://maps.googleapis.com/maps/api/directions/json?origin=${origin.latitude},${origin.longitude}&destination=${destination.latitude},${destination.longitude}&key=$apiKey';

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final jsonResult = json.decode(response.body);
      final routes = jsonResult['routes'] as List<dynamic>;
      if (routes.isNotEmpty) {
        final points = routes[0]['overview_polyline']['points'] as String;
        return _decodePolyline(points);
      }
    }
    return null;
  }

  List<LatLng> _decodePolyline(String encodedPolyline) {
    final List<LatLng> polylinePoints = [];
    int index = 0;
    int len = encodedPolyline.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int b;
      int shift = 0;
      int result = 0;
      do {
        b = encodedPolyline.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encodedPolyline.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      final LatLng point = LatLng(lat / 1E5, lng / 1E5);
      polylinePoints.add(point);
    }
    return polylinePoints;
  }

  void _startLocationUpdates() async {
    final location = Location();
    final serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      bool enabled = await location.requestService();
      if (!enabled) {
        // Handle the case where the user denies enabling the location service
        return;
      }
    }

    final permissionGranted = await location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      final permissionStatus = await location.requestPermission();
      if (permissionStatus != PermissionStatus.granted) {
        // Handle the case where the user denies granting location permission
        return;
      }
    }

    _locationSubscription = location.onLocationChanged.listen((LocationData? locationData) {
      if (locationData != null && locationData.latitude != null && locationData.longitude != null) {
        final newLocation = LatLng(locationData.latitude!, locationData.longitude!);
        _userLocation = newLocation;
        _updateLocation(newLocation, "user");
        _updatePolylines();
      }
    });

    // Set the rider's location to a static coordinate in Pakistan
    final riderLocation = LatLng(30.3753, 69.3451); // Set the rider's latitude and longitude
    _riderLocation = riderLocation;
    _updateLocation(riderLocation, "rider");
    _updatePolylines();
  }

  void _stopLocationUpdates() {
    _locationSubscription?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text('User Side'),
        ),
        body: Column(
          children: [
            Expanded(
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(37.7749, -122.4194), // Initial location (e.g., San Francisco)
                  zoom: 10.0,
                ),
                onMapCreated: (GoogleMapController controller) {
                  _controller.complete(controller);
                },
                markers: Set<Marker>.of(_markers.values),
                polylines: _polylines,
                myLocationEnabled: true, // Enable the blue dot indicating user's location
              ),
            ),
          ],
        ),
      ),
    );
  }
}
