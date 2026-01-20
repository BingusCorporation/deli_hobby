import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/poster_service.dart';
import '../data/hobbies.dart';

class CreateOglasScreen extends StatefulWidget {
  const CreateOglasScreen({super.key});

  @override
  State<CreateOglasScreen> createState() => _CreateOglasScreenState();
}

class _CreateOglasScreenState extends State<CreateOglasScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  
  String? _selectedCategory;
  String? _selectedSubcategory;
  final List<String> _selectedHobbies = [];
  File? _selectedImage;
  bool _isSubmitting = false;

  void _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() => _selectedImage = File(pickedFile.path));
      }
    } catch (e) {
      _showSnackBar('Greška pri odabiru slike: $e');
    }
  }

  void _showImagePickerDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Odaberi sliku'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Uzmi sliku'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Izaberi iz galerije'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _addHobby() {
    if (_selectedCategory != null && _selectedSubcategory != null) {
      final hobby = "$_selectedCategory > $_selectedSubcategory";
      if (!_selectedHobbies.contains(hobby)) {
        setState(() {
          _selectedHobbies.add(hobby);
          _selectedSubcategory = null;
        });
      }
    }
  }

  void _removeHobby(String hobby) {
    setState(() => _selectedHobbies.remove(hobby));
  }

  Future<void> _submitPoster() async {
    if (_titleController.text.trim().isEmpty) {
      _showSnackBar('Unesite naslov');
      return;
    }
    
    if (_descriptionController.text.trim().isEmpty) {
      _showSnackBar('Unesite opis');
      return;
    }
    
    if (_selectedHobbies.isEmpty) {
      _showSnackBar('Odaberite barem jedan hobi');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await PosterService.createPoster(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        requiredHobbies: _selectedHobbies,
        imageFile: _selectedImage,
      );

      _showSnackBar('Oglas uspešno objavljen!');
      Navigator.pop(context);
    } catch (e) {
      _showSnackBar('Greška pri objavljivanju: $e');
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Novi oglas'),
        actions: [
          IconButton(
            icon: _isSubmitting
                ? const CircularProgressIndicator()
                : const Icon(Icons.check),
            onPressed: _isSubmitting ? null : _submitPoster,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image picker
            GestureDetector(
              onTap: _showImagePickerDialog,
              child: Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.grey[200] ?? Colors.grey,
                    width: 2,
                  ),
                ),
                child: _selectedImage != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(
                          _selectedImage!,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate,
                              size: 60, color: Colors.grey),
                          const SizedBox(height: 8),
                          Text(
                            'Dodaj sliku (opciono)',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Title
            const Text(
              'Naslov*',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                hintText: 'Unesite naslov oglasa...',
                border: OutlineInputBorder(),
              ),
              maxLength: 100,
            ),
            
            const SizedBox(height: 20),
            
            // Description
            const Text(
              'Opis*',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                hintText: 'Opisite šta tražite...',
                border: OutlineInputBorder(),
              ),
              maxLines: 5,
              maxLength: 1000,
            ),
            
            const SizedBox(height: 20),
            
            // Hobbies selection
            const Text(
              'Traženi hobiji*',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            
            // Selected hobbies
            if (_selectedHobbies.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _selectedHobbies.map((hobby) {
                  return Chip(
                    label: Text(hobby),
                    deleteIcon: const Icon(Icons.close, size: 18),
                    onDeleted: () => _removeHobby(hobby),
                  );
                }).toList(),
              ),
            
            if (_selectedHobbies.isNotEmpty) const SizedBox(height: 16),
            
            // Hobby picker
            DropdownButton<String>(
              hint: const Text("Izaberi kategoriju"),
              value: _selectedCategory,
              isExpanded: true,
              items: hobbyCategories.keys.map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCategory = value;
                  _selectedSubcategory = null;
                });
              },
            ),
            
            if (_selectedCategory != null)
              Column(
                children: [
                  const SizedBox(height: 12),
                  DropdownButton<String>(
                    hint: const Text("Izaberi podkategoriju"),
                    value: _selectedSubcategory,
                    isExpanded: true,
                    items: hobbyCategories[_selectedCategory]!
                        .map((sub) => DropdownMenuItem(
                              value: sub,
                              child: Text(sub),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() => _selectedSubcategory = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _addHobby,
                    child: const Text("Dodaj hobi"),
                  ),
                ],
              ),
            
            const SizedBox(height: 32),
            
            // Submit button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitPoster,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.blue,
                ),
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Objavi oglas',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}