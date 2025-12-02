/// Provider model - represents service provider profiles
class ProviderModel {
  final String id;
  final String userId; // Reference to users collection
  final String status; // 'pending', 'active', 'suspended', 'blocked'
  final bool isOnline;
  final bool isVerified;
  final List<String> professions;
  final Address address;
  final BankDetails? bankDetails;
  final DocumentStatus documents;
  final double rating;
  final int totalBookings;
  final int completedBookings;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? verifiedAt;

  const ProviderModel({
    required this.id,
    required this.userId,
    this.status = 'pending',
    this.isOnline = false,
    this.isVerified = false,
    required this.professions,
    required this.address,
    this.bankDetails,
    required this.documents,
    this.rating = 0.0,
    this.totalBookings = 0,
    this.completedBookings = 0,
    required this.createdAt,
    this.updatedAt,
    this.verifiedAt,
  });

  factory ProviderModel.fromMap(Map<String, dynamic> data, String id) {
    return ProviderModel(
      id: id,
      userId: data['userId'] ?? '',
      status: data['status'] ?? 'pending',
      isOnline: data['isOnline'] ?? false,
      isVerified: data['isVerified'] ?? false,
      professions: List<String>.from(data['professions'] ?? []),
      address: Address.fromMap(data['address'] ?? {}),
      bankDetails: data['bankDetails'] != null
          ? BankDetails.fromMap(data['bankDetails'])
          : null,
      documents: DocumentStatus.fromMap(data['documents'] ?? {}),
      rating: (data['rating'] ?? 0.0).toDouble(),
      totalBookings: data['totalBookings'] ?? 0,
      completedBookings: data['completedBookings'] ?? 0,
      createdAt: data['createdAt'] is DateTime
          ? data['createdAt'] as DateTime
          : DateTime.now(),
      updatedAt: data['updatedAt'] is DateTime ? data['updatedAt'] as DateTime : null,
      verifiedAt: data['verifiedAt'] is DateTime ? data['verifiedAt'] as DateTime : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'status': status,
      'isOnline': isOnline,
      'isVerified': isVerified,
      'professions': professions,
      'address': address.toMap(),
      if (bankDetails != null) 'bankDetails': bankDetails!.toMap(),
      'documents': documents.toMap(),
      'rating': rating,
      'totalBookings': totalBookings,
      'completedBookings': completedBookings,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': (updatedAt ?? DateTime.now()).toIso8601String(),
      if (verifiedAt != null) 'verifiedAt': verifiedAt!.toIso8601String(),
    };
  }
}

/// Address model
class Address {
  final String street;
  final String city;
  final String state;
  final String pincode;
  final String? landmark;
  final double latitude;
  final double longitude;
  final String? addressLine2;

  const Address({
    required this.street,
    required this.city,
    required this.state,
    required this.pincode,
    this.landmark,
    required this.latitude,
    required this.longitude,
    this.addressLine2,
  });

  factory Address.fromMap(Map<String, dynamic> map) {
    return Address(
      street: map['street'] ?? '',
      city: map['city'] ?? '',
      state: map['state'] ?? '',
      pincode: map['pincode'] ?? '',
      landmark: map['landmark'],
      latitude: (map['latitude'] ?? 0.0).toDouble(),
      longitude: (map['longitude'] ?? 0.0).toDouble(),
      addressLine2: map['addressLine2'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'street': street,
      'city': city,
      'state': state,
      'pincode': pincode,
      if (landmark != null) 'landmark': landmark,
      'latitude': latitude,
      'longitude': longitude,
      if (addressLine2 != null) 'addressLine2': addressLine2,
    };
  }

  String get fullAddress => '$street, $city, $state - $pincode';
}

/// Bank details model
class BankDetails {
  final String accountHolderName;
  final String accountNumber;
  final String ifscCode;
  final String bankName;
  final String? upiId;

  const BankDetails({
    required this.accountHolderName,
    required this.accountNumber,
    required this.ifscCode,
    required this.bankName,
    this.upiId,
  });

  factory BankDetails.fromMap(Map<String, dynamic> map) {
    return BankDetails(
      accountHolderName: map['accountHolderName'] ?? '',
      accountNumber: map['accountNumber'] ?? '',
      ifscCode: map['ifscCode'] ?? '',
      bankName: map['bankName'] ?? '',
      upiId: map['upiId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'accountHolderName': accountHolderName,
      'accountNumber': accountNumber,
      'ifscCode': ifscCode,
      'bankName': bankName,
      if (upiId != null) 'upiId': upiId,
    };
  }
}

/// Document status model
class DocumentStatus {
  final String? aadharUrl;
  final String? panUrl;
  final String? photoUrl;
  final bool aadharVerified;
  final bool panVerified;
  final bool photoVerified;

  const DocumentStatus({
    this.aadharUrl,
    this.panUrl,
    this.photoUrl,
    this.aadharVerified = false,
    this.panVerified = false,
    this.photoVerified = false,
  });

  factory DocumentStatus.fromMap(Map<String, dynamic> map) {
    return DocumentStatus(
      aadharUrl: map['aadharUrl'],
      panUrl: map['panUrl'],
      photoUrl: map['photoUrl'],
      aadharVerified: map['aadharVerified'] ?? false,
      panVerified: map['panVerified'] ?? false,
      photoVerified: map['photoVerified'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (aadharUrl != null) 'aadharUrl': aadharUrl,
      if (panUrl != null) 'panUrl': panUrl,
      if (photoUrl != null) 'photoUrl': photoUrl,
      'aadharVerified': aadharVerified,
      'panVerified': panVerified,
      'photoVerified': photoVerified,
    };
  }

  bool get allDocumentsUploaded => aadharUrl != null && photoUrl != null;
}
