import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trivora_provider/core/config/app_config.dart';

/// Service to manage provider documents in Firestore and Firebase Storage
class FirestoreDocumentsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Maximum file size: 10 MB (in bytes)
  static const int maxFileSizeBytes = 10 * 1024 * 1024; // 10 MB

  /// Get all documents for a provider
  Future<List<Map<String, dynamic>>> getDocuments(String providerId) async {
    try {
      final snapshot = await _firestore
          .collection(AppConfig.providersCollection)
          .doc(providerId)
          .collection('documents')
          .orderBy('uploadedAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      debugPrint('❌ Error fetching documents: $e');
      throw Exception('Failed to fetch documents: $e');
    }
  }

  /// Get documents stream for real-time updates
  Stream<List<Map<String, dynamic>>> getDocumentsStream(String providerId) {
    return _firestore
        .collection(AppConfig.providersCollection)
        .doc(providerId)
        .collection('documents')
        .orderBy('uploadedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    });
  }

  /// Upload a document to Firebase Storage and save metadata to Firestore
  Future<Map<String, dynamic>> uploadDocument({
    required String providerId,
    required String documentType,
    required String documentName,
    required File file,
    String? description,
  }) async {
    try {
      // Check file size (maximum 10 MB)
      final fileSize = await file.length();
      if (fileSize > maxFileSizeBytes) {
        throw Exception(
          'File size exceeds 10 MB limit. Current size: ${(fileSize / (1024 * 1024)).toStringAsFixed(2)} MB',
        );
      }

      if (fileSize < 1024) {
        // Minimum 1 KB check (reasonable minimum)
        throw Exception('File is too small. Please upload a valid document.');
      }

      // Generate unique file name
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileExtension = file.path.split('.').last.toLowerCase();
      final fileName = '${documentType}_${providerId}_$timestamp.$fileExtension';
      final storagePath = 'providers/$providerId/documents/$fileName';

      // Upload to Firebase Storage
      debugPrint('📤 Uploading document: $storagePath');
      final uploadTask = _storage.ref(storagePath).putFile(file);

      // Wait for upload to complete
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      debugPrint('✅ Document uploaded successfully: $downloadUrl');

      // Save document metadata to Firestore
      final documentData = {
        'documentType': documentType,
        'documentName': documentName,
        'fileName': fileName,
        'storagePath': storagePath,
        'downloadUrl': downloadUrl,
        'fileSize': fileSize,
        'fileExtension': fileExtension,
        'status': 'uploaded',
        'uploadedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        if (description != null) 'description': description,
      };

      final docRef = await _firestore
          .collection(AppConfig.providersCollection)
          .doc(providerId)
          .collection('documents')
          .add(documentData);

      debugPrint('✅ Document metadata saved to Firestore: ${docRef.id}');

      return {
        'id': docRef.id,
        ...documentData,
      };
    } catch (e) {
      debugPrint('❌ Error uploading document: $e');
      throw Exception('Failed to upload document: $e');
    }
  }

  /// Upload document from bytes (for web)
  Future<Map<String, dynamic>> uploadDocumentFromBytes({
    required String providerId,
    required String documentType,
    required String documentName,
    required Uint8List fileBytes,
    required String fileExtension,
    String? description,
  }) async {
    try {
      // Check file size (maximum 10 MB)
      final fileSize = fileBytes.length;
      if (fileSize > maxFileSizeBytes) {
        throw Exception(
          'File size exceeds 10 MB limit. Current size: ${(fileSize / (1024 * 1024)).toStringAsFixed(2)} MB',
        );
      }

      if (fileSize < 1024) {
        throw Exception('File is too small. Please upload a valid document.');
      }

      // Generate unique file name
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${documentType}_${providerId}_$timestamp.$fileExtension';
      final storagePath = 'providers/$providerId/documents/$fileName';

      // Upload to Firebase Storage
      debugPrint('📤 Uploading document: $storagePath');
      final uploadTask = _storage.ref(storagePath).putData(
            fileBytes,
            SettableMetadata(
              contentType: _getContentType(fileExtension),
            ),
          );

      // Wait for upload to complete
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      debugPrint('✅ Document uploaded successfully: $downloadUrl');

      // Save document metadata to Firestore
      final documentData = {
        'documentType': documentType,
        'documentName': documentName,
        'fileName': fileName,
        'storagePath': storagePath,
        'downloadUrl': downloadUrl,
        'fileSize': fileSize,
        'fileExtension': fileExtension,
        'status': 'uploaded',
        'uploadedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        if (description != null) 'description': description,
      };

      final docRef = await _firestore
          .collection(AppConfig.providersCollection)
          .doc(providerId)
          .collection('documents')
          .add(documentData);

      debugPrint('✅ Document metadata saved to Firestore: ${docRef.id}');

      return {
        'id': docRef.id,
        ...documentData,
      };
    } catch (e) {
      debugPrint('❌ Error uploading document: $e');
      throw Exception('Failed to upload document: $e');
    }
  }

  /// Get content type from file extension
  String _getContentType(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'application/octet-stream';
    }
  }

  /// Delete a document from both Storage and Firestore
  Future<void> deleteDocument({
    required String providerId,
    required String documentId,
  }) async {
    try {
      // Get document data first
      final doc = await _firestore
          .collection(AppConfig.providersCollection)
          .doc(providerId)
          .collection('documents')
          .doc(documentId)
          .get();

      if (!doc.exists) {
        throw Exception('Document not found');
      }

      final data = doc.data() as Map<String, dynamic>;
      final storagePath = data['storagePath'] as String?;

      // Delete from Storage if path exists
      if (storagePath != null) {
        try {
          await _storage.ref(storagePath).delete();
          debugPrint('✅ Document deleted from Storage: $storagePath');
        } catch (e) {
          debugPrint('⚠️ Error deleting from Storage (continuing): $e');
        }
      }

      // Delete from Firestore
      await _firestore
          .collection(AppConfig.providersCollection)
          .doc(providerId)
          .collection('documents')
          .doc(documentId)
          .delete();

      debugPrint('✅ Document deleted from Firestore: $documentId');
    } catch (e) {
      debugPrint('❌ Error deleting document: $e');
      throw Exception('Failed to delete document: $e');
    }
  }

  /// Update document metadata
  Future<void> updateDocument({
    required String providerId,
    required String documentId,
    String? documentName,
    String? description,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (documentName != null) {
        updateData['documentName'] = documentName;
      }
      if (description != null) {
        updateData['description'] = description;
      }

      await _firestore
          .collection(AppConfig.providersCollection)
          .doc(providerId)
          .collection('documents')
          .doc(documentId)
          .update(updateData);

      debugPrint('✅ Document updated: $documentId');
    } catch (e) {
      debugPrint('❌ Error updating document: $e');
      throw Exception('Failed to update document: $e');
    }
  }

  /// Download document URL
  Future<String> getDownloadUrl(String providerId, String documentId) async {
    try {
      final doc = await _firestore
          .collection(AppConfig.providersCollection)
          .doc(providerId)
          .collection('documents')
          .doc(documentId)
          .get();

      if (!doc.exists) {
        throw Exception('Document not found');
      }

      final data = doc.data() as Map<String, dynamic>;
      final downloadUrl = data['downloadUrl'] as String?;

      if (downloadUrl == null) {
        throw Exception('Download URL not found');
      }

      return downloadUrl;
    } catch (e) {
      debugPrint('❌ Error getting download URL: $e');
      throw Exception('Failed to get download URL: $e');
    }
  }
}

/// Provider for FirestoreDocumentsService
final firestoreDocumentsServiceProvider = Provider<FirestoreDocumentsService>((ref) {
  return FirestoreDocumentsService();
});

