import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'main.dart'; // Import to access models and services
import 'gemini_service.dart';

// =================================================================================
// My Listings Screen (Shows user's own produce)
// =================================================================================
class MyListingsScreen extends StatelessWidget {
  final String uid;
  final UserData userData;
  const MyListingsScreen({super.key, required this.uid, required this.userData});

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();
    return Scaffold(
      appBar: AppBar(title: const Text("My Farm Stand")),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showAddListingSheet(context, userData: userData);
        },
        label: const Text("List Produce"),
        icon: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<ProduceListing>>(
        stream: firestoreService.getMyListingsStream(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }
          final listings = snapshot.data ?? [];

          if (listings.isEmpty) {
            return const _EmptyState(
              icon: Icons.storefront_outlined,
              title: "Your Stand is Empty",
              message:
                  "Tap the 'List Produce' button to showcase your harvest to the community!",
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemCount: listings.length,
            itemBuilder: (context, index) {
              final listing = listings[index];
              return _MyListingCard(
                listing: listing,
                onEdit: () => _showAddListingSheet(context,
                    userData: userData, existingListing: listing),
                onDelete: () => _confirmDelete(context, listing.id!),
              );
            },
          );
        },
      ),
    );
  }

  void _showAddListingSheet(BuildContext context,
      {required UserData userData, ProduceListing? existingListing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) => AddListingSheet(
          userData: userData,
          existingListing: existingListing,
          scrollController: scrollController,
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, String listingId) async {
    final bool? shouldDelete = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Listing?"),
        content:
            const Text("Are you sure you want to permanently delete this listing?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text("Cancel")),
          TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text("Delete",
                  style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );

    if (shouldDelete == true) {
      await FirestoreService().deleteListing(listingId);
    }
  }
}

// =================================================================================
// Marketplace Screen (Shows all users' produce)
// =================================================================================
class MarketplaceScreen extends StatelessWidget {
  const MarketplaceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();
    return Scaffold(
      appBar: AppBar(title: const Text("Community Market")),
      body: StreamBuilder<List<ProduceListing>>(
        stream: firestoreService.getAllListingsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }
          final listings = snapshot.data ?? [];

          if (listings.isEmpty) {
            return const _EmptyState(
              icon: Icons.groups_2_outlined,
              title: "Market is Quiet",
              message:
                  "There are no listings from the community right now. Be the first to add something!",
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: listings.length,
            itemBuilder: (context, index) {
              return _MarketplaceCard(listing: listings[index]);
            },
          );
        },
      ),
    );
  }
}

// =================================================================================
// Add/Edit Listing Sheet (The "pop-up")
// =================================================================================
class AddListingSheet extends StatefulWidget {
  final UserData userData;
  final ProduceListing? existingListing;
  final ScrollController scrollController;

  const AddListingSheet({
    super.key,
    required this.userData,
    this.existingListing,
    required this.scrollController,
  });

  @override
  State<AddListingSheet> createState() => _AddListingSheetState();
}

