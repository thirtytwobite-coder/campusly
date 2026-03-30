/// This screen allows club coordinators to edit their club's details.
/// It provides forms to update club description, executive committee members, photo gallery,
/// and club logo/profile picture. The screen fetches current club data from Firestore
/// and allows saving changes back to the database with validation.

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';

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
  String? _clubLogo;

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
          _clubLogo = data['profilePic'] as String?;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching club data: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<String?> _pickAndConvertImage() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 50,
      );

      if (image != null) {
        final bytes = await File(image.path).readAsBytes();
        return 'data:image/png;base64,${base64Encode(bytes)}';
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
    }
    return null;
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
        'profilePic': _clubLogo,
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
        String? tempImage;
        
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Add Committee Member"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () async {
                      final img = await _pickAndConvertImage();
                      if (img != null) {
                        setDialogState(() => tempImage = img);
                      }
                    },
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.grey[200],
                          backgroundImage: tempImage != null 
                              ? MemoryImage(base64Decode(tempImage!.split(',').last)) as ImageProvider
                              : null,
                          child: tempImage == null ? const Icon(Icons.person, size: 40) : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                            child: const Icon(Icons.add, color: Colors.white, size: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(controller: nameController, decoration: const InputDecoration(labelText: "Name")),
                  TextField(controller: roleController, decoration: const InputDecoration(labelText: "Role")),
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
                          'image': tempImage ?? '',
                        });
                      });
                      Navigator.pop(ctx);
                    }
                  },
                  child: const Text("Add"),
                ),
              ],
            );
          }
        );
      },
    );
  }

  void _editCommitteeMemberImage(int index) async {
    final img = await _pickAndConvertImage();
    if (img != null) {
      setState(() {
        _committee[index]['image'] = img;
      });
    }
  }

  void _addGalleryImage() async {
    final img = await _pickAndConvertImage();
    if (img != null) {
      setState(() => _gallery.add(img));
    }
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
                    Center(
                      child: Column(
                        children: [
                          const Text("Club Logo", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 12),
                          GestureDetector(
                            onTap: () async {
                              final img = await _pickAndConvertImage();
                              if (img != null) {
                                setState(() => _clubLogo = img);
                              }
                            },
                            child: Stack(
                              children: [
                                CircleAvatar(
                                  radius: 50,
                                  backgroundColor: Colors.grey[200],
                                  backgroundImage: (_clubLogo != null && _clubLogo!.isNotEmpty)
                                      ? (_clubLogo!.startsWith('data:image') 
                                          ? MemoryImage(base64Decode(_clubLogo!.split(',').last)) as ImageProvider
                                          : NetworkImage(_clubLogo!))
                                      : null,
                                  child: (_clubLogo == null || _clubLogo!.isEmpty) ? const Icon(Icons.business, size: 50) : null,
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                                    child: const Icon(Icons.add, color: Colors.white, size: 20),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
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
                                  leading: GestureDetector(
                                    onTap: () => _editCommitteeMemberImage(index),
                                    child: Stack(
                                      children: [
                                        CircleAvatar(
                                          backgroundImage: (member['image'] != null && 
                                                           member['image'].toString().isNotEmpty && 
                                                           (member['image'].toString().startsWith('http') || member['image'].toString().startsWith('data:image')))
                                              ? (member['image'].toString().startsWith('data:image') 
                                                  ? MemoryImage(base64Decode(member['image'].toString().split(',').last)) as ImageProvider
                                                  : NetworkImage(member['image']))
                                              : null,
                                          child: (member['image'] == null || 
                                                  member['image'].toString().isEmpty || 
                                                  (!member['image'].toString().startsWith('http') && !member['image'].toString().startsWith('data:image'))) 
                                              ? const Icon(Icons.person) 
                                              : null,
                                        ),
                                        Positioned(
                                          bottom: 0,
                                          right: 0,
                                          child: Container(
                                            padding: const EdgeInsets.all(2),
                                            decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                                            child: const Icon(Icons.add, color: Colors.white, size: 10),
                                          ),
                                        ),
                                      ],
                                    ),
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
                                    child: (imageUrl.startsWith('http') || imageUrl.startsWith('data:image'))
                                        ? (imageUrl.startsWith('data:image') ? Image.memory(
                                              base64Decode(imageUrl.split(',').last), 
                                              fit: BoxFit.cover, 
                                              width: double.infinity, 
                                              height: double.infinity,
                                              errorBuilder: (context, error, stackTrace) => Container(
                                                color: Colors.grey[200],
                                                child: const Icon(Icons.broken_image, color: Colors.grey),
                                              ),
                                            ) : Image.network(
                                              imageUrl, 
                                              fit: BoxFit.cover, 
                                              width: double.infinity, 
                                              height: double.infinity,
                                              errorBuilder: (context, error, stackTrace) => Container(
                                                color: Colors.grey[200],
                                                child: const Icon(Icons.broken_image, color: Colors.grey),
                                              ),
                                            ))
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
