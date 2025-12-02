import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:trivora_provider/core/providers/auth_provider.dart';
import 'package:trivora_provider/core/services/firestore_documents_service.dart';
import 'package:url_launcher/url_launcher.dart';

/// Documents Page - Manage provider documents
class DocumentsPage extends ConsumerStatefulWidget {
  const DocumentsPage({super.key});

  @override
  ConsumerState<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends ConsumerState<DocumentsPage> {
  @override
  Widget build(BuildContext context) {
    final authUser = ref.watch(authStateProvider).valueOrNull;
    if (authUser == null) {
      return const Scaffold(
        body: Center(child: Text('Please login to view documents')),
      );
    }

    final documentsService = ref.watch(firestoreDocumentsServiceProvider);
    final documentsStream = documentsService.getDocumentsStream(authUser.uid);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Documents'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showUploadDialog(context, authUser.uid),
            tooltip: 'Upload Document',
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: documentsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading documents: ${snapshot.error}',
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final documents = snapshot.data ?? [];

          if (documents.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_open, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'No documents uploaded yet',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Upload your documents to get started',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade500,
                        ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _showUploadDialog(context, authUser.uid),
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Upload Document'),
                  ),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Document Types Summary
              _buildDocumentTypesSummary(documents),
              const SizedBox(height: 24),
              // Documents List
              ...documents.map((doc) => _buildDocumentCard(context, doc, authUser.uid)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDocumentTypesSummary(List<Map<String, dynamic>> documents) {
    final documentTypes = <String, int>{};
    for (var doc in documents) {
      final type = doc['documentType'] as String? ?? 'other';
      documentTypes[type] = (documentTypes[type] ?? 0) + 1;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Document Summary',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: documentTypes.entries.map((entry) {
                return Chip(
                  label: Text('${entry.key}: ${entry.value}'),
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentCard(
    BuildContext context,
    Map<String, dynamic> document,
    String providerId,
  ) {
    final documentType = document['documentType'] as String? ?? 'unknown';
    final documentName = document['documentName'] as String? ?? 'Document';
    final uploadDate = document['uploadedAt'];
    final status = document['status'] as String? ?? 'uploaded';
    final fileSize = document['fileSize'] as int? ?? 0;
    final downloadUrl = document['downloadUrl'] as String?;

    DateTime? uploadedAt;
    if (uploadDate != null) {
      if (uploadDate is DateTime) {
        uploadedAt = uploadDate;
      } else {
        // Handle Timestamp if needed
        uploadedAt = DateTime.now();
      }
    }

    IconData documentIcon;
    Color statusColor;
    switch (documentType.toLowerCase()) {
      case 'aadhar':
      case 'aadhaar':
        documentIcon = Icons.badge;
        break;
      case 'pan':
        documentIcon = Icons.credit_card;
        break;
      case 'photo':
      case 'profile':
        documentIcon = Icons.photo;
        break;
      case 'license':
        documentIcon = Icons.card_membership;
        break;
      default:
        documentIcon = Icons.description;
    }

    switch (status) {
      case 'verified':
        statusColor = Colors.green;
        break;
      case 'rejected':
        statusColor = Colors.red;
        break;
      case 'pending':
        statusColor = Colors.orange;
        break;
      default:
        statusColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            documentIcon,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(
          documentName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Type: ${documentType.toUpperCase()}'),
            if (uploadedAt != null)
              Text(
                'Uploaded: ${_formatDate(uploadedAt)}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            Text(
              'Size: ${_formatFileSize(fileSize)}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: statusColor),
              ),
              child: Text(
                status.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'view' && downloadUrl != null) {
                  _openDocument(downloadUrl);
                } else if (value == 'delete') {
                  _deleteDocument(context, providerId, document['id'] as String);
                }
              },
              itemBuilder: (context) => [
                if (downloadUrl != null)
                  const PopupMenuItem(
                    value: 'view',
                    child: Row(
                      children: [
                        Icon(Icons.visibility, size: 20),
                        SizedBox(width: 8),
                        Text('View'),
                      ],
                    ),
                  ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 20, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showUploadDialog(BuildContext context, String providerId) {
    showDialog(
      context: context,
      builder: (context) => _UploadDocumentDialog(providerId: providerId),
    );
  }

  Future<void> _openDocument(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open document')),
        );
      }
    }
  }

  Future<void> _deleteDocument(BuildContext context, String providerId, String documentId) async {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Document'),
        content: const Text('Are you sure you want to delete this document? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;
      try {
        final documentsService = ref.read(firestoreDocumentsServiceProvider);
        await documentsService.deleteDocument(
          providerId: providerId,
          documentId: documentId,
        );
        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Document deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(
            content: Text('Error deleting document: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _UploadDocumentDialog extends ConsumerStatefulWidget {
  final String providerId;

  const _UploadDocumentDialog({required this.providerId});

  @override
  ConsumerState<_UploadDocumentDialog> createState() => _UploadDocumentDialogState();
}

class _UploadDocumentDialogState extends ConsumerState<_UploadDocumentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _documentNameController = TextEditingController();
  String _selectedDocumentType = 'other';
  bool _isUploading = false;

  final List<String> _documentTypes = [
    'aadhar',
    'pan',
    'photo',
    'license',
    'other',
  ];

  @override
  void dispose() {
    _documentNameController.dispose();
    super.dispose();
  }

  Future<void> _uploadDocument() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isUploading = true;
    });

    try {
      final documentsService = ref.read(firestoreDocumentsServiceProvider);
      FilePickerResult? result;

      if (kIsWeb) {
        result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        );
      } else {
        result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        );
      }

      if (result != null && result.files.single.path != null) {
        if (kIsWeb) {
          // Web upload
          final fileBytes = result.files.single.bytes;
          final fileName = result.files.single.name;
          final fileExtension = fileName.split('.').last;

          if (fileBytes != null) {
            await documentsService.uploadDocumentFromBytes(
              providerId: widget.providerId,
              documentType: _selectedDocumentType,
              documentName: _documentNameController.text,
              fileBytes: fileBytes,
              fileExtension: fileExtension,
            );
          }
        } else {
          // Mobile upload
          final file = File(result.files.single.path!);
          await documentsService.uploadDocument(
            providerId: widget.providerId,
            documentType: _selectedDocumentType,
            documentName: _documentNameController.text,
            file: file,
          );
        }

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Document uploaded successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No file selected')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading document: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Upload Document'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: _selectedDocumentType,
                decoration: const InputDecoration(
                  labelText: 'Document Type',
                  border: OutlineInputBorder(),
                ),
                items: _documentTypes.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type.toUpperCase()),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedDocumentType = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _documentNameController,
                decoration: const InputDecoration(
                  labelText: 'Document Name',
                  border: OutlineInputBorder(),
                  hintText: 'e.g., Aadhar Card Front',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a document name';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isUploading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isUploading ? null : _uploadDocument,
          child: _isUploading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Upload'),
        ),
      ],
    );
  }
}

