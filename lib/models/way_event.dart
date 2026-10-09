enum EventMode {
  online,
  offline,
}

class WayEvent {
  final String id;
  final String title;
  final String? description;
  final EventMode mode;
  final String? location;
  final String? bannerUrl;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isActive;

  WayEvent({
    required this.id,
    required this.title,
    this.description,
    this.mode = EventMode.online,
    this.location,
    this.bannerUrl,
    this.startDate,
    this.endDate,
    this.isActive = true,
  });

  factory WayEvent.fromJson(Map<String, dynamic> json) {
    return WayEvent(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      title: json['title']?.toString() ?? json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      mode: _parseEventMode(json['mode']),
      location: json['location']?.toString() ?? json['address']?.toString(),
      bannerUrl:
          (json['bannerUrl'] ?? json['banner'] ?? json['image'])?.toString(),
      startDate: json['startDate'] != null
          ? DateTime.tryParse(json['startDate'].toString())
          : (json['date'] != null
              ? DateTime.tryParse(json['date'].toString())
              : null),
      endDate: json['endDate'] != null
          ? DateTime.tryParse(json['endDate'].toString())
          : null,
      isActive: json['isActive'] ?? json['active'] ?? true,
    );
  }

  static EventMode _parseEventMode(dynamic modeValue) {
    if (modeValue == null) {
      return EventMode.online;
    }
    final str = modeValue.toString().trim().toUpperCase();
    if (str == 'OFFLINE') {
      return EventMode.offline;
    }
    return EventMode.online;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'mode': mode == EventMode.offline ? 'OFFLINE' : 'ONLINE',
      'location': location,
      'bannerUrl': bannerUrl,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'isActive': isActive,
    };
  }

  WayEvent copyWith({
    String? id,
    String? title,
    String? description,
    EventMode? mode,
    String? location,
    String? bannerUrl,
    DateTime? startDate,
    DateTime? endDate,
    bool? isActive,
  }) {
    return WayEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      mode: mode ?? this.mode,
      location: location ?? this.location,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isActive: isActive ?? this.isActive,
    );
  }
}
