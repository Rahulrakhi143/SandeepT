import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trivora_provider/core/config/app_config.dart';

/// Service for managing document uploads to Firebase Storage
class FirebaseStorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Upload a document file to Firebase Storage
  /// Returns the download URL
  Future<String> uploadDocument({
    required String providerId,
    required String documentType,
    required File file,
    String? fileName,
  }) async {
    try {
      // Validate file size (max 10 MB = 10 * 1024 * 1024 bytes)
      final fileSize = await file.length();
      const maxSize = 10 * 1024 * 1024; // 10 MB
      
      if (fileSize > maxSize) {
        throw Exception('File size exceeds 10 MB limit. Current size: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');
      }

      // Generate unique file name
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = file.path.split('.').last;
      final finalFileName = fileName ?? '${documentType}_$timestamp.$extension';
      
      // Create storage reference
      final ref = _storage
          .ref()
          .child('providers')
          .child(providerId)
          .child('documents')
          .child(documentType)
          .child(finalFileName);

      // Upload file
      debugPrint('📤 Uploading document: $documentType');
      final uploadTask = ref.putFile(
        file,
        SettableMetadata(
          contentType: _getContentType(extension),
          customMetadata: {
            'documentType': documentType,
            'uploadedAt': DateTime.now().toIso8601String(),
          },
        ),
      );

      // Wait for upload to complete
      final snapshot = await uploadTask;
      
      // Get download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();
      debugPrint('✅ Document uploaded successfully: $downloadUrl');

      // Save document metadata to Firestore
      await _saveDocumentMetadata(
        providerId: providerId,
        documentType: documentType,
        fileName: finalFileName,
        downloadUrl: downloadUrl,
        fileSize: fileSize,
        uploadPath: snapshot.ref.fullPath,
      );

      return downloadUrl;
    } catch (e) {
      debugPrint('❌ Error uploading document: $e');
      throw Exception('Failed to upload document: $e');
    }
  }

  /// Upload document from bytes (for web)
  Future<String> uploadDocumentFromBytes({
    required String providerId,
    required String documentType,
    required Uint8List bytes,
    required String fileName,
  }) async {
    try {
      // Validate file size (max 10 MB)
      const maxSize = 10 * 1024 * 1024; // 10 MB
      
      if (bytes.length > maxSize) {
        throw Exception('File size exceeds 10 MB limit. Current size: ${(bytes.length / 1024 / 1024).toStringAsFixed(2)} MB');
      }

      // Generate unique file name
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = fileName.split('.').last;
      final finalFileName = '${documentType}_$timestamp.$extension';
      
      // Create storage reference
      final ref = _storage
          .ref()
          .child('providers')
          .child(providerId)
          .child('documents')
          .child(documentType)
          .child(finalFileName);

      // Upload file
      debugPrint('📤 Uploading document: $documentType');
      final uploadTask = ref.putData(
        bytes,
        SettableMetadata(
          contentType: _getContentType(extension),
          customMetadata: {
            'documentType': documentType,
            'uploadedAt': DateTime.now().toIso8601String(),
          },
        ),
      );

      // Wait for upload to complete
      final snapshot = await uploadTask;
      
      // Get download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();
      debugPrint('✅ Document uploaded successfully: $downloadUrl');

      // Save document metadata to Firestore
      await _saveDocumentMetadata(
        providerId: providerId,
        documentType: documentType,
        fileName: finalFileName,
        downloadUrl: downloadUrl,
        fileSize: bytes.length,
        uploadPath: snapshot.ref.fullPath,
      );

      return downloadUrl;
    } catch (e) {
      debugPrint('❌ Error uploading document: $e');
      throw Exception('Failed to upload document: $e');
    }
  }

  /// Save document metadata to Firestore
  Future<void> _saveDocumentMetadata({
    required String providerId,
    required String documentType,
    required String fileName,
    required String downloadUrl,
    required int fileSize,
    required String uploadPath,
  }) async {
    try {
      await _firestore
          .collection(AppConfig.providersCollection)
          .doc(providerId)
          .collection('documents')
          .doc(documentType)
          .set({
        'documentType': documentType,
        'fileName': fileName,
        'downloadUrl': downloadUrl,
        'fileSize': fileSize,
        'uploadPath': uploadPath,
        'status': 'uploaded',
        'uploadedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('✅ Document metadata saved to Firestore');
    } catch (e) {
      debugPrint('❌ Error saving document metadata: $e');
      throw Exception('Failed to save document metadata: $e');
    }
  }

  /// Get document metadata from Firestore
  Future<Map<String, dynamic>?> getDocumentMetadata({
    required String providerId,
    required String documentType,
  }) async {
    try {
      final doc = await _firestore
          .collection(AppConfig.providersCollection)
          .doc(providerId)
          .collection('documents')
          .doc(documentType)
          .get();

      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error getting document metadata: $e');
      return null;
    }
  }

  /// Get all documents for a provider
  Future<List<Map<String, dynamic>>> getAllDocuments(String providerId) async {
    try {
      final snapshot = await _firestore
          .collection(AppConfig.providersCollection)
          .doc(providerId)
          .collection('documents')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'documentType': doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      debugPrint('❌ Error getting documents: $e');
      return [];
    }
  }

  /// Get stream of all documents for a provider
  Stream<List<Map<String, dynamic>>> getAllDocumentsStream(String providerId) {
    return _firestore
        .collection(AppConfig.providersCollection)
        .doc(providerId)
        .collection('documents')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'documentType': doc.id,
          ...data,
        };
      }).toList();
    });
  }

  /// Delete a document
  Future<void> deleteDocument({
    required String providerId,
    required String documentType,
  }) async {
    try {
      // Get document metadata
      final metadata = await getDocumentMetadata(
        providerId: providerId,
        documentType: documentType,
      );

      if (metadata != null && metadata['uploadPath'] != null) {
        // Delete from Storage
        final ref = _storage.ref(metadata['uploadPath'] as String);
        await ref.delete();
        debugPrint('✅ Document deleted from Storage');
      }

      // Delete metadata from Firestore
      await _firestore
          .collection(AppConfig.providersCollection)
          .doc(providerId)
          .collection('documents')
          .doc(documentType)
          .delete();

      debugPrint('✅ Document deleted successfully');
    } catch (e) {
      debugPrint('❌ Error deleting document: $e');
      throw Exception('Failed to delete document: $e');
    }
  }

  /// Download document URL
  Future<String> getDownloadUrl(String providerId, String documentType) async {
    try {
      final metadata = await getDocumentMetadata(
        providerId: providerId,
        documentType: documentType,
      );

      if (metadata != null && metadata['downloadUrl'] != null) {
        return metadata['downloadUrl'] as String;
      }

      throw Exception('Document not found');
    } catch (e) {
      debugPrint('❌ Error getting download URL: $e');
      throw Exception('Failed to get download URL: $e');
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
}

/// Provider for FirebaseStorageService
final firebaseStorageServiceProvider = Provider<FirebaseStorageService>((ref) {
  return FirebaseStorageService();
});

