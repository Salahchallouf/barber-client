import 'package:barbar/main.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:barbar/screens/Map_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const BarberClientApp());
}

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen>
    with TickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  String _selectedService = 'Coupe';
  DateTime? _selectedDateTime;

  late final Stream<DocumentSnapshot> _barberStatusStream;

  bool _isBookingDone = false; // Pour désactiver la saisie après réservation
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _barberStatusStream = FirebaseFirestore.instance
        .collection('barber_status')
        .doc('status')
        .snapshots();
    _loadClientInfo(); // Charger les infos client automatiquement
  }

  Future<void> _loadClientInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('clients')
          .doc(user.uid)
          .get();
      if (doc.exists) {
        final data = doc.data();
        setState(() {
          _nameController.text = data?['nom'] ?? '';
          _phoneController.text = data?['telephone'] ?? '';
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _pickDateTime() async {
    if (_isBookingDone) return; // bloquer si déjà réservé

    final today = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: today,
      lastDate: today,
      helpText: 'Sélectionner une date',
    );

    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: const TimeOfDay(hour: 10, minute: 0),
        helpText: 'Sélectionner l\'heure',
      );

      if (time != null) {
        setState(() {
          _selectedDateTime = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  Future<bool> hasBookingOnSelectedDate() async {
    if (_selectedDateTime == null || _phoneController.text.isEmpty) {
      return false;
    }

    final startOfDay = DateTime(
      _selectedDateTime!.year,
      _selectedDateTime!.month,
      _selectedDateTime!.day,
    );
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final querySnapshot = await FirebaseFirestore.instance
        .collection('appointments')
        .where('phone', isEqualTo: _phoneController.text)
        .where(
          'timestamp',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
        )
        .where('timestamp', isLessThan: Timestamp.fromDate(endOfDay))
        .get();

    return querySnapshot.docs.isNotEmpty;
  }

  Future<void> _submitBooking() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('barber_status')
        .doc('status')
        .get();

    final isOpen = (snapshot.data()?['isOpen'] ?? false);

    if (!isOpen) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Le barbier est actuellement fermé, impossible de prendre un rendez-vous.',
          ),
        ),
      );
      return;
    }

    if (_nameController.text.isEmpty ||
        _phoneController.text.isEmpty ||
        _selectedDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez remplir tous les champs')),
      );
      return;
    }

    final alreadyBooked = await hasBookingOnSelectedDate();
    if (alreadyBooked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vous avez déjà un rendez-vous ce jour-là.'),
        ),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Vous devez être connecté')));
      return;
    }

    await FirebaseFirestore.instance.collection('appointments').add({
      'name': _nameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'service': _selectedService,
      'timestamp': Timestamp.fromDate(_selectedDateTime!),
      'status': 'En attente',
      'userId': user.uid, // Sauvegarde userId pour vérification future
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('✅ Rendez-vous enregistré !')));

    setState(() {
      _isBookingDone = true;
    });
  }

  Widget _statusBadge(String status) {
    Color color;
    Icon icon;

    switch (status) {
      case 'En attente':
        color = Colors.orange.shade700;
        icon = const Icon(Icons.schedule, color: Colors.white, size: 16);
        break;
      case 'En charge':
        color = Colors.blueGrey;
        icon = const Icon(Icons.work, color: Colors.white, size: 16);
        break;
      case 'Confirmé':
        color = Colors.green.shade600;
        icon = const Icon(Icons.check_circle, color: Colors.white, size: 16);
        break;
      case 'Servi':
        color = Colors.teal.shade800;
        icon = const Icon(Icons.verified, color: Colors.white, size: 16);
        break;
      case 'Absent':
        color = Colors.red.shade700;
        icon = const Icon(Icons.cancel, color: Colors.white, size: 16);
        break;
      default:
        color = Colors.grey;
        icon = const Icon(Icons.help_outline, color: Colors.white, size: 16);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(width: 4),
          Text(status, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Palette couleurs inspirée du bois et cuivre
    const primaryColor = Color(0xFF5D4037); // brun bois foncé
    const secondaryColor = Color(0xFFD7A86E); // doré clair
    const backgroundGradientStart = Color(0xFF3E2723); // brun foncé
    const backgroundGradientEnd = Color(0xFF1B120D); // très foncé

    final String dateTimeText = _selectedDateTime == null
        ? 'Sélectionner une date et heure'
        : DateFormat('dd/MM/yyyy – HH:mm').format(_selectedDateTime!);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Réserver un rendez-vous'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.location_on),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MapPage()),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _barberStatusStream,
        builder: (context, snapshot) {
          bool isOpen = false;
          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>?;
            isOpen = data?['isOpen'] ?? false;
          }

          return Column(
            children: [
              Container(
                width: double.infinity,
                color: isOpen ? Colors.green[700] : Colors.red[700],
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Center(
                  child: Text(
                    isOpen ? 'Le barbier est ouvert' : 'Le barbier est fermé',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [backgroundGradientStart, backgroundGradientEnd],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Informations du client',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFD7A86E),
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Champ Nom
                        TextField(
                          controller: _nameController,
                          readOnly: true,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Nom',
                            labelStyle: TextStyle(
                              color: secondaryColor.withOpacity(0.8),
                            ),
                            prefixIcon: Icon(
                              Icons.person,
                              color: secondaryColor,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: secondaryColor.withOpacity(0.6),
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: secondaryColor,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            filled: true,
                            fillColor: primaryColor.withOpacity(0.3),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Champ Téléphone
                        TextField(
                          controller: _phoneController,
                          readOnly: true,
                          keyboardType: TextInputType.phone,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Téléphone',
                            labelStyle: TextStyle(
                              color: secondaryColor.withOpacity(0.8),
                            ),
                            prefixIcon: Icon(
                              Icons.phone,
                              color: secondaryColor,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: secondaryColor.withOpacity(0.6),
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: secondaryColor,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            filled: true,
                            fillColor: primaryColor.withOpacity(0.3),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Dropdown Services
                        DropdownButtonFormField<String>(
                          value: _selectedService,
                          dropdownColor: primaryColor,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Service',
                            labelStyle: TextStyle(
                              color: secondaryColor.withOpacity(0.8),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: secondaryColor.withOpacity(0.6),
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: secondaryColor,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            filled: true,
                            fillColor: primaryColor.withOpacity(0.3),
                          ),
                          onChanged: !_isBookingDone
                              ? (val) => setState(() => _selectedService = val!)
                              : null,
                          items: ['Coupe', 'Barbe', 'Coupe + Barbe']
                              .map(
                                (service) => DropdownMenuItem(
                                  value: service,
                                  child: Text(service),
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: 20),

                        // Bouton date et heure
                        Center(
                          child: ElevatedButton.icon(
                            onPressed: !_isBookingDone ? _pickDateTime : null,
                            icon: const Icon(Icons.calendar_today),
                            label: Text(dateTimeText),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: secondaryColor,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 24,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Bouton confirmer
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.check),
                            onPressed: (!_isBookingDone && isOpen)
                                ? _submitBooking
                                : null,
                            label: const Text('Confirmer le rendez-vous'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 5,
                            ),
                          ),
                        ),

                        const SizedBox(height: 36),

                        // Diviseurs et titres sections rendez-vous
                        Divider(
                          thickness: 1.5,
                          color: secondaryColor.withOpacity(0.7),
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: Text(
                            'Les rendez-vous à venir',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: secondaryColor,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                        _buildAppointments(['En attente', 'En charge']),
                        const SizedBox(height: 36),
                        Divider(
                          thickness: 1.5,
                          color: secondaryColor.withOpacity(0.7),
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: Text(
                            'Mes rendez-vous confirmés',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: secondaryColor,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                        _buildAppointments(['Confirmé']),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAppointments(List<String> statuses) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('appointments')
          .where('status', whereIn: statuses)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Center(
              child: Text(
                'Aucun rendez-vous.',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          );
        }

        docs.sort((a, b) {
          final aDate = (a['timestamp'] as Timestamp).toDate();
          final bDate = (b['timestamp'] as Timestamp).toDate();
          return aDate.compareTo(bDate);
        });

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final status = data['status'] ?? statuses.first;

            return Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.brown,
                  child: Icon(Icons.person, color: Colors.white),
                ),
                title: Text('${data['name']} - ${data['service']}'),
                subtitle: Text(
                  '📞 ${data['phone']} – ${DateFormat('dd/MM/yyyy – HH:mm').format(data['timestamp'].toDate())}',
                ),
                trailing: _statusBadge(status),
              ),
            );
          },
        );
      },
    );
  }
}
