import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';

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

  void _updatePolylines() {
    if (_userLocation != null && _riderLocation != null) {
      // Clear the existing polylines
      _polylines.clear();

      // Add a polyline between user and rider locations
      final polyline = Polyline(
        polylineId: PolylineId('route'),
        color: Colors.blue,
        points: [_userLocation!, _riderLocation!],
      );
      _polylines.add(polyline);

      setState(() {});
    }
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
        _moveCameraToUserLocation(newLocation);
      }
    });

    // Set the rider's location to a static coordinate in Pakistan
    final riderLocation = LatLng(30.3753, 69.3451); // Set the rider's latitude and longitude
    _riderLocation = riderLocation;
    _updateLocation(riderLocation, "rider");
    _updatePolylines();
    _moveCameraToUserLocation(riderLocation);
  }

  void _stopLocationUpdates() {
    _locationSubscription?.cancel();
  }

  Future<void> _moveCameraToUserLocation(LatLng location) async {
    final controller = await _controller.future;
    controller.animateCamera(
      CameraUpdate.newLatLng(location),
    );
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