class _AddListingSheetState extends State<AddListingSheet> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  final _phoneController = TextEditingController();

  final _firestoreService = FirestoreService();
  final _geminiService = GeminiService();

  Plant? _selectedPlant;
  List<Plant> _userPlants = [];
  bool _isLoadingPlants = true;
  bool _isSubmitting = false;
  bool _isFetchingAnalysis = false;

  @override
  void initState() {
    super.initState();
    _loadUserPlants();
    if (widget.existingListing != null) {
      _quantityController.text = widget.existingListing!.quantity;
      _priceController.text = widget.existingListing!.price;
      _phoneController.text = widget.existingListing!.phoneNumber ?? '';
    }
  }

  Future<void> _loadUserPlants() async {
    final plantsStream = _firestoreService.getPlantsStream(widget.userData.uid);
    final plants = await plantsStream.first; // Get the first emission

    Plant? initialPlant;
    if (widget.existingListing != null) {
      try {
        initialPlant = plants.firstWhere(
          (p) => p.name == widget.existingListing!.plantName,
        );
      } catch (e) {
        print("Could not find matching plant for existing listing: $e");
        initialPlant = null;
      }
    }

    setState(() {
      _userPlants = plants;
      _selectedPlant = initialPlant;
      _isLoadingPlants = false;
    });
  }

  Future<void> _getPriceAnalysis() async {
    if (_selectedPlant == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please select a plant first.")));
      return;
    }
    setState(() => _isFetchingAnalysis = true);
    try {
      final analysis = await _geminiService.getPriceAndMarketAnalysis(
          _selectedPlant!, _quantityController.text);
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("AI Market Insights"),
          content: SingleChildScrollView(child: MarkdownBody(data: analysis)),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text("Close")),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error fetching analysis: $e")));
    } finally {
      if (mounted) {
        setState(() => _isFetchingAnalysis = false);
      }
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedPlant == null) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Please select a plant.")));
        return;
      }
      setState(() => _isSubmitting = true);

      final newListing = ProduceListing(
        id: widget.existingListing?.id,
        userId: widget.userData.uid,
        username: widget.userData.username,
        userEmail: widget.userData.email,
        plantName: _selectedPlant!.name,
        plantType: _selectedPlant!.type,
        quantity: _quantityController.text,
        price: _priceController.text,
        phoneNumber:
            _phoneController.text.isNotEmpty ? _phoneController.text : null,
        timestamp: Timestamp.now(),
      );

      try {
        if (widget.existingListing != null) {
          await _firestoreService.updateListing(newListing);
        } else {
          await _firestoreService.addListing(newListing);
        }
        if (mounted) Navigator.of(context).pop();
      } catch (e) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Failed to submit: $e")));
      } finally {
        if (mounted) setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.grey.shade800,
                borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              widget.existingListing == null
                  ? "List Your Produce"
                  : "Edit Your Listing",
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: widget.scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _isLoadingPlants
                        ? const Center(child: CircularProgressIndicator())
                        : DropdownButtonFormField<Plant>(
                            value: _selectedPlant,
                            onChanged: (plant) =>
                                setState(() => _selectedPlant = plant),
                            decoration:
                                const InputDecoration(hintText: 'Select a Plant'),
                            items: _userPlants
                                .map((p) =>
                                    DropdownMenuItem(value: p, child: Text(p.name)))
                                .toList(),
                            validator: (v) =>
                                v == null ? 'Please select a plant' : null,
                          ),
                    const SizedBox(height: 16),
                    TextFormField(
                        controller: _quantityController,
                        decoration: const InputDecoration(
                            hintText: 'Quantity (e.g., 50 kg, 1 quintal)'),
                        validator: (v) => v!.isEmpty ? 'Required' : null),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                            child: TextFormField(
                                controller: _priceController,
                                decoration: const InputDecoration(
                                    hintText: 'Price (e.g., ₹2000)'),
                                validator: (v) =>
                                    v!.isEmpty ? 'Required' : null)),
                        const SizedBox(width: 8),
                        _isFetchingAnalysis
                            ? const Padding(
                                padding: EdgeInsets.all(12.0),
                                child: CircularProgressIndicator())
                            : IconButton.filled(
                                onPressed: _getPriceAnalysis,
                                icon: const Icon(Icons.insights),
                                tooltip: 'Get Price & Market Insights'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                        controller: _phoneController,
                        decoration: const InputDecoration(
                            hintText: 'Phone Number (Optional)'),
                        keyboardType: TextInputType.phone),
                    const SizedBox(height: 32),
                    _isSubmitting
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton(
                            onPressed: _submitForm,
                            child: Text(widget.existingListing == null
                                ? "Add to Market"
                                : "Save Changes"),
                          ),
                     const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =================================================================================
// Widgets for the Social Market
// =================================================================================

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  const _EmptyState(
      {required this.icon, required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80, color: Theme.of(context).primaryColor.withOpacity(0.5)),
            const SizedBox(height: 24),
            Text(title,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey.shade400)),
          ],
        ),
      ),
    );
  }
}


class _MyListingCard extends StatelessWidget {
  final ProduceListing listing;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _MyListingCard(
      {required this.listing, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 8, 20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
              child: Icon(getPlantIcon(listing.plantType),
                  color: Theme.of(context).primaryColor, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(listing.plantName,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  Text("${listing.quantity} - ${listing.price}",
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey.shade400)),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') onEdit();
                if (value == 'delete') onDelete();
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(value: 'edit', child: Text('Edit')),
                const PopupMenuItem<String>(
                    value: 'delete', child: Text('Delete')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


class _MarketplaceCard extends StatelessWidget {
  final ProduceListing listing;
  const _MarketplaceCard({required this.listing});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                  child: Icon(getPlantIcon(listing.plantType),
                      color: Theme.of(context).primaryColor, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(listing.plantName,
                          style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 4),
                      Text("Listed by ${listing.username}",
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(color: Colors.grey.shade400)),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24, color: Colors.white12),
            _buildInfoRow(
                context, Icons.scale_outlined, "Quantity", listing.quantity),
            const SizedBox(height: 12),
            _buildInfoRow(
                context, Icons.price_change_outlined, "Price", listing.price),
            const SizedBox(height: 12),
            _buildInfoRow(context, Icons.email_outlined, "Contact Email",
                listing.userEmail),
            if (listing.phoneNumber != null &&
                listing.phoneNumber!.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildInfoRow(context, Icons.phone_outlined, "Contact Phone",
                  listing.phoneNumber!),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
      BuildContext context, IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.grey.shade400, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(color: Colors.grey.shade400)),
              const SizedBox(height: 2),
              Text(value, style: Theme.of(context).textTheme.bodyLarge),
            ],
          ),
        ),
      ],
    );
  }
}