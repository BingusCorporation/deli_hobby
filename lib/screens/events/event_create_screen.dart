import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/hobbies.dart';
import '../../data/city.dart';
import '../../data/skill_levels.dart';
import '../../models/event_model.dart';
import '../../models/recurrence_rule_model.dart';
import '../../services/event_service.dart';

class EventCreateScreen extends StatefulWidget {
  final Event? eventToEdit;

  const EventCreateScreen({
    super.key,
    this.eventToEdit,
  });

  @override
  State<EventCreateScreen> createState() => _EventCreateScreenState();
}

class _EventCreateScreenState extends State<EventCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final EventService _eventService = EventService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Form controllers
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _locationDetailsController = TextEditingController();
  final _maxParticipantsController = TextEditingController(text: '10');

  // Form state
  String? _selectedCity;
  String? _selectedCategory;
  String? _selectedSubcategory;
  String _selectedSkillLevel = 'any';
  String _visibility = 'public';
  DateTime _startDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _startTime = const TimeOfDay(hour: 18, minute: 0);
  int _durationMinutes = 60;
  bool _isRecurring = false;
  RecurrenceType _recurrenceType = RecurrenceType.weekly;

  // Accessibility
  bool _wheelchairAccessible = false;
  bool _hearingAssistance = false;
  bool _visualAssistance = false;
  final _accessibilityNotesController = TextEditingController();

  // Schedule items
  List<ScheduleItem> _scheduleItems = [];

  bool _isLoading = false;
  String? _organizerName;

  bool get _isEditing => widget.eventToEdit != null;

  @override
  void initState() {
    super.initState();
    _loadOrganizerName();
    if (_isEditing) {
      _populateFormWithEvent();
    }
  }

  Future<void> _loadOrganizerName() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final doc = await _firestore.collection('users_private').doc(uid).get();
    if (doc.exists) {
      setState(() {
        _organizerName = doc.data()?['name'] ?? 'Nepoznato';
      });
    }
  }

  void _populateFormWithEvent() {
    final event = widget.eventToEdit!;
    _titleController.text = event.title;
    _descriptionController.text = event.description;
    _addressController.text = event.address;
    _locationDetailsController.text = event.locationDetails ?? '';
    _maxParticipantsController.text = event.maxParticipants.toString();
    _selectedCity = event.city;
    _selectedCategory = event.category;
    _selectedSubcategory = event.subcategory;
    _selectedSkillLevel = event.requiredSkillLevel;
    _visibility = event.visibility;
    _startDate = event.startDateTime;
    _startTime = TimeOfDay.fromDateTime(event.startDateTime);
    _durationMinutes = event.duration;
    _isRecurring = event.isRecurring;
    if (event.recurrenceRule != null) {
      _recurrenceType = event.recurrenceRule!.type;
    }
    _wheelchairAccessible = event.accessibility.wheelchairAccessible;
    _hearingAssistance = event.accessibility.hearingAssistance;
    _visualAssistance = event.accessibility.visualAssistance;
    _accessibilityNotesController.text = event.accessibility.notes ?? '';
    _scheduleItems = List.from(event.schedule);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _locationDetailsController.dispose();
    _maxParticipantsController.dispose();
    _accessibilityNotesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Izmeni dogadjaj' : 'Novi dogadjaj'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Basic Info Section
              _buildSectionHeader('Osnovne informacije'),
              _buildTitleField(),
              const SizedBox(height: 16),
              _buildDescriptionField(),

              const SizedBox(height: 24),

              // Category Section
              _buildSectionHeader('Kategorija'),
              _buildCategoryDropdowns(),
              const SizedBox(height: 16),
              _buildSkillLevelDropdown(),

              const SizedBox(height: 24),

              // Date & Time Section
              _buildSectionHeader('Datum i vreme'),
              _buildDateTimePickers(),
              const SizedBox(height: 16),
              _buildDurationPicker(),
              const SizedBox(height: 16),
              _buildRecurringToggle(),

              const SizedBox(height: 24),

              // Location Section
              _buildSectionHeader('Lokacija'),
              _buildCityDropdown(),
              const SizedBox(height: 16),
              _buildAddressField(),
              const SizedBox(height: 16),
              _buildLocationDetailsField(),

              const SizedBox(height: 24),

              // Capacity Section
              _buildSectionHeader('Kapacitet'),
              _buildMaxParticipantsField(),

              const SizedBox(height: 24),

              // Visibility Section
              _buildSectionHeader('Vidljivost'),
              _buildVisibilitySelector(),

              const SizedBox(height: 24),

              // Accessibility Section
              _buildSectionHeader('Pristupacnost'),
              _buildAccessibilityOptions(),

              const SizedBox(height: 24),

              // Schedule Section
              _buildSectionHeader('Raspored aktivnosti (opciono)'),
              _buildScheduleBuilder(),

              const SizedBox(height: 32),

              // Submit Button
              _buildSubmitButton(),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTitleField() {
    return TextFormField(
      controller: _titleController,
      decoration: const InputDecoration(
        labelText: 'Naziv dogadjaja',
        border: OutlineInputBorder(),
        hintText: 'npr. Fudbal vikend trening',
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Unesi naziv dogadjaja';
        }
        return null;
      },
    );
  }

  Widget _buildDescriptionField() {
    return TextFormField(
      controller: _descriptionController,
      decoration: const InputDecoration(
        labelText: 'Opis',
        border: OutlineInputBorder(),
        hintText: 'Opisi sta ce se desavati na dogadjaju...',
      ),
      maxLines: 4,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Unesi opis dogadjaja';
        }
        return null;
      },
    );
  }

  Widget _buildCategoryDropdowns() {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            value: _selectedCategory,
            decoration: const InputDecoration(
              labelText: 'Kategorija',
              border: OutlineInputBorder(),
            ),
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
            validator: (value) {
              if (value == null) {
                return 'Izaberi kategoriju';
              }
              return null;
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: DropdownButtonFormField<String>(
            value: _selectedSubcategory,
            decoration: const InputDecoration(
              labelText: 'Podkategorija',
              border: OutlineInputBorder(),
            ),
            items: _selectedCategory != null
                ? hobbyCategories[_selectedCategory]!.map((sub) {
                    return DropdownMenuItem(
                      value: sub,
                      child: Text(sub),
                    );
                  }).toList()
                : [],
            onChanged: (value) {
              setState(() {
                _selectedSubcategory = value;
              });
            },
            validator: (value) {
              if (value == null) {
                return 'Izaberi podkategoriju';
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSkillLevelDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedSkillLevel,
      decoration: const InputDecoration(
        labelText: 'Potreban nivo vestine',
        border: OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem(
          value: 'any',
          child: Text('Svi nivoi dobrodosli'),
        ),
        ...skillLevels.entries.map((entry) {
          return DropdownMenuItem(
            value: entry.key,
            child: Text(entry.value),
          );
        }),
      ],
      onChanged: (value) {
        setState(() {
          _selectedSkillLevel = value!;
        });
      },
    );
  }

  Widget _buildDateTimePickers() {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: _pickDate,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Datum',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.calendar_today),
              ),
              child: Text(
                '${_startDate.day}.${_startDate.month}.${_startDate.year}.',
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: InkWell(
            onTap: _pickTime,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Vreme',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.access_time),
              ),
              child: Text(
                '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}',
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() {
        _startDate = date;
      });
    }
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    if (time != null) {
      setState(() {
        _startTime = time;
      });
    }
  }

  Widget _buildDurationPicker() {
    return DropdownButtonFormField<int>(
      value: _durationMinutes,
      decoration: const InputDecoration(
        labelText: 'Trajanje',
        border: OutlineInputBorder(),
      ),
      items: const [
        DropdownMenuItem(value: 30, child: Text('30 minuta')),
        DropdownMenuItem(value: 60, child: Text('1 sat')),
        DropdownMenuItem(value: 90, child: Text('1.5 sat')),
        DropdownMenuItem(value: 120, child: Text('2 sata')),
        DropdownMenuItem(value: 180, child: Text('3 sata')),
        DropdownMenuItem(value: 240, child: Text('4 sata')),
        DropdownMenuItem(value: 300, child: Text('5 sati')),
        DropdownMenuItem(value: 360, child: Text('6 sati')),
      ],
      onChanged: (value) {
        setState(() {
          _durationMinutes = value!;
        });
      },
    );
  }

  Widget _buildRecurringToggle() {
    return Column(
      children: [
        SwitchListTile(
          title: const Text('Ponavljajuci dogadjaj'),
          subtitle: const Text('Dogadjaj se ponavlja'),
          value: _isRecurring,
          onChanged: (value) {
            setState(() {
              _isRecurring = value;
            });
          },
        ),
        if (_isRecurring)
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 8),
            child: DropdownButtonFormField<RecurrenceType>(
              value: _recurrenceType,
              decoration: const InputDecoration(
                labelText: 'Ponavljanje',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: RecurrenceType.daily,
                  child: Text('Svaki dan'),
                ),
                DropdownMenuItem(
                  value: RecurrenceType.weekly,
                  child: Text('Svake nedelje'),
                ),
                DropdownMenuItem(
                  value: RecurrenceType.monthly,
                  child: Text('Svaki mesec'),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _recurrenceType = value!;
                });
              },
            ),
          ),
      ],
    );
  }

  Widget _buildCityDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedCity,
      decoration: const InputDecoration(
        labelText: 'Grad',
        border: OutlineInputBorder(),
      ),
      items: serbiaCities.map((city) {
        return DropdownMenuItem(
          value: city,
          child: Text(city),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedCity = value;
        });
      },
      validator: (value) {
        if (value == null) {
          return 'Izaberi grad';
        }
        return null;
      },
    );
  }

  Widget _buildAddressField() {
    return TextFormField(
      controller: _addressController,
      decoration: const InputDecoration(
        labelText: 'Adresa',
        border: OutlineInputBorder(),
        hintText: 'npr. Sportski centar Tasmajdan',
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Unesi adresu';
        }
        return null;
      },
    );
  }

  Widget _buildLocationDetailsField() {
    return TextFormField(
      controller: _locationDetailsController,
      decoration: const InputDecoration(
        labelText: 'Dodatne informacije o lokaciji (opciono)',
        border: OutlineInputBorder(),
        hintText: 'npr. Teren 3, ulaz sa Ruzveltove',
      ),
    );
  }

  Widget _buildMaxParticipantsField() {
    return TextFormField(
      controller: _maxParticipantsController,
      decoration: const InputDecoration(
        labelText: 'Maksimalan broj ucesnika',
        border: OutlineInputBorder(),
      ),
      keyboardType: TextInputType.number,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Unesi broj ucesnika';
        }
        final number = int.tryParse(value);
        if (number == null || number < 1) {
          return 'Unesi validan broj';
        }
        return null;
      },
    );
  }

  Widget _buildVisibilitySelector() {
    return Column(
      children: [
        RadioListTile<String>(
          title: const Text('Javni dogadjaj'),
          subtitle: const Text('Svi mogu videti i prijaviti se'),
          value: 'public',
          groupValue: _visibility,
          onChanged: (value) {
            setState(() {
              _visibility = value!;
            });
          },
        ),
        RadioListTile<String>(
          title: const Text('Privatni dogadjaj'),
          subtitle: const Text('Samo pozvani mogu ucestvovati'),
          value: 'private',
          groupValue: _visibility,
          onChanged: (value) {
            setState(() {
              _visibility = value!;
            });
          },
        ),
      ],
    );
  }

  Widget _buildAccessibilityOptions() {
    return Column(
      children: [
        CheckboxListTile(
          title: const Text('Pristup za invalidska kolica'),
          value: _wheelchairAccessible,
          onChanged: (value) {
            setState(() {
              _wheelchairAccessible = value!;
            });
          },
        ),
        CheckboxListTile(
          title: const Text('Pomoc za osobe ostecenog sluha'),
          value: _hearingAssistance,
          onChanged: (value) {
            setState(() {
              _hearingAssistance = value!;
            });
          },
        ),
        CheckboxListTile(
          title: const Text('Pomoc za osobe ostecenog vida'),
          value: _visualAssistance,
          onChanged: (value) {
            setState(() {
              _visualAssistance = value!;
            });
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextFormField(
            controller: _accessibilityNotesController,
            decoration: const InputDecoration(
              labelText: 'Dodatne napomene o pristupacnosti',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildScheduleBuilder() {
    return Column(
      children: [
        ..._scheduleItems.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Text(
                item.time,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              title: Text(item.activity),
              trailing: IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () {
                  setState(() {
                    _scheduleItems.removeAt(index);
                  });
                },
              ),
            ),
          );
        }),
        OutlinedButton.icon(
          onPressed: _addScheduleItem,
          icon: const Icon(Icons.add),
          label: const Text('Dodaj aktivnost'),
        ),
      ],
    );
  }

  void _addScheduleItem() {
    final timeController = TextEditingController();
    final activityController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dodaj aktivnost'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: timeController,
              decoration: const InputDecoration(
                labelText: 'Vreme',
                hintText: 'npr. 10:00',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: activityController,
              decoration: const InputDecoration(
                labelText: 'Aktivnost',
                hintText: 'npr. Zagrevanje',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Odustani'),
          ),
          ElevatedButton(
            onPressed: () {
              if (timeController.text.isNotEmpty &&
                  activityController.text.isNotEmpty) {
                setState(() {
                  _scheduleItems.add(ScheduleItem(
                    time: timeController.text,
                    activity: activityController.text,
                  ));
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Dodaj'),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submitForm,
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(_isEditing ? 'Sacuvaj izmene' : 'Kreiraj dogadjaj'),
      ),
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final startDateTime = DateTime(
        _startDate.year,
        _startDate.month,
        _startDate.day,
        _startTime.hour,
        _startTime.minute,
      );

      final endDateTime = startDateTime.add(Duration(minutes: _durationMinutes));

      final event = Event(
        id: widget.eventToEdit?.id,
        title: _titleController.text,
        description: _descriptionController.text,
        organizerId: _auth.currentUser!.uid,
        organizerName: _organizerName ?? 'Nepoznato',
        startDateTime: startDateTime,
        endDateTime: endDateTime,
        duration: _durationMinutes,
        isRecurring: _isRecurring,
        recurrenceRule: _isRecurring
            ? RecurrenceRule(type: _recurrenceType)
            : null,
        city: _selectedCity!,
        address: _addressController.text,
        locationDetails: _locationDetailsController.text.isNotEmpty
            ? _locationDetailsController.text
            : null,
        maxParticipants: int.parse(_maxParticipantsController.text),
        currentParticipants: widget.eventToEdit?.currentParticipants ?? 0,
        participants: widget.eventToEdit?.participants ?? [],
        category: _selectedCategory!,
        subcategory: _selectedSubcategory!,
        hobby: '$_selectedCategory > $_selectedSubcategory',
        requiredSkillLevel: _selectedSkillLevel,
        visibility: _visibility,
        accessibility: EventAccessibility(
          wheelchairAccessible: _wheelchairAccessible,
          hearingAssistance: _hearingAssistance,
          visualAssistance: _visualAssistance,
          notes: _accessibilityNotesController.text.isNotEmpty
              ? _accessibilityNotesController.text
              : null,
        ),
        schedule: _scheduleItems,
        status: widget.eventToEdit?.status ?? 'active',
      );

      if (_isEditing) {
        await _eventService.updateEvent(event.id!, event.toMap());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Dogadjaj je azuriran!')),
          );
          Navigator.pop(context);
        }
      } else {
        await _eventService.createEvent(event);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Dogadjaj je kreiran!')),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Greska: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
