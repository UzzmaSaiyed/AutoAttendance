import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool isCheckedIn = false;
  String locationStatus = 'Outside Office Area';
  DateTime? checkInTime;
  DateTime? checkOutTime;
  Duration? duration;

  List<Map<String, String>> reportList = [];
  GoogleMapController? _mapController;
  LatLng _initialPosition =
      const LatLng(37.4219999, -122.0840575); // Default position (Google HQ)
  LatLng? _currentPosition;

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
  }

  Future<void> _requestLocationPermission() async {
    final status = await Permission.location.status;

    if (status.isGranted) {
      _getCurrentLocation();
    } else if (status.isDenied) {
      final result = await Permission.location.request();
      if (result.isGranted) {
        _getCurrentLocation();
      } else {
        // Show a SnackBar or alert informing the user about the need for location access
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Location permission is required to use this feature.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else if (status.isPermanentlyDenied) {
      // Open app settings if permission is permanently denied
      await openAppSettings();
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
        _initialPosition = _currentPosition!;
      });
      if (_mapController != null) {
        _mapController!
            .animateCamera(CameraUpdate.newLatLng(_currentPosition!));
      }
    } catch (e) {
      // Handle error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to get current location: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void toggleCheckIn() {
    setState(() {
      if (isCheckedIn) {
        checkOutTime = DateTime.now();
        duration = checkOutTime!.difference(checkInTime!);
        locationStatus = 'Checked Out: Outside Office Area';

        reportList.add({
          'date': DateFormat('yyyy-MM-dd').format(checkInTime!),
          'checkIn': DateFormat('hh:mm a').format(checkInTime!),
          'checkOut': DateFormat('hh:mm a').format(checkOutTime!),
          'duration': formatDuration(duration),
        });
      } else {
        checkInTime = DateTime.now();
        locationStatus = 'Checked In: Within Office Area';
        checkOutTime = null;
        duration = null;
      }
      isCheckedIn = !isCheckedIn;
    });
  }

  String formatTime(DateTime? time) {
    return time != null ? DateFormat('hh:mm a').format(time) : '--:--';
  }

  String formatDuration(Duration? duration) {
    if (duration == null) return '--:--:--';
    return duration.toString().split('.').first;
  }

  void _logout() {
    Navigator.pushReplacementNamed(context, '/signup');
  }

  Future<void> _navigateToManual() async {
    final result = await Navigator.pushNamed(context, '/manual');

    if (result == 'checkIn' && !isCheckedIn) {
      toggleCheckIn(); // Perform manual check-in
    } else if (result == 'checkOut' && isCheckedIn) {
      toggleCheckIn(); // Perform manual check-out
    }
  }

  void _navigateToReport() {
    Navigator.pushNamed(context, '/report', arguments: reportList);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt),
            onPressed: _navigateToReport, // Navigate to Report Screen
          ),
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: _navigateToManual, // Open Manual Actions
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: toggleCheckIn,
              style: ElevatedButton.styleFrom(
                backgroundColor: isCheckedIn ? Colors.red : Colors.greenAccent,
                shape: const CircleBorder(),
                padding: const EdgeInsets.all(60),
              ),
              child: Text(
                isCheckedIn ? 'Check-Out' : 'Check-In',
                style: const TextStyle(fontSize: 20),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Status: $locationStatus',
              style: TextStyle(fontSize: 18, color: Colors.grey[700]),
            ),
            const SizedBox(height: 20),
            Text(
              'Check-In Time: ${formatTime(checkInTime)}',
              style: const TextStyle(fontSize: 18),
            ),
            Text(
              'Check-Out Time: ${formatTime(checkOutTime)}',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 20),
            Text(
              'Duration: ${formatDuration(duration)}',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 30),
            Container(
              height: 300,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.blueAccent),
              ),
              child: _currentPosition == null
                  ? const Center(child: CircularProgressIndicator())
                  : GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: _initialPosition,
                        zoom: 14,
                      ),
                      onMapCreated: (GoogleMapController controller) {
                        _mapController = controller;
                        if (_currentPosition != null) {
                          _mapController!.animateCamera(
                            CameraUpdate.newLatLng(_currentPosition!),
                          );
                        }
                      },
                      markers: {
                        if (_currentPosition != null)
                          Marker(
                            markerId: const MarkerId('currentLocation'),
                            position: _currentPosition!,
                            infoWindow:
                                const InfoWindow(title: 'Your Location'),
                          ),
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
