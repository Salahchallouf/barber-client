import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MapPage(),
    );
  }
}

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final MapController _mapController = MapController();
  LatLng? _userPosition;
  List<Marker> _firebaseMarkers = [];

  @override
  void initState() {
    super.initState();
    _initLocation();
    _loadFirestoreMarkers();
  }

  Future<void> _initLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever)
      return;

    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    ).listen((Position position) {
      setState(() {
        _userPosition = LatLng(position.latitude, position.longitude);
      });
    });
  }

  Future<void> _loadFirestoreMarkers() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('markers')
        .get();
    final markers = snapshot.docs.map((doc) {
      final data = doc.data();
      final LatLng point = LatLng(data['lat'], data['lng']);
      final titre = data['titre'] ?? 'Sans titre';
      final description = data['description'] ?? 'Aucune description';

      return Marker(
        point: point,
        width: 80,
        height: 80,
        child: GestureDetector(
          onTap: () {
            _mapController.move(point, 17);
            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: Text(titre),
                content: Text(description),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Fermer"),
                  ),
                ],
              ),
            );
          },
          child: const Icon(Icons.location_on, color: Colors.green, size: 40),
        ),
      );
    }).toList();

    setState(() {
      _firebaseMarkers = markers;
    });
  }

  void _addMarker() async {
    await FirebaseFirestore.instance.collection('markers').add({
      'lat': _userPosition?.latitude ?? 0,
      'lng': _userPosition?.longitude ?? 0,
      'titre': 'Nouveau Marqueur',
      'description': 'Ajouté depuis le app Flutter',
    });
    _loadFirestoreMarkers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Localisation du Barbier")),
      body: _userPosition == null
          ? const Center(child: CircularProgressIndicator())
          : FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _userPosition!,
                initialZoom: 15,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c'],
                  userAgentPackageName: 'com.example.mapapp',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _userPosition!,
                      width: 60,
                      height: 60,
                      child: const Icon(
                        Icons.person_pin_circle,
                        color: Colors.blue,
                        size: 40,
                      ),
                    ),
                    ..._firebaseMarkers,
                  ],
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addMarker,
        child: const Icon(Icons.add_location_alt),
      ),
    );
  }
}
