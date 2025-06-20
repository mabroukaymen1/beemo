import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';

class LocationSelectionScreen extends StatefulWidget {
  final LatLng? initialLocation;

  const LocationSelectionScreen({
    Key? key,
    this.initialLocation,
  }) : super(key: key);

  @override
  _LocationSelectionScreenState createState() =>
      _LocationSelectionScreenState();
}

class _LocationSelectionScreenState extends State<LocationSelectionScreen> {
  GoogleMapController? _mapController;
  LatLng? _selectedLocation;
  String _selectedAddress = "Tap on the map to select a location";
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;
  List<Placemark> _searchResults = [];

  // Predefined locations for quick selection
  final List<Map<String, dynamic>> _predefinedLocations = [
    {
      'name': 'Monastir City Center',
      'latLng': LatLng(35.7643, 10.8113),
    },
    {
      'name': 'Monastir Marina',
      'latLng': LatLng(35.7671, 10.8168),
    },
    {
      'name': 'Monastir Airport',
      'latLng': LatLng(35.7580, 10.7547),
    },
  ];

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initializeLocation() async {
    setState(() => _isLoading = true);

    if (widget.initialLocation != null) {
      await _updateLocation(widget.initialLocation!);
    } else {
      await _determineCurrentPosition();
    }

    setState(() => _isLoading = false);
  }

  Future<void> _determineCurrentPosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permission denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied');
      }

      Position position = await Geolocator.getCurrentPosition();
      await _updateLocation(LatLng(position.latitude, position.longitude));
    } catch (e) {
      // Default to Monastir center if there's an error
      await _updateLocation(LatLng(35.7643, 10.8113));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not access location: ${e.toString()}')),
      );
    }
  }

  Future<void> _updateLocation(LatLng location) async {
    setState(() => _selectedLocation = location);
    await _getAddressFromLatLng(location);
    if (_mapController != null) {
      // Only animate if map controller is ready
      _mapController!.animateCamera(CameraUpdate.newLatLngZoom(location, 15));
    }
  }

  Future<void> _getAddressFromLatLng(LatLng location) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        location.latitude,
        location.longitude,
      );
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        setState(() {
          _selectedAddress = "${place.street ?? ''}"
              "${place.street != null && place.locality != null ? ', ' : ''}"
              "${place.locality ?? ''}"
              "${place.locality != null && place.country != null ? ', ' : ''}"
              "${place.country ?? ''}";
        });
      }
    } catch (e) {
      setState(() => _selectedAddress = "Location not found");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting address: ${e.toString()}')),
      );
    }
  }

  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    try {
      List<Location> locations = await locationFromAddress(query);
      if (locations.isNotEmpty) {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          locations[0].latitude,
          locations[0].longitude,
        );
        setState(() => _searchResults = placemarks);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error searching location: ${e.toString()}')),
      );
    }
  }

  void _confirmLocation() {
    if (_selectedLocation != null) {
      Navigator.pop(context, {
        'address': _selectedAddress,
        'latitude': _selectedLocation!.latitude,
        'longitude': _selectedLocation!.longitude,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: _buildAppBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSearchSection(),
                Expanded(child: _buildMapSection()),
                _buildBottomSection(),
              ],
            ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: Text(
        "Select Location",
        style: GoogleFonts.lato(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
      ),
      backgroundColor: const Color(0xFFD72F2F),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFD72F2F), Color(0xFFFF6B6B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search location...',
              prefixIcon: const Icon(Icons.search, color: Color(0xFFD72F2F)),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchResults = []);
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            onChanged: (value) => _searchLocation(value),
          ),
          if (_searchResults.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _searchResults.length.clamp(0, 3),
                itemBuilder: (context, index) {
                  final place = _searchResults[index];
                  return ListTile(
                    title: Text(
                      place.street ?? 'Unknown location',
                      style: GoogleFonts.lato(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '${place.locality ?? ''}, ${place.country ?? ''}',
                      style: GoogleFonts.lato(),
                    ),
                    onTap: () async {
                      List<Location> locations = await locationFromAddress(
                        "${place.street}, ${place.locality}, ${place.country}",
                      );
                      if (locations.isNotEmpty) {
                        await _updateLocation(
                          LatLng(locations[0].latitude, locations[0].longitude),
                        );
                      }
                      _searchController.clear();
                      setState(() => _searchResults = []);
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMapSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 12,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _selectedLocation ?? const LatLng(35.7643, 10.8113),
                zoom: 15,
              ),
              onMapCreated: (controller) {
                _mapController = controller;
                if (_selectedLocation != null) {
                  // After creation, animate if needed
                  _mapController!.animateCamera(
                      CameraUpdate.newLatLngZoom(_selectedLocation!, 15));
                }
              },
              markers: _selectedLocation == null
                  ? {}
                  : {
                      Marker(
                        markerId: const MarkerId('selected'),
                        position: _selectedLocation!,
                        infoWindow: InfoWindow(title: _selectedAddress),
                      ),
                    },
              onTap: _updateLocation,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
            ),
            Positioned(
              top: 16,
              right: 16,
              child: FloatingActionButton(
                mini: true,
                onPressed: _determineCurrentPosition,
                backgroundColor: const Color(0xFFD72F2F),
                child: const Icon(Icons.my_location, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 12,
            spreadRadius: 2,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: SvgPicture.asset(
              'assets/svg/app.svg',
              height: 32,
              width: 32,
            ),
            title: Text(
              _selectedAddress,
              style: GoogleFonts.lato(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _predefinedLocations.map((location) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    label: Text(
                      location['name'],
                      style: GoogleFonts.lato(
                        color: Colors.grey[800],
                      ),
                    ),
                    onPressed: () => _updateLocation(location['latLng']),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _selectedLocation != null ? _confirmLocation : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD72F2F),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              "Confirm Location",
              style: GoogleFonts.lato(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
