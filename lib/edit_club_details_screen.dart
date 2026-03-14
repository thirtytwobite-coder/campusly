import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class EditClubDetailsScreen extends StatefulWidget {
  final String clubId;
  final String clubName;

  const EditClubDetailsScreen({
    super.key,
    required this.clubId,
    required this.clubName,
  });

  @override
  State<EditClubDetailsScreen> createState() => _EditClubDetailsScreenState();
}

class _EditClubDetailsScreenState extends State<EditClubDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  List<Map<String, dynamic>> _committee = [];
  List<String> _gallery = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchClubData();
  }

  Future<void> _fetchClubData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('clubs')
          .doc(widget.clubId)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _descriptionController.text = data['description'] ?? '';
          _committee = List<Map<String, dynamic>>.from(data['executiveCommittee'] ?? []);
          _gallery = List<String>.from(data['galleryUrls'] ?? []);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching club data: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveChanges() async {
    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance
          .collection('clubs')
          .doc(widget.clubId)
          .update({
        'description': _descriptionController.text.trim(),
        'executiveCommittee': _committee,
        'galleryUrls': _gallery,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Club details updated successfully!")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint("Error saving club details: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    }
  }

  void _addCommitteeMember() {
    showDialog(
      context: context,
      builder: (ctx) {
        final nameController = TextEditingController();
        final roleController = TextEditingController();
        final imgController = TextEditingController();
        return AlertDialog(
          title: const Text("Add Committee Member"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: "Name")),
              TextField(controller: roleController, decoration: const InputDecoration(labelText: "Role")),
              TextField(controller: imgController, decoration: const InputDecoration(labelText: "Image URL (Optional)")),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.isNotEmpty) {
                  setState(() {
                    _committee.add({
                      'name': nameController.text.trim(),
                      'role': roleController.text.trim(),
                      'image': imgController.text.trim(),
                    });
                  });
                  Navigator.pop(ctx);
                }
              },
              child: const Text("Add"),
            ),
          ],
        );
      },
    );
  }

  void _addGalleryImage() {
    final urlController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Add Gallery Image"),
        content: TextField(
          controller: urlController,
          decoration: const InputDecoration(labelText: "Image URL", hintText: "Paste image address"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              if (urlController.text.isNotEmpty) {
                setState(() => _gallery.add(urlController.text.trim()));
                Navigator.pop(ctx);
              }
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("EDIT CLUB DETAILS"),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _saveChanges,
            icon: const Icon(Icons.check),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("General Information", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: "Club Description",
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Executive Committee", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        IconButton(onPressed: _addCommitteeMember, icon: const Icon(Icons.add_circle, color: Colors.blue)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _committee.isEmpty
                        ? const Text("No members added yet.", style: TextStyle(color: Colors.grey))
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _committee.length,
                            itemBuilder: (context, index) {
                              final member = _committee[index];
                              return Card(
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundImage: (member['image'] != null && 
                                                     member['image'].toString().isNotEmpty && 
                                                     member['image'].toString().startsWith('http'))
                                        ? NetworkImage(member['image'])
                                        : null,
                                    child: (member['image'] == null || 
                                            member['image'].toString().isEmpty || 
                                            !member['image'].toString().startsWith('http')) 
                                        ? const Icon(Icons.person) 
                                        : null,
                                  ),
                                  title: Text(member['name']),
                                  subtitle: Text(member['role']),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => setState(() => _committee.removeAt(index)),
                                  ),
                                ),
                              );
                            },
                          ),
                    const SizedBox(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Gallery", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        IconButton(onPressed: _addGalleryImage, icon: const Icon(Icons.add_photo_alternate, color: Colors.blue)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _gallery.isEmpty
                        ? const Text("No images in gallery.", style: TextStyle(color: Colors.grey))
                        : GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                            itemCount: _gallery.length,
                            itemBuilder: (context, index) {
                              final imageUrl = _gallery[index];
                              return Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: (imageUrl.startsWith('http'))
                                        ? Image.network(
                                            imageUrl, 
                                            fit: BoxFit.cover, 
                                            width: double.infinity, 
                                            height: double.infinity,
                                            errorBuilder: (context, error, stackTrace) => Container(
                                              color: Colors.grey[200],
                                              child: const Icon(Icons.broken_image, color: Colors.grey),
                                            ),
                                          )
                                        : Container(
                                            color: Colors.grey[200],
                                            child: const Icon(Icons.link_off, color: Colors.grey),
                                          ),
                                  ),
                                  Positioned(
                                    right: 4,
                                    top: 4,
                                    child: GestureDetector(
                                      onTap: () => setState(() => _gallery.removeAt(index)),
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                        child: const Icon(Icons.close, size: 14, color: Colors.red),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                  ],
                ),
              ),
            ),
    );
  }
}
